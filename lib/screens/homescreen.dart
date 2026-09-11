import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:life_ops/screens/account_creation_screen.dart';
import 'package:life_ops/screens/setup_screen.dart';
import 'package:life_ops/services/account_link_service.dart';
import 'package:life_ops/services/auth_service.dart';
import 'package:life_ops/services/local_pyramid_reset_service.dart';
import 'package:life_ops/services/notification.dart';
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/dbtools.dart';
import 'package:life_ops/services/sync_service.dart';
import 'package:life_ops/main.dart';
import 'package:life_ops/widgets/pyramid.dart';
import 'package:life_ops/screens/settings.dart';
import 'package:life_ops/screens/welcome_screen.dart';
import 'package:life_ops/screens/general_council_screen.dart';
import 'package:life_ops/screens/paywall_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:life_ops/screens/feedback_screen.dart';
import 'package:life_ops/screens/editpyramid.dart';
import 'package:life_ops/services/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/screens/faq.dart';
import 'package:life_ops/screens/profile.dart';
import 'package:life_ops/screens/visualizations.dart';
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
      onGenerateRoute: _generateRoute,
      // D-138: Flutter's default initial-route generation
      // (Navigator.defaultGenerateInitialRoutes) unconditionally mounts
      // '/' *and* the requested initialRoute — found live: a fresh
      // install correctly showed WelcomeScreen ('/setup') first, then
      // 2-3 seconds later AccountCreationScreen popped up on top of it.
      // Root cause, confirmed against the Flutter SDK source: '/' (this
      // screen's HomeScreenWidget) was silently mounted underneath
      // WelcomeScreen the whole time, so its own D-132
      // _enforceRealAccount gate fired once its signInSilently() call
      // resolved. Overriding onGenerateInitialRoutes mounts exactly the
      // one route actually requested.
      onGenerateInitialRoutes: (String initialRouteName) {
        if (initialRouteName == '/') {
          return [MaterialPageRoute(builder: (_) => _home)];
        }
        return [_generateRoute(RouteSettings(name: initialRouteName)) ?? _errorRoute()];
      },
      debugShowCheckedModeBanner: false,
      home: _home,
    );
  }

  static const Widget _home = DemoModeOverlay(
    child: Scaffold(
      body: HomeScreenWidget(),
    ),
  );

  static Route<dynamic>? _generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const HomeScreenWidget(),
        );
      // D-083: morning/afternoon/evening are deleted, replaced by
      // D-036's server-generated notifications. These three cases stay
      // only so a stale local notification already scheduled on a
      // device before the upgrade lands on the pyramid rather than an
      // error route.
      case '/morning':
      case '/afternoon':
      case '/evening':
        return MaterialPageRoute(
          builder: (_) => const HomeScreenWidget(),
        );
      case '/setup':
        // D-089/D-136: a fresh install lands here first via
        // routeToGo — the welcome screen, not straight into Mira's
        // opening line. A relaunch right after sign-out lands here
        // too now, identically — both are just "no session yet."
        return MaterialPageRoute(builder: (context) => const WelcomeScreen());
      default:
        return _errorRoute();
    }
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
    // D-132: enforced once per app session, not once per tab switch —
    // this StatefulWidget is mounted once at launch; currentScreenIndex
    // changes are just an index swap, not a remount.
    WidgetsBinding.instance.addPostFrameCallback((_) => _enforceRealAccount());
    super.initState();
  }

  @override
  void dispose() {
    DatabaseHelper.demoModeNotifier.removeListener(_onDemoModeChanged);
    super.dispose();
  }

  // D-132: catches an existing user whose account predates D-130 — Craig's
  // own situation: setup already completed before D-130 existed, so
  // nothing ever prompted him to link a real credential. D-032's own
  // convention (every Firestore-touching screen awaits signInSilently()
  // first, since main.dart's bootstrap is fire-and-forget and not
  // guaranteed to have run yet) is what makes the isAnonymous check below
  // reliable rather than racy.
  Future<void> _enforceRealAccount() async {
    await AuthService.instance.signInSilently();
    if (!mounted || !AuthService.instance.isAnonymous) return;
    var accountWasSwitched = false;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AccountCreationScreen(
        onDone: ({required bool switchedToExistingAccount}) {
          accountWasSwitched = switchedToExistingAccount;
          Navigator.of(context).pop();
        },
      ),
    ));
    if (accountWasSwitched) {
      // D-132: a real edge case — this device already has a local
      // pyramid *and* the Apple/Google identity just used already
      // belongs to a different, real account. That account's own cloud
      // data (if any) needs restoring; the local pyramid that was here
      // before belonged to the abandoned anonymous account.
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await SyncService.instance.restoreFromCloud(uid);
      }
    }
    if (!mounted) return;
    setState(() => setFutures());
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
    return SafeArea(
        child: Scaffold(
            // The app bar is now translucent (CustomAppBar) — without an
            // explicit backgroundColor here, Flutter's Material default
            // (white) would show through it on every tab.
            backgroundColor: AppColors.background,
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

  /// D-083 amendment / Phase 6 fix (2026-09-10): every tap-routing path
  /// that isn't the new D-124 batch check-in — D-038's local fallback,
  /// D-023's lapsed static pool, and now D-036's real tailored push (once
  /// it carries a `type: 'tailored'` data payload, wired in main.dart) —
  /// funnels through this one listener via [payload]. It used to call
  /// `navigatorKey.currentState?.pushNamed(payload)` for every payload,
  /// which is wrong for `/` (and the legacy `/morning`/`/afternoon`/
  /// `/evening` payloads a notification scheduled before this fix might
  /// still carry): those aren't real named routes here — the four tabs
  /// are plain widgets in a list indexed by `currentScreenIndex`, not
  /// pushed routes — so `pushNamed` stacked a whole second `HomeScreen`
  /// on top of the one already showing. `/paywall` was worse: never
  /// registered as a route at all, so it hit `HomeScreen`'s error route
  /// and showed a literal "Homescreen Error." screen. Both are switch
  /// cases now, not a blind push.
  void onNotificationListener(String? payload) {
    if (payload == null || payload.isEmpty) return;
    switch (payload) {
      case '/':
      case '/morning':
      case '/afternoon':
      case '/evening':
        setState(() => currentScreenIndex = 0); // the pyramid tab
        break;
      case '/paywall':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const PaywallScreen(reason: 'Continue with Green Pyramid'),
          ),
        );
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
          case 'council':
            navigateToCouncil(context);
            break;
          case 'faq':
            if (currentScreen != 'faq') {
              navigateToFAQ(context);
            }
            break;
          case 'profile':
            navigateToProfile(context);
            break;
          case 'signOut':
            signOut(context);
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
            value: 'feedback',
            child: Text('App Feedback'),
          ),
          const PopupMenuItem<String>(
            value: 'setup',
            child: Text('Set up again'),
          ),
          const PopupMenuItem<String>(
            value: 'council',
            child: Text('Talk to the Council of Advisors'),
          ),
          const PopupMenuItem<String>(
            value: 'faq',
            child: Text('FAQ'),
          ),
          const PopupMenuItem<String>(
            value: 'profile',
            child: Text('Profile'),
          ),
          // D-133: only offered when actually signed in with a real
          // account — checked live (AuthService.instance.isAnonymous),
          // not cached, so it can never go stale across a sign-out.
          if (!AuthService.instance.isAnonymous)
            const PopupMenuItem<String>(
              value: 'signOut',
              child: Text('Sign out'),
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

    // D-131 originally replaced this gradient with an opaque-feeling
    // rounded frosted panel — found live not to be what was wanted
    // ("I like what I had before... I really wanted was simply to have
    // more transparency so that the background image... shine through
    // it"). Reverted to the original gradient shape (no rounded
    // corners) and colors, with the gradient itself now translucent
    // (0.45 alpha) so the photo genuinely shows through it. A
    // BackdropFilter blur was tried here too, for the "glassier" look —
    // reverted a second time, found live: BackdropFilter blurs
    // everything painted beneath it in the same layer without clipping
    // to its own bounds, and the blur bled down into the pyramid itself
    // well past the toolbar's own height. Material(color: transparent)
    // keeps Material's own default opaque surface paint from defeating
    // the transparency; elevation still draws the same subtle shadow
    // the original had.
    return Material(
      color: Colors.transparent,
      elevation: elevation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: AppColors.appBarGradient
                .map((c) => c.withValues(alpha: 0.45))
                .toList(),
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

  void navigateToFeedback(BuildContext context) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(context,
            MaterialPageRoute(builder: (context) => const FeedbackScreen()))
        .then((value) {});
    utils.Utils().changeSystemColor(Brightness.light);
    setState(() {});
  }

  // D-136: "Set up again" in the hamburger menu — the user stays signed
  // in throughout (never touches AuthService.signOut) and is rebuilding
  // their existing, cloud-synced pyramid, not starting from a signed-out
  // state — a genuinely different, more consequential action than
  // anything WelcomeScreen handles, so it never goes near that screen.
  // Confirms explicitly (this erases real, synced data) before wiping
  // local storage and going straight into setup. setup_screen.dart's own
  // existing anonymous-check at completion already skips the D-130
  // account-creation screen for a non-anonymous user, so nothing else
  // is needed to honor "they will not be presented with the screen to
  // create an account because they're already signed in."
  Future<void> navigateToSetup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Set up again?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          "Your existing pyramid and all of its habits and history will be "
          "erased, and you'll start again from scratch. This can't be "
          "undone.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Set up again'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await LocalPyramidResetService.instance.wipeLocalPyramid();
    if (!context.mounted) return;
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(context,
            MaterialPageRoute(builder: (context) => const SetupScreen()))
        .then((value) {});
    utils.Utils().changeSystemColor(Brightness.light);
    setState(() {});
  }

  // D-136: hamburger-menu sign-out — same underlying flow Settings'
  // ACCOUNT section already uses. Leaves the app genuinely signed out
  // (no eager re-anonymization) and lands on the plain WelcomeScreen —
  // identical to a fresh install, per the owner's explicit correction
  // that "logged out" has no sub-states.
  Future<void> signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign out?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Your pyramid and history are saved to your account.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await AccountLinkService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // D-091/D-016: same client-side entitlement gate CouncilCategoryPicker
  // already uses (council_category_picker.dart:_open) — found live, the
  // hard way: without it, an unentitled account reaches GeneralCouncilScreen,
  // the backend's EntitlementRequiredException isn't one of the exceptions
  // that screen catches (matching CouncilScreen's own convention of relying
  // entirely on this gate rather than handling the exception mid-screen),
  // and the user sees a generic "Could not open this conversation" with no
  // path forward.
  Future<void> navigateToCouncil(BuildContext context) async {
    final account = await DatabaseHelper.instance.getAccountState();
    final entitlement = account[DatabaseHelper.columnEntitlement] as String?;
    final entitled = entitlement == 'trialing' || entitlement == 'subscribed';

    if (!mounted) return;

    if (!entitled) {
      final subscribed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => const PaywallScreen(reason: 'Talk to the Council of Advisors'),
        ),
      );
      if (subscribed != true || !mounted) return;
    }

    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(context,
            MaterialPageRoute(builder: (context) => const GeneralCouncilScreen()))
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
