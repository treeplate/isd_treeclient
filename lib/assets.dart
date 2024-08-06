import 'core.dart';

extension type StarIdentifier._((int category, int subindex) _value) {
  int get category => _value.$1;
  int get subindex => _value.$2;
  int get value => (_value.$1 << 20) + _value.$2;
  String get displayName => 'S${value.toRadixString(16).padLeft(6, '0')}';
  factory StarIdentifier.parse(int value) {
    return StarIdentifier._((value >> 20, value & 0xFFFFF));
  }
  factory StarIdentifier(int category, int subindex) {
    return StarIdentifier._((category, subindex));
  }
}

extension type AssetID._((String server, Uint64 id) value) {
  String get server => value.$1;
  Uint64 get id => value.$2;

  factory AssetID(String server, Uint64 id) {
    return AssetID._((server, id));
  }
}

extension type MaterialID._((String server, int id) value) {
  String get server => value.$1;
  int get id => value.$2;

  factory MaterialID(String server, int id) {
    return MaterialID._((server, id));
  }
}

sealed class Feature {}

class Asset {
  final int owner;
  final List<Feature> features;
  final double mass; // in kg
  final double size; // in meters
  final String? name;
  final String icon;
  final String className;
  final String description;

  Asset(
    this.features,
    this.mass,
    this.owner,
    this.size,
    this.name,
    this.icon,
    this.className,
    this.description,
  );
}

class OrbitChild {
  final AssetID child;
  final double semiMajorAxis; // in meters
  final double eccentricity;
  final double theta0; // in radians
  final double omega; // in radians

  OrbitChild(
    this.child,
    this.semiMajorAxis,
    this.eccentricity,
    this.theta0,
    this.omega,
  );
}

class OrbitFeature extends Feature {
  final List<OrbitChild> orbitingChildren;
  final AssetID primaryChild;

  OrbitFeature(
    this.orbitingChildren,
    this.primaryChild,
  );
}

class EmptySpaceChild {
  final AssetID child;
  final double distanceFromCenter; // in meters
  final double theta0; // in radians
  final int time0; // in seconds since epoch
  final double direction; // in radians
  final double velocity0; // in meters/second
  final double acceleration0; // in meters/second^2

  EmptySpaceChild(
    this.child,
    this.distanceFromCenter,
    this.theta0,
    this.time0,
    this.direction,
    this.velocity0,
    this.acceleration0,
  );
}

class SolarSystemChild {
  final AssetID child;
  final double distanceFromCenter; // in meters
  final double theta; // in radians

  SolarSystemChild(this.child, this.distanceFromCenter, this.theta);
}

class SolarSystemFeature extends Feature {
  final List<SolarSystemChild> children;
  final AssetID primaryChild;

  SolarSystemFeature(
    this.children,
    this.primaryChild,
  );
}

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
  final String? componentName;
  final String materialDescription;
  final int quantity;
  final int? requiredQuantity;
  final MaterialID material;

  MaterialLineItem(this.componentName, this.material, this.quantity,
      this.requiredQuantity, this.materialDescription);
}

class StructureFeature extends Feature {
  final List<MaterialLineItem> materials;

  int? get maxHP {
    double result = materials.fold(
      0,
      (a, b) => a + (b.requiredQuantity ?? double.nan),
    );
    if (result.isNaN) return null;
    return result.toInt();
  }

  final int hp;
  final int? minHP;
  StructureFeature(this.materials, this.hp, this.minHP);
}

class StarFeature extends Feature {
  final StarIdentifier starID;

  StarFeature(this.starID);
}

class SpaceSensorFeature extends Feature {
  /// Max steps up tree to nearest orbit.
  final int reach;

  /// Distance that the sensors reach up the tree from the nearest orbit.
  final int up;

  /// Distance down the tree that the sensors reach.
  final int down;

  /// The minimum size of assets that these sensors can detect (in meters).
  final double resolution;
  SpaceSensorFeature(this.reach, this.up, this.down, this.resolution);
}

class SpaceSensorStatusFeature extends Feature {
  final AssetID nearestOrbit;
  final AssetID topAsset;
  final int count;

  SpaceSensorStatusFeature(this.nearestOrbit, this.topAsset, this.count);
}
