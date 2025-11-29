import 'dart:io';

import '../../network_handler.dart';
import '../../binaryreader.dart';
import '../../data-structure.dart';
import '../../parseSystemServerBinaryMessage.dart';
import '../../assets.dart';
import 'dart:typed_data';

//ignore_for_file: avoid_print

void setTopic(
    NetworkConnection server, AssetID researcher, String topic) async {
  List<String> result = await server.send([
    'play',
    researcher.system.value.toString(),
    researcher.id.toString(),
    'set-topic',
    topic,
  ]);
  if (result.first != 'T') {
    throw Exception('\'set-topic\' error: $result');
  }
}

void build(
  NetworkConnection server,
  AssetID grid,
  GridFeature feature,
  String name,
) async {
  int x = 0;
  int y = 0;
  Buildable buildable =
      feature.buildables.singleWhere((e) => e.assetClass.name == name);
  outer:
  do {
    print('top $x $y');
    for (Building building in feature.buildings) {
      if (building.x < (x + buildable.size) &&
          building.x + building.size > x &&
          building.y < (y + buildable.size) &&
          building.y + building.size > y) {
      print('($x, $y) vs (${building.x}, ${building.y})');
        print('collision');
        x++;
        if (x + building.size >= feature.dimension) {
          x = 0;
          y++;
          assert(y < feature.dimension);
        }
        continue outer;
      }
    }
    print('bottom $x $y');
    break;
  } while (true);
  List<String> result = await server.send([
    'play',
    grid.system.value.toString(),
    grid.id.toString(),
    'build',
    x.toString(),
    y.toString(),
    buildable.assetClass.id.toString(),
  ]);
  if (result.first != 'T') {
    throw Exception('\'build\' error: $result');
  }
}

void main() async {
  DateTime startTime = DateTime.timestamp();
  NetworkConnection loginServer = await NetworkConnection.fromURL(
    loginServerURL,
    unrequestedMessageHandler: (List<String> message) {
      print('login server unrequested message: $message');
    },
    binaryMessageHandler: (ByteBuffer data) {
      print('login server binary message: $data');
    },
    onError: (Object error, StackTrace stackTrace) {
      print('login server error: $error');
    },
  );
  print('Creating new account...');
  List<String> result = await loginServer.send(['new']);
  if (result[0] == 'F') {
    throw Exception('\'new\' error: $result');
  }
  String username = result[1];
  String password = result[2];
  String dynastyServerURL = result[3];
  String token = result[4];
  int i = 1;
  while (true) {
    String newUsername = 'tasbot$i';
    if (i == 1) newUsername = 'tasbot';
    result = await loginServer
        .send(['change-username', username, password, newUsername]);
    if (result[0] == 'T') {
      username = newUsername;
      print('Username: $newUsername');
      print('Password (server-generated): $password');
      break;
    }
    if (result[1] != 'inadequate username') {
      throw Exception('\'change-username\' error: $result');
    }
    i++;
  }
  try {
    print('Connecting to dynasty server...');
    NetworkConnection dynastyServer = await NetworkConnection.fromURL(
      dynastyServerURL,
      unrequestedMessageHandler: (List<String> message) {
        print('dynasty server unrequested message: $message');
      },
      binaryMessageHandler: (ByteBuffer data) {
        print('dynasty server binary message: $data');
      },
      onError: (Object error, StackTrace stackTrace) {
        print('dynasty server error: $error');
      },
    );
    result = await dynastyServer.send(['login', token]);
    if (result[0] == 'F') {
      throw Exception('dynasty server \'login\' error: $result');
    }
    int systemServerCount = int.parse(result[2]);
    if (systemServerCount != 1) {
      throw Exception('unexpected system server count: $result');
    }
    String systemServerURL = result[3];
    print('dynasty ID: ${result[1]}');
    print('Connecting to system server...');
    DataStructure data = DataStructure();
    Map<int, String> stringTable = {};
    Map<int, AssetClass> assetClassTable = {};
    late NetworkConnection systemServer;
    systemServer = await NetworkConnection.fromURL(
      systemServerURL,
      unrequestedMessageHandler: (List<String> message) {
        print('system server unrequested message: $message');
      },
      binaryMessageHandler: (ByteBuffer message) {
        BinaryReader reader =
            BinaryReader(message, stringTable, assetClassTable, Endian.little);
        data.galaxyDiameter = 1;
        parseSystemServerBinaryMessage(reader, data);
        mainLoop(data, systemServer, assetClassTable);
      },
      onError: (Object error, StackTrace stackTrace) {
        print('system server error: $error');
      },
      onReset: (NetworkConnection server) async {
        stringTable.clear();
        result = await server.send(['login', token]);
        if (result[0] == 'F') {
          throw Exception('system server \'login\' error: $result');
        }
      },
    );
    await Future.delayed(Duration(hours: 24));
  } catch (e, st) {
    print(e);
    print(st);
  } finally {
    String newName = 'tasbot-${startTime.toIso8601String()}';
    loginServer.send(['change-username', username, password, newName]);
    print('finished, renamed to $newName');
    exit(0);
  }
}

AssetID? findAsset(DataStructure data, AssetClassID assetClassID, int skip) {
  return data.assets.entries
      .where((e) => e.value.assetClass.id == assetClassID)
      .skip(skip)
      .firstOrNull
      ?.key;
}

// region: -201
// ship: -3
//
// church: 1 (for researching religon)
// archeo hole: 5 (main research tool)
// iron table: 6 (for church)
// iron pile: 7 (to store iron before church)
// silicon table: 9 (for church)
// silicon pile: 10 (to store silicon before church)
// rally point: 11 (to build silicon table)
// mining hole w/ more help: 5001 (mining)

void mainLoop(DataStructure data, NetworkConnection systemServer,
    Map<int, AssetClass> assetClassTable) {
  AssetID rootAsset = data.rootAssets.values.single;
  Set<AssetID> messageIDs = data.findFeature<MessageFeature>(rootAsset);
  Set<MessageFeature> messages = messageIDs.map((e) {
    return data.assets[e]!.features.whereType<MessageFeature>().first;
  }).toSet();
  if (messages.any((e) => e.from == 'Passengers')) {
    AssetID spaceship = findAsset(data, -3, 0)!;
    AssetID grid = findAsset(data, -201, 0)!;
    GridFeature gridFeature =
        data.assets[grid]!.features.whereType<GridFeature>().single;
    if (messages.any((e) => e.subject == 'Communicating with our creator')) {
      setTopic(systemServer, spaceship, 'Mining');
    } else if (messages.any((e) =>
        e.subject == 'Congratulations' && e.from == 'Director of Research')) {
      setTopic(systemServer, spaceship, 'Philosophy');
    }
    AssetID? church = findAsset(data, 1, 0);
    if (church == null &&
        messages.any((e) => e.subject == 'Communicating with our creator')) {
      print('building church');
      build(systemServer, grid, gridFeature, 'Church');
    } else if (church != null) {
      setTopic(systemServer, church, 'Religion');
    }
    AssetID? hole = findAsset(data, 5001, 0);
    if (hole == null &&
        messages.any((e) => e.subject == 'Apologies please don\'t evict us')) {
      print('building hole');
      build(systemServer, grid, gridFeature, 'Mining hole with more help');
      return;
    }
    AssetID? ironTable = findAsset(data, 6, 0);
    if (ironTable == null && messages.any((e) => e.subject == 'Iron team')) {
      print('building iron table');
      build(systemServer, grid, gridFeature, 'Iron team table');
      return;
    }
    AssetID? siliconTable = findAsset(data, 9, 0);
    if (siliconTable == null && messages.any((e) => e.subject == 'Silicon')) {
      print('building silicon table');
      build(systemServer, grid, gridFeature, 'Silicon Table');
      return;
    }
    AssetID? ironPile = findAsset(data, 7, 0);
    if (ironPile == null && messages.any((e) => e.subject == 'Iron team')) {
      print('building iron pile');
      build(systemServer, grid, gridFeature, 'Iron pile');
      return;
    }
    AssetID? siliconPile = findAsset(data, 10, 0);
    if (siliconPile == null && messages.any((e) => e.subject == 'Silicon')) {
      print('building silicon pile');
      build(systemServer, grid, gridFeature, 'Silicon pile');
      return;
    }
    AssetID? rally = findAsset(data, 11, 0);
    if (rally == null && messages.any((e) => e.subject == 'Silicon')) {
      print('building rally point');
      build(systemServer, grid, gridFeature, 'Builder rally point');
      return;
    }
    if (!messages.any((e) => e.subject == 'Stuff in holes')) {
      print('waiting for archeological holes...');
      return;
    }
    AssetID? archeoHole1 = findAsset(data, 5, 0);
    if (archeoHole1 == null) {
      print('building archeological hole1');
      build(systemServer, grid, gridFeature, 'Archeological hole');
      return;
    }
    setTopic(systemServer, archeoHole1!, 'Philosophy');
    AssetID? archeoHole2 = findAsset(data, 5, 1);
    if (archeoHole2 == null) {
      print('building archeological hole2');
      build(systemServer, grid, gridFeature, 'Archeological hole');
      return;
    }
    setTopic(systemServer, archeoHole2!, 'Astronomy');
    AssetID? archeoHole3 = findAsset(data, 5, 2);
    if (archeoHole3 == null) {
      print('building archeological hole3');
      build(systemServer, grid, gridFeature, 'Archeological hole');
      return;
    }
    setTopic(
        systemServer, archeoHole3!, 'How to put small things in big things');
    AssetID? archeoHole4 = findAsset(data, 5, 3);
    if (archeoHole4 == null) {
      print('building archeological hole4');
      build(systemServer, grid, gridFeature, 'Archeological hole');
      return;
    }
    if (messages.any((e) => e.subject == '"Powerful Being" nonsense')) {
      print('researching the impact of religion on society');
      setTopic(systemServer, archeoHole4!, 'The Impact of Religion on Society');
    }
  } else {
    print('Waiting for crash...');
  }
}
