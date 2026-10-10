import 'dart:convert';

import 'package:flutter_hbb/kvm/domain/models/kvm_device.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_session.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_tenant.dart';
import 'package:flutter_hbb/kvm/kvm_logger.dart';
import 'package:http/http.dart' as http;

class KVMApi {
  KVMApi({required this.baseUrl});

  static const _log = KVMLog('Api');

  final String baseUrl;

  String getKVMApiUrl(String endpoint) => "$baseUrl/$endpoint";

  /// Logs the request line and the response status/latency. Headers and
  /// bodies are never logged because they carry credentials and tokens; the
  /// response body is only included (truncated) on error statuses.
  Future<http.Response> _send(String method, String url,
      Future<http.Response> Function() request) async {
    _log.i("-> $method $url");
    final stopwatch = Stopwatch()..start();
    final response = await request();
    final summary =
        "<- $method $url ${response.statusCode} (${stopwatch.elapsedMilliseconds}ms)";
    if (response.statusCode >= 400) {
      _log.w("$summary ${KVMLog.short(response.body)}");
    } else {
      _log.i(summary);
    }
    return response;
  }

  Map<String, String> getKVMHttpHeaders(String? authToken) {
    return {
      'Authorization': 'Bearer $authToken',
      'accept': 'application/json',
    };
  }

  Future<(KVMSession, KVMDevice?)> login(
      String username, String password, String serialNO) async {
    final endpoint = "auth/token?serial_number=$serialNO";
    try {
      Map<String, String> headers = {'accept': 'application/json'};
      headers['Content-Type'] = "application/x-www-form-urlencoded";
      final url = getKVMApiUrl(endpoint);
      final body = {"username": username, "password": password};
      final response = await _send(
          "POST",
          url,
          () => http.post(
                Uri.parse(url),
                headers: headers,
                body: body,
              ));

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('access_token')) {
        final device = json['device'];
        return (
          KVMSession.fromJson(json),
          device != null ? KVMDevice.fromJson(device) : null
        );
      } else {
        throw KVMApiError(error: "${response.statusCode}: ${response.body}");
      }
    } catch (err) {
      _log.e("login failed", err);
      rethrow;
    }
  }

  Future<KVMSession> refreshToken(String deviceId, String refreshToken) async {
    final endpoint = "auth/device/$deviceId/login";
    try {
      Map<String, String> headers = {'accept': 'application/json'};
      headers['Content-Type'] = "application/json";
      final url = getKVMApiUrl(endpoint);
      final body = jsonEncode({
        "refresh_token": refreshToken,
      });
      final response = await _send(
          "POST",
          url,
          () => http.post(
                Uri.parse(url),
                headers: headers,
                body: body,
              ));

      // A rejected refresh token means the session is gone: surface it as an
      // auth error so callers send the user back to login instead of retrying.
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw KVMAuthError(error: "${response.statusCode}: ${response.body}");
      }

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('access_token')) {
        return KVMSession.fromJson(json);
      } else {
        throw KVMApiError(error: "${response.statusCode}: ${response.body}");
      }
    } on KVMAuthError catch (err) {
      _log.w("refreshToken: auth rejected (${KVMLog.short(err)})");
      rethrow;
    } catch (err) {
      _log.e("refreshToken failed", err);
      rethrow;
    }
  }

  Future<Iterable<KVMTenant>> getTenants({String? authToken}) async {
    final endpoint = "tenants/";
    try {
      var headers = getKVMHttpHeaders(authToken);
      headers['Content-Type'] = "application/x-www-form-urlencoded";
      final url = getKVMApiUrl(endpoint);
      final response = await _send(
          "GET",
          url,
          () => http.get(
                Uri.parse(url),
                headers: headers,
              ));

      if (response.body.contains("Authentication required.")) {
        throw KVMAuthError();
      }

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('items')) {
        return (json["items"] as Iterable<dynamic>)
            .map((e) => KVMTenant.fromJson(e));
      } else {
        throw KVMApiError(error: "${response.statusCode}: ${response.body}");
      }
    } on KVMAuthError catch (err) {
      _log.w("getTenants: auth rejected (${KVMLog.short(err)})");
      rethrow;
    } catch (err) {
      _log.e("getTenants failed", err);
      rethrow;
    }
  }

  Future<Iterable<KVMFolder>> getFolders(int tenantId,
      {String? authToken}) async {
    final endpoint = "folders/";
    try {
      var headers = getKVMHttpHeaders(authToken);
      headers['Content-Type'] = "application/x-www-form-urlencoded";
      final url = "${getKVMApiUrl(endpoint)}?tenant_id=$tenantId";
      final response = await _send(
          "GET",
          url,
          () => http.get(
                Uri.parse(url),
                headers: headers,
              ));

      if (response.body.contains("Authentication required.")) {
        throw KVMAuthError();
      }

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('items')) {
        return (json["items"] as Iterable<dynamic>)
            .map((e) => KVMFolder.fromJson(e));
      } else {
        throw KVMApiError(error: "${response.statusCode}: ${response.body}");
      }
    } on KVMAuthError catch (err) {
      _log.w("getFolders: auth rejected (${KVMLog.short(err)})");
      rethrow;
    } catch (err) {
      _log.e("getFolders failed", err);
      rethrow;
    }
  }

  Future<KVMDevice> registerDevice(
    KVMFolder folder,
    String deviceName,
    String serialNO, {
    String? soName,
    String? soVersion,
    String? timeZone,
    String? localIps,
    Iterable<String>? macAddress,
    String? authToken,
  }) async {
    final endpoint = "devices/";
    try {
      var headers = getKVMHttpHeaders(authToken);
      headers['Content-Type'] = "application/json";
      final url = getKVMApiUrl(endpoint);
      final body = jsonEncode(
        {
          "name": deviceName,
          "ip_address": "",
          "mac_address": "",
          "id_rust": "",
          "pass_rust": "",
          "last_screenshot_path": "",
          "serial_number": serialNO,
          "folder_id": folder.id,
          "SO_name": soName,
          "SO_version": soVersion,
          "time_zone": timeZone,
          "local_ips": localIps,
          "MAC_adresses": macAddress,
          "os_kernel_version": "",
          "vendor_name": "",
          "vendor_model": "",
          "vendor_cores": 0,
          "vendor_ram_gb": 0
        },
      );
      final response = await _send(
          "POST",
          url,
          () => http.post(
                Uri.parse(url),
                headers: headers,
                body: body,
              ));

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('id')) {
        return KVMDevice.fromJson(json);
      } else {
        throw KVMApiError(error: "${response.statusCode}: ${response.body}");
      }
    } on KVMAuthError catch (err) {
      _log.w("registerDevice: auth rejected (${KVMLog.short(err)})");
      rethrow;
    } catch (err) {
      _log.e("registerDevice failed", err);
      rethrow;
    }
  }

  Future<KVMDevice?> getDevice(
    int? deviceId, {
    String? authToken,
  }) async {
    if (deviceId == null) {
      return null;
    }

    final endpoint = "devices/$deviceId";
    try {
      var headers = getKVMHttpHeaders(authToken);
      headers['Content-Type'] = "application/json";
      final url = getKVMApiUrl(endpoint);
      final response = await _send(
          "GET",
          url,
          () => http.get(
                Uri.parse(url),
                headers: headers,
              ));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw KVMAuthError(error: "${response.statusCode}: ${response.body}");
      }

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('id')) {
        return KVMDevice.fromJson(json);
      } else {
        throw KVMApiError(error: "${response.statusCode}: ${response.body}");
      }
    } on KVMAuthError catch (err) {
      _log.w("getDevice: auth rejected (${KVMLog.short(err)})");
      rethrow;
    } catch (err) {
      _log.e("getDevice failed", err);
      rethrow;
    }
  }

  Future<int?> heartbeat(
    int deviceId, {
    String? rustId,
    String? rustPass,
    String? authToken,
    int? memLoadMb,
  }) async {
    final endpoint = "devices/$deviceId/heartbeat";
    try {
      // var headers = getKVMHttpHeaders(authToken);
      // test sending always null on header auth token
      var headers = getKVMHttpHeaders(null);
      headers['Content-Type'] = "application/json";
      final url = getKVMApiUrl(endpoint);
      final body = rustId != null || rustPass != null
          ? jsonEncode(
              {
                "id_rust": rustId,
                "pass_rust": rustPass,
                "MEM_load_mb": memLoadMb,
              },
            )
          : jsonEncode(
              {
                "MEM_load_mb": memLoadMb,
              },
            );
      final response = await _send(
          "POST",
          url,
          () => http.post(
                Uri.parse(url),
                headers: headers,
                body: body,
              ));

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('heartbeat_s')) {
        return json['heartbeat_s'];
      } else {
        throw KVMApiError(error: "${response.statusCode}: ${response.body}");
      }
    } on KVMAuthError catch (err) {
      _log.w("heartbeat: auth rejected (${KVMLog.short(err)})");
      rethrow;
    } catch (err) {
      _log.e("heartbeat failed", err);
      rethrow;
    }
  }
}

class KVMApiError implements Exception {
  final String message;

  KVMApiError({String? error}) : message = error ?? "Something went wrong";

  @override
  String toString() {
    return message;
  }
}

class KVMAuthError implements Exception {
  final String message;

  KVMAuthError({String? error}) : message = error ?? "Session expired";

  @override
  String toString() {
    return message;
  }
}
