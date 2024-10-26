import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KVMSessionDatasource {
  final _storage = FlutterSecureStorage();

  final refreshTokenStorageKey = "refreshTokenStorageKey";
  final loginEmailStorageKey = "loginEmailStorageKey";
  final loginPasswordStorageKey = "loginPasswordStorageKey";

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

  void _store(String key, String? value) {
    _storage.write(key: key, value: value);
  }

  Future<String?> _get(String key) {
    return _storage.read(key: key);
  }
}
