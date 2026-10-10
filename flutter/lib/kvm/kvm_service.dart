import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/kvm/constants.dart';
import 'package:flutter_hbb/kvm/data/kvm_api.dart';
import 'package:flutter_hbb/kvm/domain/kvm_state_provider.dart';
import 'package:flutter_hbb/kvm/kvm_logger.dart';
import 'package:flutter_hbb/kvm/kvm_utils.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';

class KVMService {
  static final KVMService _instance = KVMService._internal();

  KVMService._internal();

  factory KVMService() => _instance;

  static const _log = KVMLog('Heartbeat');

  /// Last reason a heartbeat tick was skipped, so it is logged once per change
  /// instead of on every tick.
  String? _lastSkipReason;

  final model = gFFI.serverModel;

  String? lastKnownRustId;
  String? lastKnownRustPass;
  DateTime? lastHeartBeatTimestamp;

  late KVMStateProvider kvmState;

  int? heartbeatS;

  void start(KVMStateProvider kvmState) async {
    this.kvmState = kvmState;
    _log.i("service started (refreshRate=$kHeartbeatDefaultRefreshRate)");
    setHeartbeatRefreshRate();
  }

  static void setHeartbeatRefreshRate() {
    platformFFI.invokeMethod(
      AndroidKVMChannel.kSetHeartbeatRefreshRate,
      kHeartbeatDefaultRefreshRate,
    );
  }

  static Future<String?> getMacAddress() async {
    return await platformFFI.invokeMethod(AndroidKVMChannel.kGetMacAddres);
  }

  static Future<String?> getAndroidId() async {
    return await platformFFI.invokeMethod(AndroidKVMChannel.kGetAndroidId);
  }

  static Future<String?> getSerialNo() async {
    return await platformFFI.invokeMethod(AndroidKVMChannel.kGetSerialNo);
  }

  static Future<String?> getKVMId() async {
    return await platformFFI.invokeMethod(AndroidKVMChannel.kGetKVMId);
  }

  void checkCredentialsAndSendHeartBeat(KVMApi api) {
    // After a cold start the service can ask for a heartbeat before the KVM
    // session has been restored.
    if (model.isStart && kvmState.isKVMSetedup) {
      if (_lastSkipReason != null) {
        _log.i("heartbeat resumed");
        _lastSkipReason = null;
      }
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
          lastHeartBeatTimestamp == null ||
          lastHeartBeatTimestamp!.isBefore(DateTime.now().subtract(
            Duration(seconds: heartbeatS ?? defaultHeartbeatS),
          ));

      if (shouldSendHeartBeat) {
        sendHeartBeat(sentRustId, sentRustPass, api);
      }
    } else {
      final reason = !model.isStart
          ? "rustdesk service not started"
          : "KVM session not set up";
      if (reason != _lastSkipReason) {
        _log.w("heartbeat skipped: $reason");
        _lastSkipReason = reason;
      }
    }
  }

  void sendHeartBeat(String? sentRustId, String? sentRustPass, KVMApi api) async {
    try {
      final heartbeatS = await api.heartbeat(
        kvmState.registeredDeviceId!,
        authToken: kvmState.authToken,
        rustId: sentRustId,
        rustPass: sentRustPass,
        memLoadMb: KVMUtils.getUsedRAMInMB(),
      );
      if (heartbeatS != this.heartbeatS) {
        _log.i("heartbeat interval set to ${heartbeatS}s");
      }
      this.heartbeatS = heartbeatS;
      if (sentRustId != null || sentRustPass != null) {
        _log.i("heartbeat ok, rustdesk credentials sent (rustId=$sentRustId)");
      }
      lastKnownRustId = sentRustId ?? lastKnownRustId;
      lastKnownRustPass = sentRustPass ?? lastKnownRustPass;
      lastHeartBeatTimestamp = DateTime.now();
    } on KVMAuthError {
      _log.w("heartbeat rejected, session expired");
      kvmState.onUserSessionExpired();
    } catch (_) {
      // Already logged by KVMApi; retried on the next tick.
    }
  }

}
