import 'dart:math';

import 'package:flutter/material.dart' hide Material;
import 'package:isd_treeclient/core.dart';
import 'knowledge.dart';
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
  void didUpdateWidget(covariant SystemSelector oldWidget) {
    setState(() {});
    super.didUpdateWidget(oldWidget);
  }

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
    if (widget.data.assets.isEmpty) return [];
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
    if (widget.data.assets.isEmpty)
      return Text('Error: failed to parse system');
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

      return LayoutBuilder(builder: (context, constraints) {
        double regionSize =
            min(constraints.biggest.height, constraints.biggest.width / 2);
        return Row(
          children: [
            Expanded(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SelectableText(
                    'System ID: ${widget.planet.system.displayName}'),
                SelectableText('Planet ID: ${widget.planet.displayName}'),
                SelectableText('Dynasty ID: ${widget.data.dynastyID}'),
              ],
            )),
            Expanded(
              flex: 2,
              child: Center(
                child: Container(
                  width: regionSize,
                  height: regionSize,
                  color: Colors.green,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: double.infinity,
                    child: GridWidget(
                      gridFeature: region,
                      data: widget.data,
                      server: widget.server,
                      gridAssetID: regionID,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
                child: ListView(
              children: [
                ...region.buildables.map((Buildable buildable) => Center(
                    child: BuildableWidget(
                        buildable, regionSize / region.dimension)))
              ],
            )),
          ],
        );
      });
    } else {
      return Text('Unimplemented: multiple regions');
    }
  }
}

class BuildableWidget extends StatefulWidget {
  const BuildableWidget(this.buildable, this.cellSize, {super.key});

  final Buildable buildable;
  final double cellSize;

  @override
  State<BuildableWidget> createState() => _BuildableWidgetState();
}

class _BuildableWidgetState extends State<BuildableWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Draggable<Buildable>(
          child: ISDIcon(
              icon: widget.buildable.assetClass.icon,
              width: widget.buildable.size * widget.cellSize,
              height: widget.buildable.size * widget.cellSize),
          feedback: ISDIcon(
            icon: widget.buildable.assetClass.icon,
            width: widget.buildable.size * widget.cellSize,
            height: widget.buildable.size * widget.cellSize,
            opacity: .5,
          ),
          data: widget.buildable,
        ),
        Text(widget.buildable.assetClass.name),
        Text(widget.buildable.assetClass.description),
        Divider(),
      ],
    );
  }
}

class GridWidget extends StatefulWidget {
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
  State<GridWidget> createState() => _GridWidgetState();
}

class _GridWidgetState extends State<GridWidget> {
  Rect? draggedBuildable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return SizedBox.expand(
        child: DragTarget<Buildable>(
          onWillAcceptWithDetails: (DragTargetDetails<Buildable> details) {
            return true;
          },
          onMove: (DragTargetDetails<Buildable> details) {
            Offset localPosition = (context.findRenderObject() as RenderBox)
                .globalToLocal(details.offset);
            Offset scaledPosition = localPosition.scale(
                widget.gridFeature.dimension / constraints.maxWidth,
                widget.gridFeature.dimension / constraints.maxHeight);
            int gridX = scaledPosition.dx.floor();
            int gridY = scaledPosition.dy.floor();
            setState(() {
              draggedBuildable = Offset(gridX.toDouble(), gridY.toDouble()) &
                  Size.square(details.data.size.toDouble());
            });
          },
          onLeave: (Buildable? data) {
            draggedBuildable = null;
          },
          onAcceptWithDetails: (details) {
            draggedBuildable = null;
            Offset localPosition = (context.findRenderObject() as RenderBox)
                .globalToLocal(details.offset);
            Offset scaledPosition = localPosition.scale(
                widget.gridFeature.dimension / constraints.maxWidth,
                widget.gridFeature.dimension / constraints.maxHeight);
            int gridX = scaledPosition.dx.floor();
            int gridY = scaledPosition.dy.floor();
            buildAt(
              widget.gridFeature,
              widget.gridAssetID,
              gridX,
              gridY,
              details.data,
            );
          },
          builder: (BuildContext context, List<Buildable?> candidateData,
              List<dynamic> rejectedData) {
            return Stack(
              children: [
                for (Building building in widget.gridFeature.buildings)
                  Positioned(
                    left: building.x *
                        constraints.maxWidth /
                        widget.gridFeature.dimension,
                    top: building.y *
                        constraints.maxHeight /
                        widget.gridFeature.dimension,
                    child: Container(
                      width: constraints.maxWidth *
                          building.size /
                          widget.gridFeature.dimension,
                      height: constraints.maxHeight *
                          building.size /
                          widget.gridFeature.dimension,
                      child: AssetWidget(
                        width: constraints.maxWidth *
                            building.size /
                            widget.gridFeature.dimension,
                        height: constraints.maxHeight *
                            building.size /
                            widget.gridFeature.dimension,
                        asset: building.asset,
                        data: widget.data,
                        server: widget.server,
                      ),
                    ),
                  ),
                if (draggedBuildable != null) ...[
                  Positioned(
                    top: constraints.maxWidth *
                        draggedBuildable!.top /
                        widget.gridFeature.dimension,
                    left: constraints.maxHeight *
                        draggedBuildable!.left /
                        widget.gridFeature.dimension,
                    child: Container(
                      decoration: BoxDecoration(border: BoxBorder.all()),
                      width: constraints.maxWidth *
                          draggedBuildable!.width /
                          widget.gridFeature.dimension,
                      height: constraints.maxHeight *
                          draggedBuildable!.height /
                          widget.gridFeature.dimension,
                    ),
                  ),
                  ...getCollisions(widget.gridFeature, widget.gridAssetID,
                          draggedBuildable!)
                      .map(
                    (Rect rect) => Positioned(
                      top: constraints.maxWidth *
                          rect.top /
                          widget.gridFeature.dimension,
                      left: constraints.maxHeight *
                          rect.left /
                          widget.gridFeature.dimension,
                      child: Container(
                        color: Colors.red.withAlpha(128),
                        width: constraints.maxWidth *
                            rect.width /
                            widget.gridFeature.dimension,
                        height: constraints.maxHeight *
                            rect.height /
                            widget.gridFeature.dimension,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      );
    });
  }

  List<Rect> getCollisions(
      GridFeature grid, AssetID gridAssetID, Rect draggedBuildable) {
    List<Rect> result = [];
    if (draggedBuildable.right > grid.dimension) {
      result.add(
        Rect.fromLTRB(
          grid.dimension.toDouble(),
          draggedBuildable.top,
          draggedBuildable.right,
          draggedBuildable.bottom,
        ),
      );
    }
    if (draggedBuildable.bottom > grid.dimension) {
      result.add(
        Rect.fromLTRB(
          draggedBuildable.left,
          grid.dimension.toDouble(),
          draggedBuildable.right,
          draggedBuildable.bottom,
        ),
      );
    }
    if (draggedBuildable.left < 0) {
      result.add(
        Rect.fromLTRB(
          draggedBuildable.left,
          draggedBuildable.top,
          0,
          draggedBuildable.bottom,
        ),
      );
    }
    if (draggedBuildable.top < 0) {
      result.add(
        Rect.fromLTRB(
          draggedBuildable.left,
          draggedBuildable.top,
          draggedBuildable.right,
          0,
        ),
      );
    }
    for (Building building in grid.buildings) {
      if (building.x < draggedBuildable.right &&
          building.x + building.size > draggedBuildable.left &&
          building.y < draggedBuildable.bottom &&
          building.y + building.size > draggedBuildable.top) {
        Asset newGridAsset = widget.data.assets[building.asset]!;
        if (newGridAsset.features.whereType<GridFeature>().isEmpty) {
          result.add(
            draggedBuildable.intersect(
              Rect.fromLTWH(
                building.x.toDouble(),
                building.y.toDouble(),
                building.size.toDouble(),
                building.size.toDouble(),
              ),
            ),
          );
        } else {
          result.addAll(
            getCollisions(
              newGridAsset.features.whereType<GridFeature>().single,
              building.asset,
              draggedBuildable.shift(
                -Offset(
                  building.x.toDouble(),
                  building.y.toDouble(),
                ),
              ),
            ).map(
              (e) => e.shift(
                Offset(
                  building.x.toDouble(),
                  building.y.toDouble(),
                ),
              ),
            ),
          );
        }
      }
    }
    return result;
  }

  void buildAt(GridFeature grid, AssetID gridAssetID, int gridX, int gridY,
      Buildable buildable) {
    if (gridX + buildable.size > grid.dimension ||
        gridY + buildable.size > grid.dimension ||
        gridX < 0 ||
        gridY < 0) {
      return;
    }
    for (Building building in grid.buildings) {
      if (building.x < (gridX + buildable.size) &&
          building.x + building.size > gridX &&
          building.y < (gridY + buildable.size) &&
          building.y + building.size > gridY) {
        Asset newGridAsset = widget.data.assets[building.asset]!;
        if (newGridAsset.features.whereType<GridFeature>().isEmpty) {
          return;
        }
        return buildAt(newGridAsset.features.whereType<GridFeature>().single,
            building.asset, gridX - building.x, gridY - building.y, buildable);
      }
    }
    widget.server.send([
      'play',
      gridAssetID.system.value.toString(),
      gridAssetID.id.toString(),
      'build',
      gridX.toString(),
      gridY.toString(),
      buildable.assetClass.id!.toString(),
    ]).then((List<String> response) {
      if (response[0] == 'T') {
        assert(response.length == 1);
      } else {
        assert(response[0] == 'F');
        if (context.mounted) {
          openErrorDialog('tried to build, response: $response', context);
        }
      }
    });
    return;
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
          return Container(
            child: Stack(
              children: [
                AssetIconWidget(
                  data: data,
                  assetID: this.asset,
                  server: server,
                  asset: asset,
                  width: width,
                  height: height,
                ),
                Container(
                  width: width,
                  height: height,
                  child: Center(
                    child: IconButton(
                      padding: EdgeInsets.all(0),
                      onPressed: () => showDialog(
                        context: context,
                        builder: (context) => ListenableBuilder(
                          listenable: data,
                          builder: (context, _child) {
                            return AssetDialog(
                              asset: child,
                              data: data,
                              server: server,
                              closeDialog: () {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
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
                  ),
                )
              ],
            ),
          );
        case GridFeature():
          return Container(
            child: Stack(
              children: [
                AssetIconWidget(
                  data: data,
                  assetID: this.asset,
                  server: server,
                  asset: asset,
                  width: width,
                  height: height,
                  opacity: .5,
                ),
                Container(
                  width: width,
                  height: height,
                  child: GridWidget(
                    gridFeature: feature,
                    data: data,
                    gridAssetID: this.asset,
                    server: server,
                  ),
                )
              ],
            ),
          );
        default:
      }
    }
    return AssetIconWidget(
      data: data,
      assetID: this.asset,
      server: server,
      asset: asset,
      width: width,
      height: height,
    );
  }
}

class AssetIconWidget extends StatelessWidget {
  const AssetIconWidget({
    super.key,
    required this.data,
    required this.assetID,
    required this.server,
    required this.asset,
    required this.width,
    required this.height,
    this.opacity = 1,
  });

  final DataStructure data;
  final AssetID assetID;
  final NetworkConnection server;
  final Asset asset;
  final double width;
  final double height;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      padding: EdgeInsets.all(0),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => ListenableBuilder(
            listenable: data,
            builder: (context, child) {
              return AssetDialog(
                asset: assetID,
                data: data,
                server: server,
                closeDialog: () {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        );
      },
      icon: ISDIcon(
        icon: asset.assetClass.icon,
        width: width,
        height: height,
        opacity: opacity,
      ),
    );
  }
}

class AssetDialog extends StatefulWidget {
  AssetDialog({
    super.key,
    required this.asset,
    required this.data,
    required this.server,
    required this.closeDialog,
  });

  final AssetID asset;
  final DataStructure data;
  final NetworkConnection server;
  final void Function() closeDialog;

  @override
  State<AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<AssetDialog> {
  @override
  void initState() {
    super.initState();
    widget.data.addListener(listener);
  }

  void listener() {
    if (widget.data.assets[widget.asset] == null) {
      widget.data.removeListener(listener);
      widget.closeDialog();
    }
  }

  @override
  void dispose() {
    widget.data.removeListener(listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.assets[widget.asset] == null) {
      return Container();
    }
    Asset asset = widget.data.assets[widget.asset]!;
    return Dialog(
      child: SingleChildScrollView(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    asset.name == null
                        ? asset.assetClass.name
                        : '${asset.name} (${asset.assetClass.name})',
                    style: TextStyle(fontSize: 20),
                  ),
                  Text(asset.assetClass.description),
                  ...asset.features.map((e) => describeFeature(
                        e,
                        widget.data,
                        widget.asset.system,
                        widget.asset,
                        widget.server,
                        context,
                      ))
                ],
              ),
            ),
            Positioned(
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    },
                    icon: Icon(Icons.close),
                  ),
                ],
              ),
            ),
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
    case StructureFeature(
        materials: List<MaterialLineItem> materials,
        maxHP: int maxHP,
        minHP: int? minHP,
        builder: AssetID? builder,
      ):
      if (maxHP == 0) {
        return ContinuousBuilder(builder: (context) {
          return Text('This has ${feature.getQuantity(
                data.getTime(system, DateTime.timestamp()),
              ).toStringAsFixed(2)} units of material and ${feature.getHP(
                data.getTime(system, DateTime.timestamp()),
              ).toStringAsFixed(2)} units built.');
        });
      }
      const int minLineItemHeight = 35;
      final double minLineItemFraction = materials
              .reduce((a, b) => a.requiredQuantity < b.requiredQuantity ? a : b)
              .requiredQuantity /
          maxHP;
      final double totalHeight = minLineItemHeight / minLineItemFraction;
      final ThemeData theme = Theme.of(context);
      return ContinuousBuilder(builder: (context) {
        return Column(
          children: [
            Stack(
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
                              height: totalHeight * e.requiredQuantity / maxHP,
                            ),
                            Container(
                              height: totalHeight * e.requiredQuantity / maxHP,
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
                      maxHP,
                ),
                Container(
                  color: Colors.green,
                  width: 10,
                  height: totalHeight *
                      feature.getHP(
                        data.getTime(system, DateTime.timestamp()),
                      ) /
                      maxHP,
                ),
                if (minHP != null)
                  Positioned(
                    top: totalHeight * minHP / maxHP,
                    child: Container(
                      color: Colors.pink,
                      width: 10,
                      height: 1,
                    ),
                  ),
              ],
            ),
            OutlinedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                              'Are you sure you want to dismantle this structure?'),
                          SizedBox(
                            height: 10,
                          ),
                          OutlinedButton(
                            onPressed: () {
                              server.send(
                                [
                                  'play',
                                  asset.system.value.toString(),
                                  asset.id.toString(),
                                  'dismantle',
                                ],
                              ).then((List<String> result) {
                                Navigator.pop(context);
                                if (result.first != 'T') {
                                  assert(result.first == 'F');
                                  assert(result.length == 2);
                                  if (result.last == 'no destructors') {
                                    openErrorDialog(
                                        'No people were found to dismantle this structure.',
                                        context);
                                  } else {
                                    openErrorDialog(
                                      'dismantle response: $result',
                                      context,
                                    );
                                  }
                                  return;
                                }
                                assert(result.length == 1);
                              });
                            },
                            child: Text('Dismantle'),
                          ),
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Text('Dismantle'),
            ),
            if (builder != null) Text('Currently being built.'),
          ],
        );
      });
    case SpaceSensorFeature(
        disabledReasoning: DisabledReasoning disabledReasoning
      ):
      return Text(
          'This is a space sensor (${disabledReasoning == 0 ? 'enabled' : disabledReasoning.asString}).');
    case SpaceSensorStatusFeature():
      continue nothing;
    case PlotControlFeature(isColonyShip: bool isColonyShip):
      if (!isColonyShip) continue nothing;
      return Text('This is the colony ship.');
    case GridFeature():
      continue nothing;
    case PopulationFeature(
        disabledReasoning: DisabledReasoning disabledReasoning,
        population: int population,
        maxPopulation: int maxPopulation,
        jobs: int jobs,
        averageHappiness: double averageHappiness
      ):
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'There are $population people here ($jobs with jobs) with an average of $averageHappiness happiness (${population.toDouble() * averageHappiness} total happiness).',
          ),
          Text(
              'This houses $maxPopulation people, and is currently ${disabledReasoning == 0 ? 'in working condition' : disabledReasoning.asString}.')
        ],
      );
    case MessageBoardFeature():
      continue nothing;
    case MessageFeature():
      throw StateError('message outside messageboard');
    case RubblePileFeature(
        remainingUnitCount: Uint64 remainingUnitCount,
        materials: Map<int, Uint64> materials
      ):
      return Column(
        children: [
          Text('There is a pile of rubble with:'),
          ...materials.entries.map(
            (e) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MaterialWidget(material: data.getMaterial(e.key, system)),
                Text(
                    '${e.value.displayName} unit${e.value.lsh == 1 ? '' : 's'}')
              ],
            ),
          ),
          if (!remainingUnitCount.isZero)
            Text('Unknown: ${remainingUnitCount.displayName} units'),
          OutlinedButton(
            onPressed: () {
              server.send(
                [
                  'play',
                  asset.system.value.toString(),
                  asset.id.toString(),
                  'dismantle',
                ],
              ).then((List<String> result) {
                if (result.first != 'T') {
                  assert(result.first == 'F');
                  assert(result.length == 2);
                  openErrorDialog(
                    'dismantle response: $result',
                    context,
                  );
                  return;
                }
                assert(result.length == 1);
              });
            },
            child: Text('Dismantle'),
          ),
        ],
      );
    nothing:
    case ProxyFeature():
      return Container(
        width: 0,
      );
    case KnowledgeFeature(
        classes: List<AssetClass> classes,
        materials: Map<MaterialID, Material> materials
      ):
      return Column(
        children: [
          Text('This has information about:'),
          ...classes
              .map((e) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: AssetClassWidget(assetClass: e),
                  ))
              .followedBy(
                materials.values.map(
                  (e) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: MaterialWidget(material: e),
                  ),
                ),
              ),
        ],
      );
    case ResearchFeature(
        disabledReasoning: DisabledReasoning disabledReasoning,
        topic: String topic
      ):
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${disabledReasoning == 0 ? 'Researching' : 'Will research'}: '),
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
          if (disabledReasoning != 0) Text('(${disabledReasoning.asString})')
        ],
      );
    case MiningFeature(
        currentRate: double currentRate,
        disabledReasoning: DisabledReasoning disabledReasoning,
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
            'Mining ${currentRate % .001 == 0 ? (currentRate * 1000).toInt() : currentRate * 1000} kilogram${currentRate == .001 ? '' : 's'} per second (${disabledReasoning == 0 ? rateLimitString : disabledReasoning.asString}).',
          ),
          Text(
              'Can mine ${maxRate % .001 == 0 ? (maxRate * 1000).toInt() : maxRate * 1000} kilogram${maxRate == .001 ? '' : 's'} per second.'),
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
        disabledReasoning: DisabledReasoning disabledReasoning,
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
                ' at a rate of ${currentRate % .001 == 0 ? (currentRate * 1000).toInt() : currentRate * 1000} kilogram${currentRate == .001 ? '' : 's'} per second (${disabledReasoning == 0 ? rateLimitString : disabledReasoning.asString}).',
              ),
            ],
          ),
          Text(
              'Can refine ${maxRate % .001 == 0 ? (maxRate * 1000).toInt() : maxRate * 1000} kilogram${maxRate == .001 ? '' : 's'} per second.'),
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
    case GridSensorFeature(
        disabledReasoning: DisabledReasoning disabledReasoning,
      ):
      return Text(
          'This is a grid sensor (${disabledReasoning == 0 ? 'enabled' : disabledReasoning.asString}).');
    case GridSensorStatusFeature():
      continue nothing;
    case BuilderFeature(
        capacity: int capacity,
        rate: double rate,
        disabledReasoning: DisabledReasoning disabledReasoning,
        structures: Set<AssetID> structures
      ):
      return Text(
        'This is a builder that can build $capacity structures at a rate of ${rate * 1000} units per second. (${disabledReasoning == 0 ? 'currently building ${structures.length} structure${structures.length == 1 ? '' : 's'}.' : disabledReasoning.asString})',
      );
    case InternalSensorFeature(
        disabledReasoning: DisabledReasoning disabledReasoning,
      ):
      return Text(
          'This is an internal sensor (${disabledReasoning == 0 ? 'enabled' : disabledReasoning.asString}).');
    case InternalSensorStatusFeature():
      continue nothing;
    case OnOffFeature(enabled: bool enabled):
      return OutlinedButton(
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
                  'unexpected response to enable/disable: $result', context);
            } else {
              if (result.first != 'T') {
                openErrorDialog(
                    'server thinks miner already enabled/disabled', context);
              }
            }
          } else {
            openErrorDialog('enable/disable failed: $result', context);
          }
        },
        child: Text(enabled ? 'Disable' : 'Enable'),
      );
    case StaffingFeature(
        jobs: int jobs,
        staff: int staff,
      ):
      return Text(
        'There are $staff people working here out of $jobs required.',
      );
    case AssetPileFeature(assets: List<AssetID> assets):
      return Column(
        children: [
          ...assets.map(
            (asset) => AssetWidget(
              asset: asset,
              data: data,
              width: 100,
              height: 100,
              server: server,
            ),
          ),
        ],
      );
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
            return MaterialDialog(material: material);
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

class AssetClassWidget extends StatelessWidget {
  const AssetClassWidget({super.key, required this.assetClass});
  final AssetClass assetClass;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return AssetClassDialog(assetClass: assetClass);
          },
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ISDIcon(icon: assetClass.icon, width: 32, height: 32),
          Text(assetClass.name)
        ],
      ),
    );
  }
}
