import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:isd_treeclient/network_handler.dart';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.js_interop) 'sockets_cookies_web.dart';
import 'data-structure.dart';
import 'parser.dart';

const String loginServerURL = "wss://interstellar-dynasties.space:10024/";
void main() async {
  runApp(
    MaterialApp(
      home: RootWidget(),
    ),
  );
}

class RootWidget extends StatefulWidget {
  RootWidget({super.key});

  @override
  _RootWidgetState createState() => _RootWidgetState();
}

const String kDarkModeCookieName = 'darkMode';

class _RootWidgetState extends State<RootWidget> {
  final DataStructure data = DataStructure();
  ThemeMode themeMode = ThemeMode.system;
  NetworkConnection? loginServer;
  NetworkConnection? dynastyServer;
  bool loginServerHadError = false;
  final List<NetworkConnection> systemServers = [];
  bool get isDarkMode => themeMode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      : themeMode == ThemeMode.dark;

  void initState() {
    super.initState();
    connect(loginServerURL).then((socket) {
      setState(() {
        loginServer = NetworkConnection(socket, (message) {
          parseMessage(data, message);
        }, onResetLogin);
      });
      onResetLogin();
    }, onError: (e, st) {
      setState(() {
        loginServerHadError = true;
      });
    });
    getCookie(kDarkModeCookieName).then((darkModeCookie) {
      if (darkModeCookie != null) {
        themeMode = ThemeMode.values
                .where((mode) => mode.name == darkModeCookie)
                .firstOrNull ??
            ThemeMode.system;
      }
      setCookie(kDarkModeCookieName, themeMode.name);
    });
  }

  FutureOr<Null> onResetLogin() async {
    if (data.stars == null) {
      loginServer!
          .sendExpectingBinaryReply(['get-stars']).then(data.parseStars);
    }
    if (data.systems == null) {
      loginServer!
          .sendExpectingBinaryReply(['get-systems']).then(data.parseSystems);
    }
    if (data.username != null && data.password != null) {
      List<String> message =
          await loginServer!.send(['login', data.username!, data.password!]);
      if (message[0] == 'F') {
        if (message[1] == 'unrecognized credentials') {
          assert(message.length == 2);
          logout();
        } else {
          print(
            'startup login response (failure): ${message[1]}',
          );
        }
      } else {
        assert(message[0] == 'T');
        parseSuccessfulLoginResponse(message);
      }
    }
  }

  void connectToSystemServer(String server) {
    print('connecting to system server: $server');
    connect(server).then((socket) async {
      NetworkConnection systemServer = NetworkConnection(socket, (message) {
        parseMessage(data, message);
      }, () {});
      List<String> message = await systemServer.send(['login', data.token!]);
      print('login response (from server $server): $message');
      systemServers.add(systemServer);
    });
  }

  void parseSuccessfulLoginResponse(List<String> message) {
    assert(message[0] == 'T');
    assert(message.length == 3);
    data.setToken(message[2]);
    connect(message[1]).then((socket) async {
      dynastyServer = NetworkConnection(socket, (message) {
        parseMessage(data, message);
      }, onResetDynasty);
      await onResetDynasty();
    });
  }

  Future<void> onResetDynasty() async {
    List<String> message = await dynastyServer!.send(['login', data.token!]);
    assert(message[0] == 'T');
    int systemServerCount = int.parse(message[1]);
    if (systemServerCount == 0) {
      print('no system servers');
    }
    Iterable<String> systemServers = message.skip(2);
    assert(systemServers.length == systemServerCount);
    for (String server in systemServers) {
      connectToSystemServer(server);
    }
  }

  @override
  void dispose() {
    data.dispose();
    dynastyServer?.close();
    loginServer?.close();
    for (NetworkConnection server in systemServers) {
      server.close();
    }
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
            if (loginServer == null)
              CircularProgressIndicator()
            else if (data.username != null && data.password != null)
              IconButton(
                icon: Icon(
                  Icons.person,
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Theme(
                      data: isDarkMode ? ThemeData.dark() : ThemeData.light(),
                      child: Dialog(
                        child: ProfileWidget(
                          data: data,
                          loginServer: loginServer!,
                          logout: logout,
                        ),
                      ),
                    ),
                  );
                },
              ),
            IconButton(
              icon: Icon(
                isDarkMode
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
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
              child: Stack(
                children: [
                  if (loginServer != null)
                    if (data.username == null || data.password == null)
                      Center(
                        child: LoginWidget(
                          loginServer: loginServer!,
                          data: data,
                          parseSuccessfulLoginResponse:
                              parseSuccessfulLoginResponse,
                        ),
                      )
                    else if (data.stars != null)
                      ZoomableCustomPaint(
                        painter: (zoom, screenCenter) => GalaxyRenderer(
                            data.stars!,
                            zoom,
                            screenCenter,
                            data.systems?.values.toSet() ?? {}),
                      )
                    else
                      Column(
                        children: [
                          Text('loading starmap...'),
                          CircularProgressIndicator(),
                        ],
                      )
                  else
                    Column(
                      children: [
                        if (loginServerHadError)
                          Text(
                            'Failed to connect to login server. Please try again later.',
                          )
                        else ...[
                          Text('connecting to login server...'),
                          CircularProgressIndicator(),
                        ]
                      ],
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void logout() {
    data.removeCredentials();
    dynastyServer?.close();
  }
}

class ProfileWidget extends StatelessWidget {
  const ProfileWidget({
    super.key,
    required this.data,
    required this.loginServer,
    required this.logout,
  });

  final DataStructure data;
  final NetworkConnection loginServer;
  final VoidCallback logout;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: data,
        builder: (context, child) {
          return Column(children: [
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
                      if (newUsername.contains('\x00')) {
                        return Future.value(
                          'Username must not contain 0x0 byte.',
                        );
                      }
                      return loginServer.send(
                        [
                          'change-username',
                          data.username!,
                          data.password!,
                          newUsername,
                        ],
                      ).then(
                        (List<String> message) {
                          if (message[0] == 'F') {
                            assert(message.length == 2);
                            if (message[1] == 'unrecognized credentials') {
                              logout();
                              print('credential failure');
                              Navigator.pop(context);
                            } else if (message[1] == 'inadequate username') {
                              if (newUsername == '') {
                                return 'Username must be non-empty.';
                              } else if (newUsername.contains('\x10')) {
                                return 'Username must not contain 0x10 byte.';
                              } else {
                                return 'Username already in use.';
                              }
                            } else {
                              print(
                                'change username failure: ${message[1]}',
                              );
                              Navigator.pop(context);
                            }
                          } else {
                            assert(message[0] == 'T');
                            data.updateUsername(newUsername);
                            assert(message.length == 1);
                            Navigator.pop(context);
                          }
                          return null;
                        },
                      );
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
                      if (newPassword.contains('\x00')) {
                        return Future.value(
                          'Password must not contain 0x0 byte.',
                        );
                      }
                      return loginServer.send([
                        'change-password',
                        data.username!,
                        data.password!,
                        newPassword,
                      ]).then(
                        (List<String> message) {
                          if (message[0] == 'F') {
                            assert(message.length == 2);
                            if (message[1] == 'unrecognized credentials') {
                              logout();
                              print('credential failure');
                              Navigator.pop(context);
                            } else if (message[1] == 'inadequate password') {
                              assert(utf8.encode(newPassword).length < 6);
                              return 'Password must be at least 6 characters long.';
                            } else {
                              print(
                                'change password failure: ${message[1]}',
                              );
                              Navigator.pop(context);
                            }
                          } else {
                            assert(message[0] == 'T');
                            data.updatePassword(newPassword);
                            assert(message.length == 1);
                            Navigator.pop(context);
                          }
                          return null;
                        },
                      );
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
                ]).then((List<String> message) {
                  if (message[0] == 'F') {
                    if (message[1] == 'unrecognized credentials') {
                      print('credential failure');
                    } else {
                      print('logout failure: ${message[1]}');
                    }
                  } else {
                    assert(message[0] == 'T');
                    assert(message.length == 1);
                  }
                });
                logout();
                Navigator.pop(context);
              },
              child: Text('Logout'),
            ),
          ]);
        });
  }
}

class LoginWidget extends StatelessWidget {
  const LoginWidget({
    super.key,
    required this.loginServer,
    required this.data,
    required this.parseSuccessfulLoginResponse,
  });

  final NetworkConnection loginServer;
  final DataStructure data;
  final void Function(List<String> message) parseSuccessfulLoginResponse;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      OutlinedButton(
        onPressed: () {
          loginServer.send(['new']).then((List<String> message) {
            if (message[0] == 'T') {
              data.setCredentials(message[1], message[2]);
              List<String> loginResponse = message.skip(2).toList();
              loginResponse[0] = 'T';
              parseSuccessfulLoginResponse(loginResponse);
              assert(message.length == 5);
            } else {
              assert(message[0] == 'F');
              assert(message.length == 2);
              print(
                'failed to create new user: ${message[1]}',
              );
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
              parseSuccessfulLoginResponse: parseSuccessfulLoginResponse,
            ),
          );
        },
        child: Text('Login'),
      ),
    ]);
  }
}

class ZoomableCustomPaint extends StatefulWidget {
  const ZoomableCustomPaint({
    super.key,
    required this.painter,
    this.startingZoom = 1,
    this.startingScreenCenter = const Offset(.5, .5),
  });
  final CustomPainter Function(double zoom, Offset screenCenter) painter;
  final double startingZoom;
  final Offset startingScreenCenter;

  @override
  State<ZoomableCustomPaint> createState() => _ZoomableCustomPaintState();
}

class _ZoomableCustomPaintState extends State<ZoomableCustomPaint> {
  late double zoom = widget.startingZoom; // 1..infinity
  late Offset screenCenter = widget.startingScreenCenter; // (0, 0)..(1, 1)
  double lastRelativeScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Listener(
        onPointerSignal: (details) {
          if (details is PointerScrollEvent) {
            setState(() {
              if (details.scrollDelta.dy > 0) {
                handleZoom(1 / 1.5);
              } else {
                handleZoom(1.5);
              }
            });
          }
        },
        child: GestureDetector(
          onScaleStart: (details) {
            lastRelativeScale = 1.0;
          },
          onScaleUpdate: (details) {
            print(
                'pan ${details.focalPointDelta}! scale ${details.scale}! (tz: $zoom)');
            handlePan(details.focalPointDelta, constraints);
            double scaleMultiplicativeDelta = details.scale / lastRelativeScale;
            handleZoom(scaleMultiplicativeDelta);
            lastRelativeScale = details.scale;
          },
          child: ClipRect(
            child: CustomPaint(
              size: Size.square(constraints.biggest.shortestSide),
              painter: widget.painter(zoom, screenCenter),
            ),
          ),
        ),
      );
    });
  }

  void handleZoom(double scaleMultiplicativeDelta) {
    if (zoom >= 1 / scaleMultiplicativeDelta) {
      zoom *= scaleMultiplicativeDelta;
    }
  }

  void handlePan(Offset delta, BoxConstraints constraints) {
    setState(() {
      screenCenter -= (delta / constraints.biggest.shortestSide) / zoom;
      screenCenter = Offset(
        screenCenter.dx.clamp(0, 1),
        screenCenter.dy.clamp(0, 1),
      );
    });
  }
}

class LoginDialog extends StatefulWidget {
  const LoginDialog({
    super.key,
    required this.data,
    required this.connection,
    required this.parseSuccessfulLoginResponse,
  });

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
                if (username.text.contains('\x00')) {
                  errorMessage = 'Username must not contain 0x0 byte.';
                  return;
                }
                if (password.text.contains('\x00')) {
                  errorMessage = 'Password must not contain 0x0 byte.';
                  return;
                }
                widget.connection
                    .send(['login', username.text, password.text]).then(
                        (List<String> message) {
                  if (message[0] == 'F') {
                    if (message[1] == 'unrecognized credentials') {
                      setState(() {
                        errorMessage = 'Username or password incorrect';
                      });
                    } else {
                      print(
                        'manual login failure: ${message[1]}',
                      );
                      if (mounted) {
                        Navigator.pop(context);
                      }
                    }
                  } else {
                    assert(message[0] == 'T');
                    try {
                      widget.data.setCredentials(username.text, password.text);
                      widget.parseSuccessfulLoginResponse(message);
                    } finally {
                      if (mounted) {
                        Navigator.pop(context);
                      }
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
  const TextFieldDialog({
    super.key,
    required this.onSubmit,
    required this.dialogTitle,
    required this.buttonMessage,
    required this.textFieldLabel,
    required this.obscureText,
  });

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
                    .then(
                      (e) => setState(() {
                        errorMessage = e;
                      }),
                    );
              },
              child: Text(widget.buttonMessage),
            ),
          ],
        ),
      ),
    );
  }
}

final List<Paint> starCategories = [
  // multiply strokeWidth by size of unit square
  Paint()
    ..color = Color(0x7FFFFFFF)
    ..strokeWidth = 0.0040,
  Paint()
    ..color = Color(0xCFCCBBAA)
    ..strokeWidth = 0.0025,
  Paint()
    ..color = Color(0xDFFF0000)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0xCFFF9900)
    ..strokeWidth = 0.0007,
  Paint()
    ..color = Color(0xBFFFFFFF)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0xAFFFFFFF)
    ..strokeWidth = 0.0012,
  Paint()
    ..color = Color(0x2F0099FF)
    ..strokeWidth = 0.0010,
  Paint()
    ..color = Color(0x2F0000FF)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0x4FFF9900)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0x2FFFFFFF)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0x5FFF2200)
    ..strokeWidth = 0.0200,
];

class GalaxyRenderer extends CustomPainter {
  final List<List<Offset>> stars;
  final double zoom;
  final Offset screenCenter;
  final Set<StarIdentifier> highlightedStars;
  GalaxyRenderer(
      this.stars, this.zoom, this.screenCenter, this.highlightedStars);

  @override
  void paint(Canvas canvas, Size size) {
    int category = 0;
    Offset topLeft = Offset(screenCenter.dx - .5, screenCenter.dy - .5);

    Offset calculateScreenPosition(Offset basePosition) {
      Offset noZoomPos = (basePosition - topLeft);
      Offset afterZoomPos =
          (((noZoomPos - Offset(.5, .5)) * zoom) + Offset(.5, .5));
      return afterZoomPos.scale(size.width, size.height);
    }

    canvas.drawOval(
        (((-topLeft - Offset(.5, .5)) * zoom) + Offset(.5, .5))
                .scale(size.width, size.height) &
            size * zoom,
        Paint()
          ..color = (Color(0x5566BBFF).withAlpha((0x55 / zoom).toInt()))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10));
    for (StarIdentifier star in highlightedStars) {
      Offset starPos = stars[star.$1][star.$2];
      canvas.drawCircle(
          calculateScreenPosition(starPos),
          starCategories[star.$1].strokeWidth *
              size.shortestSide *
              2 *
              sqrt(zoom) /
              3,
          Paint.from(starCategories[star.$1])
            ..color = Colors.green
            ..strokeWidth = 0);
    }
    while (category < 11) {
      canvas.drawPoints(
          PointMode.points,
          stars[category].map((e) {
            return calculateScreenPosition(e);
          }).where((e) {
            return !(e.dx < 0 ||
                e.dy < 0 ||
                e.dx > size.width ||
                e.dy > size.height);
          }).toList(),
          Paint.from(starCategories[category])
            ..strokeCap = StrokeCap.round
            ..strokeWidth = starCategories[category].strokeWidth *
                size.shortestSide *
                sqrt(zoom)
            ..maskFilter = category == 10
                ? MaskFilter.blur(BlurStyle.normal, zoom)
                : null);
      category++;
    }
    canvas.drawRect(size.center(Offset.zero) - Offset(5, 5) & Size.square(10),
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
