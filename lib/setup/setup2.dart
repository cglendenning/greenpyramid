import 'package:flutter/material.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/setup/setup3.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:ui';
import 'package:life_ops/navbar.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/progress_bar.dart';

final List<String> categories = [
  'Health',
  'Mindset',
  'Wealth',
  'Travel',
  'Spirituality',
  'Business',
  'Parent',
  'Spouse',
  'Partner',
  'Learning',
  'Friendship',
  'Career',
  'Sports',
  'Hobbies',
  'Mentoring',
  'Team Player',
  'Social Life',
  'School',
  'Location',
  'Volunteering'
];

class Setup2 extends StatefulWidget {
  const Setup2();

  @override
  _Setup2State createState() => _Setup2State();
}

class _Setup2State extends State<Setup2> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _Setup2State();

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: '${setupVersion}_setup2');

    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    var descStyle = const TextStyle(
      fontSize: 20,
      color: AppColors.textPrimary,
    );

    return SafeArea(
        child: Container(
            decoration: BoxDecoration(
                image: DecorationImage(
              colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.5), BlendMode.dstATop),
              image: const AssetImage("images/morning_1.jpg"),
              fit: BoxFit.cover,
            )),
            child: Scaffold(
                appBar: const NavBar(),
                backgroundColor: Colors.transparent,
                body: Column(children: [
                  ProgressBar(currentStep: 1, totalSteps: 23),
                  const SizedBox(height: 10),
                  Container(
                      padding: const EdgeInsets.all(10.0),
                      child: Text(
                          "Drag six values that matter most to you "
                          "to the top of the list. Place them in order of "
                          "importance. Scroll for more options.",
                          style: descStyle)),
                  const SizedBox(height: 10),
                  Container(
                      height: MediaQuery.of(context).size.height / 2.2,
                      child: const Material(
                          color: Colors.transparent, child: ValueList())),
                  const SizedBox(height: 20),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          icon: svgForward,
                          onPressed: () {
                            setState(() {
                              navigateToSetup3();
                            });
                          },
                        )
                      ]),
                ]))));
  }

  void navigateToSetup3() async {
    cats.add(SetupCat(categoryid: 1, cat: categories[0]));
    cats.add(SetupCat(categoryid: 2, cat: categories[1]));
    cats.add(SetupCat(categoryid: 3, cat: categories[2]));
    cats.add(SetupCat(categoryid: 4, cat: categories[3]));
    cats.add(SetupCat(categoryid: 5, cat: categories[4]));
    cats.add(SetupCat(categoryid: 6, cat: categories[5]));
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => Setup3(categories)),
    );
  }
}

class ValueList extends StatefulWidget {
  const ValueList({super.key});

  @override
  State<ValueList> createState() => _ValueListState();
}

class _ValueListState extends State<ValueList> {
  var descStyle = const TextStyle(
    fontFamily: 'Raleway',
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.black,
  );

  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color oddItemColor =
        Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000)
            .withOpacity(0.85);

    final Color evenItemColor =
        Color(int.parse("#C35DCC".substring(1, 7), radix: 16) + 0xFF000000)
            .withOpacity(0.85);

    final List<Card> cards = <Card>[
      for (int index = 0; index < categories.length; index += 1)
        Card(
          key: Key('$index'),
          color: index.isOdd ? oddItemColor : evenItemColor,
          child: SizedBox(
              height: MediaQuery.of(context).size.height / 15,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text("${index + 1}) ${categories[index]}",
                            style: descStyle)),
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_showHint && index == 0)
                              AnimatedOpacity(
                                opacity: 1.0,
                                duration: const Duration(milliseconds: 500),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.red, width: 4),
                                  ),
                                  child: const Icon(Icons.drag_handle,
                                      color: Colors.red, size: 28),
                                ),
                              ),
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle),
                            ),
                          ],
                        ))
                  ])),
        ),
    ];

    Widget proxyDecorator(
        Widget child, int index, Animation<double> animation) {
      return AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final double animValue = Curves.easeInOut.transform(animation.value);
          final double elevation = lerpDouble(1, 6, animValue)!;
          final double scale = lerpDouble(1, 1.02, animValue)!;
          return Transform.scale(
            scale: scale,
            child: Card(
              elevation: elevation,
              color: cards[index].color,
              child: cards[index].child,
            ),
          );
        },
        child: child,
      );
    }

    return Stack(
      children: [
        // Add a more visible Scrollbar for the list using ScrollbarTheme
        ScrollbarTheme(
          data: ScrollbarThemeData(
            thumbColor: MaterialStateProperty.all(Colors.grey),
            thickness: MaterialStateProperty.all(12),
            radius: const Radius.circular(8),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: ReorderableListView(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              proxyDecorator: proxyDecorator,
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final String item = categories.removeAt(oldIndex);
                  categories.insert(newIndex, item);
                });
              },
              children: cards,
            ),
          ),
        ),
        if (_showHint)
          Positioned(
            left: 0,
            right: 0,
            top: (MediaQuery.of(context).size.height / 15) + 16,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Tap, hold and drag to re-order the list',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
