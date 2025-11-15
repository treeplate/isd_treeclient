import 'package:flutter/material.dart' hide Material;
import 'package:isd_treeclient/ui-core.dart';
import 'calendar.dart';
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
      selectedSystem = widget.data.rootAssets.keys.single;
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

Widget renderFeature(Feature feature, DataStructure data, StarIdentifier system,
    bool collapseOrbits) {
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
    case KnowledgeFeature():
      return KnowledgeFeatureWidget(
        feature: feature,
        data: data,
      );
    case ResearchFeature():
      return ResearchFeatureWidget(
        feature: feature,
        data: data,
      );
    case MiningFeature():
      return MiningFeatureWidget(
        feature: feature,
        data: data,
      );
    case OrePileFeature():
      return OrePileFeatureWidget(
        feature: feature,
        data: data,
      );
    case RegionFeature():
      return RegionFeatureWidget(
        feature: feature,
        data: data,
      );
    case RefiningFeature():
      return RefiningFeatureWidget(
        feature: feature,
        data: data,
      );
    case MaterialPileFeature():
      return MaterialPileFeatureWidget(
        feature: feature,
        data: data,
      );
    case MaterialStackFeature():
      return MaterialStackFeatureWidget(
        feature: feature,
        data: data,
      );
    case GridSensorFeature():
      return GridSensorFeatureWidget(
        feature: feature,
        data: data,
      );
    case GridSensorStatusFeature():
      return GridSensorStatusFeatureWidget(
        feature: feature,
        data: data,
      );
    case BuilderFeature():
      return BuilderFeatureWidget(
        feature: feature,
        data: data,
      );
    case InternalSensorFeature():
      return InternalSensorFeatureWidget(
        feature: feature,
        data: data,
      );
    case InternalSensorStatusFeature():
      return InternalSensorStatusFeatureWidget(
        feature: feature,
        data: data,
      );
    case OnOffFeature():
      return OnOffFeatureWidget(
        feature: feature,
        data: data,
      );
    case StaffingFeature():
      return StaffingFeatureWidget(
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
        ...feature.regions.entries.map(
          (e) => Indent(
            child: Column(
              children: [
                Text('At ${e.key}:'),
                AssetWidget(
                  asset: e.value,
                  data: data,
                  collapseOrbits: false,
                ),
              ],
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
          child: Text(feature.text),
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
        Text('Contains ${feature.totalUnitCount.displayName} units:'),
        ...feature.materials.entries.map(
            (e) => Text('${e.key}: ${e.value.displayName}'))
      ],
    );
  }
}

class ResearchFeatureWidget extends StatelessWidget {
  const ResearchFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final ResearchFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Researching "${feature.topic}" (disabledReasoning: ${feature.disabledReasoning})'),
      ],
    );
  }
}

class KnowledgeFeatureWidget extends StatelessWidget {
  const KnowledgeFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final KnowledgeFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Research'),
        for (MapEntry<AssetClassID, AssetClass> assetClass
            in feature.classes.entries) ...[
          Text('Knowledge about asset class ${assetClass.key}'),
          Indent(
            child: Row(
              children: [
                Container(
                  color: Colors.grey,
                  child: ISDIcon(
                    width: 32,
                    height: 32,
                    icon: assetClass.value.icon,
                  ),
                ),
                Text('${assetClass.value.name}'),
              ],
            ),
          ),
          Indent(
            child: Text('${assetClass.value.description}'),
          ),
        ],
        for (MapEntry<MaterialID, Material> material
            in feature.materials.entries) ...[
          Text('Knowledge about material ${material.key}'),
          Indent(
            child: Row(
              children: [
                Container(
                  color: Colors.grey,
                  child: ISDIcon(
                    width: 32,
                    height: 32,
                    icon: material.value.icon,
                  ),
                ),
                Text('${material.value.name}'),
              ],
            ),
          ),
          Indent(
            child: Text('${material.value.description}'),
          ),
          Indent(
            child: Text('${material.value.isFluid ? 'fluid' : 'solid'}'),
          ),
          Indent(
            child: Text('${material.value.isComponent ? 'component' : 'bulk'}'),
          ),
          Indent(
            child: Text(
                '${material.value.isPressurized ? 'pressurized' : 'not pressurized'}'),
          ),
          Indent(
            child: Text('mass per unit: ${material.value.massPerUnit}kg'),
          ),
          Indent(
            child: Text(
                'mass per cubic meter: ${material.value.massPerCubicMeter}kg'),
          ),
        ],
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
            'Health (total at ${calendar.dateName(feature.time0)} ${calendar.timeName(feature.time0)}: ${feature.hp0}/${feature.minHP ?? '???'}/${feature.maxHP}, increasing by ${feature.hpFlowRate}/ms)'),
        Text(
            'Materials (total at ${calendar.dateName(feature.time0)} ${calendar.timeName(feature.time0)}: ${feature.quantity0}/${feature.minHP ?? '???'}/${feature.maxHP}, increasing by ${feature.quantityFlowRate}/ms)'),
        ...feature.materials.map(
          (e) => Text(
            '  ${e.materialID == null ? 'unknown material' : 'M${e.materialID!.toRadixString(16).padLeft(8, '0')}'} (${e.materialDescription}) - ${e.componentName == null ? '' : '${e.componentName} '}(max ${e.requiredQuantity})',
          ),
        )
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
        Text('Planet seed: ${feature.seed}'),
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
        Text('Space sensor (disabledReasoning: ${feature.disabledReasoning})'),
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
    Asset? nearestOrbit = data.assets[feature.nearestOrbit];
    Asset? topAsset = data.assets[feature.topAsset];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '  Enclosing orbit: ${nearestOrbit == null ? '<nonexistent asset>' : nearestOrbit.name ?? 'an unnamed ${nearestOrbit.className}'}'),
        Text(
            '  Top asset reached: ${topAsset == null ? '<nonexistent asset>' : topAsset.name ?? 'an unnamed ${topAsset.className}'}'),
        Text('  Count of reached assets: ${feature.count}'),
      ],
    );
  }
}

class GridSensorFeatureWidget extends StatelessWidget {
  const GridSensorFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final GridSensorFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Grid sensor (disabledReasoning: ${feature.disabledReasoning}).'),
      ],
    );
  }
}

class GridSensorStatusFeatureWidget extends StatelessWidget {
  const GridSensorStatusFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final GridSensorStatusFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    Asset? topAsset = data.assets[feature.topAsset];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '  Top asset reached: ${topAsset == null ? '<nonexistent asset>' : topAsset.name ?? 'an unnamed ${topAsset.className}'}'),
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
            '${feature.population} people (${feature.jobs} with jobs, disabledReasoning: ${feature.disabledReasoning}) out of ${feature.maxPopulation} max with an average of ${feature.averageHappiness} happiness (${feature.population.toDouble() * feature.averageHappiness} total happiness)'),
      ],
    );
  }
}

class MiningFeatureWidget extends StatelessWidget {
  const MiningFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final MiningFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mining at a rate of ${feature.currentRate} kg/ms (out of ${feature.maxRate} max) (disabledReasoning: ${feature.disabledReasoning}, rateLimitedBySource: ${feature.rateLimitedBySource}, rateLimitedByTarget: ${feature.rateLimitedByTarget})',
        ),
      ],
    );
  }
}

class OrePileFeatureWidget extends StatelessWidget {
  const OrePileFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final OrePileFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mass of pile last update (${calendar.dateName(feature.time0)} ${calendar.timeName(feature.time0)}): ${feature.mass0} kg (increasing by ${feature.massFlowRate} kg/ms)',
        ),
        Text(
          'Capacity: ${feature.capacity} kg',
        ),
        Text(
          'Known materials: ${feature.materials.map((e) => 'M${e.toRadixString(16).padLeft(8, '0')}').join(', ')}',
        ),
      ],
    );
  }
}

class RegionFeatureWidget extends StatelessWidget {
  const RegionFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final RegionFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This region ${feature.canBeMined ? 'can still be mined' : 'can no longer be mined'}.',
        ),
      ],
    );
  }
}

class RefiningFeatureWidget extends StatelessWidget {
  const RefiningFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final RefiningFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Refining ${feature.ore == null ? 'unknown material' : 'M${feature.ore!.toRadixString(16).padLeft(8, '0')}'} at a rate of ${feature.currentRate} kg/ms (out of ${feature.maxRate} max) (disabledReasoning: ${feature.disabledReasoning}, rateLimitedBySource: ${feature.rateLimitedBySource}, rateLimitedByTarget: ${feature.rateLimitedByTarget})',
        ),
      ],
    );
  }
}

class MaterialPileFeatureWidget extends StatelessWidget {
  const MaterialPileFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final MaterialPileFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mass of pile last update (${calendar.dateName(feature.time0)} ${calendar.timeName(feature.time0)}): ${feature.mass0} kg (increasing by ${feature.massFlowRate} kg/ms)',
        ),
        Text(
          'Capacity: ${feature.capacity} kg',
        ),
        Text(
          'Material: ${feature.material == null ? 'unknown material' : 'M${feature.material!.toRadixString(16).padLeft(8, '0')}'} (${feature.materialName})',
        ),
      ],
    );
  }
}

class MaterialStackFeatureWidget extends StatelessWidget {
  const MaterialStackFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });
  final MaterialStackFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quantity of stack last update (${calendar.dateName(feature.time0)} ${calendar.timeName(feature.time0)}): ${feature.quantity0} kg (increasing by ${feature.quantityFlowRate} per ms)',
        ),
        Text(
          'Capacity: ${feature.capacity} kg',
        ),
        Text(
          'Material: ${feature.material == null ? 'unknown material' : 'M${feature.material!.toRadixString(16).padLeft(8, '0')}'} (${feature.materialName})',
        ),
      ],
    );
  }
}

class BuilderFeatureWidget extends StatelessWidget {
  const BuilderFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final BuilderFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Can build ${feature.capacity} structures at a rate of ${feature.rate} kg/ms. (disabledReasoning: ${feature.disabledReasoning})',
        ),
        Text('Currently building:'),
        ...feature.structures.map(
          (e) => Indent(
            child: Text('${data.getAssetIdentifyingName(e)}'),
          ),
        )
      ],
    );
  }
}

class InternalSensorFeatureWidget extends StatelessWidget {
  const InternalSensorFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final InternalSensorFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Internal sensor (disabledReasoning: ${feature.disabledReasoning}).',
        ),
      ],
    );
  }
}

class InternalSensorStatusFeatureWidget extends StatelessWidget {
  const InternalSensorStatusFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final InternalSensorStatusFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Indent(
      child: Column(
        children: [
          Text(
            'Can see ${feature.count} assets.',
          ),
        ],
      ),
    );
  }
}

class OnOffFeatureWidget extends StatelessWidget {
  const OnOffFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final OnOffFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Enabled: ${feature.enabled}',
        ),
      ],
    );
  }
}

class StaffingFeatureWidget extends StatelessWidget {
  const StaffingFeatureWidget({
    super.key,
    required this.feature,
    required this.data,
  });

  final StaffingFeature feature;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Staff: ${feature.staff}/${feature.jobs}',
        ),
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
                        SelectableText(
                            'Mass last update (${calendar.dateName(asset.time0)} ${calendar.timeName(asset.time0)}): ${asset.mass0} kilograms (increasing by ${asset.massFlowRate} kilograms per millisecond)'),
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
              child: renderFeature(e, data, this.asset.system, collapseOrbits),
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
