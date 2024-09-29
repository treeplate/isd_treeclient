import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:isd_treeclient/ui-core.dart';
import 'data-structure.dart';
import 'assets.dart';
import 'core.dart';

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

class _SystemViewState extends State<SystemView>
    with SingleTickerProviderStateMixin {
  late Uint64 systemTime;
  late final Ticker ticker;
  ZoomController systemZoomController = ZoomController(zoom: 15000);

  @override
  void initState() {
    super.initState();
    tick(Duration.zero);
    ticker = createTicker(tick)..start();
  }

  void tick(Duration duration) {
    setState(() {
      (DateTime, Uint64) time0 = widget.data.time0s[widget.system]!;
      systemTime = time0.$2;
      systemTime += Uint64.fromInt(
          (DateTime.timestamp().difference(time0.$1).inMilliseconds *
                  widget.data.timeFactors[widget.system]!)
              .floor());
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Asset rootAsset =
        widget.data.assets[widget.data.rootAssets[widget.system]!]!;
    SolarSystemFeature solarSystemFeature =
        (rootAsset.features.single as SolarSystemFeature);
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
                child: Container(),
              ),
              Expanded(
                flex: 2,
                child: ZoomableCustomPaint(
                  controller: systemZoomController,
                  painter: (zoom, screenCenter) => SystemRenderer(
                    zoom,
                    screenCenter,
                    widget.data,
                    widget.system,
                    systemTime,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Center on star'),
                    ...solarSystemFeature.children.map(
                      (e) => TextButton(
                        onPressed: () {
                          setState(() {
                            systemZoomController.zoom = 15000;
                            systemZoomController.screenCenter =
                                polarToCartesian(
                                        e.distanceFromCenter / rootAsset.size,
                                        e.theta) +
                                    Offset(.5, .5);
                          });
                        },
                        child: Text(
                          '${widget.data.getAssetIdentifyingName(e.child)}',
                        ),
                      ),
                    )
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
  final double zoom;
  final Offset screenCenter;
  final DataStructure data;
  final StarIdentifier system;
  final Uint64 systemTime;
  final double sizeScaleFactor;
  SystemRenderer(
    this.zoom,
    this.screenCenter,
    this.data,
    this.system,
    this.systemTime, [
    this.sizeScaleFactor = 100,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
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
          ..color = Colors.white
          ..style = PaintingStyle.stroke);
    SolarSystemFeature solarSystemFeature =
        (rootAsset.features.single as SolarSystemFeature);
    for (SolarSystemChild solarSystemChild in solarSystemFeature.children) {
      Asset orbit = data.assets[solarSystemChild.child]!;
      OrbitFeature orbitFeature = (orbit.features.single as OrbitFeature);
      Asset star = data.assets[orbitFeature.primaryChild]!;
      StarFeature starFeature = star.features.whereType().single;
      double starDiameter = (star.size / rootAsset.size) * sizeScaleFactor;
      Offset starCenter = (polarToCartesian(
                  solarSystemChild.distanceFromCenter, solarSystemChild.theta) /
              rootAsset.size) +
          Offset(.5, .5);
      canvas.drawOval(
          calculateScreenPosition(
                  starCenter - Offset(starDiameter / 2, starDiameter / 2),
                  screenCenter,
                  zoom,
                  size) &
              size * zoom * starDiameter,
          Paint()..color = starCategories[starFeature.starID.category].color);
      drawOrbits(orbitFeature, rootAsset, star, starCenter, canvas, size);
    }
    canvas.drawRect(size.center(Offset.zero) - Offset(1, 1) & Size.square(2),
        Paint()..color = Colors.white);
  }

  void drawOrbits(
      OrbitFeature orbitFeature,
      Asset rootAsset,
      Asset primaryChild,
      Offset primaryChildPosition,
      Canvas canvas,
      Size size) {
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
      canvas.drawOval(
          calculateScreenPosition(
                  assetCenter - Offset(assetDiameter / 2, assetDiameter / 2),
                  screenCenter,
                  zoom,
                  size) &
              size * zoom * assetDiameter,
          Paint()..color = Colors.blue);
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
