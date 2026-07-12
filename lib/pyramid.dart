import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/db.dart';
import 'package:life_ops/dbtools.dart';
import 'package:life_ops/tasklist.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/coach.dart';
import 'package:life_ops/mindset_select.dart';
import 'package:life_ops/pyramid_3d.dart';
import 'package:life_ops/pyramid_painting.dart';

enum Calendar { day, week, month, year }

class Pyramid extends StatefulWidget {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;
  final Future totalPctCompleteFuture;
  final ValueChanged<int>? onTimeScaleChanged;
  final VoidCallback? onReturnFromTaskList;

  const Pyramid(
      this.cat1Future,
      this.cat2Future,
      this.cat3Future,
      this.cat4Future,
      this.cat5Future,
      this.cat6Future,
      this.totalPctCompleteFuture,
      {this.onTimeScaleChanged, this.onReturnFromTaskList});

  @override
  State<Pyramid> createState() => _Pyramid();
}

class _Pyramid extends State<Pyramid> {
  Calendar calendarView = Calendar.week;

  int pctDays = 6;

  String? selectedMood;
  String? selectedCategory;

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;

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

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;
    SizedBox smallSpacer = SizedBox(height: pyramidHeight * .07);
    // SizedBox bigSpacer = SizedBox(height: pyramidHeight * .2);

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Exo2');

    var pctCompleteTextStyle = const TextStyle(
        fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Exo2');

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
                      break;
                    case Calendar.week:
                      pctDays = 6;
                      break;
                    case Calendar.month:
                      pctDays = 29;
                      break;
                    case Calendar.year:
                      pctDays = 364;
                      break;
                  }
                  if (widget.onTimeScaleChanged != null) {
                    widget.onTimeScaleChanged!(pctDays);
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
        FutureBuilder(
          future: Future.wait([
            widget.cat1Future,
            widget.cat2Future,
            widget.cat3Future,
            widget.cat4Future,
            widget.cat5Future,
            widget.cat6Future,
          ]),
          builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
            if (!snapshot.hasData) {
              return _jungleScene(
                pyramidWidth,
                Pyramid3D(
                  size: pyramidWidth,
                  categories: List.generate(
                    6,
                    (i) => const PyramidCategoryData(
                        label: '...', color: Colors.blue),
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            cat1String = data[0].cat;
            cat2String = data[1].cat;
            cat3String = data[2].cat;
            cat4String = data[3].cat;
            cat5String = data[4].cat;
            cat6String = data[5].cat;

            return _jungleScene(
              pyramidWidth,
              Pyramid3D(
                size: pyramidWidth,
                categories: [
                  for (final cat in data)
                    PyramidCategoryData(
                        label: cat.cat, color: setColor(cat.pctComplete)),
                ],
                onCategoryTap: (index) {
                  final today =
                      intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
                  navigateToTaskList(context, data[index].cat, today);
                },
              ),
            );
          },
        ),
        smallSpacer,
        FutureBuilder(
            future: widget.totalPctCompleteFuture,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              Widget display;
              if (!snapshot.hasData || snapshot.data == '') {
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
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF66CC5D), // #66CC5D
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 12.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0),
              ),
              elevation: 4,
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => MindsetSelect(
                          categories: [
                            cat1String,
                            cat2String,
                            cat3String,
                            cat4String,
                            cat5String,
                            cat6String
                          ].where((cat) => cat.isNotEmpty).toList(),
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

  void navigateToChat(
      BuildContext context, String mood, String category) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    Coach(mood: mood, category: category, showAppBar: true)))
        .then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
        setFutures();
      });
    });
  }

  // The photo-real jungle clearing the pyramid sits inside: the backdrop
  // fills a rounded card slightly taller than the pyramid so its base lands
  // on the clearing's stone plaza near the bottom of the image crop.
  Widget _jungleScene(double pyramidWidth, Widget pyramid) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: pyramidWidth,
        height: pyramidWidth * 1.12,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'images/jungle_bg.jpg',
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
              ),
            ),
            Align(alignment: Alignment.topCenter, child: pyramid),
          ],
        ),
      ),
    );
  }

  void navigateToTaskList(
      BuildContext context, String cat, String today) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(context,
            MaterialPageRoute(builder: (context) => TaskList(cat, today)))
        .then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
        setFutures();
      });
      if (widget.onReturnFromTaskList != null) {
        widget.onReturnFromTaskList!();
      }
    });
  }

  setFutures() {
    // These are now passed as widget parameters, so we don't need to re-fetch them here.
    // The FutureBuilders will handle their own updates.
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
    // If there are no tasks, pctComplete should be -1, so return blue
    if (pctComplete < 0) {
      return buildColor("#54B6FF"); // blue for no tasks
    }
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
      return buildColor("#54B6FF"); // blue (fallback)
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
// The six CustomPainters below render one flattened, stepped-pyramid-style
// segment each (using the stone+glow treatment from PyramidPainting). The
// home screen's own pyramid is now the 3D Pyramid3D widget above, but the
// setup/onboarding wizard (setup4.dart..setup18.dart) still uses these
// directly for its live pyramid-building preview.
// -----------------------------------------------------------------------------

class DrawCat1 extends CustomPainter {
  final LinearGradient lg;
  final String cat1;
  final int pctComplete;

  DrawCat1(this.lg, this.cat1, this.pctComplete);

  final cat1Path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    cat1Path.moveTo(cat1X, size.height * 2 / 3);
    cat1Path.lineTo(0, size.height);
    cat1Path.lineTo((size.width / 3), size.height);
    cat1Path.lineTo((size.width / 3), size.height * 2 / 3);
    cat1Path.close();

    if (lg.colors[0] == Colors.white) {
      PyramidPainting.paintMutedSegment(
          canvas, cat1Path, lg, const Color(0xFFEBEBEB));
    } else {
      PyramidPainting.paintGlowingSegment(canvas, cat1Path, lg.colors[0]);
    }

    final textWidth = PyramidPainting.measureWidth(cat1, maxWidth: 95);
    var xCenter = ((size.width / 2.4) - textWidth) / 2;
    var yCenter = (size.height * 4.1 / 5);

    PyramidPainting.paintReadableLabel(canvas, cat1, Offset(xCenter, yCenter),
        maxWidth: 95);
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

class DrawCat2 extends CustomPainter {
  final LinearGradient lg;
  final String cat2;
  final int pctComplete;

  DrawCat2(this.lg, this.cat2, this.pctComplete);

  final cat2Path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    var cat2X = (size.width * 1 / 3);
    cat2Path.moveTo(cat2X, size.height * 2 / 3);
    cat2Path.lineTo(cat2X, size.height);
    cat2Path.lineTo(size.width * 2 / 3, size.height);
    cat2Path.lineTo(size.width * 2 / 3, size.height * 2 / 3);
    cat2Path.close();

    if (lg.colors[0] == Colors.white) {
      PyramidPainting.paintMutedSegment(
          canvas, cat2Path, lg, const Color(0xFFEBEBEB));
    } else {
      PyramidPainting.paintGlowingSegment(canvas, cat2Path, lg.colors[0]);
    }

    final textWidth = PyramidPainting.measureWidth(cat2, maxWidth: 105);
    var xCenter = (size.width - textWidth) / 2;
    var yCenter = (size.height * 4.1 / 5);

    PyramidPainting.paintReadableLabel(canvas, cat2, Offset(xCenter, yCenter),
        maxWidth: 105);
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
    if (oldDelegate is DrawCat1 && oldDelegate.lg == lg) {
      return false;
    }
    return true;
  }
}

class DrawCat3 extends CustomPainter {
  final LinearGradient lg;
  final String cat3;
  final int pctComplete;

  DrawCat3(this.lg, this.cat3, this.pctComplete);

  final cat3Path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    var cat3X = (size.width * 2 / 3);
    cat3Path.moveTo(cat3X, size.height * 2 / 3);
    cat3Path.lineTo(cat3X, size.height);
    cat3Path.lineTo(size.width, size.height);
    cat3Path.lineTo(size.width - cat1X, size.height * 2 / 3);
    cat3Path.close();

    if (lg.colors[0] == Colors.white) {
      PyramidPainting.paintMutedSegment(
          canvas, cat3Path, lg, const Color(0xFFEBEBEB));
    } else {
      PyramidPainting.paintGlowingSegment(canvas, cat3Path, lg.colors[0]);
    }

    final textWidth = PyramidPainting.measureWidth(cat3, maxWidth: 95);
    var xCenter = ((size.width / 0.63) - textWidth) / 2;
    var yCenter = (size.height * 4.1 / 5);

    PyramidPainting.paintReadableLabel(canvas, cat3, Offset(xCenter, yCenter),
        maxWidth: 95);
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
    if (oldDelegate is DrawCat1 && oldDelegate.lg == lg) {
      return false;
    }
    return true;
  }
}

class DrawCat4 extends CustomPainter {
  final LinearGradient lg;
  final String cat4;
  final int pctComplete;

  DrawCat4(this.lg, this.cat4, this.pctComplete);

  final cat4Path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    var cat4X = ((cat1X + halfWidth) / 2);

    cat4Path.moveTo(cat4X, size.height * 1 / 3);
    cat4Path.lineTo(cat1X, size.height * 2 / 3);
    cat4Path.lineTo(halfWidth, size.height * 2 / 3);
    cat4Path.lineTo(halfWidth, size.height * 1 / 3);
    cat4Path.close();

    if (lg.colors[0] == Colors.white) {
      PyramidPainting.paintMutedSegment(
          canvas, cat4Path, lg, const Color(0xFFEBEBEB));
    } else {
      PyramidPainting.paintGlowingSegment(canvas, cat4Path, lg.colors[0]);
    }

    final textWidth = PyramidPainting.measureWidth(cat4, maxWidth: 95);
    var xCenter = ((size.width / 1.35) - textWidth) / 2;
    var yCenter = (size.height / 2.1);

    PyramidPainting.paintReadableLabel(canvas, cat4, Offset(xCenter, yCenter),
        maxWidth: 95);
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
      return false;
    }
    return true;
  }
}

class DrawCat5 extends CustomPainter {
  final LinearGradient lg;
  final String cat5;
  final int pctComplete;

  DrawCat5(this.lg, this.cat5, this.pctComplete);

  final cat5Path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    var cat5X = ((cat1X + halfWidth) / 2);

    cat5Path.moveTo(halfWidth, size.height * 1 / 3);
    cat5Path.lineTo(halfWidth, size.height * 2 / 3);
    cat5Path.lineTo(size.width - cat1X, size.height * 2 / 3);
    cat5Path.lineTo(size.width - cat5X, size.height * 1 / 3);
    cat5Path.close();

    if (lg.colors[0] == Colors.white) {
      PyramidPainting.paintMutedSegment(
          canvas, cat5Path, lg, const Color(0xFFEBEBEB));
    } else {
      PyramidPainting.paintGlowingSegment(canvas, cat5Path, lg.colors[0]);
    }

    final textWidth = PyramidPainting.measureWidth(cat5, maxWidth: 95);
    var xCenter = ((size.width / 0.8) - textWidth) / 2;
    var yCenter = (size.height / 2.1);

    PyramidPainting.paintReadableLabel(canvas, cat5, Offset(xCenter, yCenter),
        maxWidth: 95);
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
      return false;
    }
    return true;
  }
}

class DrawCat6 extends CustomPainter {
  final LinearGradient lg;
  final String cat6;
  final int pctComplete;

  DrawCat6(this.lg, this.cat6, this.pctComplete);

  final cat6Path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    var halfWidth = size.width * 1 / 2;
    var bottomLeftX = 0;
    var cat1X = ((bottomLeftX + halfWidth) / 3);
    var cat6X = ((cat1X + halfWidth) / 2);

    cat6Path.moveTo(halfWidth, 0);
    cat6Path.lineTo(cat6X, size.height * 1 / 3);
    cat6Path.lineTo(size.width - cat6X, size.height * 1 / 3);
    cat6Path.close();

    if (lg.colors[0] == Colors.white) {
      PyramidPainting.paintMutedSegment(
          canvas, cat6Path, lg, const Color(0xFFEBEBEB));
    } else {
      PyramidPainting.paintGlowingSegment(canvas, cat6Path, lg.colors[0]);
    }

    final textWidth =
        PyramidPainting.measureWidth(cat6, maxWidth: 85, fontSize: 12);
    var xCenter = ((size.width) - textWidth) / 2;
    var yCenter = (size.height / 5);

    PyramidPainting.paintReadableLabel(canvas, cat6, Offset(xCenter, yCenter),
        maxWidth: 85, fontSize: 12);
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
      return false;
    }
    return true;
  }
}

