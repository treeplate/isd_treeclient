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

void build(NetworkConnection server, AssetID grid, int x, int y,
    int assetClass) async {
  List<String> result = await server.send([
    'play',
    grid.system.value.toString(),
    grid.id.toString(),
    'build',
    x.toString(),
    y.toString(),
    assetClass.toString(),
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
    print('Connecting to system server...');
    DataStructure data = DataStructure();
    Map<int, String> stringTable = {};
    late NetworkConnection systemServer;
    systemServer = await NetworkConnection.fromURL(
      systemServerURL,
      unrequestedMessageHandler: (List<String> message) {
        print('system server unrequested message: $message');
      },
      binaryMessageHandler: (ByteBuffer message) {
        BinaryReader reader = BinaryReader(message, stringTable, Endian.little);
        data.galaxyDiameter = 1;
        parseSystemServerBinaryMessage(reader, data);
        AssetID rootAsset = data.rootAssets.values.single;
        Set<AssetID> messageIDs = data.findMessages(rootAsset);
        Set<MessageFeature> messages = messageIDs.map((e) {
          return data.assets[e]!.features.whereType<MessageFeature>().first;
        }).toSet();
        print('Waiting for topics...');
        if (messages.any((e) =>
            e.from == 'Director of Research' &&
            e.subject == 'Congratulations')) {
          AssetID spaceship =
              data.assets.entries.singleWhere((e) => e.value.classID == -3).key;
          AssetID grid = data.assets.entries
              .singleWhere((e) => e.value.classID == -201)
              .key;
          if (messages
              .any((e) => e.subject == 'Communicating with our creator')) {
            AssetID? church = data.assets.entries
                .where((e) => e.value.classID == 1)
                .firstOrNull
                ?.key;
            if (church == null) {
              GridFeature gridFeature =
                  data.assets[grid]!.features.whereType<GridFeature>().single;
              int position = gridFeature.cells.indexOf(null);
              int x = position % gridFeature.width;
              int y = position ~/ gridFeature.width;
              print('Got churches, building one...');
              build(systemServer, grid, x, y, 1);
              return;
            } else {
              print('Built church, researching Religion...');
              setTopic(systemServer, church, 'Religion');
              if (messages
                  .any((e) => e.subject == '"Powerful Being" nonsense')) {
                print('Researching The Impact of Religion on Society...');
                setTopic(systemServer, spaceship,
                    'The Impact of Religion on Society');
              }
              AssetID? church2 = data.assets.entries
                  .where((e) => e.value.classID == 1)
                  .skip(1)
                  .firstOrNull
                  ?.key;
              if (church2 == null) {
                GridFeature gridFeature =
                    data.assets[grid]!.features.whereType<GridFeature>().single;
                int position = gridFeature.cells.indexOf(null);
                int x = position % gridFeature.width;
                int y = position ~/ gridFeature.width;
                print('Building second church...');
                build(systemServer, grid, x, y, 1);
                return;
              } else {
                print('Built second church, researching City Development...');
                setTopic(systemServer, church2, 'City Development');
              }
            }
          } else if (messages.any((e) => e.subject == 'Stuff in holes')) {
            AssetID? hole = data.assets.entries
                .where((e) => e.value.classID == 1)
                .firstOrNull
                ?.key;
            if (hole == null) {
              GridFeature gridFeature =
                  data.assets[grid]!.features.whereType<GridFeature>().single;
              int position = gridFeature.cells.indexOf(null);
              int x = position % gridFeature.width;
              int y = position ~/ gridFeature.width;
              print('Got archeological holes, building one...');
              build(systemServer, grid, x, y, 5);
              return;
            } else {
              print(
                  'Built archeological hole, researching City Developement...');
              setTopic(systemServer, hole, 'City Development');
            }
          } else {
            print('Researching Philosophy...');
            setTopic(systemServer, spaceship, 'Philosophy');
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        print('system server error: $error');
      },
      onReset: (NetworkConnection server) {
        stringTable.clear();
      },
    );
    result = await systemServer.send(['login', token]);
    if (result[0] == 'F') {
      throw Exception('system server \'login\' error: $result');
    }
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
