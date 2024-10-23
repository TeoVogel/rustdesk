import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/data/kvm_api.dart';
import 'package:flutter_hbb/kvm/data/kvm_session_datasource.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_device.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_tenant.dart';

class KVMStateProvider with ChangeNotifier {

  KVMStateProvider() {
    kvmSessionDatasource.getAuthToken().then((value) {
      if (value != null) {
        _setAuthToken(value);
      }
    });
  }

  final kvmSessionDatasource = KVMSessionDatasource();

  String? authToken;
  KVMFolder? selectedFolder;
  int? registeredDeviceId;

  bool get isKVMSetedup => authToken != null && selectedFolder != null;

  void onLoginSuccess(String authToken, String email, String password) {
    kvmSessionDatasource.storeLoginEmail(email);
    kvmSessionDatasource.storeLoginPassword(password);
    _setAuthToken(authToken);
  }

  void onUserSessionExpired() {
    _setAuthToken(null);
  }

  void _setAuthToken(String? authToken) {
    if (this.authToken != authToken) {
      this.authToken = authToken;
      kvmSessionDatasource.storeAuthToken(authToken);
      notifyListeners();
    }
  }

  void setSelectedFolder(KVMFolder? selectedFolder) {
    if (this.selectedFolder != selectedFolder) {
      this.selectedFolder = selectedFolder;
      notifyListeners();
    }
  }

  void setRegisteredDeviceId(int? registeredDeviceId) {
    this.registeredDeviceId = registeredDeviceId;
    notifyListeners();
  }

  Future<T> _apiRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on KVMAuthError catch (e) {
      onUserSessionExpired();
    } on KVMApiError catch (e) {
      return Future.error("Algo salió mal");
    }
    return Future.error("Algo salió mal");
  }

  Future<KVMDevice?> login(String email, String password) async {
    return _apiRequest(() async {
      final (authToken, device) = await KVMApi.login(email, password, "1");
      onLoginSuccess(authToken, email, password);
      return device;
    });
  }

  Future<Iterable<KVMTenant>> fetchTenants() async {
    return _apiRequest(() {
      return KVMApi.getTenants(authToken: authToken);
    });
  }

  Future<int> registerDevice(KVMFolder folder, String deviceName) async {
    final trimmedDeviceName = deviceName.trim();
    if (trimmedDeviceName.isEmpty) {
      return Future.error("El nombre no puede ser vacío");
    }
    return _apiRequest(() {
      return KVMApi.registerDevice(
        folder,
        trimmedDeviceName,
        authToken: authToken,
      );
    });
  }
}
