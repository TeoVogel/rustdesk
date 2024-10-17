import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/pages/kvm_folders_page.dart';
import 'package:flutter_hbb/kvm/pages/kvm_login_page.dart';
import 'package:flutter_hbb/mobile/pages/home_page.dart';

abstract class KVMRoutingUtils {
  static void goToFoldersPage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => KVMFoldersPage(),
      ),
    );
  }

  static void goToLoginPage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => KVMLoginPage(),
      ),
    );
  }

  static void goToRustDeskHomePage(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => HomePage(),
      ),
    );
  }
}
