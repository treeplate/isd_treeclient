import 'dart:math';

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
  final double mass0; // in kg
  final double massFlowRate; // in kg/ms
  final Uint64 time0;
  double getMass(Uint64 time) {
    return mass0 + massFlowRate * ((time - time0).toDouble());
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
    this.mass0,
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
  final int requiredQuantity;
  final int? materialID;

  MaterialLineItem(this.componentName, this.materialID, this.requiredQuantity,
      this.materialDescription);
}

class StructureFeature extends Feature {
  final List<MaterialLineItem> materials;

  int get maxHP {
    double result = materials.fold(
      0,
      (a, b) => a + b.requiredQuantity,
    );
    return result.toInt();
  }

  final Uint64 time0;
  final int hp0;
  final double hpFlowRate; // units/ms
  double getHP(Uint64 time) {
    return min(
      getQuantity(time),
      hp0 + hpFlowRate * ((time - time0).toDouble()),
    );
  }

  final int quantity0;
  final double quantityFlowRate; // units/ms
  double getQuantity(Uint64 time) {
    return quantity0 + quantityFlowRate * ((time - time0).toDouble());
  }

  final int? minHP;
  StructureFeature(
    this.materials,
    this.quantity0,
    this.quantityFlowRate,
    this.hp0,
    this.hpFlowRate,
    this.minHP,
    this.time0,
  );
}

class StarFeature extends Feature {
  final StarIdentifier starID;

  StarFeature(this.starID);
}

class SpaceSensorFeature extends Feature {
  final DisabledReasoning disabledReasoning;

  /// Max steps up tree to nearest orbit.
  final int reach;

  /// Distance that the sensors reach up the tree from the nearest orbit.
  final int up;

  /// Distance down the tree that the sensors reach.
  final int down;

  /// The minimum size of assets that these sensors can detect (in meters).
  final double resolution;
  SpaceSensorFeature(
      this.disabledReasoning, this.reach, this.up, this.down, this.resolution);
}

class SpaceSensorStatusFeature extends Feature {
  final AssetID? nearestOrbit;
  final AssetID? topAsset;
  final int count;

  SpaceSensorStatusFeature(this.nearestOrbit, this.topAsset, this.count);
}

class PlanetFeature extends Feature {
  final int seed;
  PlanetFeature(this.seed);
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
  final DisabledReasoning disabledReasoning;
  final int population;
  final int maxPopulation;
  final int jobs;
  final double averageHappiness;

  PopulationFeature(this.disabledReasoning, this.population, this.maxPopulation,
      this.jobs, this.averageHappiness);
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

class RubblePileFeature extends Feature {
  // material id -> units of material
  final Map<MaterialID, Uint64> materials;
  final Uint64 totalUnitCount;

  RubblePileFeature(this.materials, this.totalUnitCount);
}

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
  final DisabledReasoning disabledReasoning;
  final String topic;

  ResearchFeature(this.disabledReasoning, this.topic);
}

sealed class ReferenceFeature extends Feature {
  void removeReferences(AssetID asset);
  Set<AssetID> get references;
}

class MiningFeature extends Feature {
  final double maxRate; // kg/ms
  final DisabledReasoning disabledReasoning;
  final bool rateLimitedBySource;
  final bool rateLimitedByTarget;
  final double currentRate; // kg/ms

  MiningFeature(
    this.maxRate,
    this.disabledReasoning,
    this.rateLimitedBySource,
    this.rateLimitedByTarget,
    this.currentRate,
  );
}

class OrePileFeature extends Feature {
  final double mass0; // kg
  final double massFlowRate; // kg/ms
  final Uint64 time0;
  double getMass(Uint64 time) {
    return mass0 + massFlowRate * ((time - time0).toDouble());
  }

  final double capacity; // kg
  final Set<MaterialID> materials;

  OrePileFeature(
    this.mass0,
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

class RefiningFeature extends Feature {
  final MaterialID? ore;
  final double maxRate; // kg/ms
  final DisabledReasoning disabledReasoning;
  final bool rateLimitedBySource;
  final bool rateLimitedByTarget;
  final double currentRate;

  RefiningFeature(
    this.ore,
    this.maxRate,
    this.disabledReasoning,
    this.rateLimitedBySource,
    this.rateLimitedByTarget,
    this.currentRate,
  );
}

class MaterialPileFeature extends Feature {
  final double mass0; // kg
  final double massFlowRate; // kg/ms
  final Uint64 time0;
  double getMass(Uint64 time) {
    return mass0 + massFlowRate * ((time - time0).toDouble());
  }

  final double capacity; // kg
  final String materialName;
  final MaterialID? material;

  MaterialPileFeature(
    this.mass0,
    this.massFlowRate,
    this.capacity,
    this.materialName,
    this.material,
    this.time0,
  );
}

class MaterialStackFeature extends Feature {
  final Uint64 quantity0;
  final double quantityFlowRate; // per ms
  final Uint64 time0;
  Uint64 getQuantity(Uint64 time) {
    return quantity0 +
        Uint64.fromDouble(
          quantityFlowRate * ((time - time0).toDouble()),
        );
  }

  final Uint64 capacity;
  final String materialName;
  final MaterialID? material;

  MaterialStackFeature(
    this.quantity0,
    this.quantityFlowRate,
    this.capacity,
    this.materialName,
    this.material,
    this.time0,
  );
}

class GridSensorFeature extends Feature {
  final DisabledReasoning disabledReasoning;

  GridSensorFeature(this.disabledReasoning);
}

class GridSensorStatusFeature extends Feature {
  final int count;
  final AssetID? topAsset;

  GridSensorStatusFeature(this.topAsset, this.count);
}

class BuilderFeature extends Feature {
  final int capacity;
  final double rate;
  final DisabledReasoning disabledReasoning;
  final Set<AssetID> structures;

  BuilderFeature(
    this.capacity,
    this.rate,
    this.disabledReasoning,
    this.structures,
  );
}

class InternalSensorFeature extends Feature {
  final DisabledReasoning disabledReasoning;

  InternalSensorFeature(this.disabledReasoning);
}

class InternalSensorStatusFeature extends Feature {
  final int count;

  InternalSensorStatusFeature(this.count);
}

class OnOffFeature extends Feature {
  final bool enabled;

  OnOffFeature(this.enabled);
}

class StaffingFeature extends Feature {
  final int jobs;
  final int staff;

  StaffingFeature(this.jobs, this.staff);
}

typedef AssetClassID = int; // 32-bit signed, but can't be 0
typedef MaterialID = int; // 32-bit signed, but can't be 0
typedef DynastyID = int; // 32-bit unsigned, but can't be 0

String joinCommaAnd(List<String> args) {
  if (args.isEmpty) return '';
  if (args.length == 1) return args.single;
  if (args.length == 2) return args.join(' and ');
  return args.getRange(0, args.length - 1).join(', ') + ', and ' + args.last;
}

// 32-bit unsigned
extension type DisabledReasoning(int flags) {
  String get asString {
    assert(flags >= 0);
    if (flags >= 0x20) {
      return 'invalid flags $flags';
    }
    List<String> problems = [];
    if (flags & 1 == 1) {
      problems.add('manually disabled');
    }
    if (flags & 2 == 2) {
      problems.add('not yet built');
    }
    if (flags & 4 == 4) {
      problems.add('in the wrong place');
    }
    if (flags & 8 == 8) {
      problems.add('not fully staffed');
    }
    if (flags & 0x10 == 0x10) {
      problems.add('not owned');
    }
    return joinCommaAnd(problems);
  }
}

class AssetClass {
  final AssetClassID id;
  final String icon;
  final String name;
  final String description;

  AssetClass(this.id, this.icon, this.name, this.description);
}
