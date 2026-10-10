

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/kvm/constants.dart';
import 'package:flutter_hbb/kvm/data/kvm_api.dart';
import 'package:flutter_hbb/kvm/data/kvm_session_datasource.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_device.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_server_config.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_session.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_tenant.dart';
import 'package:flutter_hbb/kvm/kvm_utils.dart';
import 'package:flutter_hbb/kvm/presentation/kvm_state.dart';
import 'package:flutter_hbb/models/platform_model.dart';

class KVMStateProvider with ChangeNotifier {

  KVMStateProvider() {
    restoreSession();
  }

  static const _restoreTimeout = Duration(seconds: 20);

  final kvmSessionDatasource = KVMSessionDatasource();

  final loginStepState = KVMStepLogin();
  final registerDeviceStepState = KVMStepRegisterDevice();
  final requestPermissionsStepState = KVMStepRequestPerissions();
  KVMStepState nextStepState = KVMStepInitializing();

  KVMSession? session;
  KVMDevice? device;
  KVMServerModel serverConfig = kvmServers.last;

  KVMApi get api => KVMApi(baseUrl: serverConfig.resolvedBaseUrl);

  String? get authToken => session?.authToken;
  int? get registeredDeviceId => device?.id;

  bool get isKVMSetedup => session != null && device != null;

  /// Runs on every cold start (including when Android kills the process while
  /// the user is in the system settings granting permissions). It must always
  /// leave [nextStepState] out of [KVMStepInitializing], otherwise the
  /// onboarding screen shows a spinner forever.
  Future<void> restoreSession() async {
    if (nextStepState is! KVMStepInitializing) {
      nextStepState = KVMStepInitializing();
      notifyListeners();
    }
    try {
      // The server must be restored first so the refresh token is sent to the
      // backend that issued it.
      await _restoreServerConfig();

      final refreshToken = await kvmSessionDatasource.getRefreshToken();
      final deviceId = await kvmSessionDatasource.getDeviceId();
      if (refreshToken == null || deviceId == null) {
        onUserSessionExpired();
        return;
      }

      final session = await api
          .refreshToken(deviceId.toString(), refreshToken)
          .timeout(_restoreTimeout);
      final device = await api
          .getDevice(deviceId, authToken: session.authToken)
          .timeout(_restoreTimeout);
      onSessionRestored(session, device);
    } on KVMAuthError catch (_) {
      onUserSessionExpired();
    } catch (e) {
      debugPrint("KVM session restore failed: $e");
      nextStepState = KVMStepRestoreFailed(
        e is KVMApiError ? e.message : e.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> _restoreServerConfig() async {
    final serverName = await kvmSessionDatasource.getServerName();
    final server = kvmServers.firstWhere(
      (server) => server.name == serverName,
      orElse: () => serverConfig,
    );
    final useHttps = await kvmSessionDatasource.getServerUseHttps();
    if (useHttps != null) {
      server.useHttps = useHttps;
    }
    server.baseUrlResolutionOverride =
        await kvmSessionDatasource.getServerBaseUrlOverride();
    serverConfig = server;
  }

  void _storeServerConfig() {
    kvmSessionDatasource.storeServerName(serverConfig.name);
    kvmSessionDatasource.storeServerUseHttps(serverConfig.useHttps);
    kvmSessionDatasource
        .storeServerBaseUrlOverride(serverConfig.baseUrlResolutionOverride);
  }

  void onUserSessionExpired() {
    _setSession(null);
    kvmSessionDatasource.storeLoginEmail(null);
    kvmSessionDatasource.storeLoginPassword(null);
    kvmSessionDatasource.storeDeviceId(null);
    nextStepState = loginStepState;
    notifyListeners();
  }

  void onSessionRestored(KVMSession session, KVMDevice? device) {
    _setSession(session);
    if (device != null) {
      onDeviceRegistered(device);
    } else {
      nextStepState = registerDeviceStepState;
      notifyListeners();
    }
  }

  void onLoginSuccess(
      KVMSession session, KVMDevice? device, String email, String password) {
    _setSession(session);
    _storeServerConfig();
    kvmSessionDatasource.storeLoginEmail(email);
    kvmSessionDatasource.storeLoginPassword(password);
    kvmSessionDatasource.storeDeviceId(device?.id);
    nextStepState = registerDeviceStepState;
    notifyListeners();
  }

  void onRefreshToken(KVMSession session) {
    _setSession(session);
  }

  void _setSession(KVMSession? session) {
    this.session = session;
    kvmSessionDatasource.storeRefreshToken(session?.refreshToken);
  }

  void onDeviceRegistered(KVMDevice device) {
    this.device = device;
    kvmSessionDatasource.storeDeviceId(device.id);
    nextStepState = requestPermissionsStepState;
    notifyListeners();
  }

  Future<T> _apiRequest<T>(Future<T> Function() request) async {
    try {
      return await request();
    } on KVMAuthError catch (_) {
      onUserSessionExpired();
    } on KVMApiError catch (e) {
      return Future.error(e);
    }
    return Future.error(Exception("Algo salió mal"));
  }

  Future<KVMDevice?> login(String email, String password) async {
    return _apiRequest(() async {
      final (session, device) = await api.login(
        email,
        password,
        await KVMUtils.getSerialNO(),
      );
      this.device = device;
      onLoginSuccess(session, device, email, password);
      return device;
    });
  }

  Future<Iterable<KVMTenant>> fetchTenants() async {
    return _apiRequest(() {
      return api.getTenants(authToken: authToken);
    });
  }

  Future<KVMDevice> registerDevice(KVMFolder folder, String deviceName) async {
    final trimmedDeviceName = deviceName.trim();
    if (trimmedDeviceName.isEmpty) {
      return Future.error("El nombre no puede ser vacío");
    }
    return _apiRequest(() async {
      final device = await api.registerDevice(
        folder,
        trimmedDeviceName,
        await KVMUtils.getSerialNO(),
        authToken: authToken,
        soName: KVMUtils.getOSName(),
        soVersion: await KVMUtils.getOSVersion(),
        timeZone: DateTime.now().timeZoneName,
        localIps: await KVMUtils.getIPs(),
        macAddress: await KVMUtils.getMACs(), //does not work on Android
      );
      onDeviceRegistered(device);
      return device;
    });
  }

  Future<ServerConfig> getCurrentRustdeskServerConfig() async {
    Map<String, dynamic> options =
        await jsonDecode(await bind.mainGetOptions());

    return ServerConfig.fromOptions(options);
  }

  Future<bool> setRustdeskServerConfig(KVMServerModel serverConfig) async {
    this.serverConfig = serverConfig;
    _storeServerConfig();
    notifyListeners();
    return await setServerConfig(null, null, serverConfig.config);
  }

  /// Mutates the currently selected [serverConfig] (e.g. its `useHttps` flag or
  /// `baseUrlResolutionOverride`) and notifies listeners so the resolved
  /// [api] base url picks up the change.
  void updateServerConfig(void Function(KVMServerModel server) update) {
    update(serverConfig);
    _storeServerConfig();
    notifyListeners();
  }

}
