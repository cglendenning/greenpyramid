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
import 'package:life_ops/faq.dart';
import 'package:life_ops/profile.dart';
import 'package:life_ops/visualizations.dart';
import 'package:life_ops/theme/app_colors.dart';

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
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.brandGreen,
          brightness: Brightness.dark,
          primary: AppColors.brandGreen,
          secondary: AppColors.brandPurple,
          surface: AppColors.surface,
        ),
        textTheme: Theme.of(context).textTheme.apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary),
        useMaterial3: true,
        fontFamily: 'Exo2',
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
      home: DemoModeOverlay(
        child: const Scaffold(
          body: HomeScreenWidget(),
        ),
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

  int _currentPctDays = 6; // Default to week

  String cat = '';
  String taskLogDate = '';

  // Demo mode state and backup
  bool isDemoMode = false;
  List<Map<String, dynamic>>? userCategoriesBackup;
  List<Map<String, dynamic>>? userTasksBackup;
  List<Map<String, dynamic>>? userTaskLogsBackup;

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
    // Listen for demo mode changes and refresh data
    DatabaseHelper.demoModeNotifier.addListener(_onDemoModeChanged);
    super.initState();
  }

  @override
  void dispose() {
    DatabaseHelper.demoModeNotifier.removeListener(_onDemoModeChanged);
    super.dispose();
  }

  void _onDemoModeChanged() {
    setState(() {
      setFutures();
    });
  }

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;

  Future<void> toggleDemoMode(BuildContext context) async {
    if (!DatabaseHelper.isDemoMode) {
      DatabaseHelper.toggleDemoMode();
      await dbtools.populateDemoData();
      setState(() {
        setFutures();
      });
    } else {
      DatabaseHelper.toggleDemoMode();
      setState(() {
        setFutures();
      });
    }
  }

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
                  _cat5Future, _cat6Future, _totalPctComplete,
                  onTimeScaleChanged: (int newDays) {
                    setState(() {
                      setFutures(newDays);
                    });
                  },
                  onReturnFromTaskList: () {
                    setState(() {
                      setFutures();
                    });
                  }),
              EditPyramid(
                _cat1Future,
                _cat2Future,
                _cat3Future,
                _cat4Future,
                _cat5Future,
                _cat6Future,
              ),
              Coach(showAppBar: false),
              const Settings(),
              const VisualizationsScreen(), // NEW: Visualizations screen
            ][currentScreenIndex]));
  }

  void setFutures([int? daysOverride]) {
    final days = daysOverride ?? _currentPctDays;
    _cat1Future = getPctComplete(1, days);
    _cat2Future = getPctComplete(2, days);
    _cat3Future = getPctComplete(3, days);
    _cat4Future = getPctComplete(4, days);
    _cat5Future = getPctComplete(5, days);
    _cat6Future = getPctComplete(6, days);
    _totalPctComplete = getTotalPctComplete(days);
    _currentPctDays = days;
  }

  void listenToNotification() =>
      service.onNotificationClick.stream.listen(onNotificationListener);

  void onNotificationListener(String? payload) {
    if (payload != null && payload.isNotEmpty) {
      navigatorKey.currentState?.pushNamed(payload);
    }
  }

  Future<Cat> getPctComplete(int categoryid, int days) async {
    final cat = await getCategory(categoryid);
    cat.pctComplete = await dbHelper.getCompletionPercentage(cat.cat, days);
    return cat;
  }

  Future<String> getTotalPctComplete(int days) async {
    String totalComplete = await dbHelper.getTotalPercentage(days);
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

class CustomAppBarState extends State<CustomAppBar> {
  final String currentScreen;
  final double elevation;

  CustomAppBarState(this.currentScreen, this.elevation);

  @override
  Widget build(BuildContext context) {
    const String logo = 'images/svg/logo_green.svg';
    final Widget svgLogo = SvgPicture.asset(logo,
        height: 40,
        width: 40,
        fit: BoxFit.scaleDown,
        colorFilter: const ColorFilter.mode(AppColors.brandGreen, BlendMode.srcIn),
        semanticsLabel: 'Green Pyramid Logo');

    Color barsColor = Colors.white;
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
          case 'profile':
            navigateToProfile(context);
            break;
          case 'demoMode':
            final homeScreenState = context.findAncestorStateOfType<_HomeScreen>();
            if (homeScreenState != null) {
              homeScreenState.toggleDemoMode(context);
            }
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
          const PopupMenuItem<String>(
            value: 'profile',
            child: Text('Profile'),
          ),
          const PopupMenuItem<String>(
            value: 'demoMode',
            child: Text('Toggle Demo Mode'),
          ),
        ];
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
            colors: AppColors.appBarGradient,
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
    await Navigator.push(context,
            MaterialPageRoute(builder: (context) => const Motivation()))
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
    await Navigator.push(context,
            MaterialPageRoute(builder: (context) => const EmailSender()))
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

  void navigateToProfile(BuildContext context) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
            context, MaterialPageRoute(builder: (context) => ProfileScreen()))
        .then((value) {});
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
        colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
        semanticsLabel: 'Triangle');

    final Widget svgList = SvgPicture.asset('images/svg/bottom_nav/list.svg',
        height: 21,
        width: 21,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
        semanticsLabel: 'List');

    final Widget svgChat = SvgPicture.asset('images/svg/bottom_nav/chat.svg',
        height: 26,
        width: 26,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
        semanticsLabel: 'Chat');

    final Widget svgPencil = SvgPicture.asset(
        'images/svg/bottom_nav/pencil.svg',
        height: 26,
        width: 26,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
        semanticsLabel: 'Pencil');

    final Widget svgChart = SvgPicture.asset(
        'images/svg/bottom_nav/chart.svg',
        height: 26,
        width: 26,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(AppColors.textSecondary, BlendMode.srcIn),
        semanticsLabel: 'Chart');

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

    final Widget svgChartSelected = SvgPicture.asset(
        'images/svg/bottom_nav/chart_selected.svg',
        height: selectedHeight,
        width: selectedWidth,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(triangleColor, BlendMode.srcIn),
        semanticsLabel: 'Chart Selected');

    return Container(
        decoration: BoxDecoration(
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 5,
            ),
          ],
        ),
        child: NavigationBar(
          onDestinationSelected: (int index) {
            switch (index) {
              case 0:
              case 1:
              case 2:
              case 3:
              case 4:
                if (currentScreenIndex != index) {
                  currentScreenIndex = index;
                }
                break;
            }
            homeScreenCallback();
          },
          indicatorColor: Colors.transparent,
          selectedIndex: currentScreenIndex,
          backgroundColor: AppColors.surface,
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
            NavigationDestination(
              selectedIcon: svgChartSelected,
              icon: svgChart,
              label: '',
            ),
          ],
        ));
  }
}

class DemoModeOverlay extends StatefulWidget {
  final Widget child;
  const DemoModeOverlay({required this.child, Key? key}) : super(key: key);

  @override
  State<DemoModeOverlay> createState() => _DemoModeOverlayState();
}

class _DemoModeOverlayState extends State<DemoModeOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    DatabaseHelper.demoModeNotifier.addListener(_onDemoModeChanged);
  }

  void _onDemoModeChanged() async {
    // Play flip animation
    await _controller.forward(from: 0);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final isFlipping = _animation.value < 1 && _animation.value > 0;
        final flipValue = _animation.value;
        return Stack(
          children: [
            // Main content
            Transform(
              alignment: Alignment.center,
              transform: (() {
                final matrix = Matrix4.identity();
                if (isFlipping) {
                  matrix.setEntry(3, 2, 0.001);
                  matrix.rotateY(3.1416 * flipValue);
                }
                return matrix;
              })(),
              child: widget.child,
            ),
            // Demo Mode Banner (styled like Free Tier banner)
            if (DatabaseHelper.isDemoMode)
              const DemoModeBanner(),
            // Flip animation overlay
            if (isFlipping)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: (() {
                        final matrix = Matrix4.identity();
                        matrix.setEntry(3, 2, 0.001);
                        matrix.rotateY(3.1416 * flipValue);
                        return matrix;
                      })(),
                      child: Icon(Icons.flip_camera_android, size: 100, color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    DatabaseHelper.demoModeNotifier.removeListener(_onDemoModeChanged);
    _controller.dispose();
    super.dispose();
  }
}

// DemoModeBanner styled like the Free Tier banner
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: -30,
      top: 60, // Move banner further down to avoid status bar/clock
      child: Transform.rotate(
        angle: -0.785398, // -45 degrees in radians
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(vertical: 4),
          color: Colors.redAccent, // Match 'Free Tier' banner color
          child: const Center(
            child: Text(
              'DEMO MODE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
