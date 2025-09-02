import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:isd_treeclient/ui-core.dart';
import 'data-structure.dart';
import 'assets.dart';
import 'core.dart';
import 'dart:ui' as ui;
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
  void initState() {
    if (widget.data.rootAssets.keys.length == 1) {
      selectedSystem = widget.data.rootAssets.keys.single;
    }
    super.initState();
  }

  @override
  void didUpdateWidget(SystemSelector oldWidget) {
    if (widget.data.rootAssets.keys.length == 1) {
      selectedSystem = widget.data.rootAssets.keys.single;
    }
    super.didUpdateWidget(oldWidget);
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
    return _getOrbitFeature(orbit, data)
        .orbitingChildren
        .map((e) => OrbitAssetInformation(e, this));
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
  Iterable<AssetInformation> getChildren(DataStructure data) =>
      _getChildren(child.child, data);
}

class OrbitAssetInformation extends AssetInformation {
  final OrbitChild child;
  final AssetInformation parent;

  int get hashCode => child.hashCode;
  operator ==(other) => other is OrbitAssetInformation && child == other.child;

  OrbitAssetInformation(this.child, this.parent);
  @override
  Offset calculatePositionAtTime(Uint64 systemTime, DataStructure data) {
    return calculateOrbit(
          systemTime,
          child.timeOrigin,
          child.semiMajorAxis,
          child.eccentricity,
          child.clockwise,
          data.assets[parent.getAsset(data)]!.getMass(systemTime),
          child.omega,
        ) +
        parent.calculatePositionAtTime(systemTime, data);
  }

  AssetID getAsset(DataStructure data) {
    return AssetInformation._getOrbitFeature(child.child, data).primaryChild;
  }

  @override
  Iterable<AssetInformation> getChildren(DataStructure data) =>
      _getChildren(child.child, data);
}

class _SystemViewState extends State<SystemView> with TickerProviderStateMixin {
  late Uint64 systemTime;
  late final Ticker ticker;
  late final ZoomController systemZoomController =
      ZoomController(zoom: 1, vsync: this);
  AssetInformation? screenFocus;
  double assetScale = 1;
  double maxAssetSize = 1;
  Map<String, ui.Image> icons = {};
  Map<String, ui.Image> networkIcons = {};

  @override
  void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    for (AssetInformation asset in flattenAssetTree()) {
      if (widget.data.assets[asset.getAsset(widget.data)]!.features
          .any((e) => e is PlotControlFeature && e.isColonyShip)) {
        screenFocus = asset;
        systemZoomController.animateTo(
            1e8, systemZoomController.realScreenCenter);
      }
    }
  }

  bool? useNetworkImages = null;
  void asyncTick() async {
    useNetworkImages = await getCookie(useNetworkImagesCookieName) == 'true';
  }

  @override
  void initState() {
    super.initState();
    didUpdateWidget(widget);
    tick(Duration.zero);
    ticker = createTicker(tick)..start();
  }

  Offset calculateOrbitForScreenFocus() {
    if (widget.data.rootAssets[widget.system] == null) return Offset(.5, .5);
    if (screenFocus is OrbitAssetInformation &&
        !(screenFocus as OrbitAssetInformation)
            .parent
            .getChildren(widget.data)
            .contains(screenFocus)) {
      screenFocus = (screenFocus as OrbitAssetInformation).parent;
      return systemZoomController.realScreenCenter;
    }
    return (screenFocus!.calculatePositionAtTime(systemTime, widget.data) /
            widget.data.assets[widget.data.rootAssets[widget.system]]!.size) +
        Offset(.5, .5);
  }

  final List<String> pendingNetworkImages = [];
  final List<String> noAssetImages = [];

  void tick(Duration duration) {
    asyncTick();
    for (AssetInformation assetInfo in flattenAssetTree()) {
      Asset asset = widget.data.assets[assetInfo.getAsset(widget.data)]!;
      if (useNetworkImages ?? false
          ? !networkIcons.containsKey(asset.icon)
          : !icons.containsKey(asset.icon)) {
        final ImageProvider icon;
        bool wasFromNetwork;
        if ((useNetworkImages ?? false) &&
            !failedNetworkIcons.contains(asset.icon) &&
            !pendingNetworkImages.contains(asset.icon)) {
          pendingNetworkImages.add(asset.icon);
          wasFromNetwork = true;
          icon = NetworkImage(
              'https://interstellar-dynasties.space/icons/${asset.icon}.png');
        } else {
          wasFromNetwork = false;
          icon = AssetImage('icons/${asset.icon}.png');
        }
        bool wantedToUseNetworkImages = useNetworkImages ?? false;
        icon.resolve(ImageConfiguration()).addListener(
              ImageStreamListener(
                (info, sync) {
                  (wantedToUseNetworkImages
                      ? networkIcons
                      : icons)[asset.icon] = info.image;
                },
                onError: (exception, stackTrace) {
                  if (mounted && wasFromNetwork) {
                    openErrorDialog(
                      'Failure when fetching ${asset.icon} from server: $exception',
                      context,
                    );
                  } else if (mounted && !noAssetImages.contains(asset.icon)) {
                    openErrorDialog(
                      'Could not find asset for icon ${asset.icon}: $exception',
                      context,
                    );
                    noAssetImages.add(asset.icon);
                  }
                  if (wasFromNetwork) {
                    failedNetworkIcons.add(asset.icon);
                  }
                },
              ),
            );
      }
    }
    setState(() {
      systemTime = widget.data.getTime(widget.system, DateTime.timestamp());
      if (screenFocus != null) {
        systemZoomController.modifyAnimation(
          screenCenter: calculateOrbitForScreenFocus(),
        );
      }
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    systemZoomController.dispose();
    super.dispose();
  }

  void onTap(Offset normalizedPosition) {
    for (AssetInformation asset in flattenAssetTree()) {
      Offset assetPos = (asset.calculatePositionAtTime(
                  systemTime, widget.data) /
              widget.data.assets[widget.data.rootAssets[widget.system]]!.size) +
          Offset(.5, .5);
      double assetRadius = min(
              maxAssetSize,
              widget.data.assets[asset.getAsset(widget.data)]!.size *
                  assetScale /
                  widget.data.assets[widget.data.rootAssets[widget.system]]!
                      .size) /
          2;
      if (normalizedPosition.dx > assetPos.dx - assetRadius &&
          normalizedPosition.dx < assetPos.dx + assetRadius &&
          normalizedPosition.dy > assetPos.dy - assetRadius &&
          normalizedPosition.dy < assetPos.dy + assetRadius) {
        screenFocus = asset;
        systemZoomController.animateTo(
          max(
              1 / maxAssetSize,
              widget.data.assets[widget.data.rootAssets[widget.system]!]!.size /
                  widget.data.assets[asset.getAsset(widget.data)]!.size /
                  assetScale),
          calculateOrbitForScreenFocus(),
        );
      }
    }
  }

  List<AssetInformation> flattenAssetTree() {
    if (widget.data.rootAssets[widget.system] == null) return [];
    if (widget.data.assets[widget.data.rootAssets[widget.system]!] == null) {
      return [];
    }
    Asset rootAsset =
        widget.data.assets[widget.data.rootAssets[widget.system]!]!;
    SolarSystemFeature solarSystemFeature =
        (rootAsset.features.single as SolarSystemFeature);
    List<AssetInformation> frontier = solarSystemFeature.children
        .map<AssetInformation>((e) => RootAssetInformation(e))
        .toList();
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
    return LayoutBuilder(builder: (context, constraints) {
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
                          Text('10^0'),
                          SizedBox(
                            width: max(0, constraints.maxWidth / 4 - 100),
                            child: Slider(
                              min: 0,
                              max: 10,
                              value: log(assetScale) / log(10),
                              onChanged: (newValue) {
                                setState(
                                  () {
                                    assetScale = pow(10, newValue).toDouble();
                                  },
                                );
                              },
                            ),
                          ),
                          Text('10^10'),
                        ],
                      ),
                      Text('Max asset size'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('1/10^0'),
                          SizedBox(
                            width: max(0, constraints.maxWidth / 4 - 120),
                            child: Slider(
                              min: 0,
                              max: 10,
                              value: log(1 / maxAssetSize) / log(10),
                              onChanged: (newValue) {
                                setState(
                                  () {
                                    maxAssetSize = 1 / pow(10, newValue);
                                  },
                                );
                              },
                            ),
                          ),
                          Text('1/10^10'),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ZoomableCustomPaint(
                    controller: systemZoomController,
                    onTap: onTap,
                    painter: SystemRenderer(
                      widget.data,
                      widget.system,
                      systemTime,
                      systemZoomController,
                      useNetworkImages ?? false ? networkIcons : icons,
                      assetScale,
                      maxAssetSize,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      if (screenFocus != null)
                        TextButton(
                            onPressed: () {
                              screenFocus = null;
                            },
                            child: Text(
                                'Stop following ${widget.data.getAssetIdentifyingName(screenFocus!.getAsset(widget.data))}')),
                      Text('Center on asset'),
                      ...flattenAssetTree().map(
                        (e) => TextButton(
                          onPressed: () {
                            setState(() {
                              screenFocus = e;
                              systemZoomController.animateTo(
                                max(
                                    1 / maxAssetSize,
                                    rootAsset.size /
                                        widget
                                            .data
                                            .assets[e.getAsset(widget.data)]!
                                            .size /
                                        assetScale),
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
    });
  }
}

class SystemRenderer extends CustomPainter {
  final DataStructure data;
  final StarIdentifier system;
  final Uint64 systemTime;
  final double sizeScaleFactor;
  final double maxAssetSize;
  final ZoomController zoomController;
  final Map<String, ui.Image> icons;
  SystemRenderer(
    this.data,
    this.system,
    this.systemTime,
    this.zoomController,
    this.icons, [
    this.sizeScaleFactor = 1,
    this.maxAssetSize = double.infinity,
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
      double starDiameter =
          min((star.size / rootAsset.size) * sizeScaleFactor, maxAssetSize);
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
      paintImage(
        canvas: canvas,
        rect: rect,
        image: icon,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      );
    }
  }

  void drawOrbits(
      OrbitFeature orbitFeature,
      Asset rootAsset,
      Asset primaryChild,
      Offset primaryChildPosition, //(0,0)..(1,1)
      Canvas canvas,
      Size size) {
    Offset screenCenter = zoomController.screenCenter;
    double zoom = zoomController.zoom;
    for (OrbitChild orbitChild in orbitFeature.orbitingChildren) {
      Asset orbit = data.assets[orbitChild.child]!;
      OrbitFeature childOrbitFeature = (orbit.features.single as OrbitFeature);
      Asset asset = data.assets[childOrbitFeature.primaryChild]!;
      double assetDiameter =
          min((asset.size / rootAsset.size) * sizeScaleFactor, maxAssetSize);
      Offset assetCenter = (calculateOrbit(
                  systemTime,
                  orbitChild.timeOrigin,
                  orbitChild.semiMajorAxis,
                  orbitChild.eccentricity,
                  orbitChild.clockwise,
                  primaryChild.getMass(systemTime),
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
      Offset primaryChildScreenPosition = calculateScreenPosition(
          primaryChildPosition, screenCenter, zoom, size);
      canvas.translate(
          primaryChildScreenPosition.dx, primaryChildScreenPosition.dy);
      canvas.rotate(orbitChild.omega);
      canvas.translate(
          -primaryChildScreenPosition.dx, -primaryChildScreenPosition.dy);
      Offset eccentricOffset = Offset(
          orbitChild.eccentricity * orbitChild.semiMajorAxis / rootAsset.size,
          0);
      canvas.drawOval(
          calculateScreenPosition(
                  (primaryChildPosition - eccentricOffset) -
                      orbitSize.center(Offset.zero),
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
