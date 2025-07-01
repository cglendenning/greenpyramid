import 'package:flutter/material.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:life_ops/setup/setup3.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:ui';
import 'package:life_ops/navbar.dart';


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
      color: Colors.black,
    );

    return SafeArea(
        child: Container(
            decoration: const BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage("images/morning_1.jpg"),
                  fit: BoxFit.cover,
                )),
            child: Scaffold(
                appBar: const NavBar(),
          backgroundColor: Colors.transparent,
            body: Column(children: [
              LinearProgressIndicator(
                value: 1/23,
                color: Color(int.parse("#66CC5D".substring(1, 7), radix: 16) + 0xFF000000)
              ),
      const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: Text("Drag six values that matter most to you "
                      "to the top of the list. Place them in order of "
                      "importance. Scroll for more options.",
                  style: descStyle)),
              const SizedBox(height: 10),
              Container(
                  height: MediaQuery.of(context).size.height / 2.2,
                  child:
                  const Material(
                    color: Colors.transparent,
                      child: ValueList())),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
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
      MaterialPageRoute(builder: (context) => Setup3(
        categories
      )),
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
                        child: Text(
                            "${index+1}) ${categories[index]}",
                        style: descStyle)),
                    Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
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
            // Create a Card based on the color and the content of the dragged one
            // and set its elevation to the animated value.
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

    return ReorderableListView(
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
    );
  }
}
