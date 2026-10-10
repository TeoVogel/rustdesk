/// Standard logger for the KVM integration.
///
/// Every line has the form `[KVM][<scope>] <L> <message>`, where `<L>` is
/// `I` (info), `W` (warning) or `E` (error). On Android it is written to
/// logcat under the `flutter` tag, in debug and release builds alike:
///
///   adb logcat -s flutter | grep "\[KVM\]"
///
/// Rules for callers:
/// - Keep messages short, one line, no stack traces.
/// - Never log secrets: passwords, access/refresh tokens, auth headers or the
///   RustDesk password. Request/response bodies are not logged for that reason.
///
/// `print` is used on purpose instead of `debugPrint` (which can be overridden
/// or throttled) or `dart:developer` `log` (which is dropped in release).
class KVMLog {
  final String scope;

  const KVMLog(this.scope);

  /// Server responses are truncated to this length when logged on errors.
  static const _maxDetailLength = 200;

  void i(String message) => _write('I', message);

  void w(String message) => _write('W', message);

  void e(String message, [Object? error]) =>
      _write('E', error == null ? message : '$message: ${_short(error)}');

  /// Shortens server responses and exception messages so a single entry stays
  /// readable in logcat.
  static String short(Object? value) => _short(value);

  static String _short(Object? value) {
    final text = value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= _maxDetailLength
        ? text
        : '${text.substring(0, _maxDetailLength)}…';
  }

  void _write(String level, String message) {
    // ignore: avoid_print
    print('[KVM][$scope] $level $message');
  }
}
