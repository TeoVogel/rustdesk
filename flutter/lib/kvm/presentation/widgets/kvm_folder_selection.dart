import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/data/kvm_api.dart';
import 'package:flutter_hbb/kvm/domain/kvm_state_provider.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_folder.dart';
import 'package:provider/provider.dart';

class KVMFolderPicker extends StatefulWidget {
  const KVMFolderPicker({super.key, required this.tenantId});

  final int tenantId;

  @override
  State<KVMFolderPicker> createState() => _KVMFolderPickerState();
}

class _KVMFolderPickerState extends State<KVMFolderPicker> {
  String? fetchError;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: fetchFolders(),
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

        return ListView.builder(
          itemCount: snapshot.data?.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: getFolderWidget(
                snapshot.data!.elementAt(index),
                isRoot: true,
              ),
            );
          },
        );
      },
    );
  }

  Widget getFolderWidget(KVMFolder folder, {isRoot = false}) {
    return Builder(builder: (context) {
      final selectedFolder =
          context.select<KVMStateProvider, KVMFolder?>(
          (state) => state.selectedFolder);

      return Padding(
        padding: EdgeInsets.only(left: isRoot ? 0 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: folder == selectedFolder
                  ? Theme.of(context).colorScheme.primary.withOpacity(.1)
                  : null,
              child: InkWell(
                onTap: () {
                  context.read<KVMStateProvider>().setSelectedFolder(folder);
                },
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Radio(
                          value: folder,
                          groupValue: selectedFolder,
                          onChanged: (value) {
                            context
                                .read<KVMStateProvider>()
                                .setSelectedFolder(folder);
                          }),
                      Text(folder.toString()),
                    ],
                  ),
                ),
              ),
            ),
            ...folder.subfolders.map(
              (subfolder) => getFolderWidget(subfolder),
            )
          ],
        ),
      );
    });
  }

  Future<Iterable<KVMFolder>?> fetchFolders() async {
    try {
      return await KVMApi.getFolders(
        widget.tenantId,
        authToken: context.read<KVMStateProvider>().authToken,
      );
    } on KVMApiError catch (error) {
      setState(() {
        fetchError = error.message;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } on KVMAuthError catch (error) {
      context.read<KVMStateProvider>().setAuthToken(null);
      Navigator.pop(context);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
    return [];
  }
}
