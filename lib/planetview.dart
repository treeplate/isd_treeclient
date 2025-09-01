import 'package:flutter/material.dart' hide Material;
import 'package:isd_treeclient/core.dart';
import 'ui-core.dart';
import 'assets.dart';
import 'data-structure.dart';
import 'network_handler.dart';
import 'calendar.dart';

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
    if (widget.servers[selectedSystem] == null) {
      selectedSystem = null;
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
        result.add(frontier.first);
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
    List<AssetID> planets = walkTreeForPlanets();
    if (planets.length == 1) {
      selectedPlanet = planets.single;
    }
    return selectedPlanet == null
        ? ListView(
            children: [
              if (widget.data.rootAssets.isEmpty)
                Center(child: Text('No visible planets in system.'))
              else
                for (AssetID planet in planets)
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

      // TODO: make a border around the gridfeature so the edge is obvious
      return Container(
        decoration: BoxDecoration(border: BoxBorder.all(width: 5, color: Colors.grey)),
        child: GestureDetector(
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
              catalog.sort((a, b) => a.id.compareTo(b.id));
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
                      child: gridFeature.cells[x + y * gridFeature.width] ==
                              null
                          ? null
                          : AssetWidget(
                              width: constraints.maxWidth / gridFeature.width,
                              height:
                                  constraints.maxHeight / gridFeature.height,
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
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 400,
        height: 400,
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
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(Icons.close),
                )
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: catalog.length,
                itemBuilder: (context, int i) {
                  AssetClass e = catalog[i];
                  return TextButton(
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
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      } else {
                        assert(response[0] == 'F');
                        if (context.mounted) {
                          openErrorDialog(
                              'tried to build, response: $response', context);
                        }
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
                  );
                },
              ),
            ),
          ],
        ),
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
                    width: width * data.assets[child]!.size / asset.size,
                    height: height * data.assets[child]!.size / asset.size,
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
              // TODO: make it MainAxisSize.min but find a way to put the x in the corner
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
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
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
      if (feature.minHP == null) {
        return Placeholder();
      }
      const int minLineItemHeight = 35;
      final double minLineItemFraction = materials
              .reduce((a, b) => a.requiredQuantity < b.requiredQuantity ? a : b)
              .requiredQuantity /
          feature.maxHP;
      final double totalHeight = minLineItemHeight / minLineItemFraction;
      final ThemeData theme = Theme.of(context);
      return ContinuousBuilder(builder: (context) {
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ...materials.map(
                  (e) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          color: Colors.grey,
                          width: 10,
                          height:
                              totalHeight * e.requiredQuantity / feature.maxHP,
                        ),
                        Container(
                          height:
                              totalHeight * e.requiredQuantity / feature.maxHP,
                          width: 10,
                          decoration: BoxDecoration(
                            border: BoxBorder.fromLTRB(
                              top: BorderSide(color: theme.dividerColor),
                              right: BorderSide(color: theme.dividerColor),
                              bottom: BorderSide(color: theme.dividerColor),
                            ),
                          ),
                        ),
                        Container(
                          width: 10,
                          decoration: BoxDecoration(
                            border: BoxBorder.fromLTRB(
                              top: BorderSide(color: theme.dividerColor),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        if (e.componentName != null)
                          Text('${e.componentName} - '),
                        Text('${e.requiredQuantity} x '),
                        e.materialID == null
                            ? Text('${e.materialDescription}')
                            : MaterialWidget(
                                material:
                                    data.getMaterial(e.materialID!, system),
                              ),
                      ],
                    );
                  },
                ),
              ],
            ),
            Container(
              color: const Color.fromARGB(255, 174, 230, 176),
              width: 10,
              height: totalHeight *
                  feature.getQuantity(
                    data.getTime(system, DateTime.timestamp()),
                  ) /
                  feature.maxHP,
            ),
            Container(
              color: Colors.green,
              width: 10,
              height: totalHeight *
                  feature.getHP(
                    data.getTime(system, DateTime.timestamp()),
                  ) /
                  feature.maxHP,
            ),
          ],
        );
      });
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
      return Placeholder();
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
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
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
    case MiningFeature(
        currentRate: double currentRate,
        enabled: bool enabled,
        active: bool active,
        rateLimitedBySource: bool rateLimitedBySource,
        rateLimitedByTarget: bool rateLimitedByTarget,
        maxRate: double maxRate,
      ):
      String rateLimitString = 'max speed';
      if (rateLimitedBySource) {
        rateLimitString = 'rate limited by source';
        if (rateLimitedByTarget) {
          rateLimitString = 'rate limited by source and target';
        }
      } else if (rateLimitedByTarget) {
        rateLimitString = 'rate limited by target';
      }
      return Column(
        children: [
          Text(
            'Mining ${currentRate % .001 == 0 ? (currentRate * 1000).toInt() : currentRate * 1000} kilogram${currentRate == .001 ? '' : 's'} per second (${enabled ? active ? rateLimitString : 'not in region' : 'disabled'}).',
          ),
          Text(
              'Can mine ${maxRate % .001 == 0 ? (maxRate * 1000).toInt() : maxRate * 1000} kilogram${maxRate == .001 ? '' : 's'} per second.'),
          SizedBox(width: 10),
          OutlinedButton(
            onPressed: () async {
              List<String> result = await server.send(
                [
                  'play',
                  system.value.toString(),
                  asset.id.toString(),
                  enabled ? 'disable' : 'enable',
                ],
              );
              if (result.first == 'T') {
                if (result.length != 2) {
                  openErrorDialog(
                      'unexpected response to enable/disable: $result',
                      context);
                } else {
                  if (result.first != 'T') {
                    openErrorDialog(
                        'server thinks miner already enabled/disabled',
                        context);
                  }
                }
              } else {
                openErrorDialog('enable/disable failed: $result', context);
              }
            },
            child: Text(enabled ? 'Disable' : 'Enable'),
          ),
        ],
      );
    case OrePileFeature(
        getMass: double Function(Uint64) getMass,
        materials: Set<MaterialID> materials,
        capacity: double capacity
      ):
      return ContinuousBuilder(builder: (context) {
        return Column(
          children: [
            Text(
                'Contents: ${getMass(data.getTime(system, DateTime.now())).toInt()} kg of ore / $capacity kg possible'),
            if (materials.isNotEmpty) Text('You can see:'),
            ...materials.map(
                (e) => MaterialWidget(material: data.getMaterial(e, system))),
            OutlinedButton(
              onPressed: () async {
                List<String> result = await server.send(
                  [
                    'play',
                    system.value.toString(),
                    asset.id.toString(),
                    'analyze',
                  ],
                );
                if (result.first != 'T') {
                  if (context.mounted)
                    openErrorDialog(
                      'analyze response: $result',
                      context,
                    );
                  return;
                }
                Uint64 time = Uint64.parse(result[1]);
                double totalQuantity = double.parse(result[2]);
                List<(MaterialID, Uint64)> materials = [];
                int i = 3;
                while (i < result.length) {
                  materials
                      .add((int.parse(result[i]), Uint64.parse(result[i + 1])));
                  i += 2;
                }
                showDialog(
                  context: context,
                  builder: (context) {
                    return Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '(${calendar.dateName(time)} ${calendar.timeName(time)})',
                          ),
                          Text('Total units of material: $totalQuantity'),
                          ...materials.map(
                            (e) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${e.$2.displayName} units of'),
                                MaterialWidget(
                                  material: data.getMaterial(e.$1, system),
                                )
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
              child: Text('Analyze'),
            ),
          ],
        );
      });
    case RefiningFeature(
        ore: MaterialID? ore,
        currentRate: double currentRate,
        enabled: bool enabled,
        active: bool active,
        rateLimitedBySource: bool rateLimitedBySource,
        rateLimitedByTarget: bool rateLimitedByTarget,
        maxRate: double maxRate,
      ):
      String rateLimitString = 'max speed';
      if (rateLimitedBySource) {
        rateLimitString = 'rate limited by source';
        if (rateLimitedByTarget) {
          rateLimitString = 'rate limited by source and target';
        }
      } else if (rateLimitedByTarget) {
        rateLimitString = 'rate limited by target';
      }
      return Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Refining'),
              if (ore != null)
                MaterialWidget(material: data.getMaterial(ore, system)),
              Text(
                ' at a rate of ${currentRate % .001 == 0 ? (currentRate * 1000).toInt() : currentRate * 1000} kilogram${currentRate == .001 ? '' : 's'} per second (${enabled ? active ? rateLimitString : 'not in region' : 'disabled'}).',
              ),
            ],
          ),
          Text(
              'Can refine ${maxRate % .001 == 0 ? (maxRate * 1000).toInt() : maxRate * 1000} kilogram${maxRate == .001 ? '' : 's'} per second.'),
          SizedBox(width: 10),
          OutlinedButton(
            onPressed: () async {
              List<String> result = await server.send(
                [
                  'play',
                  system.value.toString(),
                  asset.id.toString(),
                  enabled ? 'disable' : 'enable',
                ],
              );
              if (result.first == 'T') {
                if (result.length != 2) {
                  openErrorDialog(
                      'unexpected response to enable/disable: $result',
                      context);
                } else {
                  if (result.first != 'T') {
                    openErrorDialog(
                        'server thinks refiner already enabled/disabled',
                        context);
                  }
                }
              } else {
                openErrorDialog('enable/disable failed: $result', context);
              }
            },
            child: Text(enabled ? 'Disable' : 'Enable'),
          ),
        ],
      );
    case MaterialPileFeature(
        getMass: double Function(Uint64) getMass,
        materialName: String name,
        material: MaterialID? material,
        capacity: double capacity,
      ):
      return ContinuousBuilder(builder: (context) {
        return Row(
          children: [
            Text(
                'Contents: ${getMass(data.getTime(system, DateTime.now())).toInt()} kg of '),
            material == null
                ? Text(name)
                : MaterialWidget(material: data.getMaterial(material, system)),
            Text(' / $capacity kg possible'),
          ],
          mainAxisSize: MainAxisSize.min,
        );
      });
    case MaterialStackFeature(
        getQuantity: Uint64 Function(Uint64) getQuantity,
        materialName: String name,
        material: MaterialID? material,
        capacity: Uint64 capacity,
      ):
      return ContinuousBuilder(builder: (context) {
        return Row(children: [
          Text(
              'Contents: ${getQuantity(data.getTime(system, DateTime.now())).toInt()} '),
          material == null
              ? Text(name)
              : MaterialWidget(material: data.getMaterial(material, system)),
          Text('s / $capacity possible'),
        ]);
      });
    case GridSensorFeature():
      return Text('This is a grid sensor.');
    case GridSensorStatusFeature():
      continue nothing;
    case BuilderFeature(
        capacity: int capacity,
        rate: double rate,
        structures: Set<AssetID> structures
      ):
      return Text(
          'This is a builder that can build $capacity structures at a rate of ${rate * 1000} units per second. It is currently building ${structures.length} structures.');
  }
}

class MaterialWidget extends StatelessWidget {
  const MaterialWidget({super.key, required this.material});
  final Material material;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ISDIcon(icon: material.icon, width: 32, height: 32),
                      Text(material.name, style: TextStyle(fontSize: 20))
                    ],
                  ),
                  Text(material.description),
                  Text(material.isFluid ? 'A fluid.' : 'A solid.'),
                  if (material.isPressurized) Text('Pressurized.'),
                  Text(
                      'Density: ${material.massPerCubicMeter} kilograms per cubic meter.')
                ],
              ),
            );
          },
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ISDIcon(icon: material.icon, width: 32, height: 32),
          Text(material.name)
        ],
      ),
    );
  }
}
