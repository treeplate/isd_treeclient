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
  @override
  Widget build(BuildContext context) {
    if (widget.data.rootAssets.keys.length == 1) {
      selectedSystem = widget.data.rootAssets.keys.single;
    }
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
            asset.features.whereType<SurfaceFeature>().any((e) =>
                e.regions.values.any((f) => (widget.data.assets[f]!.features
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
    Map<(double, double), AssetID> regions = widget
        .data.assets[widget.planet]!.features
        .whereType<SurfaceFeature>()
        .single
        .regions;
    if (regions.length == 1) {
      AssetID regionID = regions.values.single;
      GridFeature region = widget.data.assets[regionID]!.features
          .whereType<GridFeature>()
          .single;

      return GridWidget(
          gridFeature: region,
          data: widget.data,
          server: widget.server,
          gridAssetID: regionID);
    } else {
      return Text('Unimplemented: multiple regions');
    }
  }
}

class GridWidget extends StatelessWidget {
  const GridWidget({
    super.key,
    required this.gridFeature,
    required this.data,
    required this.gridAssetID,
    required this.server,
  });

  final GridFeature gridFeature;
  final DataStructure data;
  final NetworkConnection server;
  final AssetID gridAssetID;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      int x = -1;
      int y = 0;
      bool computeNextI() {
        do {
          x++;
          if (x >= gridFeature.width) {
            x = 0;
            y++;
            if (y >= gridFeature.height) {
              return false;
            }
          }
        } while (gridFeature.cells[x + y * gridFeature.width] == null);
        return true;
      }

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (TapUpDetails details) async {
          int gridX = details.localPosition.dx *
              gridFeature.width ~/
              constraints.maxWidth;
          int gridY = details.localPosition.dy *
              gridFeature.height ~/
              constraints.maxHeight;
          if (gridFeature.cells[gridX + gridY * gridFeature.width] != null) {
            showDialog(
              context: context,
              builder: (context) => ListenableBuilder(
                listenable: data,
                builder: (context, child) {
                  return AssetDialog(
                    asset:
                        gridFeature.cells[gridX + gridY * gridFeature.width]!,
                    data: data,
                    server: server,
                  );
                },
              ),
            );
            return;
          }
          List<String> rawCatalog = await server.send([
            'play',
            gridAssetID.system.value.toString(),
            gridAssetID.id.toString(),
            'get-buildings',
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
            if (context.mounted) {
              showDialog(
                context: context,
                builder: (context) => BuildDialog(
                  catalog: catalog,
                  region: gridAssetID,
                  gridX: gridX,
                  gridY: gridY,
                  server: server,
                ),
              );
            }
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
                  left: x * constraints.maxWidth / gridFeature.width,
                  top: y * constraints.maxHeight / gridFeature.height,
                  child: Container(
                    width: constraints.maxWidth / gridFeature.width,
                    height: constraints.maxHeight / gridFeature.height,
                    color: (x + y).isEven ? Colors.blueGrey : Colors.grey,
                    child: gridFeature.cells[x + y * gridFeature.width] == null
                        ? null
                        : AssetWidget(
                            width: constraints.maxWidth / gridFeature.width,
                            height: constraints.maxHeight / gridFeature.height,
                            asset:
                                gridFeature.cells[x + y * gridFeature.width]!,
                            data: data,
                            server: server,
                          ),
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
                icon: Icon(Icons.close),
              )
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
    required this.server,
  });

  final AssetID asset;
  final DataStructure data;
  final double width;
  final double height;
  final NetworkConnection server;

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
                          server: server,
                        );
                      },
                    ),
                  ),
                  icon: AssetWidget(
                    asset: child,
                    data: data,
                    width: width / 2,
                    height: height / 2,
                    server: server,
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
    required this.server,
  });

  final AssetID asset;
  final DataStructure data;
  final NetworkConnection server;

  @override
  Widget build(BuildContext context) {
    Asset asset = data.assets[this.asset]!;
    return Dialog(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(),
                Text(
                  asset.name == null
                      ? asset.className
                      : '${asset.name} (${asset.className})',
                  style: TextStyle(fontSize: 20),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close),
                )
              ],
            ),
            Text(asset.description),
            ...asset.features.map((e) => describeFeature(
                  e,
                  data,
                  this.asset.system,
                  this.asset,
                  server,
                  context,
                ))
          ],
        ),
      ),
    );
  }
}

Widget describeFeature(
    Feature feature,
    DataStructure data,
    StarIdentifier system,
    AssetID asset,
    NetworkConnection server,
    BuildContext context) {
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
    case RegionFeature():
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
      return Text('This is a space sensor.');
    case SpaceSensorStatusFeature():
      continue nothing;
    case PlotControlFeature(isColonyShip: bool isColonyShip):
      if (!isColonyShip) continue nothing;
      return Text('This is the colony ship.');
    case GridFeature():
      return SizedBox(
          width: 300,
          height: 300,
          child: GridWidget(
              gridFeature: feature,
              data: data,
              server: server,
              gridAssetID: asset));
    case PopulationFeature(
        population: Uint64 population,
        averageHappiness: double averageHappiness
      ):
      return Text(
        'There are ${population.displayName} people here with an average of $averageHappiness happiness (${population.toDouble() * averageHappiness} total happiness)',
      );
    case MessageBoardFeature():
      continue nothing;
    case MessageFeature():
      throw StateError('message outside messageboard');
    case RubblePileFeature():
      return Text('There is a pile of rubble.');
    nothing:
    case ProxyFeature():
      return Container(
        width: 0,
      );
    case KnowledgeFeature():
      throw StateError('knowledge outside messageboard');
    case ResearchFeature(topic: String topic):
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Researching: '),
          TextButton(
            onPressed: () async {
              List<String> result = await server.send(
                [
                  'play',
                  system.value.toString(),
                  asset.id.toString(),
                  'get-topics',
                ],
              );
              if (result.first != 'T') {
                openErrorDialog(
                  'get-topics response: $result',
                  context,
                );
                return;
              }
              List<(String, bool)> topics = [];
              int i = 1;
              while (i < result.length) {
                topics.add((result[i], result[i + 1] == 'T'));
                i += 2;
              }
              showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Pick new topic'),
                        ...topics.map((e) => OutlinedButton(
                            onPressed: () async {
                              List<String> result = await server.send(
                                [
                                  'play',
                                  system.value.toString(),
                                  asset.id.toString(),
                                  'set-topic',
                                  e.$1,
                                ],
                              );
                              if (result.length == 1 && result.single == 'T') {
                                Navigator.pop(context);
                              } else {
                                openErrorDialog(
                                  'set-topic response: $result',
                                  context,
                                );
                              }
                            },
                            child: Text('${e.$1}${e.$2 ? '' : '(obsolete)'}')))
                      ],
                    ),
                  );
                },
              );
            },
            child: Text('$topic'),
          ),
        ],
      );
    case MiningFeature(rate: double rate, mode: MiningFeatureMode mode):
      switch (mode) {
        case MiningFeatureMode.disabled:
          return Column(
            children: [
              Text('Mines ${rate % .001 == 0 ? (rate * 1000).toInt() : rate * 1000} kilogram${rate==.001?'':'s'} per second (disabled)'),
              SizedBox(width: 10),
              OutlinedButton(
                onPressed: () async {
                  List<String> result = await server.send(
                    [
                      'play',
                      system.value.toString(),
                      asset.id.toString(),
                      'enable',
                    ],
                  );
                  if (result.first == 'T') {
                    if (result.length != 2) {
                      openErrorDialog(
                          'unexpected response to enable: $result', context);
                    } else {
                      if (result.first != 'T') {
                        openErrorDialog(
                            'server thinks miner already enabled', context);
                      }
                    }
                  } else {
                    openErrorDialog('enable failed: $result', context);
                  }
                },
                child: Text('Enable'),
              ),
            ],
          );
        case MiningFeatureMode.mining:
          return Column(
            children: [
              Text('Mining ${rate % .001 == 0 ? (rate * 1000).toInt() : rate * 1000} kilogram${rate==.001?'':'s'} per second.'),
              SizedBox(width: 10),
              OutlinedButton(
                onPressed: () async {
                  List<String> result = await server.send(
                    [
                      'play',
                      system.value.toString(),
                      asset.id.toString(),
                      'disable',
                    ],
                  );
                  if (result.first == 'T') {
                    if (result.length != 2) {
                      openErrorDialog(
                          'unexpected response to disable: $result', context);
                    } else {
                      if (result.first != 'T') {
                        openErrorDialog(
                            'server thinks miner already disabled', context);
                      }
                    }
                  } else {
                    openErrorDialog('disable failed: $result', context);
                  }
                },
                child: Text('Disable'),
              ),
            ],
          );
        case MiningFeatureMode.pilesFull:
          return Column(
            children: [
              Text('Mines ${rate % .001 == 0 ? (rate * 1000).toInt() : rate * 1000} kilogram${rate==.001?'':'s'} per second (out of storage space)'),
              SizedBox(width: 10),
              OutlinedButton(
                onPressed: () async {
                  List<String> result = await server.send(
                    [
                      'play',
                      system.value.toString(),
                      asset.id.toString(),
                      'disable',
                    ],
                  );
                  if (result.first == 'T') {
                    if (result.length != 2) {
                      openErrorDialog(
                          'unexpected response to disable: $result', context);
                    } else {
                      if (result.first != 'T') {
                        openErrorDialog(
                            'server thinks miner already disabled', context);
                      }
                    }
                  } else {
                    openErrorDialog('disable failed: $result', context);
                  }
                },
                child: Text('Disable'),
              ),
            ],
          );
        case MiningFeatureMode.minesEmpty:
          return Column(
            children: [
              Text('Mines ${rate % .001 == 0 ? (rate * 1000).toInt() : rate * 1000} kilogram${rate==.001?'':'s'} per second (out of resources to mine)'),
              SizedBox(width: 10),
              OutlinedButton(
                onPressed: () async {
                  List<String> result = await server.send(
                    [
                      'play',
                      system.value.toString(),
                      asset.id.toString(),
                      'disable',
                    ],
                  );
                  if (result.first == 'T') {
                    if (result.length != 2) {
                      openErrorDialog(
                          'unexpected response to disable: $result', context);
                    } else {
                      if (result.first != 'T') {
                        openErrorDialog(
                            'server thinks miner already disabled', context);
                      }
                    }
                  } else {
                    openErrorDialog('disable failed: $result', context);
                  }
                },
                child: Text('Disable'),
              ),
            ],
          );
        case MiningFeatureMode.notAtRegion:
          return Column(
            children: [
              Text('Mines ${rate % .001 == 0 ? (rate * 1000).toInt() : rate * 1000} kilogram${rate==.001?'':'s'} per second (not on planet)'),
              SizedBox(width: 10),
              OutlinedButton(
                onPressed: () async {
                  List<String> result = await server.send(
                    [
                      'play',
                      system.value.toString(),
                      asset.id.toString(),
                      'disable',
                    ],
                  );
                  if (result.first == 'T') {
                    if (result.length != 2) {
                      openErrorDialog(
                          'unexpected response to disable: $result', context);
                    } else {
                      if (result.first != 'T') {
                        openErrorDialog(
                            'server thinks miner already disabled', context);
                      }
                    }
                  } else {
                    openErrorDialog('disable failed: $result', context);
                  }
                },
                child: Text('Disable'),
              ),
            ],
          );
      }
    case OrePileFeature(getMass: double Function(Uint64) getMass, materials: List<MaterialID> materials, capacity: double capacity):
      if (materials.isNotEmpty) openErrorDialog('unimplemented: known materials', context);
      return ContinousBuilder(
        builder: (context) {
          return Text('Contents: ${getMass(data.getTime(system, DateTime.now())).toInt()} kg of ore / $capacity kg possible');
        }
      );
  }
}
