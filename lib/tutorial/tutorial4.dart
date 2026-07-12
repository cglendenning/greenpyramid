import 'package:flutter/material.dart';
import 'package:life_ops/tutorial/tutorial5.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:life_ops/navbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/pyramid.dart';

class Tutorial4 extends StatefulWidget {
  const Tutorial4({Key? key}) : super(key: key);

  @override
  State<Tutorial4> createState() => _Tutorial4();
}

class _Tutorial4 extends State<Tutorial4> {
  var _static1LGColor;

  @override
  void initState() {
    _static1LGColor =
        Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);

    super.initState();
  }

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'tutorial_tutorial4');
    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    final static1LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static1LGColor,
        _static1LGColor,
      ],
    );

    double pyramidWidth = MediaQuery.of(context).size.width - 20;
    double pyramidHeight = MediaQuery.of(context).size.width - 20;

    return Container(
        color: Colors.black,
        child: SafeArea(
            child: Scaffold(
                appBar: const NavBar(),
                body: Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                      const Text('Tutorial (4 of 5)'),
                      const SizedBox(height: 10),
                      Container(
                          padding: const EdgeInsets.all(10.0),
                          child: const Text(
                              "As you become more diligent at your daily tasks, "
                              "your pyramid will shift from red or yellow to green. ")),
                      const SizedBox(height: 10),
                      Stack(children: <Widget>[
                        // Send every DrawCatX the same green linear gradient...
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat1(static1LG, 'Physical Health', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat2(static1LG, 'Mindset', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat3(static1LG, 'Mindset', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat4(static1LG, 'Spouse', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat5(static1LG, 'Parent', 0)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat6(static1LG, 'Self-Care', 0)),
                      ]).animate().shimmer(duration: 1000.ms),
                      const SizedBox(height: 30),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: <Widget>[
                                  IconButton(
                                    icon: svgForward,
                                    onPressed: () {
                                      setState(() {
                                        navigateToTutorial5();
                                      });
                                    },
                                  ),
                                ])
                          ]),
                    ])))));
  }

  void navigateToTutorial5() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Tutorial5()),
    );
  }
}

class DrawMainText extends CustomPainter {
  DrawMainText();

  final ephPath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 20,
    );
    const textSpan = TextSpan(
      // NOTE: If you change this, you will also have to change
      // the 90 below in the offset variable.
      text: 'Your Values Pyramid',
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 1,
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 200,
    );
    final xCenter = (size.width);
    final yCenter = (size.height);
    final offset = Offset((xCenter / 2) - 90, yCenter);

    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is DrawMainText) {
      return false;
    }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                  DrawTriangle
// -----------------------------------------------------------------------------

class DrawTriangle extends CustomPainter {
  final Color color;

  DrawTriangle(this.color);

  final ephPath = Path();
  final emhPath = Path();
  final efhPath = Path();
  final efPath = Path();
  final ehPath = Path();
  final flowPath = Path();

  @override
  void paint(Canvas canvas, Size size) {
    // Set up a triangle Paint & Path
    final trianglePaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final trianglePath = Path();

    // Draw the Triangle
    trianglePath.moveTo(size.width * 1 / 2, 0);
    trianglePath.lineTo(0, size.height);
    trianglePath.lineTo(size.height, size.width);
    trianglePath.close();
    canvas.drawPath(trianglePath, trianglePaint);

    // Now let's Construct Each Block based on the measurements
    // that we have from the triangle and the square above.

    final ephPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Midpoint formula
    // (x₁ + x₂)/2, (y₁ + y₂)/2

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var ephX = ((bottomLeftX + halfWidth) / 3);
    ephPath.moveTo(ephX, size.height * 2 / 3);
    ephPath.lineTo(0, size.height);
    ephPath.lineTo((size.width / 3), size.height);
    ephPath.lineTo((size.width / 3), size.height * 2 / 3);
    ephPath.close();

    canvas.drawPath(ephPath, ephPaint);

    final emhPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Midpoint formula
    // (x₁ + x₂)/2, (y₁ + y₂)/2

    var emhX = (size.width * 1 / 3);
    emhPath.moveTo(emhX, size.height * 2 / 3);
    emhPath.lineTo(emhX, size.height);
    emhPath.lineTo(size.width * 2 / 3, size.height);
    emhPath.lineTo(size.width * 2 / 3, size.height * 2 / 3);
    emhPath.close();

    canvas.drawPath(emhPath, emhPaint);

    final efhPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Midpoint formula
    // (x₁ + x₂)/2, (y₁ + y₂)/2

    var efhX = (size.width * 2 / 3);
    efhPath.moveTo(efhX, size.height * 2 / 3);
    efhPath.lineTo(efhX, size.height);
    efhPath.lineTo(size.width, size.height);
    efhPath.lineTo(size.width - ephX, size.height * 2 / 3);
    efhPath.close();

    canvas.drawPath(efhPath, efhPaint);

    final efPaint = Paint()
      ..color = Colors.purple
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Midpoint formula
    // (x₁ + x₂)/2, (y₁ + y₂)/2

    var efX = ((ephX + halfWidth) / 2);
    efPath.moveTo(efX, size.height * 1 / 3);
    efPath.lineTo(ephX, size.height * 2 / 3);
    efPath.lineTo(halfWidth, size.height * 2 / 3);
    efPath.lineTo(halfWidth, size.height * 1 / 3);
    efPath.close();

    canvas.drawPath(efPath, efPaint);

    final ehPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Midpoint formula
    // (x₁ + x₂)/2, (y₁ + y₂)/2

    ehPath.moveTo(halfWidth, size.height * 1 / 3);
    ehPath.lineTo(halfWidth, size.height * 2 / 3);
    ehPath.lineTo(size.width - ephX, size.height * 2 / 3);
    ehPath.lineTo(size.width - efX, size.height * 1 / 3);
    ehPath.close();

    canvas.drawPath(ehPath, ehPaint);

    final flowPaint = Paint()
      ..color = Colors.teal
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Midpoint formula
    // (x₁ + x₂)/2, (y₁ + y₂)/2

    flowPath.moveTo(halfWidth, 0);
    flowPath.lineTo(efX, size.height * 1 / 3);
    flowPath.lineTo(size.width - efX, size.height * 1 / 3);
    flowPath.close();

    canvas.drawPath(flowPath, flowPaint);

    Paint paint1Fill = Paint()..style = PaintingStyle.fill;
    paint1Fill.color = color;
    canvas.drawPath(flowPath, paint1Fill);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is DrawTriangle && oldDelegate.color == color) {
      return false;
    }
    return true;
  }
}
