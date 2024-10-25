

import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/data/kvm_api.dart';
import 'package:flutter_hbb/kvm/data/kvm_session_datasource.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_device.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_tenant.dart';
import 'package:flutter_hbb/kvm/kvm_utils.dart';
import 'package:flutter_hbb/kvm/presentation/kvm_state.dart';

class KVMStateProvider with ChangeNotifier {

  KVMStateProvider() {
    kvmSessionDatasource.getAuthToken().then((value) {
      if (value != null) {
        onUserSessionExpired();
        //onSessionRestored(value);
      } else {
        onUserSessionExpired();
      }
    });
  }

  final kvmSessionDatasource = KVMSessionDatasource();

  final loginStepState = KVMStepLogin();
  final registerDeviceStepState = KVMStepRegisterDevice();
  final requestPermissionsStepState = KVMStepRequestPerissions();
  KVMStepState nextStepState = KVMStepInitializing();

  String? authToken;
  KVMDevice? device;

  int? get registeredDeviceId => device?.id;

  bool get isKVMSetedup => authToken != null && device != null;

  void onUserSessionExpired() {
    _setAuthToken(null);
    nextStepState = loginStepState;
    notifyListeners();
  }

  void onSessionRestored(String authToken) {
    _setAuthToken(authToken);
  }

  void onLoginSuccess(String authToken, String email, String password) {
    _setAuthToken(authToken);
    kvmSessionDatasource.storeLoginEmail(email);
    kvmSessionDatasource.storeLoginPassword(password);
    nextStepState = registerDeviceStepState;
    notifyListeners();
  }

  void _setAuthToken(String? authToken) {
    if (this.authToken != authToken) {
      this.authToken = authToken;
      kvmSessionDatasource.storeAuthToken(authToken);
    }
  }

  void onDeviceRegistered(KVMDevice device) {
    this.device = device;
    nextStepState = requestPermissionsStepState;
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
      final (authToken, device) = await KVMApi.login(
        email,
        password,
        await KVMUtils.getSerialNO(),
      );
      onLoginSuccess(authToken, email, password);
      return device;
    });
  }

  Future<Iterable<KVMTenant>> fetchTenants() async {
    return _apiRequest(() {
      return KVMApi.getTenants(authToken: authToken);
    });
  }

  Future<KVMDevice> registerDevice(KVMFolder folder, String deviceName) async {
    final trimmedDeviceName = deviceName.trim();
    if (trimmedDeviceName.isEmpty) {
      return Future.error("El nombre no puede ser vacío");
    }
    return _apiRequest(() async {
      final device = await KVMApi.registerDevice(
        folder,
        trimmedDeviceName,
        await KVMUtils.getSerialNO(),
        authToken: authToken,
      );
      onDeviceRegistered(device);
      return device;
    });
  }
  
}
