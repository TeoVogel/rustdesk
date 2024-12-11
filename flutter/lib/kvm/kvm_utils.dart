import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:disk_space/disk_space.dart';
import 'package:system_info2/system_info2.dart';
import 'package:windows_system_info/windows_system_info.dart';

abstract class KVMUtils {
  static Future<String> getSerialNO() async {
    if (Platform.isAndroid) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.serialNumber.contains("unknown")) {
        return androidInfo.id;
      }
      return androidInfo.serialNumber;
    } else if (Platform.isWindows) {
      return getMACs().toString();
    }
    return "unknown";
  }

  static String getOSName() => Platform.isAndroid
      ? "android"
      : Platform.isWindows
          ? "windows"
          : "unknown";

  static Future<String> getOSVersion() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      return androidInfo.version.release;
    } else if (Platform.isWindows) {
      WindowsDeviceInfo windowsDeviceInfo = await deviceInfo.windowsInfo;
      return windowsDeviceInfo.majorVersion.toString();
    }
    return "unknown";
  }

  static Future<String> getIPs() async {
    return (await NetworkInterface.list())
        .expand((e) => e.addresses)
        .map((e) => e.address)
        .toString();
  }

  static Future<Iterable<String>> getMACs() async {
    if (Platform.isWindows) {
      await WindowsSystemInfo.initWindowsInfo();
      if (await WindowsSystemInfo.isInitilized) {
        return WindowsSystemInfo.network.map((e) => e.mac);
      }
    }
    return [];
  }

  static int getUsedRAMInMB() {
    return (SysInfo.getTotalPhysicalMemory() -
            SysInfo.getFreePhysicalMemory()) ~/
        (1024 * 1024);
  }

  static Future<int> getFreeDiskSpaceInMB() async {
    return (await DiskSpace.getFreeDiskSpace)?.toInt() ?? -1;
  }
}
