import 'dart:typed_data';
import 'dart:ui' show Offset;
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'sockets_cookies_stub.dart'
    if (dart.library.io) 'sockets_cookies_io.dart'
    if (dart.library.js_interop) 'sockets_cookies_web.dart';

const String kUsernameCookieName = 'username';
const String kPasswordCookieName = 'password';
const String kGalaxyDiameterCookieName = 'galaxy-diameter';
const String kStarsCookieName = 'stars';
const String kSystemsCookieName = 'systems';
const int integerLimit32 = 0x100000000;

typedef StarIdentifier = (int category, int subindex);

StarIdentifier parseStarIdentifier(int value) {
  return (value >> 20, value & 0xFFFFF);
}

extension StarIdentifierConversion on StarIdentifier {
  int get value => $1 << 20 + $2;
}

// from systems.pas

class Material {
  final String name;
  final String description;
  final String icon;
  final bool showInKG; // true for coal, false for computers
  final double massPerUnit; // in kilograms
  final double volumePerUnit; // in kiloliters

  Material(
    this.name,
    this.description,
    this.icon,
    this.showInKG,
    this.massPerUnit,
    this.volumePerUnit,
  );
}

class MaterialLineItem {
  final String componentName;
  final Material material;
  final int quantity;

  MaterialLineItem(this.componentName, this.material, this.quantity);
}

abstract class FeatureClass {
  final String name;
  final List<MaterialLineItem> materialBill;
  final int minimumFunctionalQuantity;
  int get totalQuantity => materialBill.fold(0, (a, b) => a + b.quantity);

  FeatureClass(this.name, this.materialBill, this.minimumFunctionalQuantity);
}

class AssetClass {
  final List<FeatureClass> features;
  final String name;
  final String description;
  final String icon;

  AssetClass(this.features, this.name, this.description, this.icon);
}

abstract class FeatureNode {
  final AssetNode parent;
  final int materialsQuantity;
  final int structuralIntegrity;
  final double size; // in meters

  FeatureNode(this.parent, this.materialsQuantity, this.structuralIntegrity, this.size);
}

class AssetNode {
  final AssetClass assetClass;
  final int owner;
  final FeatureNode? parent;
  final List<FeatureNode> features;
  final double mass;
  double get size => features.reduce((a, b) => a.size > b.size ? a : b).size;

  AssetNode(this.assetClass, this.parent, this.features, this.mass, this.owner);
}

// from features/orbit.pas

class OrbitChild {
  final AssetNode child;
  final double semiMajorAxis; // meters
  final double eccentricity;
  final double theta0; // radians
  final double omega; // radians

  OrbitChild(
    this.child,
    this.semiMajorAxis,
    this.eccentricity,
    this.theta0,
    this.omega,
  );
}

class OrbitFeatureClass extends FeatureClass {
  OrbitFeatureClass(
    super.name,
    super.materialBill,
    super.minimumFunctionalQuantity,
  );
}

class OrbitFeatureNode extends FeatureNode {
  final List<OrbitChild> children;

  OrbitFeatureNode(
    super.parent,
    super.materialsQuantity,
    super.structuralIntegrity,
    super.size,
    this.children,
  );
}

class DataStructure with ChangeNotifier {
  String? username;
  String? password;
  String? token;
  double? galaxyDiameter; // in meters
  List<List<Offset>>? stars;
  Map<StarIdentifier, StarIdentifier>?
      systems; // star ID -> system ID (first star in the system)

  void setCredentials(String username, String password) {
    setCookie(kUsernameCookieName, username);
    setCookie(kPasswordCookieName, password);
    this.username = username;
    this.password = password;
    notifyListeners();
  }

  void removeCredentials() {
    setCookie(kUsernameCookieName, null);
    setCookie(kPasswordCookieName, null);
    username = null;
    password = null;
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
      systems![parseStarIdentifier(rawSystems32[index])] =
          parseStarIdentifier(rawSystems32[index + 1]);
      index += 2;
    }
    saveBinaryBlob(kSystemsCookieName, rawSystems);
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
