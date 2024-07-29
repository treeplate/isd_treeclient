import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'assets.dart';
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.js_interop) 'sockets_cookies_web.dart';

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
  Map<StarIdentifier, AssetID> rootAssetNodes = {};
  Map<StarIdentifier, Offset> systemPositions = {}; // (0, 0) to (1, 1)
  Map<AssetID, Asset> assetNodes = {};
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
    assetNodes.clear();
    rootAssetNodes.clear();
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

  void parseStars(List<int> rawStars) {
    List<List<Offset>> stars = [];
    Uint32List rawStars32 = Uint8List.fromList(rawStars).buffer.asUint32List();
    int categoryCount = rawStars32[0];
    int category = 0;
    int index = categoryCount + 1;
    assert(rawStars32.length ==
        categoryCount +
            1 +
            rawStars32
                .sublist(1, categoryCount + 1)
                .map((e) => e * 2)
                .reduce((e, f) => e + f));
    while (category < categoryCount) {
      int categoryLength = rawStars32[category + 1];
      int originalIndex = index;
      stars.add([]);
      while (index < originalIndex + categoryLength * 2) {
        stars[category].add(Offset(rawStars32[index] / integerLimit32,
            rawStars32[index + 1] / integerLimit32));
        index += 2;
      }
      category++;
    }
    this.stars = stars;
    saveBinaryBlob(kStarsCookieName, rawStars);
    notifyListeners();
  }

  void parseSystems(List<int> rawSystems) {
    Uint32List rawSystems32 =
        Uint8List.fromList(rawSystems).buffer.asUint32List();
    systems = {};
    int index = 0;
    while (index < rawSystems32.length) {
      systems![StarIdentifier.parse(rawSystems32[index])] =
          StarIdentifier.parse(rawSystems32[index + 1]);
      index += 2;
    }
    saveBinaryBlob(kSystemsCookieName, rawSystems);
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
    assetNodes[id] = node;
    notifyListeners();
  }

  void setRootAssetNode(StarIdentifier system, AssetID id) {
    rootAssetNodes[system] = id;
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
        parseStars(rawStars);
      }
    });
    getBinaryBlob(kSystemsCookieName).then((rawSystems) {
      if (rawSystems != null) {
        parseSystems(rawSystems);
      }
    });
  }
}
