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
    return AssetID._((system, id));
  }
}

sealed class Feature {
  const Feature();
}

class Asset {
  final int? owner;
  final List<Feature> features;
  final double _mass; // in kg
  final double massFlowRate; // in kg/ms
  final Uint64 time0;
  double getMass(Uint64 time) {
    return _mass + massFlowRate * ((time - time0).toDouble());
  }

  final double size; // in meters
  final String? name;
  final AssetClassID? classID;
  final String icon;
  final String className;
  final String description;
  final Set<AssetID> references = {};

  Asset(
    this.features,
    this._mass,
    this.massFlowRate,
    this.owner,
    this.size,
    this.name,
    this.classID,
    this.icon,
    this.className,
    this.description,
    this.time0,
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

class Material {
  final String icon;
  final String name;
  final String description;
  final bool isFluid;
  final bool isComponent;
  final bool isPressurized;
  final double massPerUnit; // in kilograms
  final double massPerCubicMeter; // in kilograms

  Material(
    this.icon,
    this.name,
    this.description,
    this.isFluid,
    this.isComponent,
    this.isPressurized,
    this.massPerUnit,
    this.massPerCubicMeter,
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
  PlanetFeature();
}

class PlotControlFeature extends Feature {
  final bool isColonyShip;

  PlotControlFeature(this.isColonyShip);
}

class SurfaceFeature extends Feature {
  SurfaceFeature(this.regions);

  final Map<(double, double), AssetID>
      regions; //key is (x,y) where coordinates represent distance from center of surface to center of region in meters
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
  final StarIdentifier source;
  final Uint64 timestamp;
  final bool isRead;
  final String subject;
  final String from;
  final String text;

  MessageFeature(
    this.source,
    this.timestamp,
    this.isRead,
    this.subject,
    this.from,
    this.text,
  );
}

class RubblePileFeature extends Feature {}

class ProxyFeature extends Feature {
  final AssetID child;

  ProxyFeature(this.child);
}

class KnowledgeFeature extends Feature {
  final Map<AssetClassID, AssetClass> classes;
  final Map<MaterialID, Material> materials;

  KnowledgeFeature(this.classes, this.materials);
}

class ResearchFeature extends Feature {
  final String topic;

  ResearchFeature(this.topic);
}

sealed class ReferenceFeature extends Feature {
  void removeReferences(AssetID asset);
  Set<AssetID> get references;
}

enum MiningFeatureMode { disabled, mining, pilesFull, minesEmpty, notAtRegion }

class MiningFeature extends Feature {
  final double rate; // kg/ms
  final MiningFeatureMode mode;

  MiningFeature(this.rate, this.mode);
}

class OrePileFeature extends Feature {
  final double _mass; // kg
  final double massFlowRate; // kg/ms
  final Uint64 time0;
  double getMass(Uint64 time) {
    return _mass + massFlowRate * ((time - time0).toDouble());
  }

  final double capacity; // kg
  final List<MaterialID> materials;

  OrePileFeature(
    this._mass,
    this.massFlowRate,
    this.capacity,
    this.materials,
    this.time0,
  );
}

class RegionFeature extends Feature {
  final bool canBeMined;

  RegionFeature(this.canBeMined);
}

typedef AssetClassID = int; // 32-bit signed, but can't be 0
typedef MaterialID = int; // 32-bit signed, but can't be 0

class AssetClass {
  final AssetClassID id;
  final String icon;
  final String name;
  final String description;

  AssetClass(this.id, this.icon, this.name, this.description);
}
