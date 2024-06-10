import 'package:flutter/material.dart';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.html) 'sockets_cookies_html.dart';
import 'data-structure.dart';
import 'parser.dart';

void main() async {
  WebSocketWrapper webSocket =
      await connect("wss://interstellar-dynasties.space:10024/");
  runApp(MyHomePage(
    webSocket: webSocket,
  ));
}

class MyHomePage extends StatefulWidget {
  MyHomePage({super.key, required this.webSocket});

  final WebSocketWrapper webSocket;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

const String kDarkModeCookieName = 'darkMode';

class _MyHomePageState extends State<MyHomePage> {
  DataStructure data = DataStructure();
  ThemeMode themeMode = ThemeMode.system;
  bool get isDarkMode => themeMode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      : themeMode == ThemeMode.dark;

  void initState() {
    super.initState();
    widget.webSocket.listen((event) {
      parseMessage(data, event, widget.webSocket);
    });
    String? darkModeCookie = getCookie(kDarkModeCookieName);
    if (darkModeCookie != null) {
      themeMode = ThemeMode.values
              .where((mode) => mode.name == darkModeCookie)
              .firstOrNull ??
          ThemeMode.system;
    }
    setCookie(kDarkModeCookieName, themeMode.name);
    if (data.username != null && data.password != null) {
      widget.webSocket.send('login\x00${data.username}\x00${data.password}');
    }
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
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (data.username == null || data.password == null) ...[
                  OutlinedButton(
                    onPressed: () {
                      widget.webSocket.send('new\x00');
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
                          login: (String username, String password) {
                            data.setCredentials(username, password);
                            widget.webSocket
                                .send('login\x00$username\x00$password');
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                    child: Text('Login'),
                  ),
                ] else ...[
                  OutlinedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => TextFieldDialog(
                          obscureText: false,
                          onSubmit: (String newUsername) {
                            data.updateUsername(newUsername);
                            widget.webSocket
                                .send('change-username\x00${data.username}\x00${data.password}\x00$newUsername');
                            Navigator.pop(context);
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
                            data.updatePassword(newPassword);
                            widget.webSocket
                                .send('change-password\x00${data.username}\x00${data.password}\x00$newPassword');
                            Navigator.pop(context);
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
                            widget.webSocket
                                .send('logout\x00${data.username}\x00${data.password}');
                            data.removeCredentials();
                    },
                    child: Text('Logout'),
                  ),
                ],
                SizedBox(
                  height: 10,
                ),
                Center(
                  child: Text('${data.tempCurrentMessage}'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({super.key, required this.login});

  final void Function(String username, String password) login;

  @override
  State<LoginDialog> createState() => _LoginDialogState();
}

class _LoginDialogState extends State<LoginDialog> {
  TextEditingController username = TextEditingController();
  TextEditingController password = TextEditingController();

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
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => widget.login(username.text, password.text),
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
  final void Function(String newValue) onSubmit;

  @override
  State<TextFieldDialog> createState() => _TextFieldDialogState();
}

class _TextFieldDialogState extends State<TextFieldDialog> {
  TextEditingController textFieldController = TextEditingController();

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
            OutlinedButton(
              onPressed: () => widget.onSubmit(
                textFieldController.text,
              ),
              child: Text(widget.buttonMessage),
            ),
          ],
        ),
      ),
    );
  }
}
