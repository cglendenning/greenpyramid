import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:life_ops/homescreen.dart';
import 'package:life_ops/notification.dart';
import 'package:timezone/data/latest.dart' as tz show initializeTimeZones;
import 'package:life_ops/db.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:app_install_date/app_install_date.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/widgets.dart';
import 'secrets.dart';

final GlobalKey<NavigatorState> navigatorKey =
    GlobalKey(debugLabel: "Main Navigator");

String routeToGo = '/';
String payload = '';
bool populateGap = true;
DateTime installDate = DateTime.now();
bool interventionShown = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initPlatformState();

  try {
    installDate = await AppInstallDate().installDate;
  } catch (e, st) {
    debugPrint('Failed to load install date due to $e\n$st');
  }

  // Only allow portrait.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  LocalNotificationService().intialize();
  tz.initializeTimeZones();
  final dbHelper = DatabaseHelper.instance;
  dbHelper.populateQuote();
  dbHelper.populateCategory();
  // hack to prevent getCategory() from returning nothing on first
  // app launch.
  await Future.delayed(const Duration(seconds: 1));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  int defaultCats = await dbHelper.queryLaunchSetup();

  if (defaultCats == 6) {
    routeToGo = '/setup';
  }
  runApp(HomeScreen());
}

Future<void> initPlatformState() async {
  await Purchases.setLogLevel(LogLevel.debug);
  var configuration;
  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration(revenuecatAndroidKey);
  } else if (Platform.isIOS) {
    configuration = PurchasesConfiguration(revenuecatIOSKey);
  }
  await Purchases.configure(configuration);

  bool config = await Purchases.isConfigured;
  CustomerInfo ci = await Purchases.getCustomerInfo();

  if (kDebugMode) {
    print('Purchase configured: $config');
  }
  if (kDebugMode) {
    print('Customer Info: $ci');
  }
  if (kDebugMode) {
    print('Active Subscriptions: ${ci.activeSubscriptions}');
  }
}
