import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_device.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_tenant.dart';

class KVMState {
  String? authToken;
  KVMDevice? device;
}

abstract class KVMStepState {}

class KVMStepInitializing extends KVMStepState {}

/// Restoring the stored session failed for a reason other than an expired
/// session (no network, timeout, server error). The stored session is kept so
/// the user can retry instead of having to log in again.
class KVMStepRestoreFailed extends KVMStepState {
  final String message;

  KVMStepRestoreFailed(this.message);
}

class KVMStepLogin extends KVMStepState {}

class KVMStepRegisterDevice extends KVMStepState with ChangeNotifier {
  KVMTenant? selectedTenant;
  KVMFolder? selectedFolder;

  void setSelectedTenant(KVMTenant? selectedTenant) {
    this.selectedTenant = selectedTenant;
    debugPrint("selected tenant");
    notifyListeners();
  }

  void setSelectedFolder(KVMFolder? selectedFolder) {
    this.selectedFolder = selectedFolder;
    notifyListeners();
  }
}

class KVMStepRequestPerissions extends KVMStepState {}

class KVMStepReady extends KVMStepState {}
