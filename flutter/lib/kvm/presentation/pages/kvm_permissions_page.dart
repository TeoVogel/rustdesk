import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/mobile/pages/server_page.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:provider/provider.dart';

class KVMPermissionsPage extends StatefulWidget {
  const KVMPermissionsPage({super.key});

  @override
  State<KVMPermissionsPage> createState() => _KVMPermissionsPageState();
}

class _KVMPermissionsPageState extends State<KVMPermissionsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ChangeNotifierProvider.value(
          value: gFFI.serverModel,
          builder: (context, _) {
            return Consumer<ServerModel>(builder: (context, serverModel, _) {
              return PaddingCard(
                title: "Permisos",
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PermissionRow("Screen Capture", serverModel.mediaOk,
                        serverModel.toggleService),
                    PermissionRow(
                      "Input Control",
                      serverModel.inputOk,
                      serverModel.toggleInput,
                    ),
                    PermissionRow(
                      "Transfer file",
                      serverModel.fileOk,
                      serverModel.toggleFile,
                    ),
                  ],
                ),
              );
            });
          }),
    );
  }
}
