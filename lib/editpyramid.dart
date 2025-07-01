import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/dbtools.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class EditPyramid extends StatefulWidget {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;

  const EditPyramid(this.cat1Future, this.cat2Future, this.cat3Future,
      this.cat4Future, this.cat5Future, this.cat6Future);

  @override
  State<EditPyramid> createState() => _EditPyramid(
      cat1Future, cat2Future, cat3Future, cat4Future, cat5Future, cat6Future);
}

class _EditPyramid extends State<EditPyramid> {
  final TextEditingController categoryText = TextEditingController();

  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;

  _EditPyramid(this.cat1Future, this.cat2Future, this.cat3Future,
      this.cat4Future, this.cat5Future, this.cat6Future);

  var _ts;

  @override
  void initState() {
    super.initState();

    _ts = const TextStyle(
      color: Colors.blue,
      decoration: TextDecoration.underline,
      fontSize: 14,
    );
  }

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;
  bool _cat1ColorToggled = false;
  bool _cat2ColorToggled = false;
  bool _cat3ColorToggled = false;
  bool _cat4ColorToggled = false;
  bool _cat5ColorToggled = false;
  bool _cat6ColorToggled = false;

  DrawCat1 _drawCat1 = DrawCat1(
      Colors.transparent,
      'default',
      const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        fontSize: 14,
      ));

  DrawCat2 _drawCat2 = DrawCat2(
      Colors.transparent,
      'default',
      const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        fontSize: 14,
      ));

  DrawCat3 _drawCat3 = DrawCat3(
      Colors.transparent,
      'default',
      const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        fontSize: 14,
      ));

  DrawCat4 _drawCat4 = DrawCat4(
      Colors.transparent,
      'default',
      const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        fontSize: 14,
      ));

  DrawCat5 _drawCat5 = DrawCat5(
      Colors.transparent,
      'default',
      const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        fontSize: 14,
      ));

  DrawCat6 _drawCat6 = DrawCat6(
      Colors.transparent,
      'default',
      const TextStyle(
        color: Colors.blue,
        decoration: TextDecoration.underline,
        fontSize: 14,
      ));

  bool _cat1Edited = false;
  bool _cat2Edited = false;
  bool _cat3Edited = false;
  bool _cat4Edited = false;
  bool _cat5Edited = false;
  bool _cat6Edited = false;

  Color cat1Color = Colors.transparent;
  Color cat2Color = Colors.transparent;
  Color cat3Color = Colors.transparent;
  Color cat4Color = Colors.transparent;
  Color cat5Color = Colors.transparent;
  Color cat6Color = Colors.transparent;

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'editpyramid');
    cat1Color = _cat1ColorToggled ? Colors.grey : Colors.transparent;
    cat2Color = _cat2ColorToggled ? Colors.grey : Colors.transparent;
    cat3Color = _cat3ColorToggled ? Colors.grey : Colors.transparent;
    cat4Color = _cat4ColorToggled ? Colors.grey : Colors.transparent;
    cat5Color = _cat5ColorToggled ? Colors.grey : Colors.transparent;
    cat6Color = _cat6ColorToggled ? Colors.grey : Colors.transparent;

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;
    SizedBox smallSpacer = SizedBox(height: pyramidHeight * .1);
    SizedBox bigSpacer = SizedBox(height: pyramidHeight * .2);

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      smallSpacer,
      Text(
        'Green Pyramid (Edit)',
        style: mainTextStyle,
      ),
      bigSpacer,
            Stack(children: <Widget>[
              FutureBuilder(
                  future: cat1Future,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    Widget display;
                    if (!snapshot.hasData) {
                      display = CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat1(cat1Color, 'Cat1...', _ts));
                    } else {
                      if (!_cat1Edited) {
                        _drawCat1 = DrawCat1(cat1Color, snapshot.data.cat, _ts);
                      }
                      display = GestureDetector(
                          onTapDown: (details) {
                            setState(() {
                              _cat1ColorToggled = !_cat1ColorToggled;
                            });
                          },
                          onTapUp: (details) {
                            showEditDialog(context, 1, snapshot.data.cat);
                            setState(() {
                              _cat1ColorToggled = !_cat1ColorToggled;
                            });
                          },
                          child: CustomPaint(
                              size: Size(pyramidWidth, pyramidHeight),
                              painter: _drawCat1));
                      // DrawCat1(cat1Color, snapshot.data.cat, _ts)));
                    }
                    return display;
                  }),
              FutureBuilder(
                  future: cat2Future,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    Widget display;
                    if (!snapshot.hasData) {
                      display = CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat2(cat2Color, 'Cat2...', _ts));
                    } else {
                      if (!_cat2Edited) {
                        _drawCat2 = DrawCat2(cat2Color, snapshot.data.cat, _ts);
                      }
                      display = GestureDetector(
                          onTapDown: (details) {
                            setState(() {
                              _cat2ColorToggled = !_cat2ColorToggled;
                            });
                          },
                          onTapUp: (details) {
                            showEditDialog(context, 2, snapshot.data.cat);
                            setState(() {
                              _cat2ColorToggled = !_cat2ColorToggled;
                            });
                          },
                          child: CustomPaint(
                              size: Size(pyramidWidth, pyramidHeight),
                              painter: _drawCat2));
                      // DrawCat2(cat2Color, snapshot.data.cat, _ts)));
                    }
                    return display;
                  }),
              FutureBuilder(
                  future: cat3Future,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    Widget display;
                    if (!snapshot.hasData) {
                      display = CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat3(cat3Color, 'Cat3...', _ts));
                    } else {
                      if (!_cat3Edited) {
                        _drawCat3 = DrawCat3(cat3Color, snapshot.data.cat, _ts);
                      }
                      display = GestureDetector(
                          onTapDown: (details) {
                            setState(() {
                              _cat3ColorToggled = !_cat3ColorToggled;
                            });
                          },
                          onTapUp: (details) {
                            showEditDialog(context, 3, snapshot.data.cat);
                            setState(() {
                              _cat3ColorToggled = !_cat3ColorToggled;
                            });
                          },
                          child: CustomPaint(
                              size: Size(pyramidWidth, pyramidHeight),
                              painter: _drawCat3));
                      // DrawCat3(cat3Color, snapshot.data.cat, _ts)));
                    }
                    return display;
                  }),
              FutureBuilder(
                  future: cat4Future,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    Widget display;
                    if (!snapshot.hasData) {
                      display = CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat4(cat4Color, 'Cat4...', _ts));
                    } else {
                      if (!_cat4Edited) {
                        _drawCat4 = DrawCat4(cat4Color, snapshot.data.cat, _ts);
                      }
                      display = GestureDetector(
                          onTapDown: (details) {
                            setState(() {
                              _cat4ColorToggled = !_cat4ColorToggled;
                            });
                          },
                          onTapUp: (details) {
                            showEditDialog(context, 4, snapshot.data.cat);
                            setState(() {
                              _cat4ColorToggled = !_cat4ColorToggled;
                            });
                          },
                          child: CustomPaint(
                              size: Size(pyramidWidth, pyramidHeight),
                              painter: _drawCat4));
                      // DrawCat4(cat4Color, snapshot.data.cat, _ts)));
                    }
                    return display;
                  }),
              FutureBuilder(
                  future: cat5Future,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    Widget display;
                    if (!snapshot.hasData) {
                      display = CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat5(cat5Color, 'Cat5...', _ts));
                    } else {
                      if (!_cat5Edited) {
                        _drawCat5 = DrawCat5(cat5Color, snapshot.data.cat, _ts);
                      }
                      display = GestureDetector(
                          onTapDown: (details) {
                            setState(() {
                              _cat5ColorToggled = !_cat5ColorToggled;
                            });
                          },
                          onTapUp: (details) {
                            showEditDialog(context, 5, snapshot.data.cat);
                            setState(() {
                              _cat5ColorToggled = !_cat5ColorToggled;
                            });
                          },
                          child: CustomPaint(
                              size: Size(pyramidWidth, pyramidHeight),
                              painter: _drawCat5));
                      // DrawCat5(cat5Color, snapshot.data.cat, _ts)));
                    }
                    return display;
                  }),
              FutureBuilder(
                  future: cat6Future,
                  builder: (BuildContext context, AsyncSnapshot snapshot) {
                    Widget display;
                    if (!snapshot.hasData) {
                      display = CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat6(cat6Color, 'Cat6...', _ts));
                    } else {
                      if (!_cat6Edited) {
                        _drawCat6 = DrawCat6(cat6Color, snapshot.data.cat, _ts);
                      }
                      display = GestureDetector(
                          onTapDown: (details) {
                            setState(() {
                              _cat6ColorToggled = !_cat6ColorToggled;
                            });
                          },
                          onTapUp: (details) {
                            showEditDialog(context, 6, snapshot.data.cat);
                            setState(() {
                              _cat6ColorToggled = !_cat6ColorToggled;
                            });
                          },
                          child: CustomPaint(
                              size: Size(pyramidWidth, pyramidHeight),
                              painter: _drawCat6));
                      // DrawCat6(cat6Color, snapshot.data.cat, _ts)));
                    }
                    return display;
                  }),
            ]),
            const Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 2,
              child: Text(
                '*NOTE: If a category name is changed, all tasks and task log entries for the previous category name will be deleted.',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ]);
  }

  // https://stackoverflow.com/questions/71286766/statefulwidget-does-not-refresh-after-alertdialog-is-closed
  Future<void> showEditDialog(
      BuildContext context, int categoryid, String category) async {
    setState(() {
      categoryText.clear();
    });

    Widget cancelButton = TextButton(
      child: const Text("Cancel"),
      onPressed: () => {Navigator.pop(context)},
    );
    Widget continueButton = TextButton(
      child: const Text("Update Category"),
      onPressed: () async {
        setState(() {});
        if (category != categoryText.text) {
          dbHelper
              .rawDelete("delete from tasklog where category = '$category'");
          dbHelper.rawDelete("delete from task where category = '$category'");
        }
        dbHelper.rawInsert("insert into category(categoryid, cat) values"
            "($categoryid, '${categoryText.text}') "
            " on conflict (categoryid) do update set cat = '${categoryText.text}'");
        setState(() {});
        switch (categoryid) {
          case 1:
            _cat1Edited = true;
            _drawCat1 = DrawCat1(cat1Color, categoryText.text, _ts);
          case 2:
            _cat2Edited = true;
            _drawCat2 = DrawCat2(cat2Color, categoryText.text, _ts);
          case 3:
            _cat3Edited = true;
            _drawCat3 = DrawCat3(cat3Color, categoryText.text, _ts);
          case 4:
            _cat4Edited = true;
            _drawCat4 = DrawCat4(cat4Color, categoryText.text, _ts);
          case 5:
            _cat5Edited = true;
            _drawCat5 = DrawCat5(cat5Color, categoryText.text, _ts);
          case 6:
            _cat6Edited = true;
            _drawCat6 = DrawCat6(cat6Color, categoryText.text, _ts);
          default:
        }
        Navigator.pop(context);
      },
    );
    Widget categoryField = TextField(
      controller: categoryText,
      textAlign: TextAlign.left,
      maxLength: 20,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter Your Category Here.',
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("Update Category..."),
      content: const Text("Enter the updated category name below."),
      actions: [
        categoryField,
        cancelButton,
        continueButton,
      ],
    );
    // show the dialog
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  Future<List<Cat>> getCategories() async {
    final List<Map<String, dynamic>> maps = await dbHelper.queryCategories();

    // Convert the List<Map<String, dynamic> into a List<Task>.
    return List.generate(maps.length, (i) {
      return Cat(categoryid: maps[i]['categoryid'], cat: maps[i]['cat']);
    });
  }

  Future<Cat> getCategory(int categoryid) async {
    final List<Map<String, dynamic>> maps =
        await dbHelper.queryCategory(categoryid);

    return Cat(categoryid: maps[0]['categoryid'], cat: maps[0]['cat']);
  }
}

class Cat {
  int categoryid = 0;
  String cat = '';

  Cat({required this.categoryid, required this.cat});

  Cat.fromMap(dynamic obj) {
    categoryid = obj["categoryid"];
    cat = obj["cat"];
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat1()
// -----------------------------------------------------------------------------
class DrawCat1 extends CustomPainter {
  final Color color;
  final String cat1;
  final TextStyle ts;

  DrawCat1(this.color, this.cat1, this.ts);

  final ephPath = Path();

  String hexOutlineColor = "#EBEBEB";

  @override
  void paint(Canvas canvas, Size size) {
    final ephPaint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
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

    Paint ephFill = Paint()..style = PaintingStyle.fill;
    ephFill.color = color;
    canvas.drawPath(ephPath, ephFill);

    var textSpan = TextSpan(
      text: ' $cat1', // Note the space to pad the left.
      style: ts,
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
  bool hitTest(Offset position) {
    if (ephPath.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // if (oldDelegate is DrawCat1 && oldDelegate.color == color) {
    //      return false;
    // }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat2()
// -----------------------------------------------------------------------------
class DrawCat2 extends CustomPainter {
  final Color color;
  final String cat2;
  final TextStyle ts;

  DrawCat2(this.color, this.cat2, this.ts);

  final emhPath = Path();

  String hexOutlineColor = "#EBEBEB";


  @override
  void paint(Canvas canvas, Size size) {
    final emhPaint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
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

    Paint emhFill = Paint()..style = PaintingStyle.fill;
    emhFill.color = color;
    canvas.drawPath(emhPath, emhFill);

    var textSpan = TextSpan(
      text: cat2,
      style: ts,
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
    if (emhPath.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // if (oldDelegate is DrawCat2 && oldDelegate.color == color) {
    //   return false;
    // }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat3()
// -----------------------------------------------------------------------------
class DrawCat3 extends CustomPainter {
  final Color color;
  final String cat3;
  final TextStyle ts;

  DrawCat3(this.color, this.cat3, this.ts);

  final efhPath = Path();

  String hexOutlineColor = "#EBEBEB";


  @override
  void paint(Canvas canvas, Size size) {
    final efhPaint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var ephX = ((bottomLeftX + halfWidth) / 3);
    var efhX = (size.width * 2 / 3);
    efhPath.moveTo(efhX, size.height * 2 / 3);
    efhPath.lineTo(efhX, size.height);
    efhPath.lineTo(size.width, size.height);
    efhPath.lineTo(size.width - ephX, size.height * 2 / 3);
    efhPath.close();

    canvas.drawPath(efhPath, efhPaint);

    Paint efhFill = Paint()..style = PaintingStyle.fill;
    efhFill.color = color;
    canvas.drawPath(efhPath, efhFill);

    var textSpan = TextSpan(
      text: cat3,
      style: ts,
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
    if (efhPath.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // if (oldDelegate is DrawCat3 && oldDelegate.color == color) {
    // return false;
    // }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat4()
// -----------------------------------------------------------------------------
class DrawCat4 extends CustomPainter {
  final Color color;
  final String cat4;
  final TextStyle ts;

  DrawCat4(this.color, this.cat4, this.ts);

  final efPath = Path();

  String hexOutlineColor = "#EBEBEB";


  @override
  void paint(Canvas canvas, Size size) {
    final efPaint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var ephX = ((bottomLeftX + halfWidth) / 3);
    var efX = ((ephX + halfWidth) / 2);

    efPath.moveTo(efX, size.height * 1 / 3);
    efPath.lineTo(ephX, size.height * 2 / 3);
    efPath.lineTo(halfWidth, size.height * 2 / 3);
    efPath.lineTo(halfWidth, size.height * 1 / 3);
    efPath.close();

    canvas.drawPath(efPath, efPaint);

    Paint efFill = Paint()..style = PaintingStyle.fill;
    efFill.color = color;
    canvas.drawPath(efPath, efFill);

    var textSpan = TextSpan(
      text: cat4,
      style: ts,
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
    if (efPath.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // if (oldDelegate is DrawCat4 && oldDelegate.color == color) {
    //  return false;
    // }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat5()
// -----------------------------------------------------------------------------
class DrawCat5 extends CustomPainter {
  final Color color;
  final String cat5;
  final TextStyle ts;

  DrawCat5(this.color, this.cat5, this.ts);

  final ehPath = Path();

  String hexOutlineColor = "#EBEBEB";


  @override
  void paint(Canvas canvas, Size size) {
    final ehPaint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var ephX = ((bottomLeftX + halfWidth) / 3);
    var efX = ((ephX + halfWidth) / 2);

    ehPath.moveTo(halfWidth, size.height * 1 / 3);
    ehPath.lineTo(halfWidth, size.height * 2 / 3);
    ehPath.lineTo(size.width - ephX, size.height * 2 / 3);
    ehPath.lineTo(size.width - efX, size.height * 1 / 3);
    ehPath.close();

    canvas.drawPath(ehPath, ehPaint);

    Paint ehFill = Paint()..style = PaintingStyle.fill;
    ehFill.color = color;
    canvas.drawPath(ehPath, ehFill);

    var textSpan = TextSpan(
      text: cat5,
      style: ts,
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
    if (ehPath.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // if (oldDelegate is DrawCat5 && oldDelegate.color == color) {
    //  return false;
    // }
    return true;
  }
}

// -----------------------------------------------------------------------------
//                                                                    DrawCat6()
// -----------------------------------------------------------------------------
class DrawCat6 extends CustomPainter {
  final Color color;
  final String cat6;
  final TextStyle ts;

  DrawCat6(this.color, this.cat6, this.ts);

  final flowPath = Path();

  String hexOutlineColor = "#EBEBEB";


  @override
  void paint(Canvas canvas, Size size) {
    final flowPaint = Paint()
      ..color = Color(
          int.parse(hexOutlineColor.substring(1, 7), radix: 16) + 0xFF000000)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var ephX = ((bottomLeftX + halfWidth) / 3);
    var efX = ((ephX + halfWidth) / 2);

    flowPath.moveTo(halfWidth, 0);
    flowPath.lineTo(efX, size.height * 1 / 3);
    flowPath.lineTo(size.width - efX, size.height * 1 / 3);
    flowPath.close();

    canvas.drawPath(flowPath, flowPaint);

    Paint flowFill = Paint()..style = PaintingStyle.fill;
    flowFill.color = color;
    canvas.drawPath(flowPath, flowFill);

    var textSpan = TextSpan(
      text: cat6,
      style: ts,
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
    if (flowPath.contains(position)) {
      return true;
    }
    return false;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    // if (oldDelegate is DrawCat6 && oldDelegate.color == color) {
    //  return false;
    // }
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
