import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:rxdart/subjects.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:life_ops/main.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class LocalNotificationService {
  LocalNotificationService();

  final _localNotificationService = FlutterLocalNotificationsPlugin();

  final BehaviorSubject<String?> onNotificationClick = BehaviorSubject();

  // Notification message generator
  String _generateNotificationMessage(int notificationId) {
    final random = Random();

    // Different message pools for each time of day - ALL UNIQUE AND TIME-APPROPRIATE
    List<List<String>> messagePools = [
      // Morning messages (id: 0) - 30 unique questions
      [
        "What is one thing you're looking forward to today?",
        "What healthy habit will you focus on this morning?",
        "What's your top priority for today?",
        "How will you energize yourself this morning?",
        "What's one way you can make today meaningful?",
        "What's your intention for the day?",
        "How will you practice gratitude this morning?",
        "What's one thing you want to learn today?",
        "How will you support your well-being today?",
        "What's your first step toward your main goal?",
        "How will you stay positive today?",
        "What's one thing you want to avoid today?",
        "How will you connect with others today?",
        "What's your plan for a productive morning?",
        "How will you take care of your body today?",
        "What's one thing you want to finish before noon?",
        "How will you stay focused this morning?",
        "What's your motivation for today?",
        "How will you handle distractions today?",
        "What's one thing you want to celebrate tonight?",
        "How will you practice mindfulness this morning?",
        "What's your biggest opportunity today?",
        "How will you challenge yourself today?",
        "What's your main source of inspiration today?",
        "How will you make time for yourself today?",
        "What's one thing you want to improve from yesterday?",
        "How will you show kindness today?",
        "What's your plan for a balanced day?",
        "How will you nurture your creativity today?",
        "What's your morning affirmation?",
      ],
      // Afternoon messages (id: 1) - 30 unique questions
      [
        "What's been your biggest win so far today?",
        "How are you feeling right now?",
        "What's one thing you can do to boost your afternoon energy?",
        "What's your next important task?",
        "How will you reset if you feel off track?",
        "What's something you've learned today?",
        "How can you help someone this afternoon?",
        "What's your plan for a healthy break?",
        "How will you stay motivated for the rest of the day?",
        "What's one thing you want to finish before evening?",
        "How will you manage your time this afternoon?",
        "What's your biggest challenge right now?",
        "How will you celebrate progress today?",
        "What's one thing you can delegate or simplify?",
        "How will you practice patience this afternoon?",
        "What's your strategy for handling stress today?",
        "How will you keep your goals in sight?",
        "What's one thing you're grateful for this afternoon?",
        "How will you recharge during your break?",
        "What's your focus for the next hour?",
        "How will you encourage yourself to keep going?",
        "What's one thing you can do to help your future self?",
        "How will you stay organized this afternoon?",
        "What's your plan for a smooth transition to evening?",
        "How will you reflect on your progress so far?",
        "What's one thing you want to avoid this afternoon?",
        "How will you practice self-care today?",
        "What's your biggest lesson from today so far?",
        "How will you finish the day strong?",
        "What's your afternoon affirmation?",
      ],
      // Evening messages (id: 2) - 30 unique questions
      [
        "What was your favorite moment today?",
        "How did you take care of yourself today?",
        "What's one thing you accomplished that you're proud of?",
        "How did you overcome a challenge today?",
        "What's something new you learned today?",
        "How did you show kindness today?",
        "What's one thing you're grateful for tonight?",
        "How will you unwind this evening?",
        "What's your plan for a restful night?",
        "How did you support someone today?",
        "What's one thing you'd like to improve tomorrow?",
        "How did you practice mindfulness today?",
        "What's your biggest insight from today?",
        "How did you nurture your creativity today?",
        "What's one thing you want to let go of before bed?",
        "How did you balance work and rest today?",
        "What's your intention for tomorrow?",
        "How did you manage your energy today?",
        "What's one thing you want to remember from today?",
        "How did you celebrate your progress?",
        "What's your evening affirmation?",
        "How did you handle stress today?",
        "What's one thing you'll do differently tomorrow?",
        "How did you connect with others today?",
        "What's your plan for a positive start tomorrow?",
        "How did you practice self-care this evening?",
        "What's one thing you're looking forward to tomorrow?",
        "How did you stay organized today?",
        "What's your biggest lesson from today?",
        "How will you show gratitude before sleep?",
      ],
    ];

    // Get the appropriate message pool based on notification ID
    List<String> messages = messagePools[notificationId];

    // Return a random message from the pool
    return messages[random.nextInt(messages.length)];
  }

  // Generate a random question from the full pool (for testing)

  // Schedule test notification every 1 minute for 5 minutes
  Future<void> scheduleTestNotification() async {
    try {
      final random = Random();
      // Cancel any existing test notifications
      await _localNotificationService.cancel(999);
      await _localNotificationService.cancel(998);
      await _localNotificationService.cancel(997);
      await _localNotificationService.cancel(996);
      await _localNotificationService.cancel(995);
      // Available routes for random selection
      List<String> routes = ['/morning', '/afternoon', '/evening'];
      // Schedule multiple notifications at 1-minute intervals
      for (int i = 0; i < 5; i++) {
        // Select route and corresponding question pool
        int routeIndex = random.nextInt(routes.length);
        String selectedRoute = routes[routeIndex];

        // Get appropriate question based on route
        String timeAppropriateQuestion =
            _generateNotificationMessage(routeIndex);
        // Use 1-minute intervals
        final scheduledTime =
            tz.TZDateTime.now(tz.local).add(Duration(minutes: i + 1));
        // Create iOS details with the question as the body
        final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
          sound: 'doublebeep.aiff',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        const AndroidNotificationDetails androidNotificationDetails =
            AndroidNotificationDetails(
          'green_pyramid_channel',
          'Green Pyramid Notifications',
          channelDescription: 'Notifications for Green Pyramid app',
          importance: Importance.max,
          priority: Priority.max,
          sound: RawResourceAndroidNotificationSound('doublebeep'),
          playSound: true,
          enableVibration: true,
          enableLights: true,
          showWhen: true,
          autoCancel: false,
          ongoing: false,
          channelShowBadge: true,
          icon: '@mipmap/launcher_icon',
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
          category: AndroidNotificationCategory.reminder,
          visibility: NotificationVisibility.public,
          timeoutAfter: 30000,
        );
        final NotificationDetails details = NotificationDetails(
          android: androidNotificationDetails,
          iOS: iosDetails,
        );
        try {
          await _localNotificationService.zonedSchedule(
            999 - i, // Use IDs 999, 998, 997, 996, 995
            'Green Pyramid',
            timeAppropriateQuestion,
            scheduledTime,
            details,
            androidScheduleMode: AndroidScheduleMode.exact,
            payload:
                selectedRoute, // Route to morning, afternoon, or evening based on question
            matchDateTimeComponents: null,
          );
          if (kDebugMode) {
            print(
                '✅ Test notification  \\${999 - i} scheduled for \\${scheduledTime.toString()}');
          }
          if (kDebugMode) {
            print('  Route: \\${selectedRoute}');
          }
          if (kDebugMode) {
            print('  Question: \\${timeAppropriateQuestion}');
          }
          if (kDebugMode) {
            print('  ---');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Failed to schedule notification \\${999 - i}: $e');
          }
        }
      }
      // Wait a moment then verify scheduled notifications
      await Future.delayed(Duration(seconds: 2));
      final pending =
          await _localNotificationService.pendingNotificationRequests();
      if (kDebugMode) {
        print('📋 Total pending notifications: \\${pending.length}');
      }
      for (var notification in pending) {
        if (kDebugMode) {
          print('  - ID: \\${notification.id}, Title: \\${notification.title}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error scheduling test notifications: $e');
      }
    }
  }

  // Cancel test notification
  Future<void> cancelTestNotification() async {
    await _localNotificationService.cancel(999);
    await _localNotificationService.cancel(998);
    await _localNotificationService.cancel(997);
    await _localNotificationService.cancel(996);
    await _localNotificationService.cancel(995);
    if (kDebugMode) {
      print('All test notifications cancelled');
    }
  }

  Future<void> intialize() async {
    tz.initializeTimeZones();
    final String timeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZone));
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@drawable/ic_launcher');

    DarwinInitializationSettings iosInitializationSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _localNotificationService.getNotificationAppLaunchDetails();

    var payload = notificationAppLaunchDetails!.notificationResponse?.payload;
    if (payload != null) {
      // The String sent to the payload parameter in zonedSchedule() must
      // be a valid route. '/morning' for example.
      routeToGo = payload;

      // I do not know why I had pushNamed() in the first place, but it was
      // causing a bug that required two presses of the back button to get
      // back to the home screen, but only when the app was closed, and the
      // notification was clicked.
      // navigatorKey.currentState?.pushNamed('/second');
    }

    await _localNotificationService.initialize(
      settings,
      onDidReceiveNotificationResponse: onSelectNotification,
    );

    // D-038/D-065: permission is requested explicitly, by the setup flow
    // right after the completion moment settles — never here. Calling
    // intialize() wires up the plugin (timezone, tap routing) so scheduling
    // works once permission exists; it must never itself prompt on launch.
  }

  /// D-065: called once, immediately after D-046's completion moment
  /// settles. D-038: denial degrades nothing and this is never re-asked on
  /// a schedule — callers should not invoke this more than once per
  /// install.
  Future<void> requestPermissions() => _requestNotificationPermissions();

  Future<void> _requestNotificationPermissions() async {
    try {
      // Platform-specific permission requests
      if (Platform.isAndroid) {
        // Request permissions for Android
        final bool? granted = await _localNotificationService
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();

        if (kDebugMode) {
          print('Android notification permission granted: $granted');
        }

        // Check if notifications are enabled
        final bool? areNotificationsEnabled = await _localNotificationService
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.areNotificationsEnabled();

        if (kDebugMode) {
          print('Android notifications enabled: $areNotificationsEnabled');
        }

        // Request battery optimization exemption (Android only)
        await _requestBatteryOptimizationExemption();

        // USE_EXACT_ALARM is handled via manifest, no runtime request needed
        if (kDebugMode) {
          print('USE_EXACT_ALARM permission handled via manifest');
        }
      } else if (Platform.isIOS) {
        // iOS permissions are handled during initialization
        if (kDebugMode) {
          print('iOS notification permissions handled during initialization');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting notification permissions: $e');
      }
    }
  }

  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      // Only request battery optimization exemption on Android
      if (Platform.isAndroid) {
        final status = await Permission.ignoreBatteryOptimizations.status;
        if (status.isDenied) {
          final result = await Permission.ignoreBatteryOptimizations.request();
          if (kDebugMode) {
            print('Android battery optimization exemption result: $result');
          }
        } else {
          if (kDebugMode) {
            print(
                'Android battery optimization exemption already granted: $status');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting battery optimization exemption: $e');
      }
    }
  }

  Future<bool> _canScheduleExactAlarms() async {
    try {
      // Only check exact alarms on Android
      if (Platform.isAndroid) {
        // For Android 12+, we assume exact alarms are available if the permission is in manifest
        // The system will handle the permission automatically
        if (kDebugMode) {
          print(
              'Android: Assuming exact alarms are available (permission in manifest)');
        }
        return true;
      } else {
        // iOS doesn't have exact alarm restrictions like Android
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error checking exact alarm permission: $e');
      }
      return false;
    }
  }

  Future<AndroidScheduleMode> _getOptimalScheduleMode() async {
    if (Platform.isAndroid) {
      final canScheduleExact = await _canScheduleExactAlarms();
      if (canScheduleExact) {
        if (kDebugMode) {
          print('Android: Using exactAllowWhileIdle scheduling mode');
        }
        return AndroidScheduleMode.exactAllowWhileIdle;
      } else {
        if (kDebugMode) {
          print('Android: Using exact scheduling mode (fallback)');
        }
        return AndroidScheduleMode.exact;
      }
    } else {
      // iOS doesn't use AndroidScheduleMode, but we need to return something
      // This will be ignored for iOS scheduling
      return AndroidScheduleMode.exact;
    }
  }

  Future<void> scheduleDailyNotification(
      {required int id,
      required String title,
      required int hour,
      required int minute,
      required String payload,
      String? body}) async {
    final scheduleMode = await _getOptimalScheduleMode();
    bool idFound = false;
    var pending = await _localNotificationService.pendingNotificationRequests();
    for (var i = 0; i < pending.length; i++) {
      if (pending[i].id == id) {
        idFound = true;
        if (kDebugMode) {
          print(
              '${Platform.isAndroid ? 'Android' : 'iOS'}: Pending notification with id $id found');
        }
      }
    }
    if (!idFound) {
      // Generate dynamic message based on notification ID
      // D-038: an explicit body (cached server content, or the D-063
      // static pool) overrides the built-in generic message pool.
      String dynamicBody = body ?? _generateNotificationMessage(id);
      // Create iOS details with the question as the body
      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        sound: 'doublebeep.aiff',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const AndroidNotificationDetails androidNotificationDetails =
          AndroidNotificationDetails(
        'green_pyramid_channel',
        'Green Pyramid Notifications',
        channelDescription: 'Notifications for Green Pyramid app',
        importance: Importance.max,
        priority: Priority.max,
        sound: RawResourceAndroidNotificationSound('doublebeep'),
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showWhen: true,
        autoCancel: false,
        ongoing: false,
        channelShowBadge: true,
        icon: '@mipmap/launcher_icon',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
        category: AndroidNotificationCategory.reminder,
        visibility: NotificationVisibility.public,
        timeoutAfter: 30000,
      );
      final NotificationDetails details = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosDetails,
      );
      await _localNotificationService.zonedSchedule(
        id,
        title,
        dynamicBody,
        nextInstanceOfTime(hour, minute),
        details,
        androidScheduleMode: scheduleMode,
        payload: payload,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      if (kDebugMode) {
        print(
            '✅ Daily notification scheduled for $title at $hour:$minute using mode: $scheduleMode');
      }
    }
  }

  tz.TZDateTime nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  /// D-038: lets a caller refresh or clear a previously-scheduled fallback
  /// notification (cancel before reschedule, since [scheduleDailyNotification]
  /// no-ops when the id is already pending).
  Future<void> cancelDailyNotification(int id) =>
      _localNotificationService.cancel(id);

  /// D-036: a push arriving while the app is in the foreground is not
  /// auto-displayed by the OS on most platforms — this shows it
  /// immediately via the same local-notification channel.
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'green_pyramid_channel',
      'Green Pyramid Notifications',
      channelDescription: 'Notifications for Green Pyramid app',
      importance: Importance.max,
      priority: Priority.max,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    await _localNotificationService.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {}

  onSelectNotification(NotificationResponse notificationResponse) {
    var payload = notificationResponse.payload;
    if (payload != null && payload.isNotEmpty) {
      onNotificationClick.add(payload);
    }
  }

  // Simple iOS notification test
  Future<void> testIOSNotification() async {
    try {
      await _localNotificationService.show(
        888,
        'iOS Test Title',
        'This is the iOS test body message',
        const NotificationDetails(
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      if (kDebugMode) {
        print('✅ iOS test notification sent');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ iOS test notification failed: $e');
      }
    }
  }
}
