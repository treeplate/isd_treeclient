import 'package:flutter/material.dart';
import 'package:isd_treeclient/ui-core.dart';
import 'data-structure.dart';
import 'assets.dart';
import 'core.dart';
import 'platform_specific_stub.dart'
    if (dart.library.io) 'platform_specific_io.dart'
    if (dart.library.js_interop) 'platform_specific_web.dart';

class SystemSelector extends StatefulWidget {
  const SystemSelector({super.key, required this.data});
  final DataStructure data;

  @override
  State<SystemSelector> createState() => _SystemSelectorState();
}

class _SystemSelectorState extends State<SystemSelector> {
  StarIdentifier? selectedSystem;

  void initState() {
    if (widget.data.rootAssets.keys.length == 1) {
      // loading the SystemView is slow, so we don't want to load it during a tab transition
      //selectedSystem = widget.data.rootAssets.keys.single;
    }
    super.initState();
  }

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

Widget renderFeature(Feature feature, DataStructure data, bool collapseOrbits) {
  switch (feature) {
    case OrbitFeature():
      return OrbitFeatureWidget(
        feature: feature,
        data: data,
        collapseOrbits: collapseOrbits,
      );
    case SolarSystemFeature():
      return SolarSystemFeatureWidget(
        feature: feature,
        data: data,
        collapseOrbits: collapseOrbits,
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
    case PlanetFeature():
      return PlanetFeatureWidget(
        feature: feature,
        data: data,
      );
    case PlotControlFeature():
      return PlotControlFeatureWidget(
        feature: feature,
        data: data,
      );
    case SurfaceFeature():
      return SurfaceFeatureWidget(
        feature: feature,
        data: data,
      );
    case GridFeature():
      return GridFeatureWidget(
        feature: feature,
        data: data,
      );
    case PopulationFeature():
      return PopulationFeatureWidget(
        feature: feature,
        data: data,
      );
    case MessageBoardFeature():
      return MessageBoardFeatureWidget(
        feature: feature,
        data: data,
      );
    case MessageFeature():
      return MessageFeatureWidget(
        feature: feature,
        data: data,
      );
    case RubblePileFeature():
      return RubblePileFeatureWidget(
        feature: feature,
        data: data,
      );
    case ProxyFeature():
      return ProxyFeatureWidget(
        feature: feature,
        data: data,
      );
    case AssetClassKnowledgeFeature():
      return AssetClassKnowledgeFeatureWidget(
        feature: feature,
        data: data,
      );
    case EmptyAssetClassKnowledgeFeature():
      return EmptyAssetClassKnowledgeFeatureWidget(
        feature: feature,
        data: data,
      );
  }
}

class SolarSystemFeatureWidget extends StatelessWidget {
  const SolarSystemFeatureWidget(
      {super.key,
      required this.feature,
      required this.data,
      required this.collapseOrbits});
  final SolarSystemFeature feature;
  final DataStructure data;
  final bool collapseOrbits;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Children'),
        ...feature.children.map(
          (e) => Indent(
            child: AssetWidget(
              asset: e.child,
              data: data,
              collapseOrbits: collapseOrbits,
            ),
          ),
        ),
      ],
    );
  }
}

class Indent extends StatelessWidget {
  const Indent({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16),
      child: child,
    );
  }
}

class SurfaceFeatureWidget extends StatelessWidget {
  const SurfaceFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final SurfaceFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Regions'),
        ...feature.regions.map(
          (e) => Indent(
            child: AssetWidget(
              asset: e,
              data: data,
              collapseOrbits: false,
            ),
          ),
        ),
      ],
    );
  }
}

class GridFeatureWidget extends StatelessWidget {
  const GridFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final GridFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${feature.width}x${feature.height} grid of cells each with diameter ${feature.cellSize}m',
        ),
        ...feature.cells
            .map(
              (e) => e == null
                  ? null
                  : Indent(
                      child: e == null
                          ? Text('<empty>')
                          : AssetWidget(
                              asset: e,
                              data: data,
                              collapseOrbits: false,
                            ),
                    ),
            )
            .whereType<Widget>(),
      ],
    );
  }
}

class MessageBoardFeatureWidget extends StatelessWidget {
  const MessageBoardFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final MessageBoardFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Messages'),
        ...feature.messages.map(
          (e) => Indent(
            child: AssetWidget(
              asset: e,
              data: data,
              collapseOrbits: false,
            ),
          ),
        ),
      ],
    );
  }
}

class MessageFeatureWidget extends StatelessWidget {
  const MessageFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final MessageFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '${feature.timestamp.displayName}: Message from ${feature.from} in ${feature.source.displayName} (${feature.isRead ? 'read' : 'unread'}): ${feature.subject}'),
        Indent(
          child: Text(feature.body),
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
    required this.collapseOrbits,
  });

  final OrbitFeature feature;
  final DataStructure data;
  final bool collapseOrbits;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Center'),
        Indent(
          child: AssetWidget(
            asset: feature.primaryChild,
            data: data,
            collapseOrbits: collapseOrbits,
          ),
        ),
        Text('Orbiting'),
        ...feature.orbitingChildren.map(
          (e) => Indent(
            child: AssetWidget(
              asset: e.child,
              data: data,
              collapseOrbits: collapseOrbits,
            ),
          ),
        ),
      ],
    );
  }
}

class RubblePileFeatureWidget extends StatelessWidget {
  const RubblePileFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final RubblePileFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pile of rubble'),
      ],
    );
  }
}

class AssetClassKnowledgeFeatureWidget extends StatelessWidget {
  const AssetClassKnowledgeFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final AssetClassKnowledgeFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Knowledge about asset class ${feature.classDetails.id}'),
        Indent(
          child: Row(children: [
            Container(color: Colors.grey, child: ISDIcon(width: 32, height: 32, icon: feature.classDetails.icon)),
            Text('${feature.classDetails.name}'),
          ]),
        ),
        Indent(
          child: Text('${feature.classDetails.description}'),
        ),
      ],
    );
  }
}

class EmptyAssetClassKnowledgeFeatureWidget extends StatelessWidget {
  const EmptyAssetClassKnowledgeFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final EmptyAssetClassKnowledgeFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Empty knowledge about asset class'),
      ],
    );
  }
}

class ProxyFeatureWidget extends StatelessWidget {
  const ProxyFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final ProxyFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Proxy'),
        Indent(
          child: AssetWidget(
            asset: feature.child,
            data: data,
            collapseOrbits: false,
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
        Text(
            'Components (total: ${feature.hp}/${feature.minHP ?? '???'}/${feature.maxHP ?? '???'})'),
        ...feature.materials.map((e) => Text(
            '  ${e.materialID == null ? 'unknown material' : 'M${e.materialID!.toRadixString(16).padLeft(8, '0')}'} (${e.materialDescription}) - ${e.componentName == null ? '' : '${e.componentName} '}${e.quantity}/${e.requiredQuantity ?? '???'}'))
      ],
    );
  }
}

class PlanetFeatureWidget extends StatelessWidget {
  const PlanetFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final PlanetFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HP: ${feature.hp}'),
      ],
    );
  }
}

class PlotControlFeatureWidget extends StatelessWidget {
  const PlotControlFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final PlotControlFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (feature.isColonyShip) Text('This is the colony ship.'),
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
        Text('  Smallest detectable object: ${feature.resolution}m'),
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

class PopulationFeatureWidget extends StatelessWidget {
  const PopulationFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final PopulationFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '${feature.population.displayName} people with an average of ${feature.averageHappiness} happiness (${feature.population.asDouble * feature.averageHappiness} total happiness)'),
      ],
    );
  }
}

class AssetWidget extends StatelessWidget {
  const AssetWidget({
    super.key,
    required this.asset,
    required this.data,
    required this.collapseOrbits,
  });

  final AssetID asset;
  final DataStructure data;
  final bool collapseOrbits;

  @override
  Widget build(BuildContext context) {
    Asset asset = data.assets[this.asset]!;
    if (collapseOrbits &&
        asset.features.length == 1 &&
        asset.features.single is OrbitFeature) {
      OrbitFeature orbit = asset.features.single as OrbitFeature;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetWidget(
            asset: orbit.primaryChild,
            data: data,
            collapseOrbits: collapseOrbits,
          ),
          if (orbit.orbitingChildren.isNotEmpty) ...[
            Indent(
              child: Text(
                'Orbiting',
              ),
            ),
            ...orbit.orbitingChildren.map(
              (e) => Indent(
                child: Indent(
                  child: AssetWidget(
                      asset: e.child,
                      data: data,
                      collapseOrbits: collapseOrbits),
                ),
              ),
            ),
          ]
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            style: ButtonStyle(
              padding: WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SelectableText(
                          data.getAssetIdentifyingName(this.asset),
                          style: TextStyle(fontSize: 20),
                        ),
                        if (asset.name != null)
                          Text(
                            '${asset.className}${asset.classID == null ? '' : ' (class ID ${asset.classID})'}',
                            style: TextStyle(fontSize: 10),
                          )
                        else if (asset.classID != null)
                          Text(
                            'Class ID ${asset.classID}',
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
              decoration: BoxDecoration(
                border: asset.owner == data.dynastyID
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary, width: 5)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ColoredBox(
                    color: Colors.grey,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: ISDIcon(
                        icon: asset.icon,
                        width: 32,
                        height: 32,
                      ),
                    ),
                  ),
                  Text(
                    '${asset.name ?? asset.className}',
                    style: asset.owner == null
                        ? DefaultTextStyle.of(context).style
                        : TextStyle(
                            color: getColorForDynastyID(asset.owner!),
                          ),
                  )
                ],
              ),
            ),
          ),
          ...asset.features.map(
            (e) => Indent(
              child: renderFeature(e, data, collapseOrbits),
            ),
          )
        ],
      );
    }
  }
}

class SystemView extends StatefulWidget {
  const SystemView({super.key, required this.data, required this.system});
  final DataStructure data;
  final StarIdentifier system;

  @override
  State<SystemView> createState() => _SystemViewState();
}

class _SystemViewState extends State<SystemView> {
  bool collapseOrbits = true;

  @override
  void initState() {
    () async {
      collapseOrbits = await getCookie('collapseOrbits') == true.toString();
      setState(() {});
    }();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    (DateTime, Uint64) time0 = widget.data.time0s[widget.system]!;
    return ListView(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Collapse orbits'),
            Checkbox(
              value: collapseOrbits,
              onChanged: (v) {
                setState(() {
                  collapseOrbits = v!;
                  setCookie('collapseOrbits', v.toString());
                });
              },
            )
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Center(
            child: SelectableText(
              '${widget.system.displayName}',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: SelectableText(
              'position: (${widget.data.systemPositions[widget.system]!.dx}, ${widget.data.systemPositions[widget.system]!.dy})',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: SelectableText(
              'time at ${time0.$1}: ${prettyPrintDuration(time0.$2)}',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: SelectableText(
              'time factor: ${widget.data.timeFactors[widget.system]!}',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: SelectableText(
              'position: (${widget.data.systemPositions[widget.system]!.dx}, ${widget.data.systemPositions[widget.system]!.dy})',
            ),
          ),
        ),
        AssetWidget(
          data: widget.data,
          asset: widget.data.rootAssets[widget.system]!,
          collapseOrbits: collapseOrbits,
        ),
      ],
    );
  }
}
