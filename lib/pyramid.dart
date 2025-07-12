import 'package:flutter/material.dart';
import 'package:life_ops/tasklist.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/dbtools.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/coach.dart';
import 'package:life_ops/mindset_select.dart';
// import 'package:life_ops/main.dart';

enum Calendar { day, week, month, year }

class Pyramid extends StatefulWidget {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;
  final Future totalPctCompleteFuture;

  const Pyramid(
      this.cat1Future,
      this.cat2Future,
      this.cat3Future,
      this.cat4Future,
      this.cat5Future,
      this.cat6Future,
      this.totalPctCompleteFuture);

  @override
  State<Pyramid> createState() => _Pyramid(cat1Future, cat2Future, cat3Future,
      cat4Future, cat5Future, cat6Future, totalPctCompleteFuture);
}

class _Pyramid extends State<Pyramid> {
  Calendar calendarView = Calendar.week;

  int pctDays = 6;

  Future cat1Future;
  Future cat2Future;
  Future cat3Future;
  Future cat4Future;
  Future cat5Future;
  Future cat6Future;
  Future totalPctCompleteFuture;

  _Pyramid(this.cat1Future, this.cat2Future, this.cat3Future, this.cat4Future,
      this.cat5Future, this.cat6Future, this.totalPctCompleteFuture);

  var _dynamic1LGColor,
      _dynamic2LGColor,
      _dynamic3LGColor,
      _dynamic4LGColor,
      _dynamic5LGColor,
      _dynamic6LGColor;

  String? selectedMood;
  String? selectedCategory;

  @override
  void initState() {
    _dynamic1LGColor = Colors.blue;
    _dynamic2LGColor = Colors.blue;
    _dynamic3LGColor = Colors.blue;
    _dynamic4LGColor = Colors.blue;
    _dynamic5LGColor = Colors.blue;
    _dynamic6LGColor = Colors.blue;

    super.initState();
  }

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;

  bool _cat1LGToggled = false;
  bool _cat2LGToggled = false;
  bool _cat3LGToggled = false;
  bool _cat4LGToggled = false;
  bool _cat5LGToggled = false;
  bool _cat6LGToggled = false;

  String cat1String = '';
  String cat2String = '';
  String cat3String = '';
  String cat4String = '';
  String cat5String = '';
  String cat6String = '';

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'pyramid');
    final dynamic1LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _dynamic1LGColor,
        _dynamic1LGColor,
      ],
    );

    final grey1LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.grey[350]!,
      ],
    );

    final dynamic2LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _dynamic2LGColor,
        _dynamic2LGColor,
      ],
    );

    final grey2LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.grey[350]!,
      ],
    );

    final dynamic3LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _dynamic3LGColor,
        _dynamic3LGColor,
      ],
    );

    final grey3LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.grey[350]!,
      ],
    );

    final dynamic4LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _dynamic4LGColor,
        _dynamic4LGColor,
      ],
    );

    final grey4LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.grey[350]!,
      ],
    );

    final dynamic5LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _dynamic5LGColor,
        _dynamic5LGColor,
      ],
    );

    final grey5LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.grey[350]!,
      ],
    );

    final dynamic6LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _dynamic6LGColor,
        _dynamic6LGColor,
      ],
    );

    final grey6LG = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.grey[350]!,
      ],
    );


    final cat1LG = _cat1LGToggled ? grey1LG : dynamic1LG;
    final cat2LG = _cat2LGToggled ? grey2LG : dynamic2LG;
    final cat3LG = _cat3LGToggled ? grey3LG : dynamic3LG;
    final cat4LG = _cat4LGToggled ? grey4LG : dynamic4LG;
    final cat5LG = _cat5LGToggled ? grey5LG : dynamic5LG;
    final cat6LG = _cat6LGToggled ? grey6LG : dynamic6LG;

    final DateTime now = DateTime.now();
    final intl.DateFormat formatter = intl.DateFormat('yyyy-MM-dd');
    final String today = formatter.format(now);

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;
    SizedBox smallSpacer = SizedBox(height: pyramidHeight * .07);
    // SizedBox bigSpacer = SizedBox(height: pyramidHeight * .2);

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    var pctCompleteTextStyle = const TextStyle(
        fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    var timeScaleTextStyle = const TextStyle(fontSize: 10);

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        smallSpacer,
        Text(
          'Green Pyramid',
          style: mainTextStyle,
        ),
        smallSpacer,
        Container(
            margin: EdgeInsets.symmetric(horizontal: 0.05 * pyramidWidth),
            child: SegmentedButton<Calendar>(
              segments: <ButtonSegment<Calendar>>[
                ButtonSegment<Calendar>(
                    value: Calendar.day,
                    label: Text('Day', style: timeScaleTextStyle),
                    icon: const Icon(Icons.calendar_view_day)),
                ButtonSegment<Calendar>(
                    value: Calendar.week,
                    label: Text('Week', style: timeScaleTextStyle),
                    icon: const Icon(Icons.calendar_view_week)),
                ButtonSegment<Calendar>(
                    value: Calendar.month,
                    label: Text('Month', style: timeScaleTextStyle),
                    icon: const Icon(Icons.calendar_view_month)),
                ButtonSegment<Calendar>(
                    value: Calendar.year,
                    label: Text('Year', style: timeScaleTextStyle),
                    icon: const Icon(Icons.calendar_today)),
              ],
              selected: <Calendar>{calendarView},
              onSelectionChanged: (Set<Calendar> newSelection) {
                setState(() {
                  // By default there is only a single segment that can be
                  // selected at one time, so its value is always the first
                  // item in the selected set.
                  calendarView = newSelection.first;

                  // getCompletionPercentage is inclusive of today.
                  switch (calendarView) {
                    case Calendar.day:
                      pctDays = 0;
                    case Calendar.week:
                      pctDays = 6;
                    case Calendar.month:
                      pctDays = 29;
                    case Calendar.year:
                      pctDays = 364;
                  }
                  setFutures();
                });
              },
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity(horizontal: -3, vertical: -3),
              ),
            )),
        smallSpacer,
        Stack(children: <Widget>[
          FutureBuilder(
              future: cat1Future,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                Widget display;
                if (!snapshot.hasData) {
                  display = CustomPaint(
                      size: Size(pyramidWidth, pyramidHeight),
                      painter: DrawCat1(cat1LG, 'Cat1...', 0));
                } else {
                  var dynColor = setColor(snapshot.data.pctComplete);
                  _dynamic1LGColor = dynColor;
                  dynamic1LG.colors[0] = _dynamic1LGColor;
                  dynamic1LG.colors[1] = _dynamic1LGColor;

                  // to pass to Chat()...
                  cat1String = snapshot.data.cat;

                  display = GestureDetector(
                      onTapDown: (details) {
                        setState(() {
                          _cat1LGToggled = !_cat1LGToggled;
                        });
                      },
                      onTapUp: (details) {
                        setState(() {
                          _cat1LGToggled = !_cat1LGToggled;
                          navigateToTaskList(context, snapshot.data.cat, today);
                        });
                      },
                      child: CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat1(cat1LG, snapshot.data.cat,
                              snapshot.data.pctComplete)));
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
                      painter: DrawCat2(cat2LG, 'Cat2...', 0));
                } else {
                  var dynColor = setColor(snapshot.data.pctComplete);
                  _dynamic2LGColor = dynColor;
                  dynamic2LG.colors[0] = _dynamic2LGColor;
                  dynamic2LG.colors[1] = _dynamic2LGColor;

                  // to pass to Chat()...
                  cat2String = snapshot.data.cat;

                  display = GestureDetector(
                      onTapDown: (details) {
                        setState(() {
                          _cat2LGToggled = !_cat2LGToggled;
                        });
                      },
                      onTapUp: (details) {
                        setState(() {
                          _cat2LGToggled = !_cat2LGToggled;
                          navigateToTaskList(context, snapshot.data.cat, today);
                        });
                      },
                      child: CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat2(cat2LG, snapshot.data.cat,
                              snapshot.data.pctComplete)));
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
                      painter: DrawCat3(cat3LG, 'Cat3...', 0));
                } else {
                  var dynColor = setColor(snapshot.data.pctComplete);
                  _dynamic3LGColor = dynColor;
                  dynamic3LG.colors[0] = _dynamic3LGColor;
                  dynamic3LG.colors[1] = _dynamic3LGColor;

                  // to pass to Chat()...
                  cat3String = snapshot.data.cat;

                  display = GestureDetector(
                      onTapDown: (details) {
                        setState(() {
                          _cat3LGToggled = !_cat3LGToggled;
                        });
                      },
                      onTapUp: (details) {
                        setState(() {
                          _cat3LGToggled = !_cat3LGToggled;
                          navigateToTaskList(context, snapshot.data.cat, today);
                        });
                      },
                      child: CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat3(cat3LG, snapshot.data.cat,
                              snapshot.data.pctComplete)));
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
                      painter: DrawCat4(cat4LG, 'Cat4...', 0));
                } else {
                  var dynColor = setColor(snapshot.data.pctComplete);
                  _dynamic4LGColor = dynColor;
                  dynamic4LG.colors[0] = _dynamic4LGColor;
                  dynamic4LG.colors[1] = _dynamic4LGColor;

                  // to pass to Chat()...
                  cat4String = snapshot.data.cat;

                  display = GestureDetector(
                      onTapDown: (details) {
                        setState(() {
                          _cat4LGToggled = !_cat4LGToggled;
                        });
                      },
                      onTapUp: (details) {
                        setState(() {
                          _cat4LGToggled = !_cat4LGToggled;
                          navigateToTaskList(context, snapshot.data.cat, today);
                        });
                      },
                      child: CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat4(cat4LG, snapshot.data.cat,
                              snapshot.data.pctComplete)));
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
                      painter: DrawCat5(cat5LG, 'Cat5...', 0));
                } else {
                  var dynColor = setColor(snapshot.data.pctComplete);
                  _dynamic5LGColor = dynColor;
                  dynamic5LG.colors[0] = _dynamic5LGColor;
                  dynamic5LG.colors[1] = _dynamic5LGColor;

                  // to pass to Chat()...
                  cat5String = snapshot.data.cat;

                  display = GestureDetector(
                      onTapDown: (details) {
                        setState(() {
                          _cat5LGToggled = !_cat5LGToggled;
                        });
                      },
                      onTapUp: (details) {
                        setState(() {
                          _cat5LGToggled = !_cat5LGToggled;
                          navigateToTaskList(context, snapshot.data.cat, today);
                        });
                      },
                      child: CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat5(cat5LG, snapshot.data.cat,
                              snapshot.data.pctComplete)));
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
                      painter: DrawCat6(cat6LG, 'Cat6...', 0));
                } else {
                  var dynColor = setColor(snapshot.data.pctComplete);
                  _dynamic6LGColor = dynColor;
                  dynamic6LG.colors[0] = _dynamic6LGColor;
                  dynamic6LG.colors[1] = _dynamic6LGColor;

                  // to pass to Chat()...
                  cat6String = snapshot.data.cat;

                  display = GestureDetector(
                      onTapDown: (details) {
                        setState(() {
                          _cat6LGToggled = !_cat6LGToggled;
                        });
                      },
                      onTapUp: (details) {
                        setState(() {
                          _cat6LGToggled = !_cat6LGToggled;
                          navigateToTaskList(context, snapshot.data.cat, today);
                        });
                      },
                      child: CustomPaint(
                          size: Size(pyramidWidth, pyramidHeight),
                          painter: DrawCat6(cat6LG, snapshot.data.cat,
                              snapshot.data.pctComplete)));
                }
                return display;
              })
        ]),
        smallSpacer,
        FutureBuilder(
            future: totalPctCompleteFuture,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              Widget display;
              if (!snapshot.hasData || snapshot.data == '' ) {
                display = Text(
                  '0 Percent Complete',
                  style: pctCompleteTextStyle,
                );
              } else {
                display = Text(
                  '${snapshot.data} Percent Complete',
                  style: pctCompleteTextStyle,
                );
              }
              return display;
            }),
        Container(
            padding: const EdgeInsets.all(10.0),
            child: const Text("Need to work on your mindset?")),

        // Mindset button instead of dropdowns
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          ElevatedButton.icon(
            icon: const Icon(Icons.psychology, color: Colors.white),
            label: const Text(
              'Mindset',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF66CC5D), // #66CC5D
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              elevation: 4,
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MindsetSelect(
                  categories: [cat1String, cat2String, cat3String, cat4String, cat5String, cat6String]
                      .where((cat) => cat.isNotEmpty)
                      .toList(),
                )),
              );
              if (result != null && result is List && result.length == 2) {
                final mood = result[0] as String;
                final category = result[1] as String;
                navigateToChat(context, mood, category);
              }
            },
          ),
        ]),
      ]),
    );
  }

  void navigateToChat(BuildContext context, String mood, String category) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => Coach(mood: mood, category: category, showAppBar: true))).then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
        setFutures();
      });
    });
  }

  void navigateToTaskList(
      BuildContext context, String cat, String today) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    // adInstance.loadAndShowInterstitialAd();
    await Navigator.push(context,
            MaterialPageRoute(builder: (context) => TaskList(cat, today)))
        .then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
        setFutures();
      });
    });
  }

  setFutures() {
    cat1Future = getPctComplete(1, pctDays);
    cat2Future = getPctComplete(2, pctDays);
    cat3Future = getPctComplete(3, pctDays);
    cat4Future = getPctComplete(4, pctDays);
    cat5Future = getPctComplete(5, pctDays);
    cat6Future = getPctComplete(6, pctDays);
    totalPctCompleteFuture = getTotalPctComplete(pctDays);
  }

  Future<Cat> getPctComplete(int categoryid, int pctDays) async {
    final cat = await getCategory(categoryid);
    cat.pctComplete = await dbHelper.getCompletionPercentage(cat.cat, pctDays);

    return cat;
  }

  Future<String> getTotalPctComplete(int pctDays) async {
    String totalComplete = await dbHelper.getTotalPercentage(pctDays);
    return totalComplete;
  }

  Future<Cat> getCategory(int categoryid) async {
    final List<Map<String, dynamic>> maps =
        await dbHelper.queryCategory(categoryid);

    return Cat(categoryid: maps[0]['categoryid'], cat: maps[0]['cat']);
  }

  Color setColor(int pctComplete) {
    // If you are tempted to make the shading more
    // granular, re-consider. I like the steps. They
    // are more noticeable.
    if (pctComplete >= 0 && pctComplete < 15) {
      return buildColor("#F96E6E"); // red
    } else if (pctComplete >= 15 && pctComplete < 30) {
      return buildColor("#F96E6E"); // red
    } else if (pctComplete >= 30 && pctComplete < 42) {
      return buildColor("#F96E6E"); // red
    } else if (pctComplete >= 42 && pctComplete < 55) {
      return buildColor("#F96E6E"); // red
    } else if (pctComplete >= 55 && pctComplete < 67) {
      return buildColor("#FFE177"); // yellow
    } else if (pctComplete >= 67 && pctComplete < 80) {
      return buildColor("#FFE177"); // yellow
    } else if (pctComplete >= 80 && pctComplete < 90) {
      return buildColor("#66CC5D"); // green
    } else if (pctComplete >= 90 && pctComplete <= 100) {
      return buildColor("#66CC5D"); // green
    } else {
      return buildColor("#54B6FF"); // blue
    }
  }

  Color buildColor(String hex) {
    return Color(int.parse(hex.substring(1, 7), radix: 16) + 0xFF000000);
  }
}

class Cat {
  int categoryid = 0;
  String cat = '';
  int pctComplete = 0;

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
  final LinearGradient lg;
  final String cat1;
  final int pctComplete;

  DrawCat1(this.lg, this.cat1, this.pctComplete);

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
    var textSpan = TextSpan(
      text: '$cat1',
      style: textStyle,

    );

    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 75,
    );

    var xCenter = ((size.width / 2.4) - textPainter.width) / 2;
    var yCenter = (size.height * 4.1 / 5);


    final offset = Offset(xCenter, yCenter);
    textPainter.paint(canvas, offset);
  }

  @override
  bool hitTest(Offset position) {
    if (cat1Path.contains(position)) {
      return true;
    }
    return false;
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
  final String cat2;
  final int pctComplete;

  DrawCat2(this.lg, this.cat2, this.pctComplete);

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
      text: cat2,
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 90,
    );

    var xCenter = (size.width - textPainter.width) / 2;
    var yCenter = (size.height * 4.1 / 5);

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
  final String cat3;
  final int pctComplete;

  DrawCat3(this.lg, this.cat3, this.pctComplete);

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
      text: cat3,
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 75,
    );

    var xCenter = ((size.width / 0.63) - textPainter.width) / 2;
    var yCenter = (size.height * 4.1 / 5);


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
  final String cat4;
  final int pctComplete;

  DrawCat4(this.lg, this.cat4, this.pctComplete);

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
      text: cat4,
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 75,
    );

    // when I am ready for hyphens
    // final numLines = textPainter.computeLineMetrics().length;

    var xCenter = ((size.width / 1.35) - textPainter.width) / 2;
    var yCenter = (size.height / 2.1);

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
  final String cat5;
  final int pctComplete;

  DrawCat5(this.lg, this.cat5, this.pctComplete);

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
      text: cat5,
      style: textStyle,
    );
    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 75,
    );

    var xCenter = ((size.width / 0.8) - textPainter.width) / 2;
    var yCenter = (size.height / 2.1);


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
  final String cat6;
  final int pctComplete;

  DrawCat6(this.lg, this.cat6, this.pctComplete);

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
      fontSize: 12,
    );
    var textSpan = TextSpan(
      text: cat6,
      style: textStyle,
    );

    final textPainter = TextPainter(
      maxLines: 2,
      text: textSpan,
      ellipsis: '...',
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );
    textPainter.layout(
      minWidth: 0,
      maxWidth: 65,
    );

    var xCenter = ((size.width) - textPainter.width) / 2;
    var yCenter = (size.height / 5);

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
