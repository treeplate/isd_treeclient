import 'dart:typed_data';
import 'package:flutter/widgets.dart' show ChangeNotifier, Offset;
import 'core.dart';
import 'assets.dart';
import 'platform_specific_stub.dart'
    if (dart.library.io) 'platform_specific_io.dart'
    if (dart.library.js_interop) 'platform_specific_web.dart';

const String kUsernameCookieName = 'username';
const String kPasswordCookieName = 'password';
const String kGalaxyDiameterCookieName = 'galaxy-diameter';
const String kStarsCookieName = 'stars';
const String kSystemsCookieName = 'systems';

extension type Score._(({Uint64 time, double score}) _value) {
  Uint64 get time => _value.time;
  double get score => _value.score;

  factory Score(Uint64 time, double score) =>
      Score._((time: time, score: score));
}

extension type ScoreEntry._(({int index, List<Score> scores}) _value) {
  int get index => _value.index;
  List<Score> get scores => _value.scores;
  factory ScoreEntry(int index, List<Score> scores) =>
      ScoreEntry._((index: index, scores: scores));
}

class DataStructure with ChangeNotifier {
  String? username;
  String? password;
  String? token;
  double? galaxyDiameter; // in meters
  List<List<Offset>>? stars;
  Map<StarIdentifier, StarIdentifier>?
      systems; // star ID -> system ID (first star in the system)
  Map<StarIdentifier, AssetID> rootAssets =
      {}; // system ID -> root asset of system
  Map<StarIdentifier, Offset> systemPositions =
      {}; // system ID -> system position in galaxy; (0, 0) to (1, 1)
  Map<StarIdentifier, (DateTime, Uint64)> time0s =
      {}; // system ID -> ($1, $2); $2 = system time (in milliseconds) at $1
  Map<StarIdentifier, double> timeFactors =
      {}; // system ID -> time factor of system
  Map<AssetID, Asset> assets = {};
  Map<DynastyID, ScoreEntry> scores = {};
  DynastyID? dynastyID;

  void setCredentials(String username, String password) {
    setCookie(kUsernameCookieName, username);
    setCookie(kPasswordCookieName, password);
    this.username = username;
    this.password = password;
    notifyListeners();
  }

  void logout() {
    setCookie(kUsernameCookieName, null);
    setCookie(kPasswordCookieName, null);
    username = null;
    password = null;
    token = null;
    dynastyID = null;
    assets.clear();
    rootAssets.clear();
    notifyListeners();
  }

  void setToken(String token) {
    this.token = token;
    notifyListeners();
  }

  void setGalaxyDiameter(double galaxyDiameter) {
    setCookie(kGalaxyDiameterCookieName, galaxyDiameter.toString());
    this.galaxyDiameter = galaxyDiameter;
    notifyListeners();
  }

  void updateUsername(String username) {
    setCookie(kUsernameCookieName, username);
    this.username = username;
    notifyListeners();
  }

  void updatePassword(String password) {
    setCookie(kPasswordCookieName, password);
    this.password = password;
    notifyListeners();
  }

  void parseScores(ByteBuffer buffer) {
    ByteData rawScores = buffer.asByteData(4);
    int index = 0;
    while (index < rawScores.lengthInBytes) {
      DynastyID dynastyID = rawScores.getUint32(index, Endian.little);
      int lastDataPoint = rawScores.getUint32(index + 4, Endian.little);
      int dataLength = rawScores.getUint32(index + 8, Endian.little);
      index += 12;
      int subindex = index;
      if (scores[dynastyID] == null) {
        scores[dynastyID] = ScoreEntry(lastDataPoint, []);
      }
      List<Score> dynastyScores = scores[dynastyID]!.scores;
      while (subindex < index + (dataLength * 16)) {
        Uint64 timestamp = Uint64.littleEndian(
            rawScores.getUint32(subindex, Endian.little),
            rawScores.getUint32(subindex + 4, Endian.little));
        double score = rawScores.getFloat64(subindex + 8, Endian.little);
        Score timedScore = Score(timestamp, score);
        if (!dynastyScores.contains(timedScore)) {
          dynastyScores.add(timedScore);
        }
        subindex += 16;
      }
      index = subindex;
    }
    notifyListeners();
  }

  void parseStars(ByteBuffer buffer) {
    Uint32List rawStars = buffer.asUint32List(4);
    List<List<Offset>> stars = [];
    int categoryCount = rawStars[0];
    int category = 0;
    int index = categoryCount + 1;
    assert(rawStars.length ==
        categoryCount +
            1 +
            rawStars
                .sublist(1, categoryCount + 1)
                .map((e) => e * 2)
                .reduce((e, f) => e + f));
    while (category < categoryCount) {
      int categoryLength = rawStars[category + 1];
      int originalIndex = index;
      stars.add([]);
      while (index < originalIndex + categoryLength * 2) {
        stars[category].add(Offset(rawStars[index] / integerLimit32,
            rawStars[index + 1] / integerLimit32));
        index += 2;
      }
      category++;
    }
    this.stars = stars;
    saveBinaryBlob(kStarsCookieName, buffer);
    notifyListeners();
  }

  void parseSystems(ByteBuffer buffer) {
    Uint32List rawSystems = buffer.asUint32List(4);
    systems = {};
    int index = 0;
    while (index < rawSystems.length) {
      systems![StarIdentifier.parse(rawSystems[index])] =
          StarIdentifier.parse(rawSystems[index + 1]);
      index += 2;
    }
    saveBinaryBlob(kSystemsCookieName, buffer);
    notifyListeners();
  }

  void setDynastyID(DynastyID id) {
    dynastyID = id;
    notifyListeners();
  }

  // see [systemPositions]
  void setSystemPosition(StarIdentifier system, Offset position) {
    systemPositions[system] = position;
    notifyListeners();
  }

  // see [time0s]
  void setTime0(StarIdentifier system, (DateTime, Uint64) time0) {
    time0s[system] = time0;
    notifyListeners();
  }

  // see [timeFactors]
  void setTimeFactor(StarIdentifier system, double factor) {
    timeFactors[system] = factor;
    notifyListeners();
  }

  Uint64 getTime(StarIdentifier system, DateTime time) {
    return time0s[system]!.$2 +
        Uint64.fromDouble(timeFactors[system]! *
            (time.millisecondsSinceEpoch -
                time0s[system]!.$1.millisecondsSinceEpoch));
  }

  void setAsset(AssetID id, Asset asset) {
    assets[id] = asset;
    notifyListeners();
  }

  void removeAsset(AssetID id) {
    assets.remove(id);
    notifyListeners();
  }

  // see [rootAssets]
  void setRootAsset(StarIdentifier system, AssetID id) {
    rootAssets[system] = id;
    notifyListeners();
  }

  String getAssetIdentifyingName(AssetID id) {
    Asset? asset = assets[id];
    if (asset == null) {
      throw StateError('getAssetIdentifyingName called with invalid asset id');
    }
    for (Feature feature in asset.features) {
      switch (feature) {
        case OrbitFeature(primaryChild: AssetID child):
          return 'Orbit of ${getAssetIdentifyingName(child)}';
        case StarFeature(starID: StarIdentifier id):
          return '${id.displayName}';
        default:
      }
    }
    return asset.name ?? '${id.displayName} (${asset.assetClass.name})';
  }

  Material getMaterial(MaterialID id, StarIdentifier system) {
    Set<AssetID> messages = findFeature<KnowledgeFeature>(rootAssets[system]!);
    for (AssetID message in messages) {
      Asset asset = assets[message]!;
      Iterable<KnowledgeFeature> knowledges = asset.features.whereType();
      for (KnowledgeFeature knowledge in knowledges) {
        if (knowledge.materials[id] != null) {
          return knowledge.materials[id]!;
        }
      }
    }
    throw Exception('called getMaterial with invalid material ID');
  }

  DataStructure() {
    getCookie(kUsernameCookieName).then((e) {
      username = e;
      notifyListeners();
    });
    getCookie(kPasswordCookieName).then((e) {
      password = e;
      notifyListeners();
    });
    getCookie(kGalaxyDiameterCookieName).then((e) {
      galaxyDiameter = e == null ? null : double.parse(e);
      notifyListeners();
    });
    getBinaryBlob(kStarsCookieName).then((rawStars) {
      if (rawStars != null) {
        parseStars(rawStars.buffer);
      }
    });
    getBinaryBlob(kSystemsCookieName).then((rawSystems) {
      if (rawSystems != null) {
        parseSystems(rawSystems.buffer);
      }
    });
  }

  void getChildren(AssetID assetID, Set<AssetID> result) {
    if (assets[assetID] == null) return;
    Asset asset = assets[assetID]!;
    for (Feature feature in asset.features) {
      switch (feature) {
        case SolarSystemFeature(children: List<SolarSystemChild> children):
          result.addAll(children.map((e) => e.child));
        case OrbitFeature(
            primaryChild: AssetID primaryChild,
            orbitingChildren: List<OrbitChild> orbitingChildren,
          ):
          result.add(primaryChild);
          result.addAll(orbitingChildren.map((e) => e.child));
        case SurfaceFeature(regions: Map<(double, double), AssetID> regions):
          result.addAll(regions.values);
        case GridFeature(buildings: List<Building> cells):
          result.addAll(cells.map((e) => e.asset!));
        case MessageBoardFeature(messages: List<AssetID> messages):
          result.addAll(messages);
        case ProxyFeature(child: AssetID child):
          result.add(child);
        case AssetPileFeature(assets: List<AssetID> assets):
          result.addAll(assets);
        case MessageFeature():
        case StructureFeature():
        case StarFeature():
        case SpaceSensorFeature():
        case SpaceSensorStatusFeature():
        case PlanetFeature():
        case PlotControlFeature():
        case PopulationFeature():
        case RubblePileFeature():
        case KnowledgeFeature():
        case ResearchFeature():
        case MiningFeature():
        case OrePileFeature():
        case RegionFeature():
        case RefiningFeature():
        case MaterialPileFeature():
        case MaterialStackFeature():
        case GridSensorFeature():
        case GridSensorStatusFeature():
        case BuilderFeature():
        case InternalSensorFeature():
        case InternalSensorStatusFeature():
        case OnOffFeature():
        case StaffingFeature():
        case FactoryFeature():
      }
    }
  }

  Set<AssetID> findFeature<T extends Feature>(
    AssetID root,
  ) {
    Set<AssetID> result = {};
    _findFeature<T>(root, result);
    return result;
  }

  void _findFeature<T extends Feature>(AssetID root, Set<AssetID> result) {
    Asset rootAsset = assets[root]!;
    for (Feature feature in rootAsset.features) {
      if (feature is T) result.add(root);
      switch (feature) {
        case SolarSystemFeature(children: List<SolarSystemChild> children):
          for (SolarSystemChild child in children) {
            _findFeature<T>(child.child, result);
          }
        case OrbitFeature(
            primaryChild: AssetID primaryChild,
            orbitingChildren: List<OrbitChild> orbitingChildren,
          ):
          _findFeature<T>(primaryChild, result);
          for (OrbitChild child in orbitingChildren) {
            _findFeature<T>(child.child, result);
          }
        case SurfaceFeature(regions: Map<(double, double), AssetID> regions):
          for (AssetID region in regions.values) {
            _findFeature<T>(region, result);
          }
        case GridFeature(buildings: List<Building> cells):
          for (Building cell in cells) {
            _findFeature<T>(cell.asset, result);
          }
        case MessageBoardFeature(messages: List<AssetID> messages):
          for (AssetID message in messages) {
            _findFeature<T>(message, result);
          }
        case ProxyFeature(child: AssetID child):
          _findFeature<T>(child, result);
        case AssetPileFeature(assets: List<AssetID> assets):
          for (AssetID message in assets) {
            _findFeature<T>(message, result);
          }
        case MessageFeature():
        case StructureFeature():
        case StarFeature():
        case SpaceSensorFeature():
        case SpaceSensorStatusFeature():
        case PlanetFeature():
        case PlotControlFeature():
        case PopulationFeature():
        case RubblePileFeature():
        case KnowledgeFeature():
        case ResearchFeature():
        case MiningFeature():
        case OrePileFeature():
        case RegionFeature():
        case RefiningFeature():
        case MaterialPileFeature():
        case MaterialStackFeature():
        case GridSensorFeature():
        case GridSensorStatusFeature():
        case BuilderFeature():
        case InternalSensorFeature():
        case InternalSensorStatusFeature():
        case OnOffFeature():
        case StaffingFeature():
        case FactoryFeature():
          break;
      }
    }
  }
}
