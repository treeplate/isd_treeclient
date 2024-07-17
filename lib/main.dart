import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:isd_treeclient/network_handler.dart';
import 'account.dart';
import 'assets.dart';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.js_interop) 'sockets_cookies_web.dart';
import 'data-structure.dart';
import 'parser.dart';
import 'ui-core.dart';

const String loginServerURL = "wss://interstellar-dynasties.space:10024/";
void main() async {
  runApp(
    MaterialAppWidget(),
  );
}

class MaterialAppWidget extends StatefulWidget {
  const MaterialAppWidget({super.key});

  @override
  State<MaterialAppWidget> createState() => _MaterialAppWidgetState();
}

class _MaterialAppWidgetState extends State<MaterialAppWidget> {
  ThemeMode themeMode = ThemeMode.system;
  void changeThemeMode(ThemeMode newThemeMode) {
    setState(() {
      themeMode = newThemeMode;
      setCookie(kDarkModeCookieName, themeMode.name);
    });
  }

  @override
  void initState() {
    getCookie(kDarkModeCookieName).then((darkModeCookie) {
      if (darkModeCookie != null) {
        changeThemeMode(
          ThemeMode.values
                  .where((mode) => mode.name == darkModeCookie)
                  .firstOrNull ??
              ThemeMode.system,
        );
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      darkTheme: ThemeData.dark(),
      themeMode: themeMode,
      home: ScaffoldWidget(
        themeMode: themeMode,
        changeThemeMode: changeThemeMode,
      ),
    );
  }
}

class ScaffoldWidget extends StatefulWidget {
  ScaffoldWidget(
      {super.key, required this.themeMode, required this.changeThemeMode});

  final ThemeMode themeMode;
  final void Function(ThemeMode) changeThemeMode;

  @override
  _ScaffoldWidgetState createState() => _ScaffoldWidgetState();
}

const String kDarkModeCookieName = 'darkMode';

class _ScaffoldWidgetState extends State<ScaffoldWidget>
    with SingleTickerProviderStateMixin {
  final DataStructure data = DataStructure();
  NetworkConnection? loginServer;
  NetworkConnection? dynastyServer;
  bool loginServerHadError = false;
  final List<NetworkConnection> systemServers = [];
  bool get isDarkMode => widget.themeMode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      : widget.themeMode == ThemeMode.dark;
  late TabController tabController =
      TabController(length: 3, vsync: this, initialIndex: 2);

  void initState() {
    super.initState();
    connect(loginServerURL).then((socket) {
      setState(() {
        loginServer = NetworkConnection(
          socket,
          (message) {
            String? errorMessage = parseMessage(data, message);
            if (errorMessage != null) {
              openErrorDialog(
                errorMessage,
                context,
              );
            }
          },
          parseBinaryMessage,
          onLoginServerReset,
        );
      });
      onLoginServerReset();
    }, onError: (e, st) {
      setState(() {
        loginServerHadError = true;
      });
    });
  }

  void parseBinaryMessage(int fileID, List<int> data) {
    switch (fileID) {
      case 1:
        this.data.parseStars(data);
      case 2:
        this.data.parseSystems(data);
      default:
        openErrorDialog('Error - Unrecognised file ID: $fileID', context);
    }
  }

  void getFile(int fileID) {
    loginServer!.send(['get-file', fileID.toString()]).then((message) {
      if (message[0] == 'F') {
        assert(message.length == 2);
        openErrorDialog(
            'Error: failed to get file $fileID - ${message[1]}', context);
      }
      assert(message.length == 1);
      assert(message[0] == 'T');
    });
  }

  Future<void> onLoginServerReset() async {
    if (data.galaxyDiameter == null) {
      loginServer!.send(['get-constants']).then((message) {
        if (message[0] == 'F') {
          assert(message.length == 2);
          openErrorDialog(
              'Error: failed to get settings - ${message[1]}', context);
        }
        assert(message.length == 2);
        assert(message[0] == 'T');
        data.setGalaxyDiameter(double.parse(message[1]));
      });
    }
    if (data.stars == null) {
      getFile(1);
    }
    if (data.systems == null) {
      getFile(2);
    }
    if (data.username != null && data.password != null) {
      List<String> message =
          await loginServer!.send(['login', data.username!, data.password!]);
      if (message[0] == 'F') {
        if (message[1] == 'unrecognized credentials') {
          assert(message.length == 2);
          logout();
        } else {
          openErrorDialog(
            'Error when logging in: ${message[1]}',
            context,
          );
        }
      } else {
        assert(message[0] == 'T');
        parseSuccessfulLoginResponse(message);
      }
    }
  }

  void connectToSystemServer(String server) {
    openErrorDialog(
      'connecting to system server: $server',
      context,
    );
    connect(server).then((socket) async {
      late NetworkConnection systemServer;
      systemServer = NetworkConnection(
        socket,
        (message) {
          String? errorMessage = parseMessage(data, message);
          if (errorMessage != null) {
            openErrorDialog(
              errorMessage,
              context,
            );
          }
        },
        parseBinaryMessage,
        () {
          onSystemServerReset(systemServer, server);
        },
      );
      await onSystemServerReset(systemServer, server);
      systemServers.add(systemServer);
    });
  }

  Future<void> onSystemServerReset(
      NetworkConnection systemServer, String server) async {
    List<String> message = await systemServer.send(['login', data.token!]);
    openErrorDialog(
      'login response (from server $server): $message',
      context,
    );
  }

  void parseSuccessfulLoginResponse(List<String> message) {
    setState(() {}); // for the profile button in the app bar
    assert(message[0] == 'T');
    assert(message.length == 3);
    data.setToken(message[2]);
    connect(message[1]).then((socket) async {
      setState(() {
        dynastyServer = NetworkConnection(socket, (message) {
          String? errorMessage = parseMessage(data, message);
          if (errorMessage != null) {
            openErrorDialog(
              errorMessage,
              context,
            );
          }
        }, parseBinaryMessage, onDynastyServerReset);
      });
      await onDynastyServerReset();
    });
  }

  Future<void> onDynastyServerReset() async {
    List<String> message = await dynastyServer!.send(['login', data.token!]);
    assert(message[0] == 'T');
    int systemServerCount = int.parse(message[1]);
    if (systemServerCount == 0) {
      openErrorDialog(
        'Error - No system servers',
        context,
      );
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
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          tabs: [Text('Galaxy'), Text('Debug info'), Text('Star lookup')],
          controller: tabController,
        ),
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
                  builder: (context) => Dialog(
                    child: AccountWidget(
                      data: data,
                      loginServer: loginServer!,
                      logout: logout,
                      isDarkMode: isDarkMode,
                    ),
                  ),
                );
              },
            ),
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () {
              setState(() {
                if (isDarkMode) {
                  widget.changeThemeMode(ThemeMode.light);
                } else {
                  widget.changeThemeMode(ThemeMode.dark);
                }
              });
            },
          )
        ],
      ),
      body: loginServer == null
          ? Column(
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
            )
          : loginServer!.reloading ? Column(
              children: [
                if (loginServerHadError)
                  Text(
                    'Failed to reconnect to login server. Please try again later.',
                  )
                else ...[
                  Text('reconnecting to login server...'),
                  CircularProgressIndicator(),
                ]
              ],
            ) : ListenableBuilder(
              listenable: data,
              builder: (context, child) {
                return Center(
                  child: data.username == null || data.password == null
                      ? Center(
                          child: LoginWidget(
                            loginServer: loginServer!,
                            data: data,
                            parseSuccessfulLoginResponse:
                                parseSuccessfulLoginResponse,
                          ),
                        )
                      : TabBarView(
                          controller: tabController,
                          children: [
                            if (data.stars != null)
                              ZoomableCustomPaint(
                                painter: (zoom, screenCenter) => GalaxyRenderer(
                                  data.stars!,
                                  zoom,
                                  screenCenter,
                                  data.systems?.values.toSet() ?? {},
                                ),
                              )
                            else
                              Column(
                                children: [
                                  Text('loading starmap...'),
                                  CircularProgressIndicator(),
                                ],
                              ),
                            Column(
                              children: [
                                SelectableText('username: "${data.username}"'),
                                SelectableText('password: "${data.password}"'),
                                SelectableText('token: "${data.token}"'),
                                SelectableText('galaxyDiameter: ${data.galaxyDiameter}'),
                              ],
                            ),
                            StarLookupWidget(
                              data: data,
                              dynastyServer: dynastyServer,
                            ),
                          ],
                        ),
                );
              },
            ),
    );
  }

  void logout() {
    data.removeCredentials();
    dynastyServer?.close();
    for (NetworkConnection server in systemServers) {
      server.close();
    }
  }
}

class StarLookupWidget extends StatefulWidget {
  const StarLookupWidget(
      {super.key, required this.data, required this.dynastyServer});

  final DataStructure data;
  final NetworkConnection? dynastyServer;

  @override
  State<StarLookupWidget> createState() => _StarLookupWidgetState();
}

class _StarLookupWidgetState extends State<StarLookupWidget> {
  final TextEditingController textFieldController = TextEditingController();
  String? errorMessage;
  String? description;
  Offset? starOffset; // position of star in galaxy
  StarIdentifier? selectedStar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Lookup star by ID:'),
        SizedBox(
          width: 200,
          child: TextField(
            controller: textFieldController,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                String rawStarID = textFieldController.text;
                if (!rawStarID.startsWith('S')) {
                  errorMessage =
                      'Invalid star ID. All star IDs must start with S.';
                  return;
                }
                int? integerStarID =
                    int.tryParse(rawStarID.substring(1), radix: 16);
                if (integerStarID == null) {
                  errorMessage =
                      'Invalid star ID. All star IDs must be S followed by a hexadecimal integer.';
                  return;
                }
                StarIdentifier starID = parseStarIdentifier(integerStarID);
                if (starID.$1 < 0) {
                  errorMessage =
                      'Invalid star ID. Star IDs cannot be negative.';
                  return;
                }
                if (starID.$1 > 10) {
                  errorMessage =
                      'Invalid star ID. The maximum star category (the first hexadecimal digit) is A.';
                  return;
                }
                if (widget.data.stars == null) {
                  errorMessage = 'Still loading stars. Try again later.';
                  return;
                }
                if (widget.data.stars![starID.$1].length <= starID.$2) {
                  errorMessage =
                      'Invalid star ID. The maximum value for the last five hexadecimal digits of a star with category ${starID.$1} is ${(widget.data.stars![starID.$1].length - 1).toRadixString(16)}.';
                  return;
                }
                errorMessage = null;
                description = null;
                selectedStar = starID;
                starOffset = widget.data.stars![starID.$1][starID.$2];
                if (widget.dynastyServer != null) {
                  widget.dynastyServer!.send([
                    'get-star-name',
                    starID.value.toString(),
                  ]).then((e) {
                    setState(() {
                      if (e[0] == 'F') {
                        description = e.toString();
                      } else {
                        description = '${e[1]}';
                      }
                    });
                  });
                } else {
                  errorMessage = 'Could not load name; try again later.';
                }
              });
            },
            child: Text('Lookup'),
          ),
        ),
        if (errorMessage != null)
          Text(
            errorMessage!,
            style: TextStyle(color: Colors.red),
          ),
        if (description != null)
          SelectableText(
            description!,
          ),
        if (starOffset != null)
          Expanded(
            child: ZoomableCustomPaint(
              painter: (zoom, screenCenter) => GalaxyRenderer(
                widget.data.stars!,
                zoom,
                screenCenter,
                {selectedStar!},
              ),
              startingScreenCenter: starOffset!,
              startingZoom: 100,
            ),
          ),
      ],
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
    canvas.drawRect(size.center(Offset.zero) - Offset(1, 1) & Size.square(2),
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(GalaxyRenderer oldDelegate) {
    return true;
  }
}
