import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'debugsystemview.dart' as debugsystemview;
import 'systemview.dart' as systemview;
import 'planetview.dart' as planetview;
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

  Feature parseFeature(int featureCode, BinaryReader reader, StarIdentifier systemID) {
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
          Uint64 time0 = reader.readUint64();
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
              time0,
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
      default:
        throw UnimplementedError('Unknown featureID $featureCode');
    }
  }

  static const kClientVersion = 11;

  void parseSystemServerBinaryMessage(ByteBuffer data, Map<int, String> stringTable) {
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
        this.data.setRootAsset(systemID, rootAssetID);
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
          this.data.setAssetNode(
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
                'Unexpected binary message from system server: ${bytes.length <= 10 ? bytes : '[${bytes.sublist(0, 10)}, ...${bytes.length - 10} more]'}',
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
                          StarLookupWidget(
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

class StarLookupWidget extends StatefulWidget {
  const StarLookupWidget(
      {super.key, required this.data, required this.dynastyServer});

  final DataStructure data;
  final NetworkConnection? dynastyServer;

  @override
  State<StarLookupWidget> createState() => _StarLookupWidgetState();
}

class _StarLookupWidgetState extends State<StarLookupWidget>
    with TickerProviderStateMixin {
  final TextEditingController textFieldController = TextEditingController();
  String? errorMessage;
  String? description;
  StarIdentifier? selectedStar;
  ZoomController? galaxyZoomController;

  @override
  void dispose() {
    galaxyZoomController?.dispose();
    super.dispose();
  }

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
                StarIdentifier starID = StarIdentifier.parse(integerStarID);
                if (starID.category < 0) {
                  errorMessage =
                      'Invalid star ID. Star IDs cannot be negative.';
                  return;
                }
                if (starID.category > 10) {
                  errorMessage =
                      'Invalid star ID. The maximum star category (the first hexadecimal digit) is A.';
                  return;
                }
                if (widget.data.stars == null) {
                  errorMessage = 'Still loading stars. Try again later.';
                  return;
                }
                if (widget.data.stars![starID.category].length <=
                    starID.subindex) {
                  errorMessage =
                      'Invalid star ID. The maximum value for the last five hexadecimal digits of a star with category ${starID.category} is ${(widget.data.stars![starID.category].length - 1).toRadixString(16)}.';
                  return;
                }
                errorMessage = null;
                description = null;
                selectedStar = starID;
                galaxyZoomController ??= ZoomController(
                  vsync: this,
                  zoom: 100,
                  screenCenter: widget.data.stars![starID.category]
                      [starID.subindex],
                );
                galaxyZoomController!.animateTo(
                  100,
                  widget.data.stars![starID.category][starID.subindex],
                );
                if (widget.dynastyServer != null) {
                  if (widget.dynastyServer!.reloading) {
                    errorMessage = 'Dynasty server offline; try again later';
                  } else {
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
                  }
                } else {
                  errorMessage = 'Could not load name; try again later.';
                }
              });
            },
            child: Text('Lookup'),
          ),
        ),
        OutlinedButton(
          onPressed: () {
            setState(() {
              errorMessage = null;
              description = null;
              galaxyZoomController ??= ZoomController(
                vsync: this,
                zoom: 1,
                screenCenter: Offset(0.5, 0.5),
              );
              galaxyZoomController!.animateTo(1, Offset(.5, .5));
            });
          },
          child: Text('See full galaxy'),
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
        if (galaxyZoomController != null)
          Expanded(
            child: ZoomableCustomPaint(
              painter: GalaxyRenderer(
                widget.data.stars!,
                selectedStar == null ? {} : {selectedStar!},
                galaxyZoomController!,
              ),
              controller: galaxyZoomController!,
            ),
          ),
      ],
    );
  }
}

class GalaxyRenderer extends CustomPainter {
  final List<List<Offset>> stars;
  final Set<StarIdentifier> highlightedStars;
  final ZoomController zoomController;
  const GalaxyRenderer(this.stars, this.highlightedStars, this.zoomController)
      : super(repaint: zoomController);

  @override
  void paint(Canvas canvas, Size size) {
    Offset screenCenter = zoomController.screenCenter;
    double zoom = zoomController.zoom;
    int category = 0;
    Offset topLeft = Offset(screenCenter.dx - .5, screenCenter.dy - .5);
    canvas.drawOval(
        (((-topLeft - Offset(.5, .5)) * zoom) + Offset(.5, .5))
                .scale(size.width, size.height) &
            size * zoom,
        Paint()
          ..color = (Color(0x5566BBFF).withAlpha((0x55 / zoom).toInt()))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10));
    for (StarIdentifier star in highlightedStars) {
      Offset starPos = stars[star.category][star.subindex];
      canvas.drawCircle(
          calculateScreenPosition(starPos, screenCenter, zoom, size),
          starCategories[star.category].strokeWidth *
              size.shortestSide *
              2 *
              sqrt(zoom) /
              3,
          Paint.from(starCategories[star.category])
            ..color = Colors.green
            ..strokeWidth = 0);
    }
    while (category < 11) {
      canvas.drawPoints(
          PointMode.points,
          stars[category].map((e) {
            return calculateScreenPosition(e, screenCenter, zoom, size);
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
