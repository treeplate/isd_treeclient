import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

class ZoomableCustomPaint extends StatefulWidget {
  const ZoomableCustomPaint({
    super.key,
    required this.painter,
    this.startingZoom = 1,
    this.startingScreenCenter = const Offset(.5, .5),
  });
  final CustomPainter Function(double zoom, Offset screenCenter) painter;
  final double startingZoom;
  final Offset startingScreenCenter;

  @override
  State<ZoomableCustomPaint> createState() => _ZoomableCustomPaintState();
}

class _ZoomableCustomPaintState extends State<ZoomableCustomPaint> {
  late double zoom = widget.startingZoom; // 1..infinity
  late Offset screenCenter = widget.startingScreenCenter; // (0, 0)..(1, 1)
  double lastRelativeScale = 1.0;

  @override
  void didUpdateWidget(covariant ZoomableCustomPaint oldWidget) {
    if (oldWidget.startingZoom != widget.startingZoom || oldWidget.startingScreenCenter != widget.startingScreenCenter) {
      zoom = widget.startingZoom;
      screenCenter = widget.startingScreenCenter;
    }
    super.didUpdateWidget(oldWidget);
  }

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
        child: GestureDetector(
          onScaleStart: (details) {
            lastRelativeScale = 1.0;
          },
          onScaleUpdate: (details) {
            handlePan(details.focalPointDelta, constraints);
            double scaleMultiplicativeDelta = details.scale / lastRelativeScale;
            handleZoom(scaleMultiplicativeDelta);
            lastRelativeScale = details.scale;
          },
          child: Center(
            child: ClipRect(
              child: SizedBox(
                width: constraints.biggest.shortestSide,
                height: constraints.biggest.shortestSide,
                child: CustomPaint(
                  size: Size.square(constraints.biggest.shortestSide),
                  painter: widget.painter(zoom, screenCenter),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  void handleZoom(double scaleMultiplicativeDelta) {
    if (zoom >= 1 / scaleMultiplicativeDelta) {
      zoom *= scaleMultiplicativeDelta;
    }
  }

  void handlePan(Offset delta, BoxConstraints constraints) {
    setState(() {
      screenCenter -= (delta / constraints.biggest.shortestSide) / zoom;
      screenCenter = Offset(
        screenCenter.dx.clamp(0, 1),
        screenCenter.dy.clamp(0, 1),
      );
    });
  }
}

Color getColorForDynastyID(int dynastyID) {
  return Color(0xFF000000 | (dynastyID * 0x543642));
}