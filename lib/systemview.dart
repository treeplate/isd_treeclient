import 'package:flutter/material.dart';
import 'data-structure.dart';
import 'assets.dart';

class SystemSelector extends StatefulWidget {
  const SystemSelector({super.key, required this.data});
  final DataStructure data;

  @override
  State<SystemSelector> createState() => _SystemSelectorState();
}

class _SystemSelectorState extends State<SystemSelector> {
  StarIdentifier? selectedSystem;

  @override
  Widget build(BuildContext context) {
    return selectedSystem == null
        ? ListView(
            children: [
              if (widget.data.rootAssetNodes.isEmpty)
                Center(child: Text('No visible systems.'))
              else
                for (StarIdentifier system in widget.data.rootAssetNodes.keys)
                  TextButton(
                    onPressed: () => setState(() {
                      selectedSystem = system;
                    }),
                    child: Text(system.displayName),
                  )
            ],
          )
        : SystemView(data: widget.data, system: selectedSystem!);
  }
}

// ends with newline
// first line has no indent
String prettifyFeature(DataStructure data, FeatureNode feature,
    [int indent = 0]) {
      StringBuffer buffer = StringBuffer();
  switch (feature) {
    case OrbitFeatureNode(
        orbitingChildren: List<OrbitChild> children,
        primaryChild: AssetID primaryChild
      ):
      buffer.writeln('Orbit feature');
      buffer.writeln('${'  ' * indent}  Center:');
      buffer.write(prettifyAsset(data, primaryChild, indent + 2));
      buffer.writeln('${'  ' * indent}  Orbiting:');
      for (OrbitChild child in children) {
        buffer.writeln(
            '${'  ' * indent}    theta0:${child.theta0}, eccentricity:${child.eccentricity}, omega:${child.omega}, semiMajorAxis:${child.semiMajorAxis}');
        buffer.write(prettifyAsset(data, child.child, indent + 2));
      }
    case SolarSystemFeatureNode(
        children: List<SolarSystemChild> children,
        primaryChild: AssetID primaryChild
      ):
      buffer.writeln('Solar system feature');
      buffer.writeln('${'  ' * indent}  Center:');
      buffer.write(prettifyAsset(data, primaryChild, indent + 2));
      buffer.writeln('${'  ' * indent}  Around:');
      for (SolarSystemChild child in children) {
        buffer.write(
            '${'  ' * indent}    theta:${child.theta}, distanceFromCenter:${child.distanceFromCenter}');
        buffer.write(prettifyAsset(data, child.child, indent + 2));
      }
    case StructureFeatureNode(materialsQuantity: int materialsQuantity, structuralIntegrity: int structuralIntegrity):
      buffer.writeln('Structure feature (materialsQuantity: $materialsQuantity, structuralIntegrity: $structuralIntegrity)');
    case StarFeatureNode(starID: StarIdentifier id):
      buffer.writeln('Star ID: ${id.displayName}');
  }
  return buffer.toString();
}

// ends with newline
String prettifyAsset(DataStructure data, AssetID assetID, [int indent = 0]) {
  AssetNode asset = data.assetNodes[assetID]!;
  StringBuffer buffer = StringBuffer();
  if (asset.name == null) {
    buffer.writeln('${'  ' * indent}class ${asset.assetClass.displayName}');
  } else {
    buffer.writeln('${'  ' * indent}${asset.name} (class ${asset.assetClass.displayName})');
  }
  buffer.writeln('${'  ' * indent}  mass: ${asset.mass} kilograms');
  buffer.writeln('${'  ' * indent}  size: ${asset.size} meters');
  buffer.writeln(
      '${'  ' * indent}  owner: ${asset.owner == 0 ? 'nobody' : asset.owner == data.dynastyIDs[assetID.server] ? 'you' : asset.owner}');
  buffer.writeln('${'  ' * indent}  features:');
  for (FeatureNode feature in asset.features) {
    buffer.write('${'  ' * indent}  - ');
    buffer.write(prettifyFeature(data, feature, indent + 1));
  }
  return buffer.toString();
}

class SystemView extends StatelessWidget {
  const SystemView({super.key, required this.data, required this.system});
  final DataStructure data;
  final StarIdentifier system;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Center(
            child: SelectableText(
              '${system.displayName} (${data.rootAssetNodes[system]!.server})',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
        Center(child: SelectableText(prettifyAsset(data, data.rootAssetNodes[system]!))),
      ],
    );
  }
}
