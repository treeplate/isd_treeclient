import 'package:flutter/material.dart';
import 'package:isd_treeclient/ui-core.dart';
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
              if (widget.data.rootAssets.isEmpty)
                Center(child: Text('No visible systems.'))
              else
                for (StarIdentifier system in widget.data.rootAssets.keys)
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

Widget renderFeature(Feature feature, DataStructure data) {
  switch (feature) {
    case OrbitFeature():
      return OrbitFeatureWidget(
        feature: feature,
        data: data,
      );
    case SolarSystemFeature():
      return SolarSystemFeatureWidget(
        feature: feature,
        data: data,
      );
    case StructureFeature():
      return StructureFeatureWidget(
        feature: feature,
        data: data,
      );
    case StarFeature():
      return StarFeatureWidget(
        feature: feature,
        data: data,
      );
    case SpaceSensorFeature():
      return SpaceSensorFeatureWidget(
        feature: feature,
        data: data,
      );
    case SpaceSensorStatusFeature():
      return SpaceSensorStatusFeatureWidget(
        feature: feature,
        data: data,
      );
  }
}

class SolarSystemFeatureWidget extends StatelessWidget {
  const SolarSystemFeatureWidget(
      {super.key, required this.feature, required this.data});
  final SolarSystemFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Center'),
        Padding(
          padding: EdgeInsets.only(left: 16),
          child: AssetWidget(asset: feature.primaryChild, data: data),
        ),
        Text('Around'),
        ...feature.children.map(
          (e) => Padding(
            padding: EdgeInsets.only(left: 16),
            child: AssetWidget(asset: e.child, data: data),
          ),
        ),
      ],
    );
  }
}

class OrbitFeatureWidget extends StatelessWidget {
  const OrbitFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final OrbitFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Center'),
        Padding(
          padding: EdgeInsets.only(left: 16),
          child: AssetWidget(asset: feature.primaryChild, data: data),
        ),
        Text('Orbiting'),
        ...feature.orbitingChildren.map(
          (e) => Padding(
            padding: EdgeInsets.only(left: 16),
            child: AssetWidget(asset: e.child, data: data),
          ),
        ),
      ],
    );
  }
}

class StructureFeatureWidget extends StatelessWidget {
  const StructureFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final StructureFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Components (total: ${feature.hp}/${feature.minHP ?? '???'}/${feature.maxHP ?? '???'})'),
        ...feature.materials.map((e) => Text('  ${e.material.id.toRadixString(16)} ${e.componentName == null ? '' : '${e.componentName} '}(${e.materialDescription}) ${e.quantity}/${e.requiredQuantity}'))
      ],
    );
  }
}

class StarFeatureWidget extends StatelessWidget {
  const StarFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final StarFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText('ID: ${feature.starID.displayName}'),
      ],
    );
  }
}

class SpaceSensorFeatureWidget extends StatelessWidget {
  const SpaceSensorFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final SpaceSensorFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Space sensor'),
        Text('  Maximum steps up to an orbit: ${feature.reach}'),
        Text('  Maximum steps up after orbit: ${feature.up}'),
        Text('  Maximum steps down after going up: ${feature.down}'),
        Text('  Smallest detectable object: ${feature.resolution}'),
      ],
    );
  }
}

class SpaceSensorStatusFeatureWidget extends StatelessWidget {
  const SpaceSensorStatusFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final SpaceSensorStatusFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    Asset nearestOrbit = data.assets[feature.nearestOrbit]!;
    Asset topAsset = data.assets[feature.topAsset]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '  Enclosing orbit: ${nearestOrbit.name ?? 'an unnamed ${nearestOrbit.className}'}'),
        Text(
            '  Top asset reached: ${topAsset.name ?? 'an unnamed ${topAsset.className}'}'),
        Text('  Count of reached assets: ${feature.count}'),
      ],
    );
  }
}

class AssetWidget extends StatelessWidget {
  const AssetWidget({super.key, required this.asset, required this.data});

  final AssetID asset;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    Asset asset = data.assets[this.asset]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return Dialog(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        asset.name ?? asset.className,
                        style: TextStyle(fontSize: 20),
                      ),
                      if (asset.name != null)
                        Text(
                          asset.className,
                          style: TextStyle(fontSize: 10),
                        ),
                      Text(asset.description),
                      Text(
                          'Owner: ${asset.owner == 0 ? 'nobody' : asset.owner == data.dynastyID ? 'you' : asset.owner}'),
                      SelectableText('Mass: ${asset.mass} kilograms'),
                      SelectableText('Diameter: ${asset.size} meters'),
                    ],
                  ),
                );
              },
            );
          },
          child: Container(
            decoration: BoxDecoration(border: asset.owner == data.dynastyID ? Border.all(color: Theme.of(context).colorScheme.primary, width: 5) : null,),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ColoredBox(
                  color: Colors.grey,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Image.asset(
                      'icons/${asset.icon}.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
                Text(
                  '${asset.name ?? asset.className}',
                  style: asset.owner == 0
                      ? DefaultTextStyle.of(context).style
                      : TextStyle(
                          color: getColorForDynastyID(asset.owner),
                        ),
                )
              ],
            ),
          ),
        ),
        ...asset.features.map(
          (e) => Padding(
            padding: EdgeInsets.only(left: 16),
            child: renderFeature(e, data),
          ),
        )
      ],
    );
  }
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
              '${system.displayName} (${data.rootAssets[system]!.server})',
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
        AssetWidget(data: data, asset: data.rootAssets[system]!),
      ],
    );
  }
}
