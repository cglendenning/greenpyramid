import 'package:flutter/material.dart';
import 'package:life_ops/notification.dart';
import 'package:life_ops/db.dart';
import 'package:life_ops/dbtools.dart';
import 'package:life_ops/morning.dart';
import 'package:life_ops/afternoon.dart';
import 'package:life_ops/evening.dart';
import 'package:life_ops/main.dart';
import 'package:life_ops/pyramid.dart';
import 'package:life_ops/coach.dart';
import 'package:life_ops/settings.dart';
import 'package:life_ops/setup/setup1.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/motivation.dart';
import 'package:life_ops/tutorial/tutorial1.dart';
import 'package:life_ops/email.dart';
import 'package:life_ops/editpyramid.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/ads.dart';
import 'package:life_ops/faq.dart';
import 'package:life_ops/cancel.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

int currentScreenIndex = 0;

class HomeScreen extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    FirebaseAnalytics analytics = FirebaseAnalytics.instance;
    analytics.logEvent(name: 'homescreen');
    return MaterialApp(
      title: 'Green Pyramid',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        textTheme: Theme.of(context).textTheme.apply(
            bodyColor: const Color(0xff555555),
            displayColor: const Color(0xff555555)),
        useMaterial3: true,
        fontFamily: 'SourceSans3',
        primarySwatch: Colors.blue,
      ),
      initialRoute: routeToGo,
      onGenerateRoute: (RouteSettings settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const HomeScreenWidget(),
            );
          case '/morning':
            return MaterialPageRoute(
              builder: (context) => const Morning(),
            );
          case '/afternoon':
            return MaterialPageRoute(
              builder: (context) => const Afternoon(),
            );
          case '/evening':
            return MaterialPageRoute(
              builder: (context) => const Evening(),
            );
          case '/setup':
            return MaterialPageRoute(builder: (context) => const Setup1());
          default:
            return _errorRoute();
        }
      },
      debugShowCheckedModeBanner: false,
      home: const Scaffold(
        body: HomeScreenWidget(),
      ),
    );
  }

  static Route<dynamic> _errorRoute() {
    return MaterialPageRoute(builder: (_) {
      return const Scaffold(body: Text('Homescreen Error.'));
    });
  }
}

class HomeScreenWidget extends StatefulWidget {
  const HomeScreenWidget({Key? key}) : super(key: key);

  @override
  State<HomeScreenWidget> createState() => _HomeScreen();
}

class _HomeScreen extends State<HomeScreenWidget> {
  void homeScreenCallback() {
    setState(() {
      setFutures();
    });
  }

  late final LocalNotificationService service;

  var _cat1Future,
      _cat2Future,
      _cat3Future,
      _cat4Future,
      _cat5Future,
      _cat6Future,
      _totalPctComplete;

  String cat = '';
  String taskLogDate = '';

  String taskLogCallback(String c) {
    setState(() {
      currentScreenIndex = 4;
    });
    return c;
  }

  @override
  void initState() {
    service = LocalNotificationService();
    service.intialize();

    listenToNotification();
    if (populateGap) {
      dbHelper.populateTaskLogGap();
    }
    setFutures();
    super.initState();
  }

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;

  @override
  Widget build(BuildContext context) {
    service.scheduleDailyNotification(
        id: 0,
        title: 'Morning Review',
        hour: 9,
        minute: 00,
        payload: '/morning');

    service.scheduleDailyNotification(
        id: 1,
        title: 'Afternoon Review',
        hour: 12,
        minute: 00,
        payload: '/afternoon');

    service.scheduleDailyNotification(
        id: 2,
        title: 'Evening Review',
        hour: 20,
        minute: 00,
        payload: '/evening');

    return SafeArea(
        child: Scaffold(
            appBar: const CustomAppBar(currentScreen: 'homescreen'),
            bottomNavigationBar: BottomNavBar(
                _cat1Future,
                _cat2Future,
                _cat3Future,
                _cat4Future,
                _cat5Future,
                _cat6Future,
                _totalPctComplete,
                homeScreenCallback),
            body: <Widget>[
              Pyramid(_cat1Future, _cat2Future, _cat3Future, _cat4Future,
                  _cat5Future, _cat6Future, _totalPctComplete),
              EditPyramid(
                _cat1Future,
                _cat2Future,
                _cat3Future,
                _cat4Future,
                _cat5Future,
                _cat6Future,
              ),
              Coach(showAppBar: false),
              const Settings()
            ][currentScreenIndex]));
  }

  (dynamic, dynamic) setColorAndShade(int pctComplete) {
    // If you are tempted to make the shading more
    // granular, re-consider. I like the steps. They
    // are more noticeable.
    if (pctComplete >= 0 && pctComplete < 15) {
      return (Colors.red, 500);
    } else if (pctComplete >= 15 && pctComplete < 30) {
      return (Colors.red, 400);
    } else if (pctComplete >= 30 && pctComplete < 42) {
      return (Colors.red, 300);
    } else if (pctComplete >= 42 && pctComplete < 55) {
      return (Colors.red, 200);
    } else if (pctComplete >= 55 && pctComplete < 67) {
      return (Colors.yellow, 500);
    } else if (pctComplete >= 67 && pctComplete < 80) {
      return (Colors.yellow, 200);
    } else if (pctComplete >= 80 && pctComplete < 90) {
      return (Colors.green, 100);
    } else if (pctComplete >= 90 && pctComplete <= 100) {
      return (Colors.green, 500);
    } else {
      return (Colors.blue, 100);
    }
  }

  setFutures() {
    _cat1Future = getPctComplete(1);
    _cat2Future = getPctComplete(2);
    _cat3Future = getPctComplete(3);
    _cat4Future = getPctComplete(4);
    _cat5Future = getPctComplete(5);
    _cat6Future = getPctComplete(6);
    _totalPctComplete = getTotalPctComplete();

  }

  void listenToNotification() =>
      service.onNotificationClick.stream.listen(onNotificationListener);

  void onNotificationListener(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      navigatorKey.currentState?.pushNamed(payload);
    }
  }

  Future<Cat> getPctComplete(int categoryid) async {
    final cat = await getCategory(categoryid);
    cat.pctComplete = await dbHelper.getCompletionPercentage(cat.cat, 7);
    return cat;
  }

  Future<String> getTotalPctComplete() async {
    String totalComplete = await dbHelper.getTotalPercentage(7);
    return totalComplete;
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
  int pctComplete = 0;

  Cat({required this.categoryid, required this.cat});

  Cat.fromMap(dynamic obj) {
    categoryid = obj["categoryid"];
    cat = obj["cat"];
  }
}

class CustomAppBar extends StatefulWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final double elevation;
  final String currentScreen;

  const CustomAppBar({
    Key? key,
    this.title,
    this.leading,
    this.elevation = 2.0,
    this.currentScreen = '',
  }) : super(key: key);

  @override
  CustomAppBarState createState() =>
      CustomAppBarState(currentScreen, elevation);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class CustomAppBarState extends State<CustomAppBar> with WidgetsBindingObserver {
  final String currentScreen;
  final double elevation;
  bool isSubscribed = false;

  CustomAppBarState(this.currentScreen, this.elevation);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSubscriptionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check subscription when app becomes visible
      _checkSubscriptionStatus();
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      // Invalidate cache to force fresh data from RevenueCat
      await Purchases.invalidateCustomerInfoCache();
      print('🏠 [HOME SCREEN] Cache invalidated, fetching fresh data...');
      
      CustomerInfo ci = await Purchases.getCustomerInfo();
      bool newSubscriptionStatus = ci.activeSubscriptions.isNotEmpty;
      print('🏠 [HOME SCREEN] Subscription check - isSubscribed: $newSubscriptionStatus');
      if (mounted) {
        setState(() {
          isSubscribed = newSubscriptionStatus;
        });
      }
    } catch (e) {
      print('🏠 [HOME SCREEN] Error checking subscription: $e');
      if (mounted) {
        setState(() {
          isSubscribed = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String hexLogoColor = "#66CC5D";
    Color logoColor =
        Color(int.parse(hexLogoColor.substring(1, 7), radix: 16) + 0xFF000000);
    const String logo = 'images/svg/logo_green.svg';
    final Widget svgLogo = SvgPicture.asset(logo,
        height: 40,
        width: 40,
        fit: BoxFit.scaleDown,
        colorFilter: ColorFilter.mode(logoColor, BlendMode.srcIn),
        semanticsLabel: 'Green Pyramid Logo');

    String hexBarsColor = "#FFFFFF";
    Color barsColor =
        Color(int.parse(hexBarsColor.substring(1, 7), radix: 16) + 0xFF000000);
    const String bars = 'images/svg/bars.svg';
    final Widget svgBars = SvgPicture.asset(bars,
        height: 80,
        width: 80,
        fit: BoxFit.none,
        colorFilter: ColorFilter.mode(barsColor, BlendMode.srcIn),
        semanticsLabel: 'Bars');

    var menu = PopupMenuButton<String>(
      icon: svgBars,
      onSelected: (String result) {
        switch (result) {
          case 'learnMore':
            if (currentScreen != 'learnMore') {
              navigateToTutorial(context);
            }
            break;
          case 'motivation':
            if (currentScreen != 'motivation') {
              navigateToMotivation(context);
            }
            break;
          case 'feedback':
            if (currentScreen != 'feedback') {
              navigateToFeedback(context);
            }
            break;
          case 'setup':
            if (currentScreen != 'setup') {
              navigateToSetup(context);
            }
            break;
          case 'faq':
            if (currentScreen != 'faq') {
              navigateToFAQ(context);
            }
            break;
          case 'cancel':
            navigateToCancel(context);
            break;
          default:
        }
      },
      itemBuilder: (BuildContext context) {
        List<PopupMenuEntry<String>> items = [
          const PopupMenuItem<String>(
            value: 'learnMore',
            child: Text('Learn More'),
          ),
          const PopupMenuItem<String>(
            value: 'motivation',
            child: Text('Motivation'),
          ),
          const PopupMenuItem<String>(
            value: 'feedback',
            child: Text('App Feedback'),
          ),
          const PopupMenuItem<String>(
            value: 'setup',
            child: Text('Setup'),
          ),
          const PopupMenuItem<String>(
            value: 'faq',
            child: Text('FAQ'),
          ),
        ];

        // Only show cancel option if user has an active subscription
        if (isSubscribed) {
          items.add(
            const PopupMenuItem<String>(
              value: 'cancel',
              child: Text('Cancel Subscription'),
            ),
          );
        }

        return items;
      },
    );

    List<Widget> actions = [menu];

    return Material(
      elevation: elevation,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xffC35DCC),
              Color(0xff000A61),
              Color(0xff1782FF),
            ],
          ),
        ),
        child: AppBar(
          centerTitle: true,
          elevation: 0.0,
          title: svgLogo,
          backgroundColor: Colors.transparent,
          actions: actions,
          leading: null,
        ),
      ),
    );
  }

  void navigateToMotivation(BuildContext context) async {

    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const Motivation()))
        .then((value) {});
    utils.Utils().changeSystemColor(Brightness.light);
    setState(() {});

  }

  void navigateToTutorial(BuildContext context) async {

    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Tutorial1()))
        .then((value) {});
    utils.Utils().changeSystemColor(Brightness.light);
    setState(() {});
  }

  void navigateToFeedback(BuildContext context) async {

    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const EmailSender()))
        .then((value) {});
    utils.Utils().changeSystemColor(Brightness.light);
    setState(() {});
  }

  void navigateToSetup(BuildContext context) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Setup1()))
        .then((value) {});
    utils.Utils().changeSystemColor(Brightness.light);
    setState(() {});
  }

  void navigateToFAQ(BuildContext context) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => const FAQ()))
        .then((value) {});
    utils.Utils().changeSystemColor(Brightness.light);
    setState(() {});
  }

  void navigateToCancel(BuildContext context) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
        context, MaterialPageRoute(builder: (context) => Cancel()))
        .then((value) {
      // Refresh subscription status when returning from cancel screen
      print('🏠 [HOME SCREEN] Returning from cancel screen - checking subscription');
      _checkSubscriptionStatus();
    });
    utils.Utils().changeSystemColor(Brightness.light);
    setState(() {});
  }
}

class BottomNavBar extends StatefulWidget {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;
  final Future totalPctCompleteFuture;

  final VoidCallback homeScreenCallback;

  const BottomNavBar(
      this.cat1Future,
      this.cat2Future,
      this.cat3Future,
      this.cat4Future,
      this.cat5Future,
      this.cat6Future,
      this.totalPctCompleteFuture,
      this.homeScreenCallback);

  @override
  State<BottomNavBar> createState() => _BottomNavBarState(
      cat1Future,
      cat2Future,
      cat3Future,
      cat4Future,
      cat5Future,
      cat6Future,
      totalPctCompleteFuture,
      homeScreenCallback);
}

class _BottomNavBarState extends State<BottomNavBar> {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;
  final Future totalPctCompleteFuture;
  final VoidCallback homeScreenCallback;

  _BottomNavBarState(
      this.cat1Future,
      this.cat2Future,
      this.cat3Future,
      this.cat4Future,
      this.cat5Future,
      this.cat6Future,
      this.totalPctCompleteFuture,
      this.homeScreenCallback);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final Widget svgTriangle = SvgPicture.asset(
        'images/svg/bottom_nav/triangle.svg',
        height: 26,
        width: 26,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        semanticsLabel: 'Triangle');

    final Widget svgList = SvgPicture.asset('images/svg/bottom_nav/list.svg',
        height: 21,
        width: 21,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        semanticsLabel: 'List');

    final Widget svgChat = SvgPicture.asset('images/svg/bottom_nav/chat.svg',
        height: 26,
        width: 26,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        semanticsLabel: 'Chat');

    final Widget svgPencil = SvgPicture.asset(
        'images/svg/bottom_nav/pencil.svg',
        height: 26,
        width: 26,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        semanticsLabel: 'Pencil');

    double selectedHeight = 50;
    double selectedWidth = 50;

    String hexTriangleColor = "#1782FF";
    Color triangleColor = Color(
        int.parse(hexTriangleColor.substring(1, 7), radix: 16) + 0xFF000000);

    final Widget svgTriangleSelected = SvgPicture.asset(
        'images/svg/bottom_nav/triangle_selected.svg',
        height: selectedHeight,
        width: selectedWidth,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(triangleColor, BlendMode.srcIn),
        semanticsLabel: 'Triangle Selected');

    final Widget svgListSelected = SvgPicture.asset(
        'images/svg/bottom_nav/list_selected.svg',
        height: selectedHeight,
        width: selectedWidth,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(triangleColor, BlendMode.srcIn),
        semanticsLabel: 'List Selected');

    final Widget svgChatSelected = SvgPicture.asset(
        'images/svg/bottom_nav/chat_selected.svg',
        height: selectedHeight,
        width: selectedWidth,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(triangleColor, BlendMode.srcIn),
        semanticsLabel: 'Chat Selected');

    final Widget svgPencilSelected = SvgPicture.asset(
        'images/svg/bottom_nav/pencil_selected.svg',
        height: selectedHeight,
        width: selectedWidth,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(triangleColor, BlendMode.srcIn),
        semanticsLabel: 'Pencil Selected');

    String hexShadowColor = "#CBCBCB";

    return Container(
        decoration: BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Color(
                  int.parse(hexShadowColor.substring(1, 7), radix: 16) +
                      0xFF000000),
              blurRadius: 5,
            ),
          ],
        ),
        child: NavigationBar(
          onDestinationSelected: (int index) {
            switch (index) {
              case 0:
                if (currentScreenIndex != index) {
                  print('currentScreenIndex: $currentScreenIndex');
                  print('index: $index');
                  currentScreenIndex = index;
                }
              case 1:
                if (currentScreenIndex != index) {
                  print('currentScreenIndex: $currentScreenIndex');
                  print('index: $index');
                  currentScreenIndex = index;
                }
              case 2:
                if (currentScreenIndex != index) {
                  print('currentScreenIndex: $currentScreenIndex');
                  print('index: $index');
                  currentScreenIndex = index;
                }
              case 3:
                if (currentScreenIndex != index) {
                  print('currentScreenIndex: $currentScreenIndex');
                  print('index: $index');
                  currentScreenIndex = index;
                }
            }
            homeScreenCallback();
          },
          indicatorColor: Colors.transparent,
          selectedIndex: currentScreenIndex,
          backgroundColor: Colors.white,
          destinations: <Widget>[
            NavigationDestination(
              selectedIcon: svgTriangleSelected,
              icon: svgTriangle,
              label: '',
            ),
            NavigationDestination(
              selectedIcon: svgListSelected,
              icon: svgList,
              label: '',
            ),
            NavigationDestination(
              selectedIcon: svgChatSelected,
              icon: svgChat,
              label: '',
            ),
            NavigationDestination(
              selectedIcon: svgPencilSelected,
              icon: svgPencil,
              label: '',
            ),
          ],
        ));
  }
}
