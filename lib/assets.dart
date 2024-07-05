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

  FeatureNode(
    this.parent,
    this.materialsQuantity,
    this.structuralIntegrity,
    this.size,
  );
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

// from features/space.pas

class SpaceChild {
  final AssetNode child;
  final double distanceFromCenter; // in meters
  final double theta0; // in radians
  final int time0; // in seconds since epoch
  final double direction; // in radians
  final double velocity0; // in meters/second
  final double acceleration0; // in meters/second^2

  SpaceChild(
    this.child,
    this.distanceFromCenter,
    this.theta0,
    this.time0,
    this.direction,
    this.velocity0,
    this.acceleration0,
  );
}

class SpaceFeatureClass extends FeatureClass {
  SpaceFeatureClass(
    super.name,
    super.materialBill,
    super.minimumFunctionalQuantity,
  );
}

class SpaceFeatureNode extends FeatureNode {
  final List<SpaceChild> children;

  SpaceFeatureNode(
    super.parent,
    super.materialsQuantity,
    super.structuralIntegrity,
    super.size,
    this.children,
  );
}

// from features/structure.pas

class StructureFeatureClass extends FeatureClass {
  StructureFeatureClass(
      super.name, super.materialBill, super.minimumFunctionalQuantity);
}

class StructureFeatureNode extends FeatureNode {
  StructureFeatureNode(
    super.parent,
    super.materialsQuantity,
    super.structuralIntegrity,
    super.size,
  );
}

// from features/stars.pas

class StellarFeatureClass extends FeatureClass {
  final int category; // StarIdentifier.category

  StellarFeatureClass(
    super.name,
    super.materialBill,
    super.minimumFunctionalQuantity,
    this.category,
  );
}

class StellarFeatureNode extends FeatureNode {
  final int starIndex; // StarIdentifier.subindex

  StellarFeatureNode(
    super.parent,
    super.materialsQuantity,
    super.structuralIntegrity,
    super.size,
    this.starIndex,
  );
}

// from features/name.pas

class NameFeatureClass extends FeatureClass {
  NameFeatureClass(
    super.name,
    super.materialBill,
    super.minimumFunctionalQuantity,
  );
}

class NameFeatureNode extends FeatureNode {
  final String name;

  NameFeatureNode(
    super.parent,
    super.materialsQuantity,
    super.structuralIntegrity,
    super.size,
    this.name,
  );
}
