import 'package:flutter/material.dart';
import 'package:life_ops/setup/setup3.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'dart:ui';

final List<String> categories = [
  'Physical Health',
  'Mindset',
  'Financial Health',
  'Travel',
  'Spiritual Growth',
  'Entrepreneurship',
  'Parent',
  'Spouse/Partner',
  'Friendship',
  'Mentor',
  'Team Player',
  'Social Life',
  'Physical Environment',
  'Volunteering'
];


class Welcome1 extends StatefulWidget {
  const Welcome1();

  @override
  _Welcome1State createState() => _Welcome1State();
}

class _Welcome1State extends State<Welcome1> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _Welcome1State();

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'welcome');

    const String forward = 'images/svg/forward.svg';
    final Widget svgForward = SvgPicture.asset(forward,
        fit: BoxFit.scaleDown, semanticsLabel: 'forward');

    var descStyle = const TextStyle(
      fontFamily: 'Raleway',
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );

    var italicStyle = const TextStyle(
      fontFamily: 'Raleway',
      fontSize: 16,
      fontStyle: FontStyle.italic,
      color: Colors.black,
    );



    return SafeArea(
        child: Container(
            decoration: const BoxDecoration(
                image: DecorationImage(
                  image: const AssetImage("images/borabora.jpg"),
                  fit: BoxFit.cover,
                )),

            child: Scaffold(
          backgroundColor: Colors.transparent,
            body: Column(children: [
      const SizedBox(height: 10),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  child: Text("Drag the top six items that matter most to you "
                      "to the top of the list...",
                  style: descStyle)),
              Container(
                  height: MediaQuery.of(context).size.height / 2.2,
                  child:
                  const Material(
                    color: Colors.transparent,
                      child: ValueList())),
              Container(
                  padding: const EdgeInsets.all(10.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                      border: Border.all(
                        color: Colors.transparent,
                      ),
                      borderRadius: const BorderRadius.all(Radius.circular(20))
                  ),
                  child: Text("(You will fine tune this list later...)",
                      style: italicStyle)),

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
