import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter/material.dart' show MaterialPageRoute, RouteSettings;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rxdart/subjects.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:path_provider/path_provider.dart';
import 'package:life_ops/main.dart';
import 'package:life_ops/screens/batch_checkin_screen.dart';
import 'package:life_ops/screens/newsfeed_screen.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:math';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

/// D-099 Phase 3: one "starting soon" reminder slot for a scheduled
/// habit — one per day it recurs on. Pure value object, no plugin
/// calls, so the scheduling math is directly testable.
class HabitReminderSlot {
  final int notificationId;
  final int weekday; // the habit's own day (DateTime.monday..sunday) — the
  // notification id's identity, independent of which calendar day
  // [fireTime] actually lands on (see buildHabitReminderSlots).
  final DateTime fireTime;

  const HabitReminderSlot({
    required this.notificationId,
    required this.weekday,
    required this.fireTime,
  });
}

/// D-099 Phase 3: a habit-reminder notification id is derived from the
/// habit's own row id and the specific weekday it reminds for — stable
/// and collision-free (distinct from the small, hand-picked ids D-149's
/// three daily fallbacks and D-090's test notification already use: 100,
/// 101, 102, 999999) so a reminder can be found and cancelled later
/// without re-deriving it from a hash.
const int habitReminderBaseId = 600000000;

int habitReminderId(int habitId, int weekday) =>
    habitReminderBaseId + habitId * 10 + weekday;

/// D-179: weekday slots occupy `1..7`, leaving `0` free for the single
/// daily-repeating reminder a habit active every day collapses to.
const int habitReminderDailySlot = 0;

bool isHabitReminderId(int id) => id >= habitReminderBaseId;

/// The habit a reminder id belongs to, so a reminder whose habit no longer
/// exists can be recognised and cancelled.
int habitIdFromReminderId(int id) => (id - habitReminderBaseId) ~/ 10;

/// D-099 Phase 3: the fire time for each of a scheduled habit's
/// "starting soon" reminders — [leadMinutes] before the habit's own
/// time, on every day in [activeWeekdays] (`DateTime.monday..sunday`).
/// Pure — no plugin calls — so it's testable without a live drag
/// gesture or a registered notification plugin, the same pattern this
/// codebase already uses for `CalendarService.anchorFor`.
///
/// Subtracting [leadMinutes] can roll the reminder itself onto the
/// *previous* calendar day (a habit at 00:05 with a 10-minute lead
/// reminds at 23:55 the day before) — [HabitReminderSlot.fireTime]
/// reflects that correctly, but [HabitReminderSlot.weekday] still names
/// the habit's own day, since that's the slot's stable identity for
/// [habitReminderId], not the day the reminder happens to fire on.
List<HabitReminderSlot> buildHabitReminderSlots({
  required int habitId,
  required int hour,
  required int minute,
  required List<int> activeWeekdays,
  int leadMinutes = 10,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final slots = <HabitReminderSlot>[];

  // D-179: iOS keeps at most 64 pending local notifications per app and
  // silently drops the rest. One slot per active weekday meant a habit
  // active every day — the shape most habits have — cost seven of them, so
  // a full pyramid exhausted the budget. A habit active on all seven days
  // is exactly a daily repeat, so it needs one.
  if (activeWeekdays.toSet().length == 7) {
    final habitTime =
        DateTime(reference.year, reference.month, reference.day, hour, minute);
    var fireTime = habitTime.subtract(Duration(minutes: leadMinutes));
    if (!fireTime.isAfter(reference)) {
      fireTime = fireTime.add(const Duration(days: 1));
    }
    return [
      HabitReminderSlot(
        notificationId: habitReminderId(habitId, habitReminderDailySlot),
        weekday: habitReminderDailySlot,
        fireTime: fireTime,
      ),
    ];
  }

  for (final weekday in activeWeekdays) {
    final anchorDate = _nextOrSameWeekday(reference, weekday);
    final habitTime = DateTime(
        anchorDate.year, anchorDate.month, anchorDate.day, hour, minute);
    var fireTime = habitTime.subtract(Duration(minutes: leadMinutes));
    if (!fireTime.isAfter(reference)) {
      fireTime = fireTime.add(const Duration(days: 7));
    }
    slots.add(HabitReminderSlot(
      notificationId: habitReminderId(habitId, weekday),
      weekday: weekday,
      fireTime: fireTime,
    ));
  }
  return slots;
}

DateTime _nextOrSameWeekday(DateTime from, int weekday) {
  final fromDate = DateTime(from.year, from.month, from.day);
  final diff = (weekday - fromDate.weekday) % 7;
  return fromDate.add(Duration(days: diff));
}

class LocalNotificationService {
  LocalNotificationService();

  final _localNotificationService = FlutterLocalNotificationsPlugin();

  final BehaviorSubject<String?> onNotificationClick = BehaviorSubject();

  // A notification tap that launches a terminated app is discovered before
  // Flutter has a navigator. Keep structured payloads out of routeToGo —
  // they are data, not named routes — and let HomeScreenWidget consume them
  // after its navigator and account gate are ready.
  static String? _pendingInitialPayload;
  String? _notificationArtworkPathCache;

  /// D-179: iOS *moves* a notification attachment's file out of its original
  /// location into the private attachment data store when it validates the
  /// request, so one artwork file can back exactly one notification. Every
  /// iOS attachment therefore gets its own disposable copy; the shared file
  /// below is never handed to iOS directly, so it survives to be copied
  /// again. Android is unaffected — its big-picture style reads the path
  /// when the notification is *displayed*, so it needs the stable file.
  ///
  /// Returns null on any failure, which every caller already treats as
  /// "send this notification without artwork" rather than not sending it.
  Future<String?> _disposableIosArtworkPath() async {
    if (!Platform.isIOS) return null;
    final source = await _notificationArtworkPath();
    if (source == null) return null;
    try {
      final directory = await getApplicationSupportDirectory();
      final copies = Directory('${directory.path}/notification_artwork');
      await copies.create(recursive: true);
      await _pruneArtworkCopies(copies);
      final copy = File('${copies.path}/'
          '${DateTime.now().microsecondsSinceEpoch}_${_artworkCopySequence++}.jpg');
      await File(source).copy(copy.path);
      return copy.path;
    } catch (e) {
      debugPrint('Notification artwork copy unavailable: $e');
      return null;
    }
  }

  /// A copy iOS accepted is moved away by the OS; one it rejected is left
  /// behind. Sweep the leftovers so a repeatedly failing attachment cannot
  /// grow without bound.
  Future<void> _pruneArtworkCopies(Directory copies) async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 1));
      await for (final entity in copies.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) {
          await entity.delete();
        }
      }
    } catch (e) {
      debugPrint('Notification artwork prune skipped: $e');
    }
  }

  int _artworkCopySequence = 0;

  /// D-149: copy the app's scenic brand image to a file location accepted by
  /// iOS notification attachments and Android big-picture notifications.
  /// Remote push notifications remain OS-rendered; this artwork is used for
  /// local fallbacks and foreground-rendered pushes where the app controls
  /// the notification details.
  Future<String?> _notificationArtworkPath() async {
    if (_notificationArtworkPathCache != null) {
      return _notificationArtworkPathCache;
    }
    try {
      final directory = await getApplicationSupportDirectory();
      final file = File('${directory.path}/green_pyramid_notification.jpg');
      if (!await file.exists()) {
        final data = await rootBundle.load('images/jungle_bg.jpg');
        await file.writeAsBytes(data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        ));
      }
      _notificationArtworkPathCache = file.path;
      return file.path;
    } catch (e) {
      debugPrint('Notification artwork unavailable: $e');
      return null;
    }
  }

  static String? takePendingInitialPayload() {
    final payload = _pendingInitialPayload;
    _pendingInitialPayload = null;
    return payload;
  }

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

  static const int testNotificationId = 999999;

  /// D-090: schedules a single local test notification 1 minute from
  /// now, on the same delivery channel D-149's fallback notifications
  /// use — lets the user confirm OS-level notification permission and
  /// delivery actually work, mirroring Kansei's identical settings-screen
  /// feature. Replaces the previous version's five-notification burst
  /// that routed to '/morning', '/afternoon', '/evening' — screens D-066
  /// deleted; those routes no longer exist in this app.
  Future<void> scheduleTestNotification() async {
    await _localNotificationService.cancel(testNotificationId);
    final scheduledTime =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
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
    const NotificationDetails details = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosDetails,
    );
    await _localNotificationService.zonedSchedule(
      testNotificationId,
      'Green Pyramid',
      "Notifications are working — this is what a reminder from the "
          'Council of Advisors looks like.',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '/',
      matchDateTimeComponents: null,
    );
  }

  Future<void> cancelTestNotification() =>
      _localNotificationService.cancel(testNotificationId);

  /// Account deletion must not leave reminders referring to erased habits.
  Future<void> cancelAllPendingNotifications() =>
      _localNotificationService.cancelAll();

  /// Returns true if the test notification is still scheduled (hasn't
  /// fired) — mirrors Kansei's identical `isTestNotificationPending`.
  Future<bool> isTestNotificationPending() async {
    final pending =
        await _localNotificationService.pendingNotificationRequests();
    return pending.any((n) => n.id == testNotificationId);
  }

  Future<void> intialize() async {
    tz.initializeTimeZones();
    final String timeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZone));
    const AndroidInitializationSettings androidInitializationSettings =
        AndroidInitializationSettings('@drawable/ic_launcher');

    // D-149/D-050: these must stay false. The plugin's initialize() call
    // itself requests permission immediately when they're true — on iOS
    // that means the OS dialog fires at app launch, not from D-050's
    // screen. Permission is requested explicitly later via
    // IOSFlutterLocalNotificationsPlugin.requestPermissions() in
    // _requestNotificationPermissions().
    DarwinInitializationSettings iosInitializationSettings =
        const DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    final InitializationSettings settings = InitializationSettings(
      android: androidInitializationSettings,
      iOS: iosInitializationSettings,
    );

    final NotificationAppLaunchDetails? notificationAppLaunchDetails =
        await _localNotificationService.getNotificationAppLaunchDetails();

    final payload = notificationAppLaunchDetails?.notificationResponse?.payload;
    if (payload != null) {
      if (payload.startsWith('{')) {
        // Structured payloads need a live navigator so their type-specific
        // destination can be resolved. A JSON object is never a valid named
        // route; passing it to initialRoute produced the black/error screen
        // seen when tapping the test notification from a terminated app.
        _pendingInitialPayload = payload;
        routeToGo = '/';
      } else {
        // Legacy/simple local notifications still carry a real route string.
        routeToGo = payload;
      }

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
  }

  /// D-050: called once, immediately after D-034's completion moment
  /// settles. D-149: denial degrades nothing and this is never re-asked on
  /// a schedule — callers should not invoke this more than once per
  /// install.
  ///
  /// D-144: also reused from Settings' notification banner for an account
  /// that completed setup before D-050's screen existed and so has never
  /// called this at all — found live: on such an account, iOS never
  /// creates a Notifications entry under Settings > Green Pyramid in the
  /// first place, because the OS only adds that entry once an app has
  /// actually invoked the permission-request API. Returns whether
  /// permission ended up granted, so a caller can tell "just granted it"
  /// from "already decided (denied) earlier — nothing to (re-)ask, direct
  /// to Settings instead," which iOS itself distinguishes: calling this
  /// again after a prior denial returns false immediately with no dialog.
  Future<bool> requestPermissions() => _requestNotificationPermissions();

  /// D-144: the real, current OS authorization state — distinct from
  /// [isTestNotificationPending], which only confirms the plugin
  /// *accepted* a schedule request. iOS happily "schedules" a
  /// notification with permission denied and silently drops it at
  /// delivery time with no error anywhere, which is exactly what made
  /// this invisible: found live, the owner tapped "Send test
  /// notification," saw it go to "Pending…," and nothing ever arrived,
  /// with no indication why. Uses this plugin's own
  /// checkPermissions() (already correctly wired, no extra native
  /// config) rather than package:permission_handler's
  /// Permission.notification — that package requires an iOS Podfile
  /// macro (PERMISSION_NOTIFICATIONS) this project has never enabled
  /// for any permission group, so it would have silently returned a
  /// wrong status rather than the real one.
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final enabled = await _localNotificationService
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      return enabled ?? false;
    }
    if (Platform.isIOS) {
      final options = await _localNotificationService
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.checkPermissions();
      return options?.isEnabled ?? false;
    }
    return true;
  }

  Future<bool> _requestNotificationPermissions() async {
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

        // Request battery optimization exemption (Android only)
        await _requestBatteryOptimizationExemption();

        // USE_EXACT_ALARM is handled via manifest, no runtime request needed
        if (kDebugMode) {
          print('USE_EXACT_ALARM permission handled via manifest');
        }

        return granted ?? false;
      } else if (Platform.isIOS) {
        // D-050: initialize() no longer requests permission (see
        // intialize() above) — this is what actually shows the OS dialog.
        final bool? granted = await _localNotificationService
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);

        if (kDebugMode) {
          print('iOS notification permission granted: $granted');
        }

        return granted ?? false;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting notification permissions: $e');
      }
      return false;
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
      // D-149: an explicit body (cached server content, or the D-049
      // static pool) overrides the built-in generic message pool.
      String dynamicBody = body ?? _generateNotificationMessage(id);
      final artworkPath = await _notificationArtworkPath();
      final iosArtworkPath = await _disposableIosArtworkPath();
      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        sound: 'doublebeep.aiff',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments: iosArtworkPath == null
            ? null
            : <DarwinNotificationAttachment>[
                DarwinNotificationAttachment(iosArtworkPath),
              ],
      );
      final AndroidNotificationDetails androidNotificationDetails =
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
        styleInformation: artworkPath == null
            ? null
            : BigPictureStyleInformation(
                FilePathAndroidBitmap(artworkPath),
                contentTitle: title,
                summaryText: dynamicBody,
                hideExpandedLargeIcon: true,
              ),
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

  /// D-149: lets a caller refresh or clear a previously-scheduled fallback
  /// notification (cancel before reschedule, since [scheduleDailyNotification]
  /// no-ops when the id is already pending).
  Future<void> cancelDailyNotification(int id) =>
      _localNotificationService.cancel(id);

  /// D-099 Phase 3: schedules a "starting soon" reminder [leadMinutes]
  /// before a scheduled habit's own time, recurring weekly on every day
  /// it's active — matching Kansei's own `scheduleSessionReminders`, but
  /// as a genuinely *recurring* notification per active day
  /// (`DateTimeComponents.dayOfWeekAndTime`) rather than Kansei's
  /// one-time `zonedSchedule`, since a habit repeats every week rather
  /// than firing once like a dated session. Deliberately does NOT port
  /// the other half of Kansei's pair — the "Did you do it?" reminder at
  /// session-end — D-099 replaces that with one server-triggered,
  /// batched push per day instead, not a per-habit local notification.
  /// Cancels every one of the habit's 7 possible weekday slots first, so
  /// a day that's no longer active never leaves a stale reminder behind.
  /// Returns false when notification authorization is unavailable or the
  /// native plugin does not report every requested slot as pending.
  Future<bool> scheduleHabitReminders({
    required int habitId,
    required String habitDescription,
    required int hour,
    required int minute,
    required List<int> activeWeekdays,
    int leadMinutes = 10,
  }) async {
    // Scheduling APIs accept requests even when iOS will later discard them
    // because notification authorization is off. Ask at the moment the user
    // creates the schedule so a reminder cannot silently disappear.
    if (!await areNotificationsEnabled()) {
      await requestPermissions();
      if (!await areNotificationsEnabled()) {
        debugPrint(
            'Habit reminder not scheduled: notification permission is off');
        return false;
      }
    }

    await cancelHabitReminders(habitId);
    if (activeWeekdays.isEmpty) return true;

    final slots = buildHabitReminderSlots(
      habitId: habitId,
      hour: hour,
      minute: minute,
      activeWeekdays: activeWeekdays,
      leadMinutes: leadMinutes,
    );

    final artworkPath = await _notificationArtworkPath();
    final androidDetails = AndroidNotificationDetails(
      'green_pyramid_channel',
      'Green Pyramid Notifications',
      channelDescription: 'Notifications for Green Pyramid app',
      importance: Importance.max,
      priority: Priority.max,
      sound: RawResourceAndroidNotificationSound('doublebeep'),
      playSound: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      styleInformation: artworkPath == null
          ? null
          : BigPictureStyleInformation(
              FilePathAndroidBitmap(artworkPath),
              contentTitle: 'Keep showing up',
              summaryText:
                  'Your $habitDescription starts in $leadMinutes minutes.',
              hideExpandedLargeIcon: true,
            ),
    );
    for (final slot in slots) {
      // D-179: a fresh attachment copy per request — iOS consumes the file
      // it is given, so one shared path would schedule the first slot and
      // reject the rest.
      final iosArtworkPath = await _disposableIosArtworkPath();
      final details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          sound: 'doublebeep.aiff',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          attachments: iosArtworkPath == null
              ? null
              : <DarwinNotificationAttachment>[
                  DarwinNotificationAttachment(iosArtworkPath),
                ],
        ),
      );
      try {
        await _localNotificationService.zonedSchedule(
          slot.notificationId,
          'Keep showing up',
          '$habitDescription — starts in $leadMinutes min.',
          tz.TZDateTime.from(slot.fireTime, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          // D-179: the collapsed all-week slot repeats daily, not weekly.
          matchDateTimeComponents: slot.weekday == habitReminderDailySlot
              ? DateTimeComponents.time
              : DateTimeComponents.dayOfWeekAndTime,
          payload: '/',
        );
      } catch (e) {
        // D-179: the native side rejects a request by returning an error,
        // which the plugin raises as a PlatformException. Unhandled, it
        // escaped this method and the scheduling screen's own handler, so
        // the "reminder could not be scheduled" notice below was never
        // reached and the failure was completely silent.
        debugPrint(
            'Habit reminder slot ${slot.notificationId} was rejected: $e');
      }
    }

    // The plugin can acknowledge a request even when the native platform
    // rejects it. Verify that every recurring slot is actually pending so the
    // scheduling screen can tell the user that calendar scheduling succeeded
    // but reminder delivery still needs attention.
    final pending =
        await _localNotificationService.pendingNotificationRequests();
    final pendingIds = pending.map((request) => request.id).toSet();
    final missing = slots
        .where((slot) => !pendingIds.contains(slot.notificationId))
        .map((slot) => slot.notificationId)
        .toList();
    if (missing.isNotEmpty) {
      debugPrint('Habit reminder slots missing after scheduling: $missing');
      return false;
    }
    return true;
  }

  /// D-099 Phase 3: cancels all 7 possible weekday reminder slots for a
  /// habit — unconditional and idempotent, since cancelling an id with
  /// no pending notification is a no-op. Called both when a habit is
  /// unscheduled entirely and as the first step of
  /// [scheduleHabitReminders], so a changed set of active days never
  /// leaves a stale reminder for a day that's no longer active.
  Future<void> cancelHabitReminders(int habitId) async {
    // D-179: slot 0 is the collapsed daily variant, 1..7 the per-weekday
    // ones. Cancelling every shape means switching between them — or
    // between two different sets of active days — leaves nothing behind.
    for (var slot = habitReminderDailySlot; slot <= DateTime.sunday; slot++) {
      await _localNotificationService.cancel(habitReminderId(habitId, slot));
    }
  }

  /// D-179: cancels habit reminders whose habit no longer exists.
  ///
  /// Wiping the pyramid (a rebuild, an account switch) deleted the habit
  /// rows without cancelling their reminders, so every rebuild stranded up
  /// to seven permanently pending notifications belonging to habit ids that
  /// were gone. Nothing could ever cancel them again — no habit owns them
  /// and no screen lists them — and they still counted against the 64
  /// pending notifications iOS allows, eventually crowding out the live
  /// reminders. Returns the ids it removed.
  Future<List<int>> pruneOrphanHabitReminders(Set<int> liveHabitIds) async {
    final pending =
        await _localNotificationService.pendingNotificationRequests();
    final orphans = pending
        .map((request) => request.id)
        .where(isHabitReminderId)
        .where((id) => !liveHabitIds.contains(habitIdFromReminderId(id)))
        .toList();
    for (final id in orphans) {
      await _localNotificationService.cancel(id);
    }
    if (orphans.isNotEmpty) {
      debugPrint('Cancelled orphaned habit reminders: $orphans');
    }
    return orphans;
  }

  /// D-179: what the OS is actually holding. The plugin exposes no fire
  /// time, so this reports identity only — enough to answer "was this
  /// reminder ever really scheduled?", which is the question a silently
  /// rejected request leaves open.
  Future<List<PendingNotificationRequest>> pendingNotifications() =>
      _localNotificationService.pendingNotificationRequests();

  /// D-149: a push arriving while the app is in the foreground is not
  /// auto-displayed by the OS on most platforms — this shows it
  /// immediately via the same local-notification channel.
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final artworkPath = await _notificationArtworkPath();
    final androidDetails = AndroidNotificationDetails(
      'green_pyramid_channel',
      'Green Pyramid Notifications',
      channelDescription: 'Notifications for Green Pyramid app',
      importance: Importance.max,
      priority: Priority.max,
      styleInformation: artworkPath == null
          ? null
          : BigPictureStyleInformation(
              FilePathAndroidBitmap(artworkPath),
              contentTitle: title,
              summaryText: body,
              hideExpandedLargeIcon: true,
            ),
    );
    final iosArtworkPath = await _disposableIosArtworkPath();
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      attachments: iosArtworkPath == null
          ? null
          : <DarwinNotificationAttachment>[
              DarwinNotificationAttachment(iosArtworkPath),
            ],
    );
    await _localNotificationService.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: payload,
    );
  }

  void onDidReceiveLocalNotification(
      int id, String? title, String? body, String? payload) {}

  void handleNotificationPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    // D-099 Phase 5: a structured JSON payload (currently only the batch
    // check-in's foreground-shown local notification uses this shape,
    // via main.dart's batchCheckinPayloadFrom) routes directly, rather
    // than going through the plain route-string path below — which
    // pushes a stacked duplicate HomeScreen for anything that isn't a
    // real named route (D-066's amendment).
    if (payload.startsWith('{')) {
      _handleStructuredPayload(payload);
      return;
    }
    onNotificationClick.add(payload);
  }

  void onSelectNotification(NotificationResponse notificationResponse) {
    handleNotificationPayload(notificationResponse.payload);
  }

  void _handleStructuredPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      switch (data['type']) {
        case 'batch_checkin':
          final habitsJson = data['habits'] as String?;
          if (habitsJson == null) {
            // D-149 transports only stable habit ids. Resolve current local
            // records at tap time so deleted habits are harmless and the
            // occurrence date remains the server-supplied date.
            openBatchCheckinFromPayload(data);
            return;
          }
          final habits =
              (jsonDecode(habitsJson) as List).cast<Map<String, dynamic>>();
          navigatorKey.currentState?.push(MaterialPageRoute(
              settings: const RouteSettings(name: 'BatchCheckinScreen'),
              builder: (_) => BatchCheckinScreen(habits: habits)));
        case 'tailored':
        case 'intervention':
        case 'upgrade':
          handlePushDataTap(data);
          break;
        case 'newsfeed_item':
          // D-122: "when you tap the notification, it will go directly
          // to the newsfeed" — and, specifically, scrolled to and
          // highlighting the exact item the notification was about.
          final dedupeKey = data['dedupeKey'] as String?;
          if (dedupeKey == null) return;
          navigatorKey.currentState?.push(MaterialPageRoute(
              settings: const RouteSettings(name: 'NewsfeedScreen'),
              builder: (_) => NewsfeedScreen(highlightDedupeKey: dedupeKey)));
      }
    } catch (e, st) {
      debugPrint('Failed to handle structured notification payload: $e\n$st');
    }
  }

  /// D-122: the Settings "Send test notification" control now behaves
  /// exactly like a real newsfeed notification — owner: "the button to
  /// send a test notification to behave the same way that it will have
  /// a headline of one of the news items and when you tap the
  /// notification it brings you to that headline in the newsfeed."
  /// Reuses [testNotificationId] so the existing pending/cancel tracking
  /// in Settings keeps working unchanged.
  Future<void> scheduleNewsfeedTestNotification({
    required String title,
    required String body,
    required String dedupeKey,
  }) async {
    await _localNotificationService.cancel(testNotificationId);
    final scheduledTime =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
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
    const NotificationDetails details = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iosDetails,
    );
    await _localNotificationService.zonedSchedule(
      testNotificationId,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({'type': 'newsfeed_item', 'dedupeKey': dedupeKey}),
      matchDateTimeComponents: null,
    );
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
