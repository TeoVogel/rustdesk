import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KVMSessionDatasource {
  final _storage = FlutterSecureStorage();

  final refreshTokenStorageKey = "refreshTokenStorageKey";

  final loginEmailStorageKey = "loginEmailStorageKey";
  final loginPasswordStorageKey = "loginPasswordStorageKey";

  final deviceIdStorageKey = "deviceIdStorageKey";

  final serverNameStorageKey = "serverNameStorageKey";
  final serverUseHttpsStorageKey = "serverUseHttpsStorageKey";
  final serverBaseUrlOverrideStorageKey = "serverBaseUrlOverrideStorageKey";

  Future<String?> getRefreshToken() => _get(refreshTokenStorageKey);
  void storeRefreshToken(String? token) {
    _store(refreshTokenStorageKey, token);
  }

  Future<String?> getLoginEmail() => _get(loginEmailStorageKey);
  void storeLoginEmail(String? emaiil) {
    _store(loginEmailStorageKey, emaiil);
  }

  Future<String?> getLoginPassword() => _get(loginPasswordStorageKey);
  void storeLoginPassword(String? password) {
    _store(loginPasswordStorageKey, password);
  }

  Future<int?> getDeviceId() async {
    final deviceIdString = await _get(deviceIdStorageKey);
    return deviceIdString != null ? int.parse(deviceIdString) : null;
  }

  void storeDeviceId(int? deviceId) {
    _store(deviceIdStorageKey, deviceId?.toString());
  }

  Future<String?> getServerName() => _get(serverNameStorageKey);
  void storeServerName(String? name) {
    _store(serverNameStorageKey, name);
  }

  Future<bool?> getServerUseHttps() async {
    final useHttpsString = await _get(serverUseHttpsStorageKey);
    return useHttpsString != null ? useHttpsString == "true" : null;
  }

  void storeServerUseHttps(bool? useHttps) {
    _store(serverUseHttpsStorageKey, useHttps?.toString());
  }

  Future<String?> getServerBaseUrlOverride() =>
      _get(serverBaseUrlOverrideStorageKey);
  void storeServerBaseUrlOverride(String? baseUrlOverride) {
    _store(serverBaseUrlOverrideStorageKey, baseUrlOverride);
  }

  void _store(String key, String? value) {
    _storage.write(key: key, value: value);
  }

  Future<String?> _get(String key) {
    return _storage.read(key: key);
  }
}
