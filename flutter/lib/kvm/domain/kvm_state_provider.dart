import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/data/kvm_session_datasource.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';

class KVMStateProvider with ChangeNotifier {

  KVMStateProvider() {
    kvmSessionDatasource.getAuthToken().then((value) {
      if (value != null) {
        setAuthToken(value);
      }
    });
  }

  final kvmSessionDatasource = KVMSessionDatasource();

  String? authToken;
  KVMFolder? selectedFolder;
  int? registeredDeviceId;

  bool get isKVMSetedup => authToken != null && selectedFolder != null;

  void onLoginSuccess(String authToken, String email, String password) {
    kvmSessionDatasource.storeLoginEmail(email);
    kvmSessionDatasource.storeLoginPassword(password);
    setAuthToken(authToken);
  }

  void setAuthToken(String? authToken) {
    if (this.authToken != authToken) {
      this.authToken = authToken;
      kvmSessionDatasource.storeAuthToken(authToken);
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
