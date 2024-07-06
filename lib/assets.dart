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

abstract class FeatureClass<T extends FeatureNode> {}

class AssetClass {
  final List<FeatureClass> features;
  final String name;
  final String description;
  final String icon;

  AssetClass(this.features, this.name, this.description, this.icon);
}

abstract class FeatureNode {
  final AssetNode parent;

  FeatureNode(this.parent);
}

class AssetNode {
  final AssetClass assetClass;
  final int owner;
  final List<FeatureNode> features;
  final double mass;
  final double size;

  AssetNode(this.assetClass, this.features, this.mass, this.owner, this.size);
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

class OrbitFeatureClass extends FeatureClass<OrbitFeatureNode> {}

class OrbitFeatureNode extends FeatureNode {
  final List<OrbitChild> orbitingChildren;
  final AssetNode primaryChild;

  OrbitFeatureNode(
    super.parent,
    this.orbitingChildren,
    this.primaryChild,
  );
}

// from features/space.pas

class EmptySpaceChild {
  final AssetNode child;
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
  final AssetNode child;
  final double distanceFromCenter; // in meters
  final double theta;

  SolarSystemChild(
      this.child, this.distanceFromCenter, this.theta); // in radians
}

class SolarSystemFeatureClass extends FeatureClass<SolarSystemFeatureNode> {}

class SolarSystemFeatureNode extends FeatureNode {
  final List<SolarSystemChild> children;

  SolarSystemFeatureNode(
    super.parent,
    this.children,
  );
}

// from features/structure.pas

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
    super.parent,
    this.materialsQuantity,
    this.structuralIntegrity,
  );
}

// from features/stellar.pas

class StellarFeatureClass extends FeatureClass {}

class StellarFeatureNode extends FeatureNode {
  final int starIndex; // StarIdentifier.subindex

  StellarFeatureNode(super.parent, this.starIndex);
}

// from features/name.pas

class NameFeatureClass extends FeatureClass {}

class NameFeatureNode extends FeatureNode {
  final String name;

  NameFeatureNode(super.parent, this.name);
}
