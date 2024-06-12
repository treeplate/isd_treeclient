import 'package:flutter/material.dart';
import 'package:isd_treeclient/network_handler.dart';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.html) 'sockets_cookies_html.dart';
import 'data-structure.dart';
import 'parser.dart';

const String loginServerURL = "wss://interstellar-dynasties.space:10024/";
void main() async {
  runApp(MyHomePage());
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

const String kDarkModeCookieName = 'darkMode';

class _MyHomePageState extends State<MyHomePage> {
  DataStructure data = DataStructure();
  ThemeMode themeMode = ThemeMode.system;
  late final NetworkConnection loginServer;
  NetworkConnection? dynastyServer;
  bool get isDarkMode => themeMode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      : themeMode == ThemeMode.dark;

  void initState() {
    super.initState();
    connect(loginServerURL).then((socket) async {
      loginServer = NetworkConnection(socket, (message) {
        parseMessage(data, message);
      });
      if (data.username != null && data.password != null) {
        loginServer.send(['login', data.username!, data.password!]);
        List<String> message = await loginServer.readItem();
        if (message[0] == 'F') {
          if (message[1] == 'unrecognized credentials') {
            data.removeCredentials();
            assert(message.length == 2);
          } else {
            data.tempMessage('startup login response (failure): ${message[1]}');
          }
        } else {
          assert(message[0] == 'T');
          parseSuccessfulLoginResponse(message);
        }
      }
    });
    String? darkModeCookie = getCookie(kDarkModeCookieName);
    if (darkModeCookie != null) {
      themeMode = ThemeMode.values
              .where((mode) => mode.name == darkModeCookie)
              .firstOrNull ??
          ThemeMode.system;
    }
    setCookie(kDarkModeCookieName, themeMode.name);
  }

  void parseSuccessfulLoginResponse(List<String> message) {
    connect(message[1]).then((socket) async {
      dynastyServer = NetworkConnection(socket, (message) {
        parseMessage(data, message);
      });
      dynastyServer!.send(['moo']);
      List<String> message = await dynastyServer!.readItem();
      data.tempMessage('moo response: $message');
    });
    assert(message.length == 2);
  }

  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData.dark(),
      themeMode: themeMode,
      home: Scaffold(
        appBar: AppBar(
          actions: [
            IconButton(
              icon: Icon(isDarkMode
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined),
              onPressed: () {
                setState(() {
                  if (isDarkMode) {
                    themeMode = ThemeMode.light;
                  } else {
                    themeMode = ThemeMode.dark;
                  }
                  setCookie(kDarkModeCookieName, themeMode.name);
                });
              },
            )
          ],
        ),
        body: ListenableBuilder(
          listenable: data,
          builder: (context, child) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (data.username == null || data.password == null) ...[
                    OutlinedButton(
                      onPressed: () {
                        loginServer.send(['new']);
                        loginServer.readItem().then((List<String> message) {
                          if (message[0] == 'T') {
                            data.setCredentials(message[1], message[2]);
                            assert(message.length == 3);
                          } else {
                            assert(message[0] == 'F');
                            assert(message.length == 2);
                            data.tempMessage(
                                'failed to create new user: ${message[1]}');
                          }
                        });
                      },
                      child: Text('Start new game'),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => LoginDialog(
                            data: data,
                            connection: loginServer,
                            parseSuccessfulLoginResponse:
                                parseSuccessfulLoginResponse,
                          ),
                        );
                      },
                      child: Text('Login'),
                    ),
                  ] else ...[
                    Text('Logged in as ${data.username}'),
                    SizedBox(
                      height: 10,
                    ),
                    OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => TextFieldDialog(
                            obscureText: false,
                            onSubmit: (String newUsername) {
                              loginServer.send(
                                [
                                  'change-username',
                                  data.username!,
                                  data.password!,
                                  newUsername,
                                ],
                              );
                              if (newUsername.contains('\x00')) {
                                return Future.value(
                                  'Username must not contain 0x0 byte.',
                                );
                              }
                              return loginServer
                                  .readItem()
                                  .then((List<String> message) {
                                if (message[0] == 'F') {
                                  assert(message.length == 2);
                                  if (message[1] ==
                                      'unrecognized credentials') {
                                    data.removeCredentials();
                                    data.tempMessage('credential failure');
                                    Navigator.pop(context);
                                  } else if (message[1] ==
                                      'inadequate username') {
                                    if (newUsername == '') {
                                      return 'Username must be non-empty.';
                                    } else if (newUsername.contains('\x10')) {
                                      return 'Username must not contain 0x10 byte.';
                                    } else {
                                      return 'Username already in use.';
                                    }
                                  } else {
                                    data.tempMessage(
                                        'change username failure: ${message[1]}');
                                    Navigator.pop(context);
                                  }
                                } else {
                                  assert(message[0] == 'T');
                                  data.updateUsername(newUsername);
                                  assert(message.length == 1);
                                  Navigator.pop(context);
                                }
                                return null;
                              });
                            },
                            dialogTitle: 'Change username',
                            buttonMessage: 'Change username',
                            textFieldLabel: 'New username',
                          ),
                        );
                      },
                      child: Text('Change username'),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    OutlinedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => TextFieldDialog(
                            obscureText: true,
                            onSubmit: (String newPassword) {
                              loginServer.send([
                                'change-password',
                                data.username!,
                                data.password!,
                                newPassword,
                              ]);
                              return loginServer
                                  .readItem()
                                  .then((List<String> message) {
                                if (message[0] == 'F') {
                                  assert(message.length == 2);
                                  if (message[1] ==
                                      'unrecognized credentials') {
                                    data.removeCredentials();
                                    data.tempMessage('credential failure');
                                    Navigator.pop(context);
                                  } else if (message[1] ==
                                      'inadequate password') {
                                    assert(newPassword.length < 6);
                                    return 'Password must be at least 6 characters long.';
                                  } else {
                                    data.tempMessage(
                                        'change password failure: ${message[1]}');
                                    Navigator.pop(context);
                                  }
                                } else {
                                  assert(message[0] == 'T');
                                  data.updatePassword(newPassword);
                                  assert(message.length == 1);
                                  Navigator.pop(context);
                                }
                                return null;
                              });
                            },
                            dialogTitle: 'Change password',
                            buttonMessage: 'Change password',
                            textFieldLabel: 'New password',
                          ),
                        );
                      },
                      child: Text('Change password'),
                    ),
                    SizedBox(
                      height: 10,
                    ),
                    OutlinedButton(
                      onPressed: () {
                        loginServer.send([
                          'logout',
                          data.username!,
                          data.password!,
                        ]);
                        loginServer.readItem().then((List<String> message) {
                          if (message[0] == 'F') {
                            if (message[1] == 'unrecognized credentials') {
                              data.tempMessage('credential failure');
                            } else {
                              data.tempMessage('logout failure: ${message[1]}');
                            }
                          } else {
                            assert(message[0] == 'T');
                            assert(message.length == 1);
                          }
                        });
                        data.removeCredentials();
                        dynastyServer?.close();
                      },
                      child: Text('Logout'),
                    ),
                  ],
                  if (data.tempCurrentMessage != null) ...[
                    SizedBox(
                      height: 10,
                    ),
                    Center(
                      child: Text('${data.tempCurrentMessage}'),
                    ),
                  ]
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class LoginDialog extends StatefulWidget {
  const LoginDialog(
      {super.key,
      required this.data,
      required this.connection,
      required this.parseSuccessfulLoginResponse});

  final DataStructure data;
  final NetworkConnection connection;
  final void Function(List<String> message) parseSuccessfulLoginResponse;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  TextEditingController username = TextEditingController();
  TextEditingController password = TextEditingController();
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Login'),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Username:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: username,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Password:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: password,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                widget.connection.send(['login', username.text, password.text]);
                widget.connection.readItem().then((List<String> message) {
                  if (message[0] == 'F') {
                    if (message[1] == 'unrecognized credentials') {
                      setState(() {
                        errorMessage = 'Username or password incorrect';
                      });
                    } else {
                      widget.data
                          .tempMessage('manual login failure: ${message[1]}');
                      Navigator.pop(context);
                    }
                  } else {
                    assert(message[0] == 'T');
                    try {
                      widget.data.setCredentials(username.text, password.text);
                      widget.parseSuccessfulLoginResponse(message);
                    } finally {
                      Navigator.pop(context);
                    }
                  }
                });
              },
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class TextFieldDialog extends StatefulWidget {
  const TextFieldDialog(
      {super.key,
      required this.onSubmit,
      required this.dialogTitle,
      required this.buttonMessage,
      required this.textFieldLabel,
      required this.obscureText});

  final String dialogTitle;
  final String textFieldLabel;
  final String buttonMessage;
  final bool obscureText;
  final Future<String?> Function(String newValue) onSubmit;

  @override
  State<TextFieldDialog> createState() => _TextFieldDialogState();
}

class _TextFieldDialogState extends State<TextFieldDialog> {
  TextEditingController textFieldController = TextEditingController();
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(widget.dialogTitle),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('${widget.textFieldLabel}:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    obscureText: widget.obscureText,
                    controller: textFieldController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            OutlinedButton(
              onPressed: () {
                widget
                    .onSubmit(
                      textFieldController.text,
                    )
                    .then((e) => setState(() {
                          errorMessage = e;
                        }));
              },
              child: Text(widget.buttonMessage),
            ),
          ],
        ),
      ),
    );
  }
}
