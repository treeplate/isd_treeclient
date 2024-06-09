import 'package:flutter/material.dart';
import 'package:isd_treeclient/sockets_cookies_stub.dart'
    if (dart.library.io) 'package:isd_treeclient/sockets_cookies_io.dart'
    if (dart.library.html) 'package:isd_treeclient/sockets_cookies_html.dart';
import 'package:isd_treeclient/data-structure.dart';
import 'parser.dart';

void main() async {
  WebSocketWrapper webSocket = await connect("wss://interstellar-dynasties.space:10024/");
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
      parseMessage(data, event);
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
                OutlinedButton(
                  onPressed: () {
                    widget.webSocket.send('create\x00');
                  },
                  child: Text('Create'),
                ),
                SizedBox(
                  height: 10,
                ),
                OutlinedButton(
                  onPressed: () {
                    widget.webSocket.send('login\x00');
                  },
                  child: Text('Login'),
                ),
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
