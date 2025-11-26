import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart' hide Material;

import 'binaryreader.dart';
import 'debugsystemview.dart' as debugsystemview;
import 'systemview.dart' as systemview;
import 'planetview.dart' as planetview;
import 'galaxyview.dart';
import 'inbox.dart';
import 'network_handler.dart';
import 'feature_parser.dart';
import 'account.dart';
import 'assets.dart';
import 'data-structure.dart';
import 'ui-core.dart';
import 'parseSystemServerBinaryMessage.dart';
import 'platform_specific_stub.dart'
    if (dart.library.io) 'platform_specific_io.dart'
    if (dart.library.js_interop) 'platform_specific_web.dart';

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

enum LoginState {
  connectingToLoginServer,
  waitingOnLoginServer,
  loginServerConnectionError,
  loginServerLoginError,

  connectingToDynastyServer,
  waitingOnDynastyServer,
  dynastyServerConnectionError,
  dynastyServerLoginError,

  connectingToSystemServers,
  waitingOnSystemServers,
  systemServerConnectionError,
  systemServerLoginError,

  noSystemServers,
  notLoggedIn,
  ready,
}

const List<LoginState> cannotCloseLoginServer = [
  LoginState.connectingToLoginServer,
  LoginState.waitingOnLoginServer,
  LoginState.loginServerConnectionError,
  LoginState.notLoggedIn,
];

class _ScaffoldWidgetState extends State<ScaffoldWidget>
    with TickerProviderStateMixin {
  final DataStructure data = DataStructure();
  NetworkConnection? loginServer;
  NetworkConnection? dynastyServer;
  int expectedSystemServerCount = 0;
  int currentSystemServerConnectedCount = 0;
  LoginState loginState = LoginState.connectingToLoginServer;
  final Map<String, NetworkConnection> systemServers = {}; // URI -> connection
  final Map<StarIdentifier, NetworkConnection> systemServersBySystemID = {};
  final List<String> systemServersLoggedIn =
      []; // list of system server URIs that have responded to "login"
  bool get isDarkMode => widget.themeMode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      : widget.themeMode == ThemeMode.dark;
  late TabController tabController =
      TabController(length: 4, vsync: this, initialIndex: 1);

  late final Timer ticker;

  void initState() {
    super.initState();
    getCookie('previousError').then((e) {
      if (e != null) openErrorDialog('Cookie error: $e', context);
    });
    connectToLoginServer().then((server) => onLoginServerConnect(),
        onError: (e, st) {
      setState(() {
        loginState = LoginState.loginServerConnectionError;
      });
    });
    // ticker = Timer.periodic(
    //     Duration(seconds: 1),
    //     ((_) =>
    //         data.dynastyID == null ? null : getHighScores([data.dynastyID!])));
  }

  void parseLoginServerBinaryMessage(ByteBuffer data) {
    Uint32List uint32s = data.asUint32List();
    int fileID = uint32s[0];
    switch (fileID) {
      case 0:
        this.data.parseScores(data);
      case 1:
        this.data.parseStars(data);
      case 2:
        this.data.parseSystems(data);
      default:
        openErrorDialog('Error - Unrecognised file ID: $fileID', context);
    }
  }

  void getFile(int fileID) {
    connectToLoginServer()
        .then((e) => e.send(['get-file', fileID.toString()]))
        .then((message) {
      if (message[0] == 'F') {
        assert(message.length == 2);
        openErrorDialog(
            'Error: failed to get file $fileID - ${message[1]}', context);
      }
      assert(message.length == 1);
      assert(message[0] == 'T');
    });
  }

  void getHighScores(Iterable<DynastyID> ids) {
    connectToLoginServer()
        .then(
            (e) => e.send(['get-high-scores', ...ids.map((e) => e.toString())]))
        .then((message) {
      if (message[0] == 'F') {
        assert(message.length == 2);
        openErrorDialog(
            'Error: failed to get high scores for dynasties $ids - ${message[1]}',
            context);
      }
      assert(message.length == 1);
      assert(message[0] == 'T');
    });
  }

  Future<void> onLoginServerConnect() async {
    setState(() {
      loginState = LoginState.notLoggedIn;
    });
    if (data.galaxyDiameter == null) {
      loginServer!.send(['get-constants']).then((message) {
        if (message[0] == 'F') {
          assert(message.length == 2);
          openErrorDialog(
              'Error: failed to get constants - ${message[1]}', context);
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
      login();
    }
  }

  Future<void> login() async {
    if (loginServer == null) {
      setState(() {
        loginState = LoginState.connectingToLoginServer;
      });
      try {
        await connectToLoginServer();
      } on HttpException {
        return login();
      }
    }
    setState(() {
      loginState = LoginState.waitingOnLoginServer;
    });
    List<String> message =
        await loginServer!.send(['login', data.username!, data.password!]);
    if (message[0] == 'F') {
      if (message[1] == 'unrecognized credentials') {
        assert(message.length == 2);
        logout();
      } else {
        setState(() {
          loginState = LoginState.loginServerLoginError;
        });
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

  void connectToSystemServer(String server) {
    connect(server).then((socket) async {
      Map<int, String> stringTable = {};
      Map<int, AssetClass> assetClassTable = {};
      late NetworkConnection systemServer;
      systemServer = NetworkConnection(
        socket,
        unrequestedMessageHandler: (message) {
          openErrorDialog(
            'Unexpected message from system server $server: $message',
            context,
          );
        },
        binaryMessageHandler: (data) {
          if (mounted)
            setState(() {
              try {
                for (StarIdentifier star in systemServersBySystemID.entries
                    .toList()
                    .where((e) => e.value == server)
                    .map((e) => e.key)) {
                  systemServersBySystemID.remove(star);
                }
                BinaryReader reader = BinaryReader(
                    data, stringTable, assetClassTable, Endian.little);
                Set<StarIdentifier> systems = parseSystemServerBinaryMessage(
                  reader,
                  this.data,
                );
                systemServersBySystemID
                    .addEntries(systems.map((e) => MapEntry(e, systemServer)));
              } catch (e) {
                this.data.assets.clear();
                this.data.rootAssets.clear();
                openErrorDialog(e.toString(), context);
              }
            });
        },
        onReset: (NetworkConnection systemServer) {
          stringTable.clear();
          assetClassTable.clear();
          onSystemServerReset(systemServer, server);
        },
        onError: (e, st) {
          setState(() {
            loginState = LoginState.connectingToSystemServers;
            currentSystemServerConnectedCount--;
            systemServersLoggedIn.remove(server);
          });
        },
      );
      systemServers[server] = systemServer;
    }, onError: (e, st) {
      setState(() {
        loginState = LoginState.systemServerConnectionError;
      });
    });
  }

  Future<void> onSystemServerReset(
      NetworkConnection systemServer, String serverName) async {
    currentSystemServerConnectedCount++;
    assert(currentSystemServerConnectedCount <= expectedSystemServerCount,
        'more servers connected than expected, expected $expectedSystemServerCount connected, got $currentSystemServerConnectedCount');
    if (currentSystemServerConnectedCount == expectedSystemServerCount) {
      setState(() {
        loginState = LoginState.waitingOnSystemServers;
      });
    }
    if (data.token == null) {
      loginState = LoginState.notLoggedIn;
      currentSystemServerConnectedCount--;
      systemServer.close();
      return;
    }
    List<String> message = await systemServer.send(['login', data.token!]);
    if (message[0] == 'F') {
      if (message[1] == 'unrecognized credentials') {
        await connectToLoginServer();
        currentSystemServerConnectedCount--;
        if (data.username != null && data.password != null) {
          await login();
        } else {
          systemServer.close();
          return;
        }
        onSystemServerReset(systemServer, serverName);
      } else {
        openErrorDialog(
            'Error: failed system server $serverName login ($message)',
            context);
        loginState = LoginState.systemServerLoginError;
      }
    } else {
      systemServersLoggedIn.add(serverName);
      assert(systemServersLoggedIn.length <= expectedSystemServerCount);
      if (systemServersLoggedIn.length == expectedSystemServerCount) {
        setState(() {
          loginState = LoginState.ready;
        });
      }
      assert(message[0] == 'T');
      assert(message.length == 2);
      int version = int.parse(message[1]);
      if (version != kClientVersion) {
        openErrorDialog(
          'Warning: server version $version does not match client version $kClientVersion',
          context,
        );
      }
    }
  }

  void parseSuccessfulLoginResponse(List<String> message) {
    assert(message[0] == 'T');
    assert(message.length == 3);
    data.setToken(message[2]);
    loginServer!.close();
    loginServer = null;
    setState(() {
      loginState = LoginState.connectingToDynastyServer;
    });
    connect(message[1]).then((socket) async {
      if (mounted)
        setState(() {
          dynastyServer?.close();
          dynastyServer = NetworkConnection(
            socket,
            unrequestedMessageHandler: onDynastyServerMessage,
            binaryMessageHandler: (data) {
              Uint8List bytes = data.asUint8List();
              openErrorDialog(
                'Unexpected binary message from dynasty server: ${bytes.length <= 10 ? bytes : '[${bytes.sublist(0, 10).join(', ')}, ...${bytes.length - 10} more]'}',
                context,
              );
            },
            onReset: onDynastyServerReset,
            onError: (e, st) {
              setState(() {
                loginState = LoginState.connectingToDynastyServer;
              });
            },
          );
        });
    }, onError: (e, st) {
      setState(() {
        loginState = LoginState.dynastyServerConnectionError;
      });
    });
  }

  void onDynastyServerMessage(message) {
    switch (message.first) {
      case 'system-servers':
        int systemServerCount = int.parse(message[1]);
        connectToSystemServers(systemServerCount, message.skip(2));
      default:
        openErrorDialog(
          'Unexpected message from dynasty server: $message',
          context,
        );
    }
  }

  void connectToSystemServers(
      int systemServerCount, Iterable<String> systemServerURIs) {
    for (NetworkConnection connection in systemServers.values) {
      connection.close();
    }
    systemServers.clear();
    systemServersLoggedIn.clear();
    systemServersBySystemID.clear();
    assert(systemServerURIs.length == systemServerCount);
    expectedSystemServerCount = systemServerCount;
    currentSystemServerConnectedCount = 0;
    setState(() {
      loginState = LoginState.connectingToSystemServers;
    });
    if (systemServerCount == 0) {
      setState(() {
        loginState = LoginState.noSystemServers;
      });
    }
    for (String server in systemServerURIs) {
      connectToSystemServer(server);
    }
  }

  Future<void> onDynastyServerReset(NetworkConnection dynastyServer) async {
    setState(() {
      loginState = LoginState.waitingOnDynastyServer;
    });
    if (data.token == null) {
      loginState = LoginState.notLoggedIn;
      return;
    }
    List<String> message = await dynastyServer.send(['login', data.token!]);
    if (message[0] == 'F') {
      assert(message.length == 2);
      if (message[1] == 'unrecognized credentials') {
        try {
          await connectToLoginServer();
        } catch (error) {
          openErrorDialog(error.toString(), context);
          onDynastyServerReset(dynastyServer);
        }
        if (data.username != null && data.password != null) {
          await login();
        } else {
          dynastyServer.close();
          return;
        }
        onDynastyServerReset(dynastyServer);
      } else {
        openErrorDialog(
            'response from dynasty server login: ${message[1]}', context);
        setState(() {
          loginState = LoginState.dynastyServerLoginError;
        });
      }
    } else {
      assert(message[0] == 'T');
      data.setDynastyID(int.parse(message[1]));
      int systemServerCount = int.parse(message[2]);
      Iterable<String> systemServerURIs = message.skip(3);
      connectToSystemServers(systemServerCount, systemServerURIs);
    }
  }

  @override
  void dispose() {
    data.dispose();
    dynastyServer?.close();
    loginServer?.close();
    ticker.cancel();
    for (NetworkConnection server in systemServers.values) {
      server.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: loginState == LoginState.ready
            ? TabBar(
                tabs: [
                  Text('Galaxy view'),
                  Text('System view'),
                  Text('System view (debug)'),
                  Text('Planet view')
                ],
                controller: tabController,
              )
            : null,
        actions: [
          if (systemServersBySystemID.isNotEmpty)
            IconButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: DebugCommandSenderWidget(
                      servers: systemServersBySystemID,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.abc),
            ),
          if (data.rootAssets.length > 0)
            ListenableBuilder(
                listenable: data,
                builder: (context, child) {
                  int messageCount = data.rootAssets.values.fold(
                      0,
                      (a, b) =>
                          a +
                          data
                              .findFeature<MessageFeature>(b)
                              .where((e) => data.assets[e]!.features
                                  .any((e) => e is MessageFeature && !e.isRead))
                              .length);
                  return Badge.count(
                    count: messageCount,
                    isLabelVisible: messageCount > 0,
                    child: IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Inbox(
                              data: data,
                              servers: systemServersBySystemID,
                            ),
                          ),
                        );
                      },
                      icon: Icon(Icons.inbox),
                    ),
                  );
                }),
          if (data.username != null && data.password != null)
            IconButton(
              icon: Icon(
                Icons.person,
              ),
              onPressed: () => openAccountDialog(context),
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
      body: loginServer?.reloading ?? false
          ? Column(
              children: [
                Text('reconnecting to login server...'),
                CircularProgressIndicator(),
              ],
            )
          : switch (loginState) {
              LoginState.connectingToLoginServer => Center(
                  child: Column(
                    children: [
                      Text('connecting to login server...'),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              LoginState.waitingOnLoginServer => Center(
                  child: Column(
                    children: [
                      Text(
                          'waiting for login server to respond to login message...'),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              LoginState.loginServerConnectionError => Center(
                  child: Text('Failed to connect to login server.'),
                ),
              LoginState.loginServerLoginError => Center(
                  child: Text('Login server had error when logging in.'),
                ),
              LoginState.connectingToDynastyServer => Center(
                  child: Column(
                    children: [
                      Text('connecting to dynasty server...'),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              LoginState.waitingOnDynastyServer => Center(
                  child: Column(
                    children: [
                      Text(
                        'waiting for dynasty server to respond to login message...',
                      ),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              LoginState.dynastyServerConnectionError => Center(
                  child: Text('Failed to connect to dynasty server.'),
                ),
              LoginState.dynastyServerLoginError => Center(
                  child: Text('Dynasty server had error when logging in.'),
                ),
              LoginState.connectingToSystemServers => Center(
                  child: Column(
                    children: [
                      Text('connecting to system server...'),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              LoginState.waitingOnSystemServers => Center(
                  child: Column(
                    children: [
                      Text(
                          'waiting for system server to respond to login message...'),
                      CircularProgressIndicator(),
                    ],
                  ),
                ),
              LoginState.systemServerConnectionError => Center(
                  child: Text('Failed to connect to system server.'),
                ),
              LoginState.systemServerLoginError => Center(
                  child: Text('System server had error when logging in.'),
                ),
              LoginState.noSystemServers => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                          'You have no visibility into anything. You should create another account.'),
                      Text(
                          'This sometimes means the system server is not running or broken.'),
                      OutlinedButton(
                          onPressed: () => openAccountDialog(context),
                          child: Text('Change username or password')),
                      OutlinedButton(onPressed: logout, child: Text('Logout'))
                    ],
                  ),
                ),
              LoginState.notLoggedIn => loginServer == null
                  ? Center(
                      child: Column(
                        children: [
                          Text('connecting to login server...'),
                          CircularProgressIndicator(),
                        ],
                      ),
                    )
                  : Center(
                      child: LoginWidget(
                        loginServer: loginServer!,
                        data: data,
                        parseSuccessfulLoginResponse:
                            parseSuccessfulLoginResponse,
                      ),
                    ),
              LoginState.ready => ListenableBuilder(
                  listenable: data,
                  builder: (context, child) {
                    return Row(
                      children: [
                        Expanded(
                          child: TabBarView(
                            controller: tabController,
                            children: [
                              GalaxyView(
                                data: data,
                                dynastyServer: dynastyServer,
                              ),
                              systemview.SystemSelector(data: data),
                              debugsystemview.SystemSelector(data: data),
                              planetview.SystemSelector(
                                data: data,
                                servers: systemServersBySystemID,
                              ),
                            ],
                          ),
                        ),
                        VerticalDivider(),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('LEADERBOARD'),
                            ...(data.scores.entries.toList()
                                  ..sort((a, b) => -a.value.scores.last.score
                                      .compareTo(b.value.scores.last.score)))
                                .map((e) => Text.rich(TextSpan(children: [
                                      TextSpan(
                                        text:
                                            '${e.key == data.dynastyID ? 'You' : 'Dynasty'}',
                                        style: TextStyle(
                                            color: getColorForDynastyID(e.key)),
                                      ),
                                      TextSpan(
                                        text:
                                            '${e.value.scores.last.score} points',
                                      ),
                                    ])))
                          ],
                        ),
                      ],
                    );
                  },
                ),
            },
    );
  }

  void openAccountDialog(BuildContext context) {
    connectToLoginServer().then(
      (server) => showDialog(
        context: context,
        builder: (context) => Dialog(
          child: AccountWidget(
            data: data,
            loginServer: server,
            logout: logout,
            isDarkMode: isDarkMode,
          ),
        ),
      ).then((value) {
        if (!cannotCloseLoginServer.contains(loginState)) {
          loginServer?.close();
          loginServer = null;
        }
      }),
      onError: (e, st) {
        openErrorDialog('Could not connect to login server.', context);
      },
    );
  }

  /// deletes all account-related info from this machine and goes back to login screen
  void logout() {
    setState(() {
      loginState = LoginState.connectingToLoginServer;
    });
    data.logout();
    dynastyServer?.close();
    for (NetworkConnection server in systemServers.values) {
      server.close();
    }
    systemServers.clear();
    systemServersLoggedIn.clear();
    systemServersBySystemID.clear();
    connectToLoginServer().then((e) {
      setState(() {
        loginState = LoginState.notLoggedIn;
      });
    }, onError: (e, st) {
      setState(() {
        loginState = LoginState.loginServerConnectionError;
      });
    });
  }

  Future<NetworkConnection> connectToLoginServer() {
    if (loginServer != null) return Future.value(loginServer!);
    Completer<NetworkConnection> result = Completer();
    NetworkConnection.fromURL(
      loginServerURL,
      unrequestedMessageHandler: (message) {
        openErrorDialog(
          'Unexpected message from login server: $message',
          context,
        );
      },
      binaryMessageHandler: parseLoginServerBinaryMessage,
      onError: (e, st) {
        connectToLoginServer();
      },
    ).then(
      (server) {
        setState(() {
          loginServer = server;
          result.complete(server);
        });
      },
      onError: (e, st) {
        setState(() {
          loginState = LoginState.loginServerConnectionError;
          result.completeError(e);
        });
      },
    );
    return result.future;
  }
}

class DebugCommandSenderWidget extends StatefulWidget {
  const DebugCommandSenderWidget({super.key, required this.servers});
  final Map<StarIdentifier, NetworkConnection> servers;

  @override
  State<DebugCommandSenderWidget> createState() =>
      _DebugCommandSenderWidgetState();
}

class _DebugCommandSenderWidgetState extends State<DebugCommandSenderWidget> {
  StarIdentifier? systemID;
  TextEditingController assetID = TextEditingController();
  TextEditingController command = TextEditingController();
  TextEditingController semicolonSeparatedArgs = TextEditingController();

  void sendMessage() {
    if (!assetID.text.startsWith('A')) {
      openErrorDialog(
          'Failure parsing asset ID: Asset IDs must start with A.', context);
      return;
    }
    int assetIDV;
    try {
      assetIDV = int.parse(assetID.text.substring(1), radix: 16);
    } catch (e) {
      openErrorDialog('Failure when trying to parse asset ID: $e', context);
      return;
    }
    String commandV = command.text;
    List<String> args = semicolonSeparatedArgs.text.isEmpty
        ? []
        : semicolonSeparatedArgs.text.split(';');
    widget.servers[systemID]!.send([
      'play',
      systemID!.value.toString(),
      assetIDV.toString(),
      commandV,
      ...args,
    ]).then((List<String> response) {
      showDialog(
          context: context,
          builder: (context) => Dialog(
                child: SelectableText('response: $response'),
              ));
    });
  }

  @override
  void initState() {
    if (widget.servers.keys.length == 1) {
      systemID = widget.servers.keys.single;
    }
    super.initState();
  }

  @override
  void didUpdateWidget(covariant DebugCommandSenderWidget oldWidget) {
    setState(() {});
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<StarIdentifier>(
          hint: Text('System ID'),
          value: systemID,
          items: widget.servers.keys
              .map(
                (e) => DropdownMenuItem<StarIdentifier>(
                  value: e,
                  child: Text('${e.displayName}'),
                ),
              )
              .toList(),
          onChanged: (e) {
            setState(() {
              systemID = e;
            });
          },
        ),
        SizedBox(
          width: 100,
          child: TextField(
            decoration: InputDecoration(label: Text('Asset ID')),
            controller: assetID,
          ),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            decoration: InputDecoration(label: Text('Command')),
            controller: command,
          ),
        ),
        SizedBox(
          width: 100,
          child: TextField(
            decoration: InputDecoration(label: Text('Args (;)')),
            controller: semicolonSeparatedArgs,
          ),
        ),
        OutlinedButton(
          onPressed: sendMessage,
          child: Text('Send'),
        ),
      ],
    );
  }
}
