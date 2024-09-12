import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/kvm_state.dart';
import 'package:flutter_hbb/kvm/pages/kvm_login_page.dart';
import 'package:provider/provider.dart';
import 'package:settings_ui/settings_ui.dart';

class KVMSettingsSection extends SettingsSection {
  KVMSettingsSection({super.key})
      : super(
          title: Text("KVM"),
          tiles: [
            SettingsTile(
              title: Consumer<KVMState>(builder: (context, state, _) {
                return Text(state.registeredDeviceId == null
                    ? "KVM Setup"
                    : "KVM Setup Done!");
              }),
              leading: Consumer<KVMState>(builder: (context, state, _) {
                return Icon(
                  state.registeredDeviceId == null
                      ? Icons.settings
                      : Icons.check,
                  color: state.registeredDeviceId != null ? Colors.green : null,
                );
              }),
              onPressed: (context) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => KVMLoginPage(),
                  ),
                );
              },
            ),
          ],
        );
}
