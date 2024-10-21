import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';

class KVMState with ChangeNotifier {
  String? authToken;
  KVMFolder? selectedFolder;
  int? registeredDeviceId;

  bool get isKVMSetedup => authToken != null && selectedFolder != null;

  void setAuthToken(String? authToken) {
    if (this.authToken != authToken) {
      this.authToken = authToken;
      notifyListeners();
    }
  }

  void setSelectedFolder(KVMFolder? selectedFolder) {
    if (this.selectedFolder != selectedFolder) {
      this.selectedFolder = selectedFolder;
      notifyListeners();
    }
  }

  void setRegisteredDeviceId(int? registeredDeviceId) {
    this.registeredDeviceId = registeredDeviceId;
    notifyListeners();
  }
}
