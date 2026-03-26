package com.carriez.flutter_hbb

/**
 * Handle remote input and dispatch android gesture
 *
 * Inspired by [droidVNC-NG] https://github.com/bk138/droidVNC-NG
 */

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.widget.EditText
import android.view.accessibility.AccessibilityEvent
import android.view.ViewGroup.LayoutParams
import android.view.accessibility.AccessibilityNodeInfo
import android.graphics.Rect
import android.accessibilityservice.AccessibilityServiceInfo
import android.accessibilityservice.AccessibilityServiceInfo.FLAG_INPUT_METHOD_EDITOR
import android.accessibilityservice.AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
import android.view.inputmethod.EditorInfo
import androidx.annotation.RequiresApi
import java.util.*
import java.lang.Character
import kotlin.math.abs
import kotlin.math.max
import hbb.MessageOuterClass.KeyEvent
import hbb.MessageOuterClass.KeyboardMode
import hbb.KeyEventConverter

import java.io.BufferedReader
import java.io.IOException
import java.io.InputStreamReader
import java.nio.charset.Charset
import java.util.concurrent.TimeUnit

const val LIFT_DOWN = 9
const val LIFT_MOVE = 8
const val LIFT_UP = 10
const val RIGHT_UP = 18
const val WHEEL_BUTTON_DOWN = 33
const val WHEEL_BUTTON_UP = 34
const val WHEEL_DOWN = 523331
const val WHEEL_UP = 963

const val TOUCH_SCALE_START = 1
const val TOUCH_SCALE = 2
const val TOUCH_SCALE_END = 3
const val TOUCH_PAN_START = 4
const val TOUCH_PAN_UPDATE = 5
const val TOUCH_PAN_END = 6

const val WHEEL_STEP = 120
const val WHEEL_DURATION = 50L
const val LONG_TAP_DELAY = 200L

class InputService : AccessibilityService() {

    companion object {
        var ctx: InputService? = null
        val isOpen: Boolean
            get() = ctx != null
    }

    private val logTag = "input service"

    // ------------------------------------------------------------------
    // FIX #1 - re-entrancy guard: prevents ADB injection from looping
    // back through the IME pipeline on certain devices/ROMs and firing
    // onKeyEvent a second time.
    // ------------------------------------------------------------------
    private var isInjectingKey = false

    private var leftIsDown = false
    private var touchPath = Path()
    private var lastTouchGestureStartTime = 0L
    private var mouseX = 0
    private var mouseY = 0
    private var timer = Timer()
    private var recentActionTask: TimerTask? = null

    private val wheelActionsQueue = LinkedList<GestureDescription>()
    private var isWheelActionsPolling = false
    private var isWaitingLongPress = false

    private var fakeEditTextForTextStateCalculation: EditText? = null

    // ------------------------------------------------------------------
    // FIX #3 - cache the keyboard event device path so findKeyboardEvent()
    // doesn't shell-exec on every single Ctrl combo.
    // ------------------------------------------------------------------
    private var cachedKeyboardEventDevice: String? = null

    @RequiresApi(Build.VERSION_CODES.N)
    fun onMouseInput(mask: Int, _x: Int, _y: Int) {
        val x = max(0, _x)
        val y = max(0, _y)

        if (mask == 0 || mask == LIFT_MOVE) {
            val oldX = mouseX
            val oldY = mouseY
            mouseX = x * SCREEN_INFO.scale
            mouseY = y * SCREEN_INFO.scale
            if (isWaitingLongPress) {
                val delta = abs(oldX - mouseX) + abs(oldY - mouseY)
                Log.d(logTag,"delta:$delta")
                if (delta > 8) {
                    isWaitingLongPress = false
                }
            }
        }

        // left button down ,was up
        if (mask == LIFT_DOWN) {
            isWaitingLongPress = true
            timer.schedule(object : TimerTask() {
                override fun run() {
                    if (isWaitingLongPress) {
                        isWaitingLongPress = false
                        leftIsDown = false
                        endGesture(mouseX, mouseY)
                    }
                }
            }, LONG_TAP_DELAY * 4)

            leftIsDown = true
            startGesture(mouseX, mouseY)
            return
        }

        // left down ,was down
        if (leftIsDown) {
            continueGesture(mouseX, mouseY)
        }

        // left up ,was down
        if (mask == LIFT_UP) {
            if (leftIsDown) {
                leftIsDown = false
                isWaitingLongPress = false
                endGesture(mouseX, mouseY)
                return
            }
        }

        if (mask == RIGHT_UP) {
            performGlobalAction(GLOBAL_ACTION_BACK)
            return
        }

        // long WHEEL_BUTTON_DOWN -> GLOBAL_ACTION_RECENTS
        if (mask == WHEEL_BUTTON_DOWN) {
            timer.purge()
            recentActionTask = object : TimerTask() {
                override fun run() {
                    performGlobalAction(GLOBAL_ACTION_RECENTS)
                    recentActionTask = null
                }
            }
            timer.schedule(recentActionTask, LONG_TAP_DELAY)
        }

        // wheel button up
        if (mask == WHEEL_BUTTON_UP) {
            if (recentActionTask != null) {
                recentActionTask!!.cancel()
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
            return
        }

        if (mask == WHEEL_DOWN) {
            if (mouseY < WHEEL_STEP) {
                return
            }
            val path = Path()
            path.moveTo(mouseX.toFloat(), mouseY.toFloat())
            path.lineTo(mouseX.toFloat(), (mouseY - WHEEL_STEP).toFloat())
            val stroke = GestureDescription.StrokeDescription(
                path,
                0,
                WHEEL_DURATION
            )
            val builder = GestureDescription.Builder()
            builder.addStroke(stroke)
            wheelActionsQueue.offer(builder.build())
            consumeWheelActions()

        }

        if (mask == WHEEL_UP) {
            if (mouseY < WHEEL_STEP) {
                return
            }
            val path = Path()
            path.moveTo(mouseX.toFloat(), mouseY.toFloat())
            path.lineTo(mouseX.toFloat(), (mouseY + WHEEL_STEP).toFloat())
            val stroke = GestureDescription.StrokeDescription(
                path,
                0,
                WHEEL_DURATION
            )
            val builder = GestureDescription.Builder()
            builder.addStroke(stroke)
            wheelActionsQueue.offer(builder.build())
            consumeWheelActions()
        }
    }

    @RequiresApi(Build.VERSION_CODES.N)
    fun onTouchInput(mask: Int, _x: Int, _y: Int) {
        when (mask) {
            TOUCH_PAN_UPDATE -> {
                mouseX -= _x * SCREEN_INFO.scale
                mouseY -= _y * SCREEN_INFO.scale
                mouseX = max(0, mouseX);
                mouseY = max(0, mouseY);
                continueGesture(mouseX, mouseY)
            }
            TOUCH_PAN_START -> {
                mouseX = max(0, _x) * SCREEN_INFO.scale
                mouseY = max(0, _y) * SCREEN_INFO.scale
                startGesture(mouseX, mouseY)
            }
            TOUCH_PAN_END -> {
                endGesture(mouseX, mouseY)
                mouseX = max(0, _x) * SCREEN_INFO.scale
                mouseY = max(0, _y) * SCREEN_INFO.scale
            }
            else -> {}
        }
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun consumeWheelActions() {
        if (isWheelActionsPolling) {
            return
        } else {
            isWheelActionsPolling = true
        }
        wheelActionsQueue.poll()?.let {
            dispatchGesture(it, null, null)
            timer.purge()
            timer.schedule(object : TimerTask() {
                override fun run() {
                    isWheelActionsPolling = false
                    consumeWheelActions()
                }
            }, WHEEL_DURATION + 10)
        } ?: let {
            isWheelActionsPolling = false
            return
        }
    }

    private fun startGesture(x: Int, y: Int) {
        touchPath = Path()
        touchPath.moveTo(x.toFloat(), y.toFloat())
        lastTouchGestureStartTime = System.currentTimeMillis()
    }

    private fun continueGesture(x: Int, y: Int) {
        touchPath.lineTo(x.toFloat(), y.toFloat())
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun endGesture(x: Int, y: Int) {
        try {
            touchPath.lineTo(x.toFloat(), y.toFloat())
            var duration = System.currentTimeMillis() - lastTouchGestureStartTime
            if (duration <= 0) {
                duration = 1
            }
            val stroke = GestureDescription.StrokeDescription(
                touchPath,
                0,
                duration
            )
            val builder = GestureDescription.Builder()
            builder.addStroke(stroke)
            Log.d(logTag, "end gesture x:$x y:$y time:$duration")
            dispatchGesture(builder.build(), null, null)
        } catch (e: Exception) {
            Log.e(logTag, "endGesture error:$e")
        }
    }

    @RequiresApi(Build.VERSION_CODES.N)
    fun onKeyEvent(data: ByteArray) {
        val keyEvent = KeyEvent.parseFrom(data)
        val keyboardMode = keyEvent.getMode()

        Log.d("SIA", "onKeyEvent received - mode=$keyboardMode down=${keyEvent.getDown()} thread=${Thread.currentThread().name}")

        var textToCommit: String? = null

        if (keyboardMode == KeyboardMode.Legacy) {
            if (keyEvent.hasChr() && keyEvent.getDown()) {
                val chr = keyEvent.getChr()
                if (chr != null) {
                    textToCommit = String(Character.toChars(chr))
                }
            }
        } else if (keyboardMode == KeyboardMode.Translate) {
            if (keyEvent.hasSeq() && keyEvent.getDown()) {
                val seq = keyEvent.getSeq()
                if (seq != null) {
                    textToCommit = seq
                }
            }
        }

        Log.d(logTag, "onKeyEvent $keyEvent textToCommit:$textToCommit")
        Log.d("SIA", "onKeyEvent parsed - textToCommit=$textToCommit isInjectingKey=$isInjectingKey")

        if (Build.VERSION.SDK_INT >= 33) {
            Log.d("SIA", "onKeyEvent path: API>=33 branch")
            getInputMethod()?.let { inputMethod ->
                inputMethod.getCurrentInputConnection()?.let { inputConnection ->
                    if (textToCommit != null) {
                        Log.d("SIA", "onKeyEvent committing text via IME: $textToCommit")
                        textToCommit?.let { text ->
                            inputConnection.commitText(text, 1, null)
                        }
                    } else {
                        KeyEventConverter.toAndroidKeyEvent(keyEvent).let { event ->
                            Log.d("SIA", "onKeyEvent converting to Android KeyEvent: keyCode=${event?.keyCode} action=${event?.action}")
                            sendADBKey(event)
                        }
                    }
                } ?: Log.w("SIA", "onKeyEvent: getCurrentInputConnection() returned null")
            } ?: Log.w("SIA", "onKeyEvent: getInputMethod() returned null")
        } else {
            Log.d("SIA", "onKeyEvent path: legacy branch (API<33)")
            val handler = Handler(Looper.getMainLooper())
            handler.post {
                KeyEventConverter.toAndroidKeyEvent(keyEvent)?.let { event ->
                    val possibleNodes = possibleAccessibiltyNodes()
                    Log.d(logTag, "possibleNodes:$possibleNodes")
                    Log.d("SIA", "onKeyEvent legacy - possibleNodes count=${possibleNodes.size} keyCode=${event.keyCode} action=${event.action}")
                    for (item in possibleNodes) {
                        Log.d("SIA", "onKeyEvent legacy - sending ADB key for node: $item")
                        sendADBKey(event)
                        break
                    }
                } ?: Log.w("SIA", "onKeyEvent legacy - toAndroidKeyEvent returned null")
            }
        }
    }

    private fun sendADBKey(event: android.view.KeyEvent) {
        // ------------------------------------------------------------------
        // FIX #1 - re-entrancy guard.
        // On some ROMs, injecting via 'input keyevent' while inside the IME
        // callback causes onKeyEvent to fire again, doubling the input.
        // ------------------------------------------------------------------
        if (isInjectingKey) {
            Log.w("SIA", "sendADBKey BLOCKED - re-entrant call detected! keyCode=${event.keyCode} action=${event.action}")
            return
        }

        Log.d("SIA", "sendADBKey CALLED - keyCode=${event.keyCode} action=${event.action} isCtrlPressed=${event.isCtrlPressed} thread=${Thread.currentThread().name}")

        // ------------------------------------------------------------------
        // FIX #2 - handle Ctrl combos before the ACTION_UP guard so they
        // are never accidentally skipped.
        // ------------------------------------------------------------------
        if (event.isCtrlPressed && event.action == android.view.KeyEvent.ACTION_UP) {
            Log.d("SIA", "sendADBKey - detected Ctrl combo, delegating to sendCtrlCombo keyCode=${event.keyCode}")
            sendCtrlCombo(event.keyCode)
            return
        }

        // Only dispatch plain keys on ACTION_UP (avoids double-fire from
        // 'input keyevent' which internally generates DOWN + UP).
        if (event.action != android.view.KeyEvent.ACTION_UP) {
            Log.d("SIA", "sendADBKey - skipping, not ACTION_UP (action=${event.action})")
            return
        }

        Log.d("SIA", "sendADBKey - executing 'input keyevent ${event.keyCode}' via su")

        isInjectingKey = true
        var process: Process? = null
        try {
            val adbCommand = "input keyevent ${event.keyCode}\n"
            process = Runtime.getRuntime().exec("su")
            process.outputStream.use { outputStream ->
                outputStream.write(adbCommand.toByteArray(charset = Charsets.US_ASCII))
                outputStream.flush()
            }

            // ------------------------------------------------------------------
            // FIX #4 - waitFor with timeout so a hung su shell on a specific
            // device can't block indefinitely and let a second event race in.
            // ------------------------------------------------------------------
            val finished = process.waitFor(2, TimeUnit.SECONDS)
            if (!finished) {
                Log.w("SIA", "sendADBKey - process timed out for keyCode=${event.keyCode}, destroying")
                process.destroy()
            } else {
                Log.d("SIA", "sendADBKey - process finished, exitCode=${process.exitValue()} keyCode=${event.keyCode}")
            }
        } catch (e: IOException) {
            Log.e("SIA", "sendADBKey - IOException for keyCode=${event.keyCode}: $e")
            throw RuntimeException(e)
        } catch (e: Exception) {
            Log.e("SIA", "sendADBKey - Exception for keyCode=${event.keyCode}: $e")
            throw RuntimeException(e)
        } finally {
            isInjectingKey = false
            Log.d("SIA", "sendADBKey - isInjectingKey reset to false")
        }
    }

    private val androidToLinuxKeyMap = mapOf(
        android.view.KeyEvent.KEYCODE_A to 30, // KEY_A
        android.view.KeyEvent.KEYCODE_B to 48,
        android.view.KeyEvent.KEYCODE_C to 46,
        android.view.KeyEvent.KEYCODE_D to 32,
        android.view.KeyEvent.KEYCODE_E to 18,
        android.view.KeyEvent.KEYCODE_F to 33,
        android.view.KeyEvent.KEYCODE_G to 34,
        android.view.KeyEvent.KEYCODE_H to 35,
        android.view.KeyEvent.KEYCODE_I to 23,
        android.view.KeyEvent.KEYCODE_J to 36,
        android.view.KeyEvent.KEYCODE_K to 37,
        android.view.KeyEvent.KEYCODE_L to 38,
        android.view.KeyEvent.KEYCODE_M to 50,
        android.view.KeyEvent.KEYCODE_N to 49,
        android.view.KeyEvent.KEYCODE_O to 24,
        android.view.KeyEvent.KEYCODE_P to 25,
        android.view.KeyEvent.KEYCODE_Q to 16,
        android.view.KeyEvent.KEYCODE_R to 19,
        android.view.KeyEvent.KEYCODE_S to 31,
        android.view.KeyEvent.KEYCODE_T to 20,
        android.view.KeyEvent.KEYCODE_U to 22,
        android.view.KeyEvent.KEYCODE_V to 47,
        android.view.KeyEvent.KEYCODE_W to 17,
        android.view.KeyEvent.KEYCODE_X to 45,
        android.view.KeyEvent.KEYCODE_Y to 21,
        android.view.KeyEvent.KEYCODE_Z to 44
    )

    fun sendCtrlCombo(androidKeyCode: Int) {
        Log.d("SIA", "sendCtrlCombo - androidKeyCode=$androidKeyCode")
        val linuxKeyCode = androidToLinuxKeyMap[androidKeyCode]
        if (linuxKeyCode == null) {
            Log.w("SIA", "sendCtrlCombo - no Linux key mapping for androidKeyCode=$androidKeyCode, aborting")
            return
        }

        Log.d("SIA", "sendCtrlCombo - mapped to linuxKeyCode=$linuxKeyCode")
        val event = findKeyboardEvent()
        Log.d("SIA", "sendCtrlCombo - using device=$event")

        val cmd = """
        sendevent $event 1 29 1
        sendevent $event 1 $linuxKeyCode 1
        sendevent $event 1 $linuxKeyCode 0
        sendevent $event 1 29 0
        sendevent $event 0 0 0
    """.trimIndent()

        val process = Runtime.getRuntime().exec("su")
        process.outputStream.use {
            it.write(cmd.toByteArray())
            it.flush()
        }
        val finished = process.waitFor(2, TimeUnit.SECONDS)
        if (!finished) {
            Log.w("SIA", "sendCtrlCombo - process timed out for linuxKeyCode=$linuxKeyCode, destroying")
            process.destroy()
        } else {
            Log.d("SIA", "sendCtrlCombo - process finished exitCode=${process.exitValue()}")
        }
    }

    fun findKeyboardEvent(): String {
        // ------------------------------------------------------------------
        // FIX #3 - return cached device path instead of shell-execing every
        // time a Ctrl combo fires.
        // ------------------------------------------------------------------
        cachedKeyboardEventDevice?.let {
            Log.d("SIA", "findKeyboardEvent - returning cached device: $it")
            return it
        }

        Log.d("SIA", "findKeyboardEvent - cache miss, running getevent -lp via su")
        val process = Runtime.getRuntime().exec("su")
        process.outputStream.use {
            it.write("getevent -lp\n".toByteArray())
            it.flush()
        }

        val output = process.inputStream.bufferedReader().readText()
        process.waitFor()

        val devices = output.split("add device")
        Log.d("SIA", "findKeyboardEvent - found ${devices.size} device blocks")

        for (device in devices) {
            if (
                device.contains("KEY_LEFTCTRL") ||
                device.contains("KEY_A") && device.contains("KEY_Z")
            ) {
                val match = Regex("/dev/input/event\\d+").find(device)
                if (match != null) {
                    val found = match.value
                    Log.d("SIA", "findKeyboardEvent - matched keyboard device: $found")
                    cachedKeyboardEventDevice = found
                    return found
                }
            }
        }

        Log.e("SIA", "findKeyboardEvent - no keyboard device found in getevent output")
        throw IllegalStateException("Keyboard device not found")
    }

    fun sendCtrlF() {
        Log.d("SIA", "sendCtrlF - called")
        val event = findKeyboardEvent()
        Log.d("SIA", "sendCtrlF - using device=$event")

        val cmd = """
            sendevent $event 1 29 1
            sendevent $event 1 33 1
            sendevent $event 1 33 0
            sendevent $event 1 29 0
            sendevent $event 0 0 0
        """.trimIndent()

        val process = Runtime.getRuntime().exec("su")
        process.outputStream.use {
            it.write(cmd.toByteArray())
            it.flush()
        }
        val finished = process.waitFor(2, TimeUnit.SECONDS)
        if (!finished) {
            Log.w("SIA", "sendCtrlF - process timed out, destroying")
            process.destroy()
        } else {
            Log.d("SIA", "sendCtrlF - process finished exitCode=${process.exitValue()}")
        }
    }

    private fun insertAccessibilityNode(list: LinkedList<AccessibilityNodeInfo>, node: AccessibilityNodeInfo) {
        if (node == null) {
            return
        }
        if (list.contains(node)) {
            return
        }
        list.add(node)
    }

    private fun findChildNode(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) {
            return null
        }
        if (node.isEditable() && node.isFocusable()) {
            return node
        }
        val childCount = node.getChildCount()
        for (i in 0 until childCount) {
            val child = node.getChild(i)
            if (child != null) {
                if (child.isEditable() && child.isFocusable()) {
                    return child
                }
                if (Build.VERSION.SDK_INT < 33) {
                    child.recycle()
                }
            }
        }
        for (i in 0 until childCount) {
            val child = node.getChild(i)
            if (child != null) {
                val result = findChildNode(child)
                if (Build.VERSION.SDK_INT < 33) {
                    if (child != result) {
                        child.recycle()
                    }
                }
                if (result != null) {
                    return result
                }
            }
        }
        return null
    }

    private fun possibleAccessibiltyNodes(): LinkedList<AccessibilityNodeInfo> {
        val linkedList = LinkedList<AccessibilityNodeInfo>()
        val latestList = LinkedList<AccessibilityNodeInfo>()

        val focusInput = findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
        var focusAccessibilityInput = findFocus(AccessibilityNodeInfo.FOCUS_ACCESSIBILITY)

        val rootInActiveWindow = getRootInActiveWindow()

        Log.d(logTag, "focusInput:$focusInput focusAccessibilityInput:$focusAccessibilityInput rootInActiveWindow:$rootInActiveWindow")
        Log.d("SIA", "possibleAccessibilityNodes - focusInput=$focusInput focusAccessibilityInput=$focusAccessibilityInput root=$rootInActiveWindow")

        if (focusInput != null) {
            if (focusInput.isFocusable() && focusInput.isEditable()) {
                insertAccessibilityNode(linkedList, focusInput)
                Log.d("SIA", "possibleAccessibilityNodes - focusInput added to primary list")
            } else {
                insertAccessibilityNode(latestList, focusInput)
                Log.d("SIA", "possibleAccessibilityNodes - focusInput added to fallback list (not editable/focusable)")
            }
        }

        if (focusAccessibilityInput != null) {
            if (focusAccessibilityInput.isFocusable() && focusAccessibilityInput.isEditable()) {
                insertAccessibilityNode(linkedList, focusAccessibilityInput)
                Log.d("SIA", "possibleAccessibilityNodes - focusAccessibilityInput added to primary list")
            } else {
                insertAccessibilityNode(latestList, focusAccessibilityInput)
                Log.d("SIA", "possibleAccessibilityNodes - focusAccessibilityInput added to fallback list")
            }
        }

        val childFromFocusInput = findChildNode(focusInput)
        Log.d(logTag, "childFromFocusInput:$childFromFocusInput")
        Log.d("SIA", "possibleAccessibilityNodes - childFromFocusInput=$childFromFocusInput")

        if (childFromFocusInput != null) {
            insertAccessibilityNode(linkedList, childFromFocusInput)
        }

        val childFromFocusAccessibilityInput = findChildNode(focusAccessibilityInput)
        if (childFromFocusAccessibilityInput != null) {
            insertAccessibilityNode(linkedList, childFromFocusAccessibilityInput)
        }
        Log.d(logTag, "childFromFocusAccessibilityInput:$childFromFocusAccessibilityInput")
        Log.d("SIA", "possibleAccessibilityNodes - childFromFocusAccessibilityInput=$childFromFocusAccessibilityInput")
        Log.d("SIA", "possibleAccessibilityNodes - final list size=${linkedList.size}")

        if (rootInActiveWindow != null) {
            insertAccessibilityNode(linkedList, rootInActiveWindow)
        }

        for (item in latestList) {
            insertAccessibilityNode(linkedList, item)
        }

        return linkedList
    }

    private fun trySendKeyEvent(event: android.view.KeyEvent, node: AccessibilityNodeInfo, textToCommit: String?): Boolean {
        node.refresh()
        this.fakeEditTextForTextStateCalculation?.setSelection(0,0)
        this.fakeEditTextForTextStateCalculation?.setText(null)

        val text = node.getText()
        var isShowingHint = false
        if (Build.VERSION.SDK_INT >= 26) {
            isShowingHint = node.isShowingHintText()
        }

        var textSelectionStart = node.textSelectionStart
        var textSelectionEnd = node.textSelectionEnd

        if (text != null) {
            if (textSelectionStart > text.length) {
                textSelectionStart = text.length
            }
            if (textSelectionEnd > text.length) {
                textSelectionEnd = text.length
            }
            if (textSelectionStart > textSelectionEnd) {
                textSelectionStart = textSelectionEnd
            }
        }

        var success = false

        Log.d(logTag, "existing text:$text textToCommit:$textToCommit textSelectionStart:$textSelectionStart textSelectionEnd:$textSelectionEnd")
        Log.d("SIA", "trySendKeyEvent - node=${node.className} text='$text' textToCommit=$textToCommit sel=[$textSelectionStart,$textSelectionEnd] isShowingHint=$isShowingHint")

        if (textToCommit != null) {
            if ((textSelectionStart == -1) || (textSelectionEnd == -1)) {
                Log.d("SIA", "trySendKeyEvent - no selection, setting full text to: $textToCommit")
                val newText = textToCommit
                this.fakeEditTextForTextStateCalculation?.setText(newText)
                success = updateTextForAccessibilityNode(node)
            } else if (text != null) {
                Log.d("SIA", "trySendKeyEvent - inserting '$textToCommit' at position $textSelectionStart")
                this.fakeEditTextForTextStateCalculation?.setText(text)
                this.fakeEditTextForTextStateCalculation?.setSelection(
                    textSelectionStart,
                    textSelectionEnd
                )
                this.fakeEditTextForTextStateCalculation?.text?.insert(textSelectionStart, textToCommit)
                success = updateTextAndSelectionForAccessibiltyNode(node)
            }
        } else {
            if (isShowingHint) {
                this.fakeEditTextForTextStateCalculation?.setText(null)
            } else {
                this.fakeEditTextForTextStateCalculation?.setText(text)
            }
            if (textSelectionStart != -1 && textSelectionEnd != -1) {
                Log.d(logTag, "setting selection $textSelectionStart $textSelectionEnd")
                this.fakeEditTextForTextStateCalculation?.setSelection(
                    textSelectionStart,
                    textSelectionEnd
                )
            }

            this.fakeEditTextForTextStateCalculation?.let {
                val rect = Rect()
                node.getBoundsInScreen(rect)

                it.layout(rect.left, rect.top, rect.right, rect.bottom)
                it.onPreDraw()
                if (event.action == android.view.KeyEvent.ACTION_DOWN) {
                    val succ = it.onKeyDown(event.getKeyCode(), event)
                    Log.d(logTag, "onKeyDown $succ")
                    Log.d("SIA", "trySendKeyEvent - onKeyDown result=$succ keyCode=${event.keyCode}")
                } else if (event.action == android.view.KeyEvent.ACTION_UP) {
                    val success = it.onKeyUp(event.getKeyCode(), event)
                    Log.d(logTag, "keyup $success")
                    Log.d("SIA", "trySendKeyEvent - onKeyUp result=$success keyCode=${event.keyCode}")
                } else {
                    Log.d("SIA", "trySendKeyEvent - unexpected action=${event.action}, skipping key dispatch")
                }
            }

            success = updateTextAndSelectionForAccessibiltyNode(node)
        }

        Log.d("SIA", "trySendKeyEvent - final success=$success")
        return success
    }

    fun updateTextForAccessibilityNode(node: AccessibilityNodeInfo): Boolean {
        var success = false
        this.fakeEditTextForTextStateCalculation?.text?.let {
            val arguments = Bundle()
            arguments.putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                it.toString()
            )
            success = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, arguments)
        }
        return success
    }

    fun updateTextAndSelectionForAccessibiltyNode(node: AccessibilityNodeInfo): Boolean {
        var success = updateTextForAccessibilityNode(node)

        if (success) {
            val selectionStart = this.fakeEditTextForTextStateCalculation?.selectionStart
            val selectionEnd = this.fakeEditTextForTextStateCalculation?.selectionEnd

            if (selectionStart != null && selectionEnd != null) {
                val arguments = Bundle()
                arguments.putInt(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_START_INT,
                    selectionStart
                )
                arguments.putInt(
                    AccessibilityNodeInfo.ACTION_ARGUMENT_SELECTION_END_INT,
                    selectionEnd
                )
                success = node.performAction(AccessibilityNodeInfo.ACTION_SET_SELECTION, arguments)
                Log.d(logTag, "Update selection to $selectionStart $selectionEnd success:$success")
            }
        }

        return success
    }


    override fun onAccessibilityEvent(event: AccessibilityEvent) {
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        ctx = this
        val info = AccessibilityServiceInfo()
        if (Build.VERSION.SDK_INT >= 33) {
            info.flags = FLAG_INPUT_METHOD_EDITOR or FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        } else {
            info.flags = FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        }
        setServiceInfo(info)
        fakeEditTextForTextStateCalculation = EditText(this)
        // Size here doesn't matter, we won't show this view.
        fakeEditTextForTextStateCalculation?.layoutParams = LayoutParams(100, 100)
        fakeEditTextForTextStateCalculation?.onPreDraw()
        val layout = fakeEditTextForTextStateCalculation?.getLayout()
        Log.d(logTag, "fakeEditTextForTextStateCalculation layout:$layout")
        Log.d(logTag, "onServiceConnected!")
    }

    override fun onDestroy() {
        Log.d("SIA", "onDestroy - clearing ctx and cachedKeyboardEventDevice")
        cachedKeyboardEventDevice = null
        ctx = null
        super.onDestroy()
    }

    override fun onInterrupt() {}
}
