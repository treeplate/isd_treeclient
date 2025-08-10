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
  int? dynastyID;

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

  void parseStars(Uint32List rawStars1, ByteBuffer buffer) {
    Uint32List rawStars = rawStars1.sublist(1);
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

  void parseSystems(Uint32List rawSystems1, ByteBuffer buffer) {
    Uint32List rawSystems = rawSystems1.sublist(1);
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

  void setDynastyID(int id) {
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
          return getAssetIdentifyingName(child);
        case StarFeature(starID: StarIdentifier id):
          return '${id.displayName}';
        default:
      }
    }
    return asset.name ??
        'A${id.id.toRadixString(16).padLeft(6, '0')} (${asset.className})';
  }

  Material getMaterial(MaterialID id, StarIdentifier system) {
    Set<AssetID> messages = findMessages(rootAssets[system]!);
    // TODO: knowledge can be from assets without message features
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
        parseStars(rawStars.buffer.asUint32List(), rawStars.buffer);
      }
    });
    getBinaryBlob(kSystemsCookieName).then((rawSystems) {
      if (rawSystems != null) {
        parseSystems(rawSystems.buffer.asUint32List(), rawSystems.buffer);
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
        case GridFeature(cells: List<AssetID?> cells):
          result.addAll(cells.where((e) => e != null).cast());
        case MessageBoardFeature(messages: List<AssetID> messages):
          result.addAll(messages);
        case ProxyFeature(child: AssetID child):
          result.add(child);
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
      }
    }
  }

  Set<AssetID> findMessages(
    AssetID root,
  ) {
    Set<AssetID> result = {};
    _findMessages(root, result);
    return result;
  }

  void _findMessages(AssetID root, Set<AssetID> result) {
    Asset rootAsset = assets[root]!;
    for (Feature feature in rootAsset.features) {
      switch (feature) {
        case SolarSystemFeature(children: List<SolarSystemChild> children):
          for (SolarSystemChild child in children) {
            _findMessages(child.child, result);
          }
        case OrbitFeature(
            primaryChild: AssetID primaryChild,
            orbitingChildren: List<OrbitChild> orbitingChildren,
          ):
          _findMessages(primaryChild, result);
          for (OrbitChild child in orbitingChildren) {
            _findMessages(child.child, result);
          }
        case SurfaceFeature(regions: Map<(double, double), AssetID> regions):
          for (AssetID region in regions.values) {
            _findMessages(region, result);
          }
        case GridFeature(cells: List<AssetID?> cells):
          for (AssetID? cell in cells) {
            if (cell != null) {
              _findMessages(cell, result);
            }
          }
        case MessageBoardFeature(messages: List<AssetID> messages):
          for (AssetID message in messages) {
            _findMessages(message, result);
          }
        case MessageFeature():
          result.add(root);
        case ProxyFeature(child: AssetID child):
          _findMessages(child, result);
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
          break;
      }
    }
  }
}
