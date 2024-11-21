import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';

abstract class KVMUtils {
  static Future<String> getSerialNO() async {
    if (isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      debugPrint("SerialNO: ${androidInfo.serialNumber}");
      if (androidInfo.serialNumber.contains("unknown")) {
        debugPrint("Android id: ${androidInfo.id}");
        return androidInfo.id;
      }
      return androidInfo.serialNumber;
    } else {
      return "desktop";
    }
  }
}
