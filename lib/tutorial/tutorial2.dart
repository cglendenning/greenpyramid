import 'package:flutter/material.dart';
import 'package:life_ops/tutorial/tutorial3.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/navbar.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class Tutorial2 extends StatefulWidget {
  const Tutorial2({Key? key}) : super(key: key);

  @override
  State<Tutorial2> createState() => _Tutorial2();
}

class _Tutorial2 extends State<Tutorial2> {
  var _static1LGColor;
  var _static2LGColor;
  var _static3LGColor;
  var _static4LGColor;
  var _static5LGColor;
  var _static6LGColor;

  @override
  void initState() {
    _static1LGColor = Color(int.parse("#FFE177".substring(1, 7), radix: 16) + 0xFF000000);
    _static2LGColor = Color(int.parse("#F96E6E".substring(1, 7), radix: 16) + 0xFF000000);
    _static3LGColor = Color(int.parse("#FFE177".substring(1, 7), radix: 16) + 0xFF000000);
    _static4LGColor = Color(int.parse("#F96E6E".substring(1, 7), radix: 16) + 0xFF000000);
    _static5LGColor = Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);
    _static6LGColor = Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000);

    super.initState();
  }

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'tutorial_tutorial2');
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

    final static2LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static2LGColor,
        _static2LGColor,
      ],
    );

    final static3LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static3LGColor,
        _static3LGColor,
      ],
    );

    final static4LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static4LGColor,
        _static4LGColor,
      ],
    );

    final static5LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static5LGColor,
        _static5LGColor,
      ],
    );

    final static6LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _static6LGColor,
        _static6LGColor,
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
                          const Text('Tutorial (2 of 5)'),
                          const SizedBox(height: 10),
                          Container(
                              padding: const EdgeInsets.all(10.0),
                              child: const Text(
                                  "Each block is a category of your life that matters "
                                      "to you... "
                              )),
                      Stack(children: <Widget>[
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat1(static1LG)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat2(static2LG)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat3(static3LG)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat4(static4LG)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat5(static5LG)),
                        CustomPaint(
                            size: Size(pyramidWidth, pyramidHeight),
                            painter: DrawCat6(static6LG)),
                      ]).animate().shimmer(duration: 1000.ms),
                      const SizedBox(height: 30),
                          Container(
                              padding: const EdgeInsets.all(10.0),
                              child: const Text(
                                  "...You can put the most important categories of your "
                                      "life on the bottom, because they hold up the rest of "
                                      "your life."
                              )),
                          Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Column(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: <Widget>[
                                      IconButton(
                                        icon: svgForward,
                                        onPressed: () {
                                          setState(() {
                                            navigateToTutorial3();
                                          });
                                        },
                                      ),
                                    ])
                              ]),

                    ]))
            )));
  }

  void navigateToTutorial3() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Tutorial3()),
    );
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat1()
// -----------------------------------------------------------------------------
class DrawCat1 extends CustomPainter {
  final LinearGradient lg;

  DrawCat1(this.lg);

  final cat1Path = Path();

  String hexOutlineColor = "#EBEBEB";

  @override
  void paint(Canvas canvas, Size size) {
    final cat1Paint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Midpoint formula
    // (x₁ + x₂)/2, (y₁ + y₂)/2

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    cat1Path.moveTo(cat1X, size.height * 2 / 3);
    cat1Path.lineTo(0, size.height);
    cat1Path.lineTo((size.width / 3), size.height);
    cat1Path.lineTo((size.width / 3), size.height * 2 / 3);
    cat1Path.close();

    Paint cat1Fill = Paint()..style = PaintingStyle.fill;
    cat1Fill.shader = lg.createShader(cat1Path.getBounds());
    canvas.drawPath(cat1Path, cat1Fill);
    canvas.drawPath(cat1Path, cat1Paint);

    const textStyle = TextStyle(
      color: Colors.black,
      fontSize: 14,
    );
    var textSpan = const TextSpan(
      text: ' Physical Health', // Note the space to pad the left.
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 70,
    );
    final xCenter = (size.width / 5) / 2;
    final yCenter = (size.height * 4 / 5);
    final offset = Offset(xCenter, yCenter);
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is DrawCat1 && oldDelegate.lg == lg) {
      return false;
    }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat2()
// -----------------------------------------------------------------------------
class DrawCat2 extends CustomPainter {
  final LinearGradient lg;

  DrawCat2(this.lg);

  final cat2Path = Path();

  String hexOutlineColor = "#EBEBEB";

  @override
  void paint(Canvas canvas, Size size) {
    final cat2Paint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Midpoint formula
    // (x₁ + x₂)/2, (y₁ + y₂)/2

    var cat2X = (size.width * 1 / 3);
    cat2Path.moveTo(cat2X, size.height * 2 / 3);
    cat2Path.lineTo(cat2X, size.height);
    cat2Path.lineTo(size.width * 2 / 3, size.height);
    cat2Path.lineTo(size.width * 2 / 3, size.height * 2 / 3);
    cat2Path.close();

    Paint cat2Fill = Paint()..style = PaintingStyle.fill;
    cat2Fill.shader = lg.createShader(cat2Path.getBounds());
    canvas.drawPath(cat2Path, cat2Fill);
    canvas.drawPath(cat2Path, cat2Paint);

    var textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 14,
    );
    var textSpan = TextSpan(
      text: 'Mindset',
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 70,
    );
    final xCenter = size.width / 2.5;
    final yCenter = (size.height * 4 / 5);
    final offset = Offset(xCenter, yCenter);
    textPainter.paint(canvas, offset);
  }

  @override
  bool hitTest(Offset position) {
    if (cat2Path.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // DrawCat1 is deliberate!!
    if (oldDelegate is DrawCat1 && oldDelegate.lg == lg) {
      return false;
    }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat3()
// -----------------------------------------------------------------------------
class DrawCat3 extends CustomPainter {
  final LinearGradient lg;

  DrawCat3(this.lg);

  final cat3Path = Path();

  String hexOutlineColor = "#EBEBEB";

  @override
  void paint(Canvas canvas, Size size) {
    final cat3Paint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    var cat3X = (size.width * 2 / 3);
    cat3Path.moveTo(cat3X, size.height * 2 / 3);
    cat3Path.lineTo(cat3X, size.height);
    cat3Path.lineTo(size.width, size.height);
    cat3Path.lineTo(size.width - cat1X, size.height * 2 / 3);
    cat3Path.close();

    Paint cat3Fill = Paint()..style = PaintingStyle.fill;
    cat3Fill.shader = lg.createShader(cat3Path.getBounds());
    canvas.drawPath(cat3Path, cat3Fill);
    canvas.drawPath(cat3Path, cat3Paint);

    var textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 14,
    );
    var textSpan = TextSpan(
      text: 'Finances',
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 70,
    );
    final xCenter = size.width / 1.45;
    final yCenter = (size.height * 4 / 5);
    final offset = Offset(xCenter, yCenter);
    textPainter.paint(canvas, offset);
  }

  @override
  bool hitTest(Offset position) {
    if (cat3Path.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // DrawCat1 is deliberate!!
    if (oldDelegate is DrawCat1 && oldDelegate.lg == lg) {
      return false;
    }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat4()
// -----------------------------------------------------------------------------
class DrawCat4 extends CustomPainter {
  final LinearGradient lg;

  DrawCat4(this.lg);

  final cat4Path = Path();

  String hexOutlineColor = "#EBEBEB";

  @override
  void paint(Canvas canvas, Size size) {
    final cat4Paint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    var cat4X = ((cat1X + halfWidth) / 2);

    cat4Path.moveTo(cat4X, size.height * 1 / 3);
    cat4Path.lineTo(cat1X, size.height * 2 / 3);
    cat4Path.lineTo(halfWidth, size.height * 2 / 3);
    cat4Path.lineTo(halfWidth, size.height * 1 / 3);
    cat4Path.close();

    Paint cat4Fill = Paint()..style = PaintingStyle.fill;
    cat4Fill.shader = lg.createShader(cat4Path.getBounds());
    canvas.drawPath(cat4Path, cat4Fill);
    canvas.drawPath(cat4Path, cat4Paint);

    var textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 14,
    );
    var textSpan = TextSpan(
      text: 'Spouse',
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 70,
    );
    final xCenter = size.width / 3.2;
    final yCenter = (size.height * 1 / 2.1);
    final offset = Offset(xCenter, yCenter);
    textPainter.paint(canvas, offset);
  }

  @override
  bool hitTest(Offset position) {
    if (cat4Path.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is DrawCat1 && oldDelegate.lg == lg) {
      // DrawCat1 is deliberate!!
      return false;
    }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat5()
// -----------------------------------------------------------------------------
class DrawCat5 extends CustomPainter {
  final LinearGradient lg;

  DrawCat5(this.lg);

  final cat5Path = Path();

  String hexOutlineColor = "#EBEBEB";

  @override
  void paint(Canvas canvas, Size size) {
    final cat5Paint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    var cat5X = ((cat1X + halfWidth) / 2);

    cat5Path.moveTo(halfWidth, size.height * 1 / 3);
    cat5Path.lineTo(halfWidth, size.height * 2 / 3);
    cat5Path.lineTo(size.width - cat1X, size.height * 2 / 3);
    cat5Path.lineTo(size.width - cat5X, size.height * 1 / 3);
    cat5Path.close();

    Paint cat5Fill = Paint()..style = PaintingStyle.fill;
    cat5Fill.shader = lg.createShader(cat5Path.getBounds());
    canvas.drawPath(cat5Path, cat5Fill);
    canvas.drawPath(cat5Path, cat5Paint);

    var textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 14,
    );
    var textSpan = TextSpan(
      text: 'Parent',
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 70,
    );
    final xCenter = size.width / 1.85;
    final yCenter = (size.height * 1 / 2.1);
    final offset = Offset(xCenter, yCenter);
    textPainter.paint(canvas, offset);
  }

  @override
  bool hitTest(Offset position) {
    if (cat5Path.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is DrawCat1 && oldDelegate.lg == lg) {
      // DrawCat1 is deliberate!!
      return false;
    }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat6()
// -----------------------------------------------------------------------------
class DrawCat6 extends CustomPainter {
  final LinearGradient lg;

  DrawCat6(this.lg);

  final cat6Path = Path();

  String hexOutlineColor = "#EBEBEB";

  @override
  void paint(Canvas canvas, Size size) {
    final cat6Paint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    var cat6X = ((cat1X + halfWidth) / 2);

    cat6Path.moveTo(halfWidth, 0);
    cat6Path.lineTo(cat6X, size.height * 1 / 3);
    cat6Path.lineTo(size.width - cat6X, size.height * 1 / 3);
    cat6Path.close();

    Paint cat6Fill = Paint()..style = PaintingStyle.fill;
    cat6Fill.shader = lg.createShader(cat6Path.getBounds());
    canvas.drawPath(cat6Path, cat6Fill);
    canvas.drawPath(cat6Path, cat6Paint);

    var textStyle = const TextStyle(
      color: Colors.black,
      fontSize: 14,
    );
    var textSpan = TextSpan(
      text: 'Self-Care',
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 70,
    );
    final xCenter = size.width / 2.4;
    final yCenter = (size.height / 5);
    final offset = Offset(xCenter, yCenter);
    textPainter.paint(canvas, offset);
  }

  @override
  bool hitTest(Offset position) {
    if (cat6Path.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    if (oldDelegate is DrawCat1 && oldDelegate.lg == lg) {
      // DrawCat1 is deliberate!!
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
