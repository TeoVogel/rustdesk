import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/constants.dart';
import 'package:flutter_hbb/kvm/models/kvm_folder.dart';
import 'package:flutter_hbb/kvm/models/kvm_tenant.dart';
import 'package:http/http.dart' as http;

abstract class KVMApi {
  static String getKVMApiUrl(String endpoint) => "$kvmApi/$endpoint";

  static Map<String, String> getKVMHttpHeaders(String? authToken) {
    return {'Authorization': 'Bearer $authToken'};
  }

  static Future<String> login(String username, String password) async {
    final endpoint = "auth/token";
    try {
      var headers = getKVMHttpHeaders(null);
      headers['Content-Type'] = "application/x-www-form-urlencoded";
      final response = await http.post(
        Uri.parse(getKVMApiUrl(endpoint)),
        headers: headers,
        body: {"username": username, "password": password},
      );

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('access_token')) {
        return json['access_token'];
      } else {
        throw KVMApiError();
      }
    } catch (err) {
      debugPrint(err.toString());
      throw KVMApiError();
    }
  }

  static Future<Iterable<KVMTenant>> getTenants({String? authToken}) async {
    final endpoint = "tenants/";
    try {
      var headers = getKVMHttpHeaders(authToken);
      headers['Content-Type'] = "application/x-www-form-urlencoded";
      final response = await http.get(
        Uri.parse(getKVMApiUrl(endpoint)),
        headers: headers,
      );

      if (response.body.contains("Authentication required.")) {
        throw KVMAuthError();
      }

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('items')) {
        return (json["items"] as Iterable<dynamic>)
            .map((e) => KVMTenant.fromJson(e));
      } else {
        throw KVMApiError();
      }
    } catch (err) {
      debugPrint(err.toString());
      throw KVMApiError();
    }
  }

  static Future<Iterable<KVMFolder>> getFolders(int tenantId,
      {String? authToken}) async {
    final endpoint = "folders/";
    try {
      var headers = getKVMHttpHeaders(authToken);
      headers['Content-Type'] = "application/x-www-form-urlencoded";
      final response = await http.get(
        Uri.parse("${getKVMApiUrl(endpoint)}?tenant_id=$tenantId"),
        headers: headers,
      );

      if (response.body.contains("Authentication required.")) {
        throw KVMAuthError();
      }

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('items')) {
        return (json["items"] as Iterable<dynamic>)
            .map((e) => KVMFolder.fromJson(e));
      } else {
        throw KVMApiError();
      }
    } catch (err) {
      debugPrint(err.toString());
      throw KVMApiError();
    }
  }

  static Future<int> registerDevice(KVMFolder folder, String deviceName,
      {String? authToken}) async {
    final endpoint = "devices/";
    try {
      var headers = getKVMHttpHeaders(authToken);
      headers['Content-Type'] = "application/json";
      final response = await http.post(Uri.parse(getKVMApiUrl(endpoint)),
          headers: headers,
          body: jsonEncode(
            {
              "name": deviceName,
              "ip_address": "",
              "mac_address": "",
              "id_rust": "",
              "pass_rust": "",
              "last_screenshot_path": "",
              "folder_id": folder.id,
              "os_name": "",
              "os_version": "",
              "os_kernel_version": "",
              "vendor_name": "",
              "vendor_model": "",
              "vendor_cores": 0,
              "vendor_ram_gb": 0
            },
          ));

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('id')) {
        return json['id'];
      } else {
        throw KVMApiError();
      }
    } catch (err) {
      debugPrint(err.toString());
      throw KVMApiError();
    }
  }

  static Future<String> heartbeat(
    int deviceId, {
    String? rustId,
    String? rustPass,
    String? authToken,
  }) async {
    final endpoint = "devices/$deviceId/heartbeat";
    try {
      var headers = getKVMHttpHeaders(authToken);
      headers['Content-Type'] = "application/json";
      final response = await http.post(
        Uri.parse(getKVMApiUrl(endpoint)),
        headers: headers,
        body: rustId != null || rustPass != null
            ? jsonEncode(
                {
                  "id_rust": rustId,
                  "pass_rust": rustPass,
                },
              )
            : jsonEncode({}),
      );

      Map<String, dynamic> json = jsonDecode(response.body);
      if (response.statusCode == 200 && json.containsKey('timestamp')) {
        return json['timestamp'];
      } else {
        throw KVMApiError();
      }
    } catch (err) {
      debugPrint(err.toString());
      throw KVMApiError();
    }
  }
}

class KVMApiError implements Exception {
  final String message;

  KVMApiError({String? error}) : message = error ?? "Something went wrong";
}

class KVMAuthError implements Exception {
  final String message;

  KVMAuthError({String? error}) : message = error ?? "Session expired";
}
