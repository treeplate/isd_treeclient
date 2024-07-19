typedef StarIdentifier = (int category, int subindex);
typedef AssetID = (String, int); // server, id

StarIdentifier parseStarIdentifier(int value) {
  return (value >> 20, value & 0xFFFFF);
}

extension StarIdentifierConversion on StarIdentifier {
  int get value => ($1 << 20) + $2;
  String get displayName => 'S${value.toRadixString(16).padLeft(6, '0')}';
}

// from systems.pas

abstract class FeatureClass<T extends FeatureNode> {}

class AssetClass {
  final List<FeatureClass> features;
  final String name;
  final String description;
  final String icon;

  AssetClass(this.features, this.name, this.description, this.icon);
}

abstract class FeatureNode {} // XXX maybe name field?

class AssetNode {
  final AssetClass assetClass;
  final int owner;
  final List<FeatureNode> features;
  final double mass; // in kg
  final double size; // in meters

  AssetNode(this.assetClass, this.features, this.mass, this.owner, this.size);
}

// from features/orbit.pas

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

class OrbitFeatureClass extends FeatureClass<OrbitFeatureNode> {}

class OrbitFeatureNode extends FeatureNode {
  final List<OrbitChild> orbitingChildren;
  final AssetID primaryChild;

  OrbitFeatureNode(
    this.orbitingChildren,
    this.primaryChild,
  );
}

// from features/space.pas

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

class SolarSystemFeatureClass extends FeatureClass<SolarSystemFeatureNode> {}

class SolarSystemFeatureNode extends FeatureNode {
  final List<SolarSystemChild> children;
  final AssetID primaryChild;

  SolarSystemFeatureNode(
    this.children,
    this.primaryChild,
  );
}

// from features/structure.pas

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

class StructureFeatureClass extends FeatureClass {
  final List<MaterialLineItem> materialBill;
  final int minimumFunctionalQuantity;
  int get totalQuantity => materialBill.fold(0, (a, b) => a + b.quantity);

  StructureFeatureClass(
    this.materialBill,
    this.minimumFunctionalQuantity,
  );
}

class StructureFeatureNode extends FeatureNode {
  final int materialsQuantity;
  final int structuralIntegrity;
  StructureFeatureNode(
    this.materialsQuantity,
    this.structuralIntegrity,
  );
}

// from features/stellar.pas

class StarFeatureClass extends FeatureClass {}

class StarFeatureNode extends FeatureNode {
  final StarIdentifier starID;

  StarFeatureNode(this.starID);
}

// from features/name.pas

class AssetNameFeatureClass extends FeatureClass {}

class AssetNameFeatureNode extends FeatureNode {
  final String assetName;

  AssetNameFeatureNode(this.assetName);
}
