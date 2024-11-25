import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show ChangeNotifier;
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
  Map<StarIdentifier, AssetID> rootAssets = {}; // system ID -> root asset of system
  Map<StarIdentifier, Offset> systemPositions = {}; // system ID -> system position in galaxy; (0, 0) to (1, 1)
  Map<StarIdentifier, (DateTime, Uint64)> time0s = {}; // system ID -> ($1, $2); $2 = system time (in milliseconds) at $1
  Map<StarIdentifier, double> timeFactors = {}; // system ID -> time factor of system
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
      switch(feature) {
        case OrbitFeature(primaryChild: AssetID child):
          return getAssetIdentifyingName(child);
        case StarFeature(starID: StarIdentifier id):
          return '${id.displayName}';
        default:
      }
    }
    return asset.name ?? 'A${id.id.toRadixString(16).padLeft(6,'0')} (${asset.className})';
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
}
