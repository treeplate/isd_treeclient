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
String prettifyFeature(DataStructure data, Feature feature,
    [int indent = 0]) {
  StringBuffer buffer = StringBuffer();
  switch (feature) {
    case OrbitFeature(
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
    case SolarSystemFeature(
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
    case StructureFeature(
        materialsQuantity: int materialsQuantity,
        structuralIntegrity: int structuralIntegrity
      ):
      buffer.writeln(
          'Structure feature (materialsQuantity: $materialsQuantity, structuralIntegrity: $structuralIntegrity)');
    case StarFeature(starID: StarIdentifier id):
      buffer.writeln('Star ID: ${id.displayName}');
    case SpaceSensorFeature(reach: int reach, up: int up, down: int down, resolution: double resolution):
      buffer.writeln('Space Sensor: Up $reach to orbit, up $up more, down $down, anything larger than $resolution meters');
    case SpaceSensorStatusFeature(topOrbit: AssetID topOrbit, nearestOrbit: AssetID nearestOrbit, count: int count):
      buffer.writeln('Sensor status: Went up to ${data.assetNodes[nearestOrbit]!.name ?? 'an unnamed orbit'}, then continued up to ${data.assetNodes[topOrbit]!.name ?? 'an unnamed orbit'}. Found a total of $count assets.');
  }
  return buffer.toString();
}

// ends with newline
String prettifyAsset(DataStructure data, AssetID assetID, [int indent = 0]) {
  Asset asset = data.assetNodes[assetID]!;
  StringBuffer buffer = StringBuffer();
  if (asset.name == null) {
    buffer.writeln('${'  ' * indent}${asset.className}');
  } else {
    buffer.writeln(
        '${'  ' * indent}${asset.name} (${asset.className})');
  }
  buffer.writeln('${'  ' * indent}  mass: ${asset.mass} kilograms');
  buffer.writeln('${'  ' * indent}  size: ${asset.size} meters');
  buffer.writeln('${'  ' * indent}  icon: ${asset.icon}');
  buffer.writeln('${'  ' * indent}  description: ${asset.description}');
  buffer.writeln(
      '${'  ' * indent}  owner: ${asset.owner == 0 ? 'nobody' : asset.owner == data.dynastyID ? 'you' : asset.owner}');
  buffer.writeln('${'  ' * indent}  features:');
  for (Feature feature in asset.features) {
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
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: SelectableText(
              'position: (${data.systemPositions[system]!.dx}, ${data.systemPositions[system]!.dy})',
            ),
          ),
        ),
        Center(
            child: SelectableText(
                prettifyAsset(data, data.rootAssetNodes[system]!))),
      ],
    );
  }
}
