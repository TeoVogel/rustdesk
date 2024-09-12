import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_hbb/kvm/kvm_state.dart';
import 'package:flutter_hbb/kvm/pages/kvm_folders_page.dart';
import 'package:flutter_hbb/kvm/kvm_api.dart';
import 'package:provider/provider.dart';

class KVMLoginPage extends StatefulWidget {
  const KVMLoginPage({super.key});

  @override
  State<KVMLoginPage> createState() => _KVMLoginPageState();
}

class _KVMLoginPageState extends State<KVMLoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? signInError;

  bool isLogingIn = false;

  var passwordVisible = false;

  @override
  void initState() {
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      if (context.read<KVMState>().authToken != null) {
        _loginSuccess();
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("KVM Login"),
      ),
      body: Center(
        child: Card(
          margin: EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: "User",
                      border: const UnderlineInputBorder(),
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
                            labelText: "Password",
                            border: const UnderlineInputBorder(),
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
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _loginPressed();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Log in"),
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
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ],
                    )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _loginPressed() async {
    String username = usernameController.text.trim();
    String password = passwordController.text.trim();

    try {
      setState(() {
        isLogingIn = true;
      });
      final authToken = await KVMApi.login(username, password);
      context.read<KVMState>().setAuthToken(authToken);
      _loginSuccess();
    } on KVMApiError catch (error) {
      setState(() {
        signInError = error.message;
      });
    }
    setState(() {
      isLogingIn = false;
    });
  }

  void _loginSuccess() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => KVMFoldersPage(),
      ),
    );
  }
}
