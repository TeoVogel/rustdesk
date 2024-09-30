import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/kvm/kvm_api.dart';
import 'package:flutter_hbb/kvm/kvm_state.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

class KVMService {
  static final KVMService _instance = KVMService._internal();

  KVMService._internal();

  factory KVMService() => _instance;

  final model = gFFI.serverModel;

  final kvmServiceInterval = 20;

  String? lastKnownRustId;
  String? lastKnownRustPass;

  late KVMState kvmState;
  Timer? timer;

  void start(KVMState kvmState) async {
    this.kvmState = kvmState;
    setHeartbeatRefreshRate();
  }

  static void setHeartbeatRefreshRate() {
    platformFFI.invokeMethod(
      AndroidKVMChannel.kSetHeartbeatRefreshRate,
      kHeartbeatDefaultRefreshRate,
    );
  }

  void sendHeartBeat() async {
    print("HEARTBEAT SENT");
    if (kvmState.authToken != null && kvmState.registeredDeviceId != null) {
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
        try {
          await KVMApi.heartbeat(
            kvmState.registeredDeviceId!,
            authToken: kvmState.authToken,
            rustId: sentRustId,
            rustPass: sentRustPass,
          );
          debugPrint("current: $currentRustId, sent: $sentRustId");
          debugPrint("current: $currentRustPass, sent: $sentRustPass");
          lastKnownRustId = currentRustId;
          lastKnownRustPass = currentRustPass;
        } on KVMAuthError {
          kvmState.setAuthToken(null);
        } on KVMApiError {
          //
        }
      }
    } else {
      debugPrint("KVM not seted up");
    }
  }
}
