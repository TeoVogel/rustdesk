# Bugfix: duplicación de caracteres al escribir en Android (rama `1.4.5_sia`)

**Rama del fix:** `1.4.5_sia-fix-key-dup` (copia de `1.4.5_sia`; **no** modificar `1.4.5_sia`)
**Archivo:** `flutter/android/app/src/main/kotlin/com/carriez/flutter_hbb/InputService.kt`
**Síntoma:** al escribir en el dispositivo Android controlado, los caracteres se duplican.
Ej.: se teclea `aurora` y llega `aurooraa`.

---

## TL;DR

Cada carácter imprimible se estaba inyectando **dos veces**:

1. En el **key-down**, vía `sendADBText()` → `input text "<char>"`.
2. En el **key-up**, vía `sendADBKey()` → `input keyevent <keyCode>` (que **también** teclea el carácter).

El fix ignora `sendADBKey()` para teclas imprimibles (las que ya se enviaron con
`input text`), reenviando por `input keyevent` **solo** teclas no imprimibles
(Enter, Backspace, flechas, Tab…) y los combos Ctrl.

---

## Contexto de esta rama

Esta rama (`1.4.5_sia`) reemplazó el mecanismo estándar de RustDesk para inyectar
input en Android (`InputConnection.commitText()` / nodos de accesibilidad) por
**inyección con root (`su`)** usando comandos de shell:

- `sendADBText(text)` → `input text "<text>"`
- `sendADBKey(event)` → `input keyevent <keyCode>`

Esto es específico de este fork; **no existe en `master`** (por eso `sendADBKey`
no aparece en la rama principal).

## Cómo llega un carácter (modo Legacy)

Controlando Android **siempre se usa el modo Legacy**
(`flutter/lib/models/input_model.dart`, `legacyKeyboardModeRaw`). Por cada tecla
el controlador envía **dos** mensajes `KeyEvent` (protobuf):

| Mensaje | `down` | `press` | `chr` |
|---------|:------:|:-------:|:-----:|
| key-down | `true`  | `false` | sí (p. ej. `o`) |
| key-up   | `false` | `false` | sí (p. ej. `o`) |

## El flujo defectuoso en `onKeyEvent()`

```kotlin
// Legacy: textToCommit se setea SOLO si (down || press)
if (keyEvent.hasChr() && (keyEvent.getDown() || keyEvent.getPress())) {
    textToCommit = String(Character.toChars(keyEvent.getChr()))
}
...
if (textToCommit != null) {
    sendADBText(text)        // <-- key-DOWN: escribe el carácter con `input text`
} else {
    ke?.let { sendADBKey(it) } // <-- key-UP:  vuelve a escribirlo con `input keyevent`
}
```

Traza para la letra `o`:

| Evento | `textToCommit` | Rama | Comando shell | Efecto |
|--------|:--------------:|------|---------------|--------|
| **down** | `"o"`  | `sendADBText` | `input text "o"`          | escribe `o` ✅ |
| **up**   | `null` | `sendADBKey`  | `input keyevent KEYCODE_O` | escribe `o` otra vez ❌ |

### Por qué `input keyevent` teclea la letra

En `KeyboardKeyEventMapper.kt` el `KeyEvent` de Android se construye así:

```kotlin
// chrValue termina siendo el KEYCODE (no el char); en Legacy:
chrValue = convertUnicodeToKeyCode(keyEventProto.getChr())   // 'o' -> KEYCODE_O
...
return KeyEvent(0, 0, action, chrValue, 0, modifiers)         // arg 4 = keyCode
```

Entonces el `up` produce un `KeyEvent` con `keyCode = KEYCODE_O`, y
`sendADBKey` ejecuta `input keyevent KEYCODE_O`. `input keyevent` inyecta una
pulsación **completa** (down+up) en el campo enfocado, por lo que escribe la letra.

### Por qué se ve intermitente (`aurooraa` y no `aauurroorraa`)

`sendADBText` y `sendADBKey` lanzan **dos procesos `su` independientes** que corren
en paralelo y compiten. Según el timing (latencia de `su`, orden de registro en el
campo), a veces la segunda inyección se registra y a veces no. El defecto de fondo
es determinístico (doble inyección); la observación es intermitente por la carrera.

---

## El fix

`sendADBKey()` no debe re-teclear caracteres imprimibles (ya fueron enviados por
`input text` en el key-down). Se agrega un guard usando `unicodeChar`
(0 = tecla no imprimible / de control):

```kotlin
if (event.action != KeyEventAndroid.ACTION_UP) {
    return
}

// Los caracteres imprimibles ya se inyectaron en el key-down vía `input text`
// (sendADBText). Reinyectarlos aquí como `input keyevent` los tecleaba de nuevo,
// causando duplicación (ej: "aurora" -> "aurooraa"). Solo reenviar teclas no
// imprimibles (Enter, Backspace, flechas, Tab, ...).
if (event.unicodeChar != 0) {
    return
}

// ... `input keyevent <keyCode>` (v3)
```

### Por qué es seguro (casos cubiertos)

- **Letras / números / símbolos:** `unicodeChar != 0` → no se reinyectan. Se
  escriben una sola vez (por `input text`). ✅
- **Combos Ctrl (Ctrl+F, etc.):** se manejan **antes** del guard
  (`if (event.isCtrlPressed && ACTION_UP) { sendCtrlCombo(...); return }`). ✅
- **Enter, Backspace, flechas, Tab:** son teclas de control, `unicodeChar == 0`
  → siguen pasando por `input keyevent`. ✅
- **Espacio:** se escribe con `input text` en el down; en el up `unicodeChar == 32`
  → se omite → no se duplica. ✅

---

## Cómo verificar

El código ya loguea cada paso. Con la tablet conectada por USB (y `su`/root
habilitado):

```bash
adb logcat -s ADBCommand
```

- **Antes del fix**, por cada letra aparecían **ambos**:
  `sendADBText from if` **y** `sendADBKey from if`.
- **Después del fix**, para letras aparece **solo** `sendADBText from if`.
  `sendADBKey` solo debe verse con teclas no imprimibles (Enter, Backspace, …).

Prueba manual: escribir `aurora` en un campo de texto del dispositivo controlado
y confirmar que llega `aurora` (sin letras repetidas).

---

## Fix relacionado: Ctrl + letra ya no teclea la letra

### El problema

Un combo tipo **Ctrl+F** generaba **dos** efectos a la vez:

| Evento | Qué hacía | Efecto |
|--------|-----------|--------|
| key-down (`chr='f'`, ctrl) | `sendADBText("f")` → `input text "f"` | escribía `f` ❌ |
| key-up (`chr='f'`, ctrl)   | `sendCtrlCombo(KEYCODE_F)` → `sendevent` | disparaba el atajo Ctrl+F ✅ |

Es decir, el atajo funcionaba pero **además se colaba la letra** en el campo.
`sendCtrlCombo` (vía `sendevent`, teclado virtual a nivel kernel) solo mapea A–Z
(`androidToLinuxKeyMap`); para otras teclas hace `return` (no-op), pero la letra
igual se tecleaba.

### La solución

No commitear el carácter como texto cuando hay un **modificador no-shift**
(Ctrl/Alt/Meta) activo — eso es un atajo, no escritura. Shift/CapsLock/NumLock
**no** cuentan (afectan el carácter, no son atajos).

```kotlin
// helper
private fun hasNonShiftModifier(keyEvent: KeyEvent): Boolean {
    return keyEvent.getModifiersList().any { modifier ->
        when (modifier) {
            ControlKey.Control, ControlKey.RControl,
            ControlKey.Alt, ControlKey.RAlt,
            ControlKey.Meta -> true
            else -> false
        }
    }
}

// en la rama Legacy de onKeyEvent:
if (keyEvent.hasChr() && (keyEvent.getDown() || keyEvent.getPress())
        && !hasNonShiftModifier(keyEvent)) {
    textToCommit = String(Character.toChars(keyEvent.getChr()))
}
```

Traza de Ctrl+F después del fix:

| Evento | `textToCommit` | Rama | Efecto |
|--------|:--------------:|------|--------|
| **down** | `null` (bloqueado por el modificador) | `sendADBKey(down)` → `action != UP` → return | nada |
| **up**   | `null` | `sendADBKey(up)` → `isCtrlPressed` → `sendCtrlCombo(F)` | dispara **solo** el atajo ✅ |

Requiere el import `import hbb.MessageOuterClass.ControlKey`.

---

## Caveats / trabajo futuro (fuera del alcance de estos fixes)

- La inyección por `su` + shell (`input text` / `input keyevent` / `sendevent`)
  depende de root y es sensible a timing. A mediano plazo conviene evaluar volver
  al camino estándar (`commitText` / accesibilidad) del upstream, que no requiere
  root.
- `sendCtrlCombo` solo mapea **A–Z**. Combos como Ctrl+1, Ctrl+`,` etc. no se
  inyectan (hace `return`). Con el fix ya **no** teclean la letra, pero tampoco
  ejecutan el atajo — quedan sin efecto. Ampliar `androidToLinuxKeyMap` si hace
  falta.

---

## Requisitos de rama

- **No modificar `1.4.5_sia`.** El trabajo va en la copia `1.4.5_sia-fix-key-dup`.
- Commit del fix: ver `git log` de la rama (`fix(android): evitar duplicacion de
  caracteres al escribir`).
