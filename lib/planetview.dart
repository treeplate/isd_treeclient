import 'package:flutter/material.dart';
import 'package:isd_treeclient/core.dart';
import 'ui-core.dart';
import 'assets.dart';
import 'data-structure.dart';
import 'network_handler.dart';
import 'platform_specific_stub.dart'
    if (dart.library.io) 'platform_specific_io.dart'
    if (dart.library.js_interop) 'platform_specific_web.dart';

class SystemSelector extends StatefulWidget {
  const SystemSelector({super.key, required this.data, required this.servers});
  final DataStructure data;
  final Map<StarIdentifier, NetworkConnection> servers;

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
        : PlanetSelector(
            data: widget.data,
            system: selectedSystem!,
            server: widget.servers[selectedSystem]!,
          );
  }
}

class PlanetSelector extends StatefulWidget {
  const PlanetSelector(
      {super.key,
      required this.data,
      required this.system,
      required this.server});
  final DataStructure data;
  final StarIdentifier system;
  final NetworkConnection server;

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
        : PlanetView(
            data: widget.data,
            planet: selectedPlanet!,
            server: widget.server,
          );
  }
}

class PlanetView extends StatefulWidget {
  const PlanetView(
      {super.key,
      required this.data,
      required this.planet,
      required this.server});
  final DataStructure data;
  final AssetID planet;
  final NetworkConnection server;

  @override
  State<PlanetView> createState() => _PlanetViewState();
}

class _PlanetViewState extends State<PlanetView> {
  @override
  Widget build(BuildContext context) {
    AssetID regionID = widget.data.assets[widget.planet]!.features
        .whereType<SurfaceFeature>()
        .single
        .regions
        .single;
    GridFeature region =
        widget.data.assets[regionID]!.features.whereType<GridFeature>().single;

    return LayoutBuilder(builder: (context, constraints) {
      int x = -1;
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

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails details) async {
          int gridX =
              details.localPosition.dx * region.width ~/ constraints.maxWidth;
          int gridY =
              details.localPosition.dy * region.height ~/ constraints.maxHeight;
          if (region.cells[gridX + gridY * region.width] != null) {
            showDialog(
              context: context,
              builder: (context) => ListenableBuilder(
                listenable: widget.data,
                builder: (context, child) {
                  return AssetDialog(
                    asset: region.cells[gridX + gridY * region.width]!,
                    data: widget.data,
                  );
                },
              ),
            );
            return;
          }
          List<String> rawCatalog = await widget.server.send([
            'play',
            regionID.system.value.toString(),
            regionID.id.toString(),
            'catalog',
            gridX.toString(),
            gridY.toString()
          ]);
          if (rawCatalog[0] == 'T') {
            int i = 1;
            List<AssetClass> catalog = [];
            while (i < rawCatalog.length) {
              AssetClassID id = int.parse(rawCatalog[i]);
              String icon = rawCatalog[i + 1];
              String name = rawCatalog[i + 2];
              String description = rawCatalog[i + 3];
              catalog.add(AssetClass(id, icon, name, description));
              i += 4;
            }
            showDialog(
              context: context,
              builder: (context) => BuildDialog(
                catalog: catalog,
                region: regionID,
                gridX: gridX,
                gridY: gridY,
                server: widget.server,
              ),
            );
          } else {
            assert(rawCatalog[0] == 'F');
            openErrorDialog(
                'tried to get catalog, response: $rawCatalog', context);
          }
        },
        child: SizedBox.expand(
          child: Stack(
            children: [
              for (; computeNextI();)
                Positioned(
                  left: x * constraints.maxWidth / region.width,
                  top: y * constraints.maxHeight / region.height,
                  child: Container(
                    width: constraints.maxWidth / region.width,
                    height: constraints.maxHeight / region.height,
                    color: (x + y).isEven ? Colors.blueGrey : Colors.grey,
                    child: region.cells[x + y * region.width] == null
                        ? null
                        : AssetWidget(
                            width: constraints.maxWidth / region.width,
                            height: constraints.maxHeight / region.height,
                            asset: region.cells[x + y * region.width]!,
                            data: widget.data),
                  ),
                )
            ],
          ),
        ),
      );
    });
  }
}

class BuildDialog extends StatelessWidget {
  const BuildDialog(
      {super.key,
      required this.catalog,
      required this.gridX,
      required this.gridY,
      required this.server,
      required this.region});
  final List<AssetClass> catalog;
  final int gridX;
  final int gridY;
  final AssetID region;
  final NetworkConnection server;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(),
              Text('Build at $gridX, $gridY'),
              IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close))
            ],
          ),
          ...catalog.map(
            (e) => TextButton(
              onPressed: () async {
                List<String> response = await server.send([
                  'play',
                  region.system.value.toString(),
                  region.id.toString(),
                  'build',
                  gridX.toString(),
                  gridY.toString(),
                  e.id.toString()
                ]);

                if (response[0] == 'T') {
                  assert(response.length == 1);
                  Navigator.pop(context);
                } else {
                  assert(response[0] == 'F');
                  openErrorDialog(
                      'tried to build, response: $response', context);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ISDIcon(
                        height: 32,
                        width: 32,
                        icon: e.icon,
                      ),
                      Text(e.name),
                    ],
                  ),
                  Text(e.description)
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AssetWidget extends StatelessWidget {
  const AssetWidget({
    super.key,
    required this.asset,
    required this.data,
    required this.width,
    required this.height,
  });

  final AssetID asset;
  final DataStructure data;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    Asset asset = data.assets[this.asset]!;
    for (Feature feature in asset.features) {
      switch (feature) {
        case ProxyFeature(child: AssetID child):
          return Stack(
            children: [
              ISDIcon(
                icon: asset.icon,
                width: width,
                height: height,
              ),
              Center(
                child: IconButton(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (context) => ListenableBuilder(
                      listenable: data,
                      builder: (context, _child) {
                        return AssetDialog(
                          asset: child,
                          data: data,
                        );
                      },
                    ),
                  ),
                  icon: AssetWidget(
                    asset: child,
                    data: data,
                    width: width / 2,
                    height: height / 2,
                  ),
                ),
              )
            ],
          );
        default:
      }
    }
    return ISDIcon(
      icon: asset.icon,
      width: width,
      height: height,
    );
  }
}

class AssetDialog extends StatelessWidget {
  const AssetDialog({
    super.key,
    required this.asset,
    required this.data,
  });

  final AssetID asset;
  final DataStructure data;

  @override
  Widget build(BuildContext context) {
    Asset asset = data.assets[this.asset]!;
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              asset.name == null
                  ? asset.className
                  : '${asset.name} (${asset.className})',
              style: TextStyle(fontSize: 20),
            ),
            Text(asset.description),
            ...asset.features.map((e) => describeFeature(
                  e,
                  data,
                ))
          ],
        ),
      ),
    );
  }
}

Widget describeFeature(Feature feature, DataStructure data) {
  switch (feature) {
    case OrbitFeature():
      throw StateError('orbit on planet');
    case SolarSystemFeature():
      throw StateError('solar system on planet');
    case StarFeature():
      throw StateError('star on planet');
    case PlanetFeature():
      throw StateError('planet on planet');
    case SurfaceFeature():
      throw StateError('surface on planet');
    case StructureFeature(materials: List<MaterialLineItem> materials):
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...materials.map(
            (e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (e.componentName != null) Text('${e.componentName} - '),
                Text(
                    '${e.requiredQuantity ?? '???'} x ${e.materialDescription}'),
                if (e.requiredQuantity != null)
                  SizedBox(
                      width: 250,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: LinearProgressIndicator(
                          value: e.quantity / e.requiredQuantity!,
                        ),
                      )),
              ],
            ),
          ),
        ],
      );
    case SpaceSensorFeature():
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('This is a space sensor.'),
        ],
      );
    case SpaceSensorStatusFeature():
      continue nothing;
    case PlotControlFeature(isColonyShip: bool isColonyShip):
      if (!isColonyShip) continue nothing;
      return Text('This is the colony ship.');
    case GridFeature():
      // TODO: Handle this case.
      return Placeholder();
    case PopulationFeature(
        population: Uint64 population,
        averageHappiness: double averageHappiness
      ):
      return Text(
        'There are ${population.displayName} people here with an average of $averageHappiness happiness (${population.asDouble * averageHappiness} total happiness)',
      );
    case MessageBoardFeature():
      continue nothing;
    case MessageFeature():
      // TODO: Handle this case.
      return Placeholder();
    case RubblePileFeature():
      return Text('There is a pile of rubble.');
    nothing:
    case ProxyFeature():
    case EmptyAssetClassKnowledgeFeature():
      return Container(
        width: 0,
      );
    case AssetClassKnowledgeFeature():
      // TODO: Handle this case.
      return Placeholder();
  }
}
