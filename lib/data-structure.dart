import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'assets.dart';
import 'platform_specific_stub.dart'
    if (dart.library.io) 'platform_specific_io.dart'
    if (dart.library.js_interop) 'platform_specific_web.dart';

const String kUsernameCookieName = 'username';
const String kPasswordCookieName = 'password';
const String kGalaxyDiameterCookieName = 'galaxy-diameter';
const String kStarsCookieName = 'stars';
const String kSystemsCookieName = 'systems';
const int integerLimit32 = 0x100000000;

class DataStructure with ChangeNotifier {
  String? username;
  String? password;
  String? token;
  double? galaxyDiameter; // in meters
  List<List<Offset>>? stars;
  Map<StarIdentifier, StarIdentifier>?
      systems; // star ID -> system ID (first star in the system)
  Map<StarIdentifier, AssetID> rootAssets = {};
  Map<StarIdentifier, Offset> systemPositions = {}; // (0, 0) to (1, 1)
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

  void setSystemPosition(StarIdentifier system, Offset position) {
    systemPositions[system] = position;
    notifyListeners();
  }

  void setAssetNode(AssetID id, Asset node) {
    assets[id] = node;
    notifyListeners();
  }

  void setRootAsset(StarIdentifier system, AssetID id) {
    rootAssets[system] = id;
    notifyListeners();
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
