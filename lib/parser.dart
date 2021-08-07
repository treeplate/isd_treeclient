import 'raw_connection.dart';

String login = "0\x000\x00login\x00tree\x00moo\x00";
int lastMessageId = 0;
List<String> messagesSent = [login];
List<String> techs = [];
Map<int, List<String>> cashedChanges = {};
ParseResult parseMessage(String message) {
  List<String> parts =
      message.split('\x00').sublist(0, message.split('\x00').length - 1);
  switch (parts[0]) {
    case "error":
      print(
          "error responding (${messagesSent[int.parse(parts[1])].split('\x00').join('/')})");
      return ParseResult.replyError;
    case "reply":
      if (parts[2] == "F") {
        print(
            "fail in response (${messagesSent[int.parse(parts[1])].split('\x00').join('/')})");
        return ParseResult.replyFail;
      }
      switch (messagesSent[int.parse(parts[1])].split('\x00')[2]) {
        case "create":
        case "login":
          Map<String, String> technologies = {};
          for (int i = 8; i < parts.length; i += 3) {
            technologies[parts[i]] = parts[i + 2];
          }
          techs = technologies.keys.toList();
          actors[int.parse(parts[6])] = Actor(parts[5], int.parse(parts[6]));
          return ParseResult.handled;
        case "get":
          int id =
              int.parse(messagesSent[int.parse(parts[1])].split('\x00')[1]);
          message =
              "change\x00$id\x00" + parts.sublist(3).join('\x00') + '\x00';
          return parseMessage(message);
        case "build":
          requestActorData(int.parse(parts[4]), parts[3]);
          return ParseResult.handled;
        case "set-research-topic":
          return ParseResult.handled;
      }
      print(
          "Message with conversation ID ${int.parse(parts[1])} has an unknown method (${messagesSent[int.parse(parts[1])].split('\x00')[2]}).");
      return ParseResult.confused;
    case "death":
      actors.remove(int.parse(parts[1]));
      return ParseResult.handled;
    case "change":
      if (actors[int.parse(parts[1])] == null)
        cashedChanges[int.parse(parts[1])] = parts;
      else
        return handleChange(parts);
      return ParseResult.handled;
    case "news":
      print("DEBUG news: $parts");
      requestActorData(int.parse(parts[2]), parts[1]);
      print("NEWS!!! ${actors[int.parse(parts[2])]}");
      return ParseResult.handled;
    case "dynasty":
      Map<String, String> technologies = {};
      for (int i = 2; i < parts.length; i += 3) {
        technologies[parts[i]] = parts[i + 2];
      }
      techs = technologies.keys.toList();
      return ParseResult.handled;
    default:
      print("${message.split('\x00').join('  ')} (raw)");
      return ParseResult.confused;
  }
}

ParseResult handleChange(List<String> parts) {
  int propertyLength = (int.parse(parts[2]) * 3);
  Map<String, Property> properties = {};
  for (int i = 6; i < propertyLength + 3; i += 3) {
    int nameI = i;
    Object value;
    switch (parts[i + 1]) {
      case "string":
      case "dynasty":
        value = parts[i + 2];
        break;
      case "integer":
        value = int.parse(parts[i + 2]);
        break;
      case "float":
        value = double.parse(parts[i + 2]);
        break;
      case "boolean":
        value = parts[i + 2] == "T";
        break;
      case "array":
        propertyLength += 1;
        int valueN = int.parse(parts[i + 3]);
        List<String> values = [];
        for (int index = 0; index < valueN; index++) {
          values.add(parts[i + 4]);
          i++;
          propertyLength++;
        }
        value = values;
        i += 1;
        break;
      case "actor":
        propertyLength++;
        i++;
        requestActorData(int.parse(parts[i + 2]), parts[i + 1]);
        value = actors[int.parse(parts[i + 2])];
        break;
      case "actor-nil":
      case "dynasty-nil":
        i -= 1;
        propertyLength -= 1;
        break;
      default:
        print("Unknown value type ${parts[i + 1]}");
        return ParseResult.confused;
    }
    properties[parts[nameI]] = Property(parts[nameI + 1], value);
  }
  List<String> rawActorData = parts.sublist(propertyLength + 3);
  ExtraInfo actorData;
  switch (actors[int.parse(parts[1])]?.type ?? 'child') {
    case 'child':
    case 'news':
      actorData = NoExtraInfo();
      break;
    case 'space':
      List<SpaceChild> children = [];
      for (int i = 1; i < rawActorData.length; i += 6) {
        SpaceChild child = SpaceChild(
          double.parse(rawActorData[i]),
          double.parse(rawActorData[i + 1]),
          double.parse(rawActorData[i + 2]),
          double.parse(rawActorData[i + 3]),
          int.parse(rawActorData[i + 5]),
        );
        children.add(child);
        requestActorData(int.parse(rawActorData[i + 5]), rawActorData[i + 4]);
      }
      actorData = SpaceExtraInfo(children);
      break;
    case 'grid':
      List<GridCell> cells = [];
      for (int i = 2; i < rawActorData.length;) {
        String env = rawActorData[i];
        i++;
        int actor = rawActorData[i] == "T"
            ? int.parse(rawActorData[i += 2])
            : ((x) => null)(i++);
        if (actor != null) {
          requestActorData(actor, rawActorData[i - 1]);
        }
        if (actor != null) i++;
        cells.add(GridCell(env, actor));
      }
      actorData = GridExtraInfo(
          int.parse(rawActorData[0]), int.parse(rawActorData[1]), cells);
      break;
    default:
      print('Unknown render type \'${actors[int.parse(parts[1])].type}\'');
      return ParseResult.confused;
  }
  if (actors[int.parse(parts[1])] == null) {
    print(
        "Parsing error: state for ${parts[5]} (id ${parts[1]}) was found BEFORE identity, but passed testing.");
    return ParseResult.confused;
  }
  actors[int.parse(parts[1])].name = parts[5];
  actors[int.parse(parts[1])].info = actorData;
  actors[int.parse(parts[1])].props = properties;

  return ParseResult.handled;
}

class Property {
  Property(this.type, this.value);
  final String type;
  final Object value;
}

Map<int, Actor> actors = {};

class Actor {
  Actor.raw(this.type, this.id) : this.name = id.toString();
  factory Actor(String type, int id) {
    actors[id] = Actor.raw(type, id);
    if (cashedChanges[id] != null) handleChange(cashedChanges[id]);
    actors[id] = null;
    return Actor.raw(type, id);
  }
  final String type;
  String name;
  final int id;
  Map<String, Property> props = {};
  ExtraInfo info = NoExtraInfo();
  String toString() => "$name";
}

abstract class ExtraInfo {
  String toString() => "No extra info";
}

class NoExtraInfo extends ExtraInfo {}

class GridExtraInfo extends ExtraInfo {
  final int w;
  final int h;
  final List<GridCell> grid;

  GridExtraInfo(this.w, this.h, this.grid);
  String toString() {
    StringBuffer stringBuffer = StringBuffer();
    for (int y = 0; y < h; y++) {
      stringBuffer.writeln(grid.sublist(y, y + w).join(' '));
    }
    return stringBuffer.toString();
  }
}

class GridCell {
  final String env;
  final int actor;

  GridCell(this.env, this.actor);
  String toString() => "$env ($actor)";
}

class SpaceExtraInfo extends ExtraInfo {
  SpaceExtraInfo(this.children);
  final List<SpaceChild> children;
  String toString() => "Also Children: $children";
}

class SpaceChild {
  SpaceChild(this.x, this.y, this.dx, this.dy, this.id);
  final double x;
  final double y;
  final double dx;
  final double dy;
  final int id;
  String toString() => "${actors[id]}: pos ($x, $y) vel ($dx, $dy)";
}

enum ParseResult {
  confused,
  handled,
  replyFail,
  replyError,
}

void requestActorData(int id, String type) {
  if (actors[id] == null) {
    lastMessageId++;
    String message = "$lastMessageId\x00$id\x00get\x00";
    messagesSent.add(message);
    webSocket.add(message);
    actors[id] = Actor(type, id);
  }
}
