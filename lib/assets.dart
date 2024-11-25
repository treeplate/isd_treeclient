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

extension type AssetID._((StarIdentifier system, int id) value) {
  StarIdentifier get system => value.$1;
  int get id => value.$2;

  factory AssetID(StarIdentifier system, int id) {
    assert(id > 0);
    assert(
      id <= 0xFFFFFF,
      'getAssetIdentifyingName assumes the biggest asset id is 6 hexadecimal digits (this is guaranteed by the docs as of this assert being written)',
    );
    return AssetID._((system, id));
  }
}

sealed class Feature {}

class Asset {
  final int? owner;
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
  final Uint64 timeOrigin; // in milliseconds
  final bool clockwise;
  final double omega; // in radians

  OrbitChild(
    this.child,
    this.semiMajorAxis,
    this.eccentricity,
    this.timeOrigin,
    this.clockwise,
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

class SolarSystemChild {
  final AssetID child;
  final double distanceFromCenter; // in meters
  final double theta; // in radians

  SolarSystemChild(this.child, this.distanceFromCenter, this.theta);
}

class SolarSystemFeature extends Feature {
  final List<SolarSystemChild> children;

  SolarSystemFeature(
    this.children,
  );
}

// the server does not currently have any way of sending this class, and as such it is not in the documentation
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
  final int? materialID;

  MaterialLineItem(this.componentName, this.materialID, this.quantity,
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

class PlanetFeature extends Feature {
  final int hp;

  PlanetFeature(this.hp);
}

class PlotControlFeature extends Feature {
  final bool isColonyShip;

  PlotControlFeature(this.isColonyShip);
}

class SurfaceFeature extends Feature {
  SurfaceFeature(this.regions);

  final List<AssetID> regions;
}

class GridFeature extends Feature {
  GridFeature(this.cells, this.width, this.height, this.cellSize);

  final List<AssetID?> cells;
  final int width;
  final int height;
  // meters
  final double cellSize;
}

class PopulationFeature extends Feature {
  final Uint64 population;
  final double averageHappiness;

  PopulationFeature(this.population, this.averageHappiness);
}

class MessageBoardFeature extends Feature {
  final List<AssetID> messages;

  MessageBoardFeature(this.messages);
}

class MessageFeature extends Feature {
  final StarIdentifier sourceSystem;
  final AssetID? sourceAsset;
  final Uint64 timestamp;
  final bool isRead;
  final String message;

  MessageFeature(this.sourceSystem, this.sourceAsset, this.timestamp, this.isRead, this.message);
}
