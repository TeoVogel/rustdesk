import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hbb/kvm/kvm_routing_utils.dart';
import 'package:flutter_hbb/kvm/domain/kvm_state_provider.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_tenant.dart';
import 'package:flutter_hbb/kvm/presentation/widgets/kvm_app_bar.dart';
import 'package:flutter_hbb/kvm/presentation/widgets/kvm_folder_selection.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class KVMFoldersPage extends StatefulWidget {
  const KVMFoldersPage({super.key});

  @override
  State<KVMFoldersPage> createState() => _KVMFoldersPageState();
}

class _KVMFoldersPageState extends State<KVMFoldersPage> {

  KVMTenant? selectedTenant;

  bool isRegisteringDevice = false;

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      context.read<KVMStateProvider>().setSelectedFolder(null);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(builder: (context) {
        return CustomScrollView(
          slivers: [
            getKVMSliverAppBar(context),
            SliverFillRemaining(
              child: FutureBuilder(
                future: context.read<KVMStateProvider>().fetchTenants(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(snapshot.error.toString()),
                    );
                  }

                  final dropdownTenants = [
                    "Select tenant",
                    ...snapshot.data!
                        .toList()
                        .map((tenant) => tenant.toString())
                  ];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Container(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.1),
                          child: DropdownButton<String>(
                            hint: Text("Select tenant"),
                            padding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            value: selectedTenant != null
                                ? selectedTenant.toString()
                                : "Select tenant",
                            items: dropdownTenants
                                .map(
                                  (tenant) => DropdownMenuItem<String>(
                                    value: tenant.toString(),
                                    child: Text(tenant.toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                context
                                    .read<KVMStateProvider>()
                                    .setSelectedFolder(null);
                                selectedTenant = snapshot.data!
                                    .toList()
                                    .firstWhereOrNull(
                                        (tenant) => tenant.toString() == value);
                              });
                            },
                            isExpanded: true,
                          ),
                        ),
                      ),
                      if (selectedTenant != null)
                        Expanded(
                            child:
                                KVMFolderPicker(tenantId: selectedTenant!.id))
                      else
                        Spacer(),
                      Builder(builder: (context) {
                        final selectedFolder =
                            context.select<KVMStateProvider, KVMFolder?>(
                                (state) => state.selectedFolder);
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.all(12)),
                            onPressed: selectedFolder != null &&
                                    !isRegisteringDevice
                                ? () {
                                    _registerDevice(selectedFolder, context);
                                  }
                                : null,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Register device"),
                                if (isRegisteringDevice)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator()),
                                  ),
                              ],
                            ),
                          ),
                        );
                      })
                    ],
                  );
                },
              ),
            ),
          ],
        );
      }
      ),
    );
  }

  void _registerDevice(KVMFolder folder, BuildContext context) async {
    final deviceName = await showDialogNamePicker();
    if (deviceName == null) {
      return;
    }

    setState(() {
      isRegisteringDevice = true;
    });

    await context
        .read<KVMStateProvider>()
        .registerDevice(folder, deviceName)
        .then((registeredDeviceId) {
      _registerDeviceSuccess(registeredDeviceId);
    }).catchError((error) {
      displayErrorSnackbar(error.toString(), context);
    });

    setState(() {
      isRegisteringDevice = false;
    });
  }

  void _registerDeviceSuccess(int registeredDeviceId) async {
    context.read<KVMStateProvider>().setRegisteredDeviceId(registeredDeviceId);
    KVMRoutingUtils.goToPermissionsPage(context);
  }

  Future<String?> showDialogNamePicker() {
    return showDialog<String?>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text("Set device name"),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: "Device name",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, controller.text);
              },
              child: Text("Continue"),
            )
          ],
        );
      },
    );
  }

  void displayErrorSnackbar(String message, BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
