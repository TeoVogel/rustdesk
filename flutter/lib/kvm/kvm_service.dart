import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/kvm/constants.dart';
import 'package:flutter_hbb/kvm/data/kvm_api.dart';
import 'package:flutter_hbb/kvm/domain/kvm_state_provider.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

class KVMService {
  static final KVMService _instance = KVMService._internal();

  KVMService._internal();

  factory KVMService() => _instance;

  final model = gFFI.serverModel;

  String? lastKnownRustId;
  String? lastKnownRustPass;
  DateTime lastHeartBeatTimestamp = DateTime.now();

  late KVMStateProvider kvmState;

  void start(KVMStateProvider kvmState) async {
    this.kvmState = kvmState;
    setHeartbeatRefreshRate();

    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      print('Serial No : ${androidInfo.serialNumber}');
      print('id : ${androidInfo.id}');
      print(androidInfo.id);
    }
  }

  static void setHeartbeatRefreshRate() {
    platformFFI.invokeMethod(
      AndroidKVMChannel.kSetHeartbeatRefreshRate,
      kHeartbeatDefaultRefreshRate,
    );
  }

  void checkCredentialsAndSendHeartBeat() {
    if (model.isStart) {
      final currentRustId = model.serverId.value.text.removeAllWhitespace;
      final currentRustPass = model.serverPasswd.value.text;

      String? sentRustId;
      String? sentRustPass;
      if (lastKnownRustId != currentRustId ||
          lastKnownRustPass != currentRustPass) {
        sentRustId = currentRustId;
        sentRustPass = currentRustPass;
      }
      var credentialsChanged = sentRustId != null || sentRustPass != null;
      var shouldSendHeartBeat = credentialsChanged ||
          lastHeartBeatTimestamp.isBefore(DateTime.now().subtract(
            Duration(seconds: heartBeatIntervalInSeconds),
          ));

      if (shouldSendHeartBeat) {
        sendHeartBeat(sentRustId, sentRustPass);
      }
    } else {
      debugPrint("KVM not seted up");
    }
  }

  void sendHeartBeat(String? sentRustId, String? sentRustPass) async {
    try {
      await KVMApi.heartbeat(
        kvmState.registeredDeviceId!,
        authToken: kvmState.authToken,
        rustId: sentRustId,
        rustPass: sentRustPass,
      );
      print("HEARTBEAT SENT");
      lastKnownRustId = sentRustId ?? lastKnownRustId;
      lastKnownRustPass = sentRustPass ?? lastKnownRustPass;
      lastHeartBeatTimestamp = DateTime.now();
    } on KVMAuthError {
      kvmState.onUserSessionExpired();
    } on KVMApiError {
      //
    }
  }

}
