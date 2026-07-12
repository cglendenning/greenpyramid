import 'package:flutter/material.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/dbtools.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/pyramid.dart' as pyr;

// Normal blocks render the main-screen stone+glow look in the brand
// green; a pressed block flips to the muted state via a white gradient.
const LinearGradient _kGreenLG =
    LinearGradient(colors: [Color(0xFF66CC5D), Color(0xFF66CC5D)]);
const LinearGradient _kWhiteLG =
    LinearGradient(colors: [Colors.white, Colors.white]);

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

  @override
  void initState() {
    super.initState();
  }

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;
  bool _cat1ColorToggled = false;
  bool _cat2ColorToggled = false;
  bool _cat3ColorToggled = false;
  bool _cat4ColorToggled = false;
  bool _cat5ColorToggled = false;
  bool _cat6ColorToggled = false;

  pyr.DrawCat1 _drawCat1 = pyr.DrawCat1(_kGreenLG, 'default', 0);

  pyr.DrawCat2 _drawCat2 = pyr.DrawCat2(_kGreenLG, 'default', 0);

  pyr.DrawCat3 _drawCat3 = pyr.DrawCat3(_kGreenLG, 'default', 0);

  pyr.DrawCat4 _drawCat4 = pyr.DrawCat4(_kGreenLG, 'default', 0);

  pyr.DrawCat5 _drawCat5 = pyr.DrawCat5(_kGreenLG, 'default', 0);

  pyr.DrawCat6 _drawCat6 = pyr.DrawCat6(_kGreenLG, 'default', 0);

  bool _cat1Edited = false;
  bool _cat2Edited = false;
  bool _cat3Edited = false;
  bool _cat4Edited = false;
  bool _cat5Edited = false;
  bool _cat6Edited = false;


  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'editpyramid');
    final lg1 = _cat1ColorToggled ? _kWhiteLG : _kGreenLG;
    final lg2 = _cat2ColorToggled ? _kWhiteLG : _kGreenLG;
    final lg3 = _cat3ColorToggled ? _kWhiteLG : _kGreenLG;
    final lg4 = _cat4ColorToggled ? _kWhiteLG : _kGreenLG;
    final lg5 = _cat5ColorToggled ? _kWhiteLG : _kGreenLG;
    final lg6 = _cat6ColorToggled ? _kWhiteLG : _kGreenLG;

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;
    SizedBox smallSpacer = SizedBox(height: pyramidHeight * .1);
    SizedBox bigSpacer = SizedBox(height: pyramidHeight * .2);

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Exo2');

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
                    painter: pyr.DrawCat1(lg1, 'Cat1...', 0));
              } else {
                if (!_cat1Edited) {
                  _drawCat1 = pyr.DrawCat1(lg1, snapshot.data.cat, 0);
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
                // pyr.DrawCat1(lg1, snapshot.data.cat, 0)));
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
                    painter: pyr.DrawCat2(lg2, 'Cat2...', 0));
              } else {
                if (!_cat2Edited) {
                  _drawCat2 = pyr.DrawCat2(lg2, snapshot.data.cat, 0);
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
                // pyr.DrawCat2(lg2, snapshot.data.cat, 0)));
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
                    painter: pyr.DrawCat3(lg3, 'Cat3...', 0));
              } else {
                if (!_cat3Edited) {
                  _drawCat3 = pyr.DrawCat3(lg3, snapshot.data.cat, 0);
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
                // pyr.DrawCat3(lg3, snapshot.data.cat, 0)));
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
                    painter: pyr.DrawCat4(lg4, 'Cat4...', 0));
              } else {
                if (!_cat4Edited) {
                  _drawCat4 = pyr.DrawCat4(lg4, snapshot.data.cat, 0);
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
                // pyr.DrawCat4(lg4, snapshot.data.cat, 0)));
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
                    painter: pyr.DrawCat5(lg5, 'Cat5...', 0));
              } else {
                if (!_cat5Edited) {
                  _drawCat5 = pyr.DrawCat5(lg5, snapshot.data.cat, 0);
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
                // pyr.DrawCat5(lg5, snapshot.data.cat, 0)));
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
                    painter: pyr.DrawCat6(lg6, 'Cat6...', 0));
              } else {
                if (!_cat6Edited) {
                  _drawCat6 = pyr.DrawCat6(lg6, snapshot.data.cat, 0);
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
                // pyr.DrawCat6(lg6, snapshot.data.cat, 0)));
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
            color: AppColors.textPrimary,
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
            _drawCat1 = pyr.DrawCat1(_kGreenLG, categoryText.text, 0);
          case 2:
            _cat2Edited = true;
            _drawCat2 = pyr.DrawCat2(_kGreenLG, categoryText.text, 0);
          case 3:
            _cat3Edited = true;
            _drawCat3 = pyr.DrawCat3(_kGreenLG, categoryText.text, 0);
          case 4:
            _cat4Edited = true;
            _drawCat4 = pyr.DrawCat4(_kGreenLG, categoryText.text, 0);
          case 5:
            _cat5Edited = true;
            _drawCat5 = pyr.DrawCat5(_kGreenLG, categoryText.text, 0);
          case 6:
            _cat6Edited = true;
            _drawCat6 = pyr.DrawCat6(_kGreenLG, categoryText.text, 0);
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
