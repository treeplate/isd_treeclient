import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:isd_treeclient/ui-core.dart';
import 'data-structure.dart';
import 'assets.dart';
import 'core.dart';
import 'dart:ui' as ui;

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

class SystemView extends StatefulWidget {
  const SystemView({super.key, required this.data, required this.system});

  final DataStructure data;
  final StarIdentifier system;

  @override
  State<SystemView> createState() => _SystemViewState();
}

abstract class AssetInformation {
  Offset calculatePositionAtTime(Uint64 systemTime, DataStructure data);
  @protected
  static OrbitFeature _getOrbitFeature(AssetID orbit, DataStructure data) {
    return (data.assets[orbit]!.features.single as OrbitFeature);
  }
  @protected
  Iterable<AssetInformation> _getChildren(AssetID orbit, DataStructure data) {
    return 
        _getOrbitFeature(orbit, data).orbitingChildren.map((e) => OrbitAssetInformation(e, this));
  }

  AssetID getAsset(DataStructure data);
  Iterable<AssetInformation> getChildren(DataStructure data);
}

class RootAssetInformation extends AssetInformation {
  final SolarSystemChild child;

  RootAssetInformation(this.child);
  @override
  Offset calculatePositionAtTime(Uint64 systemTime, DataStructure data) {
    return polarToCartesian(
      child.distanceFromCenter,
      child.theta,
    );
  }

  AssetID getAsset(DataStructure data) {
    return AssetInformation._getOrbitFeature(child.child, data).primaryChild;
  }
  
  @override
  Iterable<AssetInformation> getChildren(DataStructure data) => _getChildren(child.child, data);
}

class OrbitAssetInformation extends AssetInformation {
  final OrbitChild child;
  final AssetInformation parent;

  OrbitAssetInformation(this.child, this.parent);
  @override
  Offset calculatePositionAtTime(Uint64 systemTime, DataStructure data) {
    return calculateOrbit(
          systemTime - (child.timeOffset * 1000),
          child.semiMajorAxis,
          child.eccentricity,
          child.clockwise,
          data.assets[parent.getAsset(data)]!.mass,
          child.omega,
        ) +
        parent.calculatePositionAtTime(systemTime, data);
  }

  AssetID getAsset(DataStructure data) {
    return AssetInformation._getOrbitFeature(child.child, data).primaryChild;
  }
  @override
  Iterable<AssetInformation> getChildren(DataStructure data) => _getChildren(child.child, data);
}

class _SystemViewState extends State<SystemView> with TickerProviderStateMixin {
  late Uint64 systemTime;
  late final Ticker ticker;
  late final ZoomController systemZoomController =
      ZoomController(zoom: 15000, vsync: this);
  AssetInformation? screenFocus;
  double assetScale = 1;
  Map<String, ui.Image> icons = {};

  @override
  void initState() {
    super.initState();
    tick(Duration.zero);
    ticker = createTicker(tick)..start();
  }

  Offset calculateOrbitForScreenFocus() {
    return (screenFocus!.calculatePositionAtTime(systemTime, widget.data) /
            widget.data.assets[widget.data.rootAssets[widget.system]]!.size) +
        Offset(.5, .5);
  }

  void tick(Duration duration) {
    for (AssetInformation assetInfo in flattenAssetTree()) {
      Asset asset = widget.data.assets[assetInfo.getAsset(widget.data)]!;
      if (!icons.containsKey(asset.icon)) {
        print('finding ${asset.icon}');
        AssetImage('icons/${asset.icon}.png')
            .resolve(ImageConfiguration())
            .addListener(ImageStreamListener(
                (info, sync) => icons[asset.icon] = info.image));
      }
    }
    setState(() {
      (DateTime, Uint64) time0 = widget.data.time0s[widget.system]!;
      systemTime = time0.$2;
      systemTime += Uint64.fromInt(
          (DateTime.timestamp().difference(time0.$1).inMilliseconds *
                  widget.data.timeFactors[widget.system]!)
              .floor());
      if (screenFocus != null) {
        systemZoomController.modifyAnimation(
            screenCenter: calculateOrbitForScreenFocus());
      }
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    systemZoomController.dispose();
    super.dispose();
  }

  List<AssetInformation> flattenAssetTree() {Asset rootAsset =
        widget.data.assets[widget.data.rootAssets[widget.system]!]!;
    SolarSystemFeature solarSystemFeature =
        (rootAsset.features.single as SolarSystemFeature);
    List<AssetInformation> frontier = solarSystemFeature.children.map<AssetInformation>((e) => RootAssetInformation(e)).toList();
    List<AssetInformation> result = [];
    while (frontier.isNotEmpty) {
      AssetInformation parent = frontier.last;
      frontier.removeLast();
      frontier.addAll(parent.getChildren(widget.data));
      result.add(parent);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    Asset rootAsset =
        widget.data.assets[widget.data.rootAssets[widget.system]!]!;
    return Column(
      children: [
        SelectableText(
          '${widget.system.displayName}',
          style: TextStyle(fontSize: 20),
        ),
        Text('current solar system time: ${prettyPrintDuration(systemTime)}'),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('Asset size multiplier'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('1'),
                        Slider(
                          min: 1,
                          max: 100,
                          value: assetScale,
                          onChanged: (newValue) {
                            setState(
                              () {
                                assetScale = newValue;
                              },
                            );
                          },
                        ),
                        Text('100'),
                      ],
                    )
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: ZoomableCustomPaint(
                  controller: systemZoomController,
                  painter: SystemRenderer(
                    widget.data,
                    widget.system,
                    systemTime,
                    systemZoomController,
                    icons,
                    assetScale,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    Text('Center on asset'),
                    ...flattenAssetTree().map(
                          (e) => TextButton(
                            onPressed: () {
                              setState(() {
                                screenFocus = e;
                                systemZoomController.animateTo(
                                  rootAsset.size /
                                      widget.data.assets[e.getAsset(widget.data)]!.size /
                                      assetScale,
                                  calculateOrbitForScreenFocus(),
                                );
                              });
                            },
                            child: Text(
                              '${widget.data.getAssetIdentifyingName(e.getAsset(widget.data))}',
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SystemRenderer extends CustomPainter {
  final DataStructure data;
  final StarIdentifier system;
  final Uint64 systemTime;
  final double sizeScaleFactor;
  final ZoomController zoomController;
  final Map<String, ui.Image> icons;
  SystemRenderer(
    this.data,
    this.system,
    this.systemTime,
    this.zoomController,
    this.icons, [
    this.sizeScaleFactor = 1,
  ]) : super(repaint: zoomController);

  @override
  void paint(Canvas canvas, Size size) {
    Offset screenCenter = zoomController.screenCenter;
    double zoom = zoomController.zoom;
    Asset rootAsset = data.assets[data.rootAssets[system]!]!;
    Rect r = Offset.zero & size;
    canvas.drawLine(
        r.topLeft,
        r.topRight,
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 2);
    canvas.drawLine(
        r.bottomLeft,
        r.bottomRight,
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 2);
    canvas.drawLine(
        r.topLeft,
        r.bottomLeft,
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 2);
    canvas.drawLine(
        r.topRight,
        r.bottomRight,
        Paint()
          ..color = Colors.grey
          ..strokeWidth = 2);
    canvas.drawOval(
        calculateScreenPosition(Offset.zero, screenCenter, zoom, size) &
            size * zoom,
        Paint()
          ..color = Colors.grey
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    SolarSystemFeature solarSystemFeature =
        (rootAsset.features.single as SolarSystemFeature);
    for (SolarSystemChild solarSystemChild in solarSystemFeature.children) {
      Asset orbit = data.assets[solarSystemChild.child]!;
      OrbitFeature orbitFeature = (orbit.features.single as OrbitFeature);
      Asset star = data.assets[orbitFeature.primaryChild]!;
      double starDiameter = (star.size / rootAsset.size) * sizeScaleFactor;
      Offset starCenter = (polarToCartesian(
                  solarSystemChild.distanceFromCenter, solarSystemChild.theta) /
              rootAsset.size) +
          Offset(.5, .5);
      drawAsset(
          star,
          canvas,
          calculateScreenPosition(
                  starCenter - Offset(starDiameter / 2, starDiameter / 2),
                  screenCenter,
                  zoom,
                  size) &
              size * zoom * starDiameter);
      drawOrbits(orbitFeature, rootAsset, star, starCenter, canvas, size);
    }
    canvas.drawRect(size.center(Offset.zero) - Offset(1, 1) & Size.square(2),
        Paint()..color = Colors.white);
  }

  void drawAsset(Asset asset, Canvas canvas, Rect rect) {
    for (Feature feature in asset.features) {
      switch (feature) {
        case OrbitFeature():
          throw ArgumentError(
              'drawAsset does not support orbits, try drawOrbits');
        case StarFeature(starID: StarIdentifier id):
          canvas.drawOval(
              rect, Paint()..color = starCategories[id.category].color);
          return;
        default:
      }
    }
    canvas.drawOval(
        rect,
        Paint()
          ..color = asset.owner == null
              ? Colors.grey
              : getColorForDynastyID(asset.owner!));
    final ui.Image? icon = icons[asset.icon];
    if (icon != null) {
      canvas.drawImageNine(icon, rect, rect, Paint());
    }
  }

  void drawOrbits(
      OrbitFeature orbitFeature,
      Asset rootAsset,
      Asset primaryChild,
      Offset primaryChildPosition,
      Canvas canvas,
      Size size) {
    Offset screenCenter = zoomController.screenCenter;
    double zoom = zoomController.zoom;
    for (OrbitChild orbitChild in orbitFeature.orbitingChildren) {
      Asset orbit = data.assets[orbitChild.child]!;
      OrbitFeature childOrbitFeature = (orbit.features.single as OrbitFeature);
      Asset asset = data.assets[childOrbitFeature.primaryChild]!;
      double assetDiameter = (asset.size / rootAsset.size) * sizeScaleFactor;
      Offset assetCenter = (calculateOrbit(
                  systemTime - orbitChild.timeOffset * 1000,
                  orbitChild.semiMajorAxis,
                  orbitChild.eccentricity,
                  orbitChild.clockwise,
                  primaryChild.mass,
                  orbitChild.omega)) /
              rootAsset.size +
          primaryChildPosition;
      assert(!assetCenter.dx.isNaN && !assetCenter.dy.isNaN);
      Size orbitSize = Size(
              orbitChild.semiMajorAxis * 2,
              orbitChild.semiMajorAxis *
                  sqrt(1 - orbitChild.eccentricity * orbitChild.eccentricity) *
                  2) /
          rootAsset.size;
      canvas.save();
      Offset orbitCenter = primaryChildPosition +
          Offset(orbitChild.eccentricity * orbitChild.semiMajorAxis, 0);
      canvas.translate(orbitCenter.dx, orbitCenter.dy);
      canvas.rotate(orbitChild.omega);
      canvas.translate(-orbitCenter.dx, -orbitCenter.dy);
      canvas.drawOval(
          calculateScreenPosition(
                  primaryChildPosition -
                      (orbitSize / 2).bottomRight(Offset.zero),
                  screenCenter,
                  zoom,
                  size) &
              Size(size.width * orbitSize.width,
                      size.height * orbitSize.height) *
                  zoom,
          Paint()
            ..color = Colors.cyan
            ..style = PaintingStyle.stroke);
      canvas.restore();
      drawAsset(
        asset,
        canvas,
        calculateScreenPosition(
                assetCenter - Offset(assetDiameter / 2, assetDiameter / 2),
                screenCenter,
                zoom,
                size) &
            size * zoom * assetDiameter,
      );
      drawOrbits(
        childOrbitFeature,
        rootAsset,
        asset,
        assetCenter,
        canvas,
        size,
      );
    }
  }

  @override
  bool shouldRepaint(SystemRenderer oldDelegate) {
    return true;
  }
}
