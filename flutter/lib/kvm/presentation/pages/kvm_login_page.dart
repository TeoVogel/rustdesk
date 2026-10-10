import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/kvm/constants.dart';
import 'package:flutter_hbb/kvm/domain/kvm_state_provider.dart';
import 'package:flutter_hbb/kvm/domain/models/kvm_server_config.dart';
import 'package:provider/provider.dart';

class KVMLoginPage extends StatefulWidget {
  const KVMLoginPage({super.key});

  @override
  State<KVMLoginPage> createState() => _KVMLoginPageState();
}

class _KVMLoginPageState extends State<KVMLoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final baseUrlOverrideController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? signInError;

  bool isLogingIn = false;

  var passwordVisible = false;

  @override
  void initState() {
    usernameController.text = prefilledEmail ?? "";
    passwordController.text = prefilledPass ?? "";
    baseUrlOverrideController.text =
        _selectedServer.baseUrlResolutionOverride ?? "";
    super.initState();

    final appLinks = AppLinks(); // AppLinks is singleton
    // Subscribe to all events (initial link and further)
    appLinks.uriLinkStream.listen((uri) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        showDialog(
            context: context,
            builder: (context) => AlertDialog(title: Text(uri.toString())));
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onBackground,
        elevation: 0,
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
              minHeight: constraints.maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        "Iniciar Sesión",
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: usernameController,
                        decoration: InputDecoration(
                          labelText: "Usuario",
                          border: const OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value ==
                                  null /* ||
                                IRemoteAuth.validateEmailAddress(value.trim())*/
                              ) {
                            return "error";
                          }
                          return null;
                        },
                      ),
                      Column(
                        children: [
                          const SizedBox(height: 16.0),
                          TextFormField(
                            obscureText: !passwordVisible,
                            controller: passwordController,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return "error";
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                                labelText: "Contraseña",
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    passwordVisible
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      passwordVisible = !passwordVisible;
                                    });
                                  },
                                )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: ElevatedButton(
                          onPressed: () {
                            if (!isLogingIn && _formKey.currentState!.validate()) {
                              _loginPressed();
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Ingresar"),
                              if (isLogingIn)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                      )),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (signInError != null)
                        Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                signInError!,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      SizedBox(height: 8),
                      Consumer<KVMStateProvider>(
                        builder: (context, kvmState, _) {
                          final selectedServer = kvmState.serverConfig;
                          final hasOverride = (selectedServer
                                      .baseUrlResolutionOverride
                                      ?.trim()
                                      .isNotEmpty ??
                                  false);
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Server config",
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                ...kvmServers.map((server) {
                                  return RadioListTile<KVMServerModel>(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(server.name),
                                    value: server,
                                    groupValue: selectedServer,
                                    onChanged: (value) {
                                      _onServerSelected(value!);
                                    },
                                  );
                                }).toList(),
                                const Divider(),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text("Usar HTTPS"),
                                  subtitle: Text(
                                    hasOverride
                                        ? "Ignorado mientras haya un override"
                                        : "Resuelve la url sobre "
                                            "${selectedServer.useHttps ? 'https' : 'http'}",
                                  ),
                                  value: selectedServer.useHttps,
                                  onChanged: hasOverride
                                      ? null
                                      : (value) =>
                                          _onUseHttpsChanged(value),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: baseUrlOverrideController,
                                  keyboardType: TextInputType.url,
                                  decoration: InputDecoration(
                                    labelText: "base override",
                                    border: const OutlineInputBorder(),
                                    suffixIcon: hasOverride
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: _onClearOverride,
                                          )
                                        : null,
                                  ),
                                  onChanged: _onOverrideChanged,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "URL: ${selectedServer.resolvedBaseUrl}",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 8),
                      Text("KVM build number: $buildNumber"),
                      Text(buildDate),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  KVMServerModel get _selectedServer =>
      context.read<KVMStateProvider>().serverConfig;

  void _loginPressed() async {
    String username = usernameController.text.trim();
    String password = passwordController.text.trim();

    setState(() {
      isLogingIn = true;
    });

    await context
        .read<KVMStateProvider>()
        .login(username, password)
        .catchError((error) {
      displayErrorSnackbar(error.toString(), context);
    });

    setState(() {
      isLogingIn = false;
    });
  }

  void displayErrorSnackbar(String message, BuildContext context) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _onServerSelected(KVMServerModel server) async {
    baseUrlOverrideController.text = server.baseUrlResolutionOverride ?? "";
    await context.read<KVMStateProvider>().setRustdeskServerConfig(server);
  }

  void _onUseHttpsChanged(bool value) {
    context
        .read<KVMStateProvider>()
        .updateServerConfig((server) => server.useHttps = value);
  }

  void _onOverrideChanged(String value) {
    context.read<KVMStateProvider>().updateServerConfig(
        (server) => server.baseUrlResolutionOverride = value);
  }

  void _onClearOverride() {
    baseUrlOverrideController.clear();
    context.read<KVMStateProvider>().updateServerConfig(
        (server) => server.baseUrlResolutionOverride = null);
  }
}
