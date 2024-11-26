import 'package:flutter/material.dart';
import 'package:isd_treeclient/ui-core.dart';
import 'assets.dart';
import 'data-structure.dart';
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
        : PlanetSelector(data: widget.data, system: selectedSystem!);
  }
}

class PlanetSelector extends StatefulWidget {
  const PlanetSelector({super.key, required this.data, required this.system});
  final DataStructure data;
  final StarIdentifier system;

  @override
  State<PlanetSelector> createState() => _PlanetSelectorState();
}

class _PlanetSelectorState extends State<PlanetSelector> {
  AssetID? selectedPlanet;
  bool showEmptyPlanets = true;

  @override
  void initState() {
    () async {
      showEmptyPlanets =
          (await getCookie('showEmptyPlanets') ?? true) == true.toString();
      setState(() {});
    }();
    super.initState();
  }

  List<AssetID> walkTreeForPlanets() {
    Asset rootAsset =
        widget.data.assets[widget.data.rootAssets[widget.system]]!;
    List<AssetID> frontier = [
      ...(rootAsset.features.single as SolarSystemFeature)
          .children
          .map((e) => e.child)
    ];
    List<AssetID> result = [];
    while (frontier.isNotEmpty) {
      Asset asset = widget.data.assets[frontier.first]!;
      if (asset.features
          .any((e) => e is SurfaceFeature && e.regions.isNotEmpty)) {
        if (showEmptyPlanets ||
            asset.features.whereType<SurfaceFeature>().any((e) => e.regions.any(
                (f) => (widget.data.assets[f]!.features
                        .singleWhere((g) => g is GridFeature) as GridFeature)
                    .cells
                    .any((g) => g != null)))) {
          result.add(frontier.first);
        }
      } else if (asset.features.any((e) => e is OrbitFeature)) {
        OrbitFeature feature = asset.features.single as OrbitFeature;
        frontier.add(feature.primaryChild);
        frontier.addAll(feature.orbitingChildren.map((e) => e.child));
      }
      frontier.removeAt(0);
    }
    return result..sort((a, b) => a.id.compareTo(b.id));
  }

  @override
  Widget build(BuildContext context) {
    return selectedPlanet == null
        ? ListView(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Show empty planets'),
                  Checkbox(
                    value: showEmptyPlanets,
                    onChanged: (v) {
                      setState(() {
                        showEmptyPlanets = v!;
                        setCookie('showEmptyPlanets', v.toString());
                      });
                    },
                  )
                ],
              ),
              if (widget.data.rootAssets.isEmpty)
                Center(child: Text('No visible planets in system.'))
              else
                for (AssetID planet in walkTreeForPlanets())
                  TextButton(
                    onPressed: () => setState(() {
                      selectedPlanet = planet;
                    }),
                    child: Text(widget.data.getAssetIdentifyingName(planet)),
                  )
            ],
          )
        : PlanetView(data: widget.data, planet: selectedPlanet!);
  }
}

class PlanetView extends StatefulWidget {
  const PlanetView({super.key, required this.data, required this.planet});
  final DataStructure data;
  final AssetID planet;

  @override
  State<PlanetView> createState() => _PlanetViewState();
}

class _PlanetViewState extends State<PlanetView> {
  @override
  Widget build(BuildContext context) {
    GridFeature region = widget
        .data
        .assets[widget.data.assets[widget.planet]!.features
            .whereType<SurfaceFeature>()
            .single
            .regions
            .single]!
        .features
        .whereType<GridFeature>()
        .single;
    int x = 0;
    int y = 0;
    bool computeNextI() {
      do {
        x++;
        if (x >= region.width) {
          x = 0;
          y++;
          if (y >= region.height) {
            return false;
          }
        }
      } while (region.cells[x + y * region.width] == null);
      return true;
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          for (; computeNextI();)
            Positioned(
                left: x * constraints.maxWidth / region.width,
                top: y * constraints.maxHeight / region.height,
                child: Container(
                  color: (x + y).isEven ? Colors.blueGrey : Colors.grey,
                  width: constraints.maxWidth / region.width,
                  height: constraints.maxHeight / region.height,
                  child: AssetWidget(
                      asset: region.cells[x + y * region.width]!,
                      data: widget.data),
                ))
        ],
      );
    });
  }
}

class AssetWidget extends StatelessWidget {
  const AssetWidget({
    super.key,
    required this.asset,
    required this.data,
  });

  final AssetID asset;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    Asset asset = data.assets[this.asset]!;
    return ISDIcon(icon: asset.icon);
  }
}
