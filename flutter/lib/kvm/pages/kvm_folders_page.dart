import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hbb/kvm/kvm_state.dart';
import 'package:flutter_hbb/kvm/models/kvm_folder.dart';
import 'package:flutter_hbb/kvm/models/kvm_tenant.dart';
import 'package:flutter_hbb/kvm/kvm_api.dart';
import 'package:flutter_hbb/kvm/widgets/kvm_folder_selection.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

class KVMFoldersPage extends StatefulWidget {
  const KVMFoldersPage({super.key});

  @override
  State<KVMFoldersPage> createState() => _KVMFoldersPageState();
}

class _KVMFoldersPageState extends State<KVMFoldersPage> {
  String? fetchError;

  KVMTenant? selectedTenant;

  bool isRegisteringDevice = false;

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      context.read<KVMState>().setSelectedFolder(null);
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Register device")),
      body: FutureBuilder(
        future: fetchTenants(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(),
            );
          }

          if (fetchError != null) {
            return Center(
              child: Text(fetchError!),
            );
          }

          final dropdownTenants = [
            "Select tenant",
            ...snapshot.data!.toList().map((tenant) => tenant.toString())
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  child: DropdownButton<String>(
                    hint: Text("Select tenant"),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        context.read<KVMState>().setSelectedFolder(null);
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
                Expanded(child: KVMFolderPicker(tenantId: selectedTenant!.id))
              else
                Spacer(),
              Builder(builder: (context) {
                final selectedFolder = context.select<KVMState, KVMFolder?>(
                    (state) => state.selectedFolder);
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: FilledButton(
                    onPressed: selectedFolder != null && !isRegisteringDevice
                        ? () {
                            _registerDevice(selectedFolder);
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
    );
  }

  void _registerDevice(KVMFolder folder) async {
    final deviceName = await showDialogNamePicker();
    if (deviceName == null) {
      return;
    }
    if (deviceName.isEmpty) {
      displayErrorSnackbar("Device name can't be empty");
      return;
    }

    try {
      setState(() {
        isRegisteringDevice = true;
      });
      final registeredDeviceId = await KVMApi.registerDevice(
        folder,
        deviceName,
        authToken: context.read<KVMState>().authToken,
      );
      context.read<KVMState>().setRegisteredDeviceId(registeredDeviceId);
      Navigator.pop(context);
    } on KVMApiError catch (error) {
      displayErrorSnackbar(error.message);
    } on KVMAuthError catch (error) {
      context.read<KVMState>().setAuthToken(null);
      Navigator.pop(context);

      displayErrorSnackbar(error.message);
    }
    setState(() {
      isRegisteringDevice = false;
    });
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
                var sanitizedDeviceName =
                    getSanitizedDeviceName(controller.text);
                Navigator.pop(context, sanitizedDeviceName);
              },
              child: Text("Continue"),
            )
          ],
        );
      },
    );
  }

  String? getSanitizedDeviceName(String? input) {
    if (input == null) {
      return null;
    }

    final trimmedInput = input.trim();
    return trimmedInput;
  }

  Future<Iterable<KVMTenant>?> fetchTenants() async {
    try {
      return await KVMApi.getTenants(
          authToken: context.read<KVMState>().authToken);
    } on KVMApiError catch (error) {
      setState(() {
        fetchError = error.message;
      });

      displayErrorSnackbar(error.message);
    } on KVMAuthError catch (error) {
      context.read<KVMState>().setAuthToken(null);
      Navigator.pop(context);

      displayErrorSnackbar(error.message);
    }
    return [];
  }

  void displayErrorSnackbar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
