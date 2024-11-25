import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:isd_treeclient/assets.dart';
import 'package:isd_treeclient/data-structure.dart';
import 'package:isd_treeclient/network_handler.dart';
import 'package:isd_treeclient/ui-core.dart';

class GalaxyView extends StatefulWidget {
  const GalaxyView(
      {super.key, required this.data, required this.dynastyServer});

  final DataStructure data;
  final NetworkConnection? dynastyServer;

  @override
  State<GalaxyView> createState() => _GalaxyViewState();
}

class _GalaxyViewState extends State<GalaxyView>
    with TickerProviderStateMixin {
  final TextEditingController textFieldController = TextEditingController();
  String? errorMessage;
  String? description;
  StarIdentifier? selectedStar;
  ZoomController? galaxyZoomController;

  @override
  void dispose() {
    galaxyZoomController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Lookup star by ID:'),
        SizedBox(
          width: 200,
          child: TextField(
            controller: textFieldController,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: OutlinedButton(
            onPressed: () {
              setState(() {
                String rawStarID = textFieldController.text;
                if (!rawStarID.startsWith('S')) {
                  errorMessage =
                      'Invalid star ID. All star IDs must start with S.';
                  return;
                }
                int? integerStarID =
                    int.tryParse(rawStarID.substring(1), radix: 16);
                if (integerStarID == null) {
                  errorMessage =
                      'Invalid star ID. All star IDs must be S followed by a hexadecimal integer.';
                  return;
                }
                StarIdentifier starID = StarIdentifier.parse(integerStarID);
                if (starID.category < 0) {
                  errorMessage =
                      'Invalid star ID. Star IDs cannot be negative.';
                  return;
                }
                if (starID.category > 10) {
                  errorMessage =
                      'Invalid star ID. The maximum star category (the first hexadecimal digit) is A.';
                  return;
                }
                if (widget.data.stars == null) {
                  errorMessage = 'Still loading stars. Try again later.';
                  return;
                }
                if (widget.data.stars![starID.category].length <=
                    starID.subindex) {
                  errorMessage =
                      'Invalid star ID. The maximum value for the last five hexadecimal digits of a star with category ${starID.category} is ${(widget.data.stars![starID.category].length - 1).toRadixString(16)}.';
                  return;
                }
                errorMessage = null;
                description = null;
                selectedStar = starID;
                galaxyZoomController ??= ZoomController(
                  vsync: this,
                  zoom: 100,
                  screenCenter: widget.data.stars![starID.category]
                      [starID.subindex],
                );
                galaxyZoomController!.animateTo(
                  100,
                  widget.data.stars![starID.category][starID.subindex],
                );
                if (widget.dynastyServer != null) {
                  if (widget.dynastyServer!.reloading) {
                    errorMessage = 'Dynasty server offline; try again later';
                  } else {
                    widget.dynastyServer!.send([
                      'get-star-name',
                      starID.value.toString(),
                    ]).then((e) {
                      setState(() {
                        if (e[0] == 'F') {
                          description = e.toString();
                        } else {
                          description = '${e[1]}';
                        }
                      });
                    });
                  }
                } else {
                  errorMessage = 'Could not load name; try again later.';
                }
              });
            },
            child: Text('Lookup'),
          ),
        ),
        OutlinedButton(
          onPressed: () {
            setState(() {
              errorMessage = null;
              description = null;
              galaxyZoomController ??= ZoomController(
                vsync: this,
                zoom: 1,
                screenCenter: Offset(0.5, 0.5),
              );
              galaxyZoomController!.animateTo(1, Offset(.5, .5));
            });
          },
          child: Text('See full galaxy'),
        ),
        if (errorMessage != null)
          Text(
            errorMessage!,
            style: TextStyle(color: Colors.red),
          ),
        if (description != null)
          SelectableText(
            description!,
          ),
        if (galaxyZoomController != null)
          Expanded(
            child: ZoomableCustomPaint(
              painter: GalaxyRenderer(
                widget.data.stars!,
                selectedStar == null ? {} : {selectedStar!},
                galaxyZoomController!,
              ),
              controller: galaxyZoomController!,
            ),
          ),
      ],
    );
  }
}

class GalaxyRenderer extends CustomPainter {
  final List<List<Offset>> stars;
  final Set<StarIdentifier> highlightedStars;
  final ZoomController zoomController;
  const GalaxyRenderer(this.stars, this.highlightedStars, this.zoomController)
      : super(repaint: zoomController);

  @override
  void paint(Canvas canvas, Size size) {
    Offset screenCenter = zoomController.screenCenter;
    double zoom = zoomController.zoom;
    int category = 0;
    Offset topLeft = Offset(screenCenter.dx - .5, screenCenter.dy - .5);
    canvas.drawOval(
        (((-topLeft - Offset(.5, .5)) * zoom) + Offset(.5, .5))
                .scale(size.width, size.height) &
            size * zoom,
        Paint()
          ..color = (Color(0x5566BBFF).withAlpha((0x55 / zoom).toInt()))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10));
    for (StarIdentifier star in highlightedStars) {
      Offset starPos = stars[star.category][star.subindex];
      canvas.drawCircle(
          calculateScreenPosition(starPos, screenCenter, zoom, size),
          starCategories[star.category].strokeWidth *
              size.shortestSide *
              2 *
              sqrt(zoom) /
              3,
          Paint.from(starCategories[star.category])
            ..color = Colors.green
            ..strokeWidth = 0);
    }
    while (category < 11) {
      canvas.drawPoints(
          PointMode.points,
          stars[category].map((e) {
            return calculateScreenPosition(e, screenCenter, zoom, size);
          }).where((e) {
            return !(e.dx < 0 ||
                e.dy < 0 ||
                e.dx > size.width ||
                e.dy > size.height);
          }).toList(),
          Paint.from(starCategories[category])
            ..strokeCap = StrokeCap.round
            ..strokeWidth = starCategories[category].strokeWidth *
                size.shortestSide *
                sqrt(zoom)
            ..maskFilter = category == 10
                ? MaskFilter.blur(BlurStyle.normal, zoom)
                : null);
      category++;
    }
    canvas.drawRect(size.center(Offset.zero) - Offset(1, 1) & Size.square(2),
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(GalaxyRenderer oldDelegate) {
    return true;
  }
}
