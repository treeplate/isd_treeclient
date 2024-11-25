import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'debugsystemview.dart' as debugsystemview;
import 'systemview.dart' as systemview;
import 'planetview.dart' as planetview;
import 'galaxyview.dart';
import 'inbox.dart';
import 'binaryreader.dart';
import 'network_handler.dart';
import 'account.dart';
import 'assets.dart';
import 'data-structure.dart';
import 'ui-core.dart';
import 'core.dart';
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
  int currentSystemServerLoggedInCount = 0;
  LoginState loginState = LoginState.connectingToLoginServer;
  final Map<String, NetworkConnection> systemServers = {}; // URI -> connection
  final List<String> systemServersLoggedIn =
      []; // list of system server URIs that have responded to "login"
  bool get isDarkMode => widget.themeMode == ThemeMode.system
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      : widget.themeMode == ThemeMode.dark;
  late TabController tabController =
      TabController(length: 4, vsync: this, initialIndex: 1);

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
  }

  void parseLoginServerBinaryMessage(ByteBuffer data) {
    Uint32List uint32s = data.asUint32List();
    int fileID = uint32s[0];
    switch (fileID) {
      case 1:
        this.data.parseStars(uint32s, data);
      case 2:
        this.data.parseSystems(uint32s, data);
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

  Feature parseFeature(
      int featureCode, BinaryReader reader, StarIdentifier systemID) {
    switch (featureCode) {
      case 1:
        return StarFeature(StarIdentifier.parse(reader.readUint32()));
      case 2:
        int id = reader.readUint32();
        assert(id != 0);
        AssetID primaryChild = AssetID(systemID, id);
        int childCount = reader.readUint32();
        int i = 0;
        List<SolarSystemChild> children = [
          SolarSystemChild(primaryChild, 0, 0)
        ];
        while (i < childCount) {
          double distanceFromCenter = reader.readFloat64();
          double theta = reader.readFloat64();
          int id = reader.readUint32();
          assert(id != 0);
          AssetID child = AssetID(systemID, id);
          children.add(SolarSystemChild(child, distanceFromCenter, theta));
          i++;
        }
        return SolarSystemFeature(children);
      case 3:
        int id = reader.readUint32();
        assert(id != 0);
        AssetID primaryChild = AssetID(systemID, id);
        int childCount = reader.readUint32();
        int i = 0;
        List<OrbitChild> children = [];
        while (i < childCount) {
          double semiMajorAxis = reader.readFloat64();
          double eccentricity = reader.readFloat64();
          double omega = reader.readFloat64();
          Uint64 timeOrigin = reader.readUint64();
          int direction = reader.readUint8();
          if (direction > 0x1) {
            openErrorDialog(
                'Unsupported OrbitChild.direction: 0x${direction.toRadixString(16)}',
                context);
          }
          int id = reader.readUint32();
          assert(id != 0);
          AssetID child = AssetID(systemID, id);
          children.add(
            OrbitChild(
              child,
              semiMajorAxis,
              eccentricity,
              timeOrigin,
              direction & 0x1 > 0,
              omega,
            ),
          );
          i++;
        }
        return OrbitFeature(children, primaryChild);
      case 4:
        List<MaterialLineItem> materials = [];
        while (reader.readUint32() != 0) {
          int quantity = reader.readUint32();
          int max = reader.readUint32();
          String componentName = reader.readString();
          String materialDescription = reader.readString();
          int id = reader.readUint32();
          int? materialID = id == 0 ? null : id;
          materials.add(MaterialLineItem(
            componentName == '' ? null : componentName,
            materialID,
            quantity,
            max == 0 ? null : max,
            materialDescription,
          ));
        }
        int hp = reader.readUint32();
        int minHP = reader.readUint32();
        return StructureFeature(
          materials,
          hp,
          minHP == 0 ? null : minHP,
        );
      case 5:
        return SpaceSensorFeature(
          reader.readUint32(),
          reader.readUint32(),
          reader.readUint32(),
          reader.readFloat64(),
        );
      case 6:
        return SpaceSensorStatusFeature(
          AssetID(systemID, reader.readUint32()),
          AssetID(systemID, reader.readUint32()),
          reader.readUint32(),
        );
      case 7:
        int hp = reader.readUint32();
        return PlanetFeature(
          hp,
        );
      case 8:
        int isColonyShip = reader.readUint32();
        assert(isColonyShip < 2);
        return PlotControlFeature(
          isColonyShip == 1,
        );
      case 9:
        int regionCount = reader.readUint32();
        if (regionCount != 1) {
          openErrorDialog('surface has $regionCount regions', context);
        }
        int i = 0;
        List<AssetID> regions = [];
        while (i < regionCount) {
          int id = reader.readUint32();
          assert(id != 0);
          AssetID region = AssetID(systemID, id);
          regions.add(region);
          i++;
        }
        return SurfaceFeature(regions);
      case 10:
        double cellSize = reader.readFloat64();
        int width = reader.readUint32();
        int height = reader.readUint32();
        int cellCount = reader.readUint32();
        int i = 0;
        List<AssetID?> cells = List.filled(width * height, null);
        while (i < cellCount) {
          int x = reader.readUint32();
          int y = reader.readUint32();
          int id = reader.readUint32();
          assert(id != 0);
          cells[x + y * width] = AssetID(systemID, id);
          i++;
        }
        return GridFeature(cells, width, height, cellSize);
      case 11:
        Uint64 population = reader.readUint64();
        double averageHappiness = reader.readFloat64();
        return PopulationFeature(population, averageHappiness);
      case 12:
        int messageCount = reader.readUint32();
        int i = 0;
        List<AssetID> messages = [];
        while (i < messageCount) {
          int id = reader.readUint32();
          assert(id != 0);
          AssetID message = AssetID(systemID, id);
          messages.add(message);
          i++;
        }
        return MessageBoardFeature(messages);
      case 13:
        StarIdentifier sourceSystem = StarIdentifier.parse(reader.readUint32());
        int id = reader.readUint32();
        AssetID? sourceAsset = id == 0 ? AssetID(systemID, id) : null;
        assert(systemID == sourceSystem || sourceAsset == null);
        Uint64 timestamp = reader.readUint64();
        int isRead = reader.readUint8();
        if (isRead > 0x1) {
          openErrorDialog(
              'Unsupported MessageFeature.isRead: 0x${isRead.toRadixString(16)}',
              context);
        }
        String message = reader.readString();
        return MessageFeature(sourceSystem, sourceAsset, timestamp, isRead == 0x1, message);
      default:
        throw UnimplementedError('Unknown featureID $featureCode');
    }
  }

  static const kClientVersion = 13;

  void parseSystemServerBinaryMessage(
      ByteBuffer data, Map<int, String> stringTable) {
    BinaryReader reader = BinaryReader(data, stringTable, Endian.little);
    while (!reader.done) {
      int id = reader.readUint32();
      if (id < 0x10000000) {
        StarIdentifier systemID = StarIdentifier.parse(id);

        (DateTime, Uint64) time0 = (DateTime.timestamp(), reader.readUint64());
        double timeFactor = reader.readFloat64();
        id = reader.readUint32();
        assert(id != 0);
        AssetID rootAssetID = AssetID(systemID, id);
        setState(() {
          this.data.setRootAsset(systemID, rootAssetID);
        });
        Offset position = Offset(reader.readFloat64(), reader.readFloat64());
        this
            .data
            .setSystemPosition(systemID, position / this.data.galaxyDiameter!);
        this.data.setTime0(systemID, time0);
        this.data.setTimeFactor(systemID, timeFactor);
        while (true) {
          int id = reader.readUint32();
          if (id == 0) break;
          AssetID assetID = AssetID(systemID, id);
          int owner = reader.readUint32();
          double mass = reader.readFloat64();
          double size = reader.readFloat64();
          String name = reader.readString();
          String icon = reader.readString();
          String className = reader.readString();
          String description = reader.readString();
          List<Feature> features = [];
          while (true) {
            int featureCode = reader.readUint32();
            if (featureCode == 0) break;
            features.add(parseFeature(featureCode, reader, systemID));
          }
          this.data.setAsset(
                assetID,
                Asset(
                  features,
                  mass,
                  owner == 0 ? null : owner,
                  size,
                  name == '' ? null : name,
                  icon,
                  className,
                  description,
                ),
              );
        }
      } else {
        switch (id) {
          default:
            throw UnimplementedError(
                'Unknown notification ID 0x${id.toRadixString(16)}');
        }
      }
    }
  }

  void connectToSystemServer(String server) {
    connect(server).then((socket) async {
      Map<int, String> stringTable = {};
      NetworkConnection systemServer = NetworkConnection(
        socket,
        unrequestedMessageHandler: (message) {
          openErrorDialog(
            'Unexpected message from system server $server: $message',
            context,
          );
        },
        binaryMessageHandler: (data) =>
            parseSystemServerBinaryMessage(data, stringTable),
        onReset: (NetworkConnection systemServer) {
          onSystemServerReset(systemServer, server);
        },
        onError: (e, st) {
          setState(() {
            loginState = LoginState.connectingToSystemServers;
            currentSystemServerConnectedCount--;
            if (systemServersLoggedIn.contains(server)) {
              currentSystemServerLoggedInCount--;
            }
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
      return;
    }
    List<String> message = await systemServer.send(['login', data.token!]);
    if (message[0] == 'F') {
      if (message[1] == 'unrecognized credentials') {
        await connectToLoginServer();
        await login();
        onSystemServerReset(systemServer, serverName);
      } else {
        openErrorDialog(
            'Error: failed system server $serverName login ($message)',
            context);
        loginState = LoginState.systemServerLoginError;
      }
    } else {
      currentSystemServerLoggedInCount++;
      systemServersLoggedIn.add(serverName);
      assert(currentSystemServerLoggedInCount <= expectedSystemServerCount);
      if (currentSystemServerLoggedInCount == expectedSystemServerCount) {
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
            context);
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
      print('logged in succesfully');
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
              print('dynasty server error; reconnecting...');
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
    assert(systemServerURIs.length == systemServerCount);
    expectedSystemServerCount = systemServerCount;
    currentSystemServerLoggedInCount = 0;
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
        await connectToLoginServer();
        await login();
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
          if (data.rootAssets.length > 0)
            ListenableBuilder(
                listenable: data,
                builder: (context, child) {
                  int messageCount = data.rootAssets.values
                      .fold(0, (a, b) => a + findMessages(b, data).length);
                  return Badge.count(
                    count: messageCount,
                    isLabelVisible: messageCount > 0,
                    child: IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            child: Inbox(data: data),
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
                    return Center(
                      child: TabBarView(
                        controller: tabController,
                        children: [
                          GalaxyView(
                            data: data,
                            dynastyServer: dynastyServer,
                          ),
                          systemview.SystemSelector(data: data),
                          debugsystemview.SystemSelector(data: data),
                          planetview.SystemSelector(data: data),
                        ],
                      ),
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

  Future<NetworkConnection> connectToLoginServer() async {
    if (loginServer != null) return loginServer!;
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
