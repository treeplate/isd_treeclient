import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'core.dart';

void openErrorDialog(String message, BuildContext context) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$message'),
            SizedBox(
              height: 16,
            ),
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Ok'),
            )
          ],
        ),
      );
    },
  );
}

class TextFieldDialog extends StatefulWidget {
  const TextFieldDialog({
    super.key,
    required this.onSubmit,
    required this.dialogTitle,
    required this.buttonMessage,
    required this.textFieldLabel,
    required this.obscureText,
  });

  final String dialogTitle;
  final String textFieldLabel;
  final String buttonMessage;
  final bool obscureText;
  final Future<String?> Function(String newValue) onSubmit;

  @override
  State<TextFieldDialog> createState() => _TextFieldDialogState();
}

class _TextFieldDialogState extends State<TextFieldDialog> {
  TextEditingController textFieldController = TextEditingController();
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(widget.dialogTitle),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${widget.textFieldLabel}:'),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: TextField(
                    obscureText: widget.obscureText,
                    controller: textFieldController,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            OutlinedButton(
              onPressed: () {
                widget
                    .onSubmit(
                      textFieldController.text,
                    )
                    .then(
                      (e) => setState(() {
                        errorMessage = e;
                      }),
                    );
              },
              child: Text(widget.buttonMessage),
            ),
          ],
        ),
      ),
    );
  }
}

class ZoomController extends ChangeNotifier {
  double _zoom;
  late double _oldZoom = _zoom;
  double get realZoom => _zoom;
  double get zoom =>
      Curves.easeInOutQuint.transform(_animation.value) * (_zoom - _oldZoom) +
      _oldZoom;
  Offset _screenCenter;
  late Offset _oldScreenCenter = _screenCenter;
  Offset get realScreenCenter => _screenCenter;
  Offset get screenCenter =>
      (_screenCenter - _oldScreenCenter) *
          Curves.easeOutExpo.transform(_animation.value) +
      _oldScreenCenter;

  late final AnimationController _animation;

  void animateTo(double newZoom, Offset newScreenCenter) {
    _oldZoom = zoom;
    _oldScreenCenter = screenCenter;
    _zoom = newZoom;
    _screenCenter = newScreenCenter;
    _animation.reset();
    _animation.animateTo(1);
  }

  void modifyAnimation({double? zoom, Offset? screenCenter}) {
    _zoom = zoom ?? _zoom;
    _screenCenter = screenCenter ?? _screenCenter;
  }

  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  ZoomController(
      {double zoom = 1,
      Offset screenCenter = const Offset(.5, .5),
      required TickerProvider vsync})
      : _zoom = zoom,
        _screenCenter = screenCenter {
    _animation = AnimationController(
        vsync: vsync, duration: Duration(seconds: 1), value: 1);
    _animation.addListener(notifyListeners);
  }
}

class ZoomableCustomPaint extends StatefulWidget {
  const ZoomableCustomPaint({
    super.key,
    required this.painter,
    required this.controller,
    this.onTap,
  });
  final CustomPainter painter;
  final ZoomController controller;
  final void Function(Offset)? onTap;

  @override
  State<ZoomableCustomPaint> createState() => _ZoomableCustomPaintState();
}

class _ZoomableCustomPaintState extends State<ZoomableCustomPaint> {
  double lastRelativeScale = 1.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return Listener(
        onPointerSignal: (details) {
          if (details is PointerScrollEvent) {
            setState(() {
              if (details.scrollDelta.dy > 0) {
                handleZoom(1 / 1.5);
              } else {
                handleZoom(1.5);
              }
            });
          }
        },
        child: Center(
          child: GestureDetector(
            onScaleStart: (details) {
              lastRelativeScale = 1.0;
            },
            onScaleUpdate: (details) {
              handlePan(details.focalPointDelta, constraints);
              double scaleMultiplicativeDelta =
                  details.scale / lastRelativeScale;
              handleZoom(scaleMultiplicativeDelta);
              lastRelativeScale = details.scale;
            },
            onTapUp: (TapUpDetails details) {
              Offset topLeft = Offset(
                  widget.controller.screenCenter.dx - .5,
                  widget.controller.screenCenter.dy - .5);
              Offset preZoom =
                  details.localPosition / constraints.biggest.shortestSide;
              Offset postZoom =
                  (preZoom - Offset(.5, .5)) / widget.controller.zoom +
                      Offset(.5, .5) +
                      topLeft;
              if (widget.onTap != null) {
                widget.onTap!(postZoom);
              }
            },
            child: ClipRect(
              child: SizedBox(
                width: constraints.biggest.shortestSide,
                height: constraints.biggest.shortestSide,
                child: CustomPaint(
                  size: Size.square(constraints.biggest.shortestSide),
                  painter: widget.painter,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  void handleZoom(double scaleMultiplicativeDelta) {
    if (widget.controller.realZoom >= 1 / scaleMultiplicativeDelta) {
      widget.controller.modifyAnimation(
          zoom: widget.controller.realZoom * scaleMultiplicativeDelta);
    }
  }

  void handlePan(Offset delta, BoxConstraints constraints) {
    setState(() {
      Offset newScreenCenter = widget.controller.realScreenCenter -
          (delta / constraints.biggest.shortestSide) /
              widget.controller.realZoom;
      widget.controller.modifyAnimation(
        screenCenter: Offset(
          newScreenCenter.dx.clamp(0, 1),
          newScreenCenter.dy.clamp(0, 1),
        ),
      );
    });
  }
}

Offset calculateScreenPosition(
    Offset basePosition, Offset screenCenter, double zoom, Size screenSize) {
  Offset topLeft = Offset(screenCenter.dx - .5, screenCenter.dy - .5);
  Offset noZoomPos = (basePosition - topLeft);
  Offset afterZoomPos =
      (((noZoomPos - Offset(.5, .5)) * zoom) + Offset(.5, .5));
  return afterZoomPos.scale(screenSize.width, screenSize.height);
}

Color getColorForDynastyID(int dynastyID) {
  return Color(0xFF000000 | (dynastyID * 0x543642));
}

Offset polarToCartesian(double distanceFromCenter, double theta) {
  return Offset(cos(theta), sin(theta)) * distanceFromCenter;
}

const double gravitationalConstant = 6.67430e-11; // m*m*m/kg*s*s

// arguments are defined in https://software.hixie.ch/fun/isd/test-2024/servers/src/systems-server/README.md, the section on orbit features.
// [t] is in milliseconds.
Offset calculateOrbit(
    Uint64 t, double a, double e, bool clockwise, double M, double omega) {
  const double G = gravitationalConstant;
  double T = 2 *
      pi *
      sqrt((a * a * a) / (G * M)) *
      1000; // this multiplies by 1000 to convert seconds to milliseconds
  double tau = (t.asDouble % T) / T;
  double q = -0.99 * pi / 4 * (e - 3 * sqrt(e));
  double theta = 2 * pi * (tan(tau * 2 * q - q) - tan(-q)) / (tan(q) - tan(-q));
  if (!clockwise) {
    theta = -theta;
  }
  if (e == 0) {
    theta = 2 * pi * tau;
  }
  double L = a * (1 - e * e);
  double r = L / (1 + e * cos(theta));
  return polarToCartesian(r, theta + omega);
}

final List<Paint> starCategories = [
  // multiply strokeWidth by size of unit square
  Paint()
    ..color = Color(0x7FFFFFFF)
    ..strokeWidth = 0.0040,
  Paint()
    ..color = Color(0xCFCCBBAA)
    ..strokeWidth = 0.0025,
  Paint()
    ..color = Color(0xDFFF0000)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0xCFFF9900)
    ..strokeWidth = 0.0007,
  Paint()
    ..color = Color(0xBFFFFFFF)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0xAFFFFFFF)
    ..strokeWidth = 0.0012,
  Paint()
    ..color = Color(0x2F0099FF)
    ..strokeWidth = 0.0010,
  Paint()
    ..color = Color(0x2F0000FF)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0x4FFF9900)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0x2FFFFFFF)
    ..strokeWidth = 0.0005,
  Paint()
    ..color = Color(0x5FFF2200)
    ..strokeWidth = 0.0200,
];
