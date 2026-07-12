import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:life_ops/notification.dart';
import 'package:life_ops/morning.dart';
import 'package:life_ops/afternoon.dart';
import 'package:life_ops/evening.dart';
import 'package:life_ops/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

Future<void> showPreviewWarningDialog(BuildContext context) async {
  if (!Platform.isIOS) return; // Only show on iOS

  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('How to Show Notification Previews'),
      content: SizedBox(
        width: 350,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'To see the full content of notifications, you must set "Show Previews" to "Always" for Green Pyramid notifications.\n',
                style: TextStyle(fontSize: 16),
              ),
              const Text(
                'Step 1:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Image.asset(
                'images/previews1.jpg',
                fit: BoxFit.contain,
                width: 320,
                height: 220,
              ),
              const SizedBox(height: 8),
              const Text(
                'Open your iPhone Settings, scroll down and tap on "Green Pyramid", then tap "Notifications".',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Step 2:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Image.asset(
                'images/previews2.jpg',
                fit: BoxFit.contain,
                width: 320,
                height: 220,
              ),
              const SizedBox(height: 8),
              const Text(
                'Scroll down to "Show Previews" and set it to "Always". This will allow notification content to be visible.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              const Text(
                'After making this change, return to the app and test notifications again.',
                style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            if (await canLaunchUrl(Uri.parse('app-settings:'))) {
              await launchUrl(Uri.parse('app-settings:'));
            }
            Navigator.of(context).pop();
          },
          child: const Text('Open Notification Settings'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

class Settings extends StatefulWidget {
  const Settings();

  @override
  _SettingsState createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  DateFormat dowFmt = DateFormat('EEEE');
  var todayFmt;
  late final LocalNotificationService lns;

  @override
  void initState() {
    todayFmt = dowFmt.format(DateTime.now()).toString();
    lns = LocalNotificationService();
    lns.intialize();
    super.initState();
  }

  var allNotifications = const NotificationSwitch();

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'settings');
    double pyramidHeight = MediaQuery.of(context).size.width * 0.82;
    SizedBox smallSpacer = SizedBox(height: pyramidHeight * .1);

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Exo2');

    List<Map<String, String>> notifications = [];
    notifications = [
      {
        'desc': 'Morning',
        'timeofday': '9am',
      },
      {
        'desc': 'Afternoon',
        'timeofday': '12pm',
      },
      {
        'desc': 'Evening',
        'timeofday': '8pm',
      },
    ];

    return SafeArea(
        child: Scaffold(
            body: Center(
                child: Column(children: [
      smallSpacer,
      Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  'Notifications',
                  style: mainTextStyle,
                )

                /* Re-enable this once I store notifications in the db

                            Column(
                                children: <Widget>[
                                  Container(
                                      width: (screenWidth/2) - 10,
                                      height: 100,
                                      // color: Colors.blue,
                                    alignment: Alignment.centerLeft,
                                    child: Text('Notifications')
                                  ),
                                ]),
                            Column(
                                children: <Widget>[
                                  Container(
                                    width: (screenWidth/2) - 10,
                                    // color: Colors.yellow,
                                    alignment: Alignment.topRight,
                                    child: allNotifications,
                                  ),
                                ])

                            */
              ])),
      Container(
          height: MediaQuery.of(context).size.height / 3,
          child: Scrollbar(
              child: ListView.builder(
                  itemCount: notifications.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text('${notifications[index]['desc']}'),
                      subtitle: Text('${notifications[index]['timeofday']}'),
                      onTap: () {
                        switch (index) {
                          case 0:
                            navigateToMorning(context);
                          case 1:
                            navigateToAfternoon(context);
                          case 2:
                            navigateToEvening(context);
                        }
                      },
                    );
                  }))),
      // Adjust Previews link - only show on iOS
      if (Platform.isIOS)
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: TextButton(
            onPressed: () async {
              await showPreviewWarningDialog(context);
            },
            child: const Text(
              'Adjust Previews',
              style: TextStyle(
                fontSize: 16,
                decoration: TextDecoration.underline,
                color: Colors.blue,
              ),
            ),
          ),
        ),
    ]))));
  }

  void navigateToMorning(BuildContext context) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Morning()))
        .then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
      });
    });
  }

  void navigateToAfternoon(BuildContext context) async {
    utils.Utils().changeSystemColor(Brightness.dark);

    await Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Afternoon()))
        .then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
      });
    });
  }

  void navigateToEvening(BuildContext context) async {
    utils.Utils().changeSystemColor(Brightness.dark);

    await Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Evening()))
        .then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
      });
    });
  }
}

class NotificationSwitch extends StatefulWidget {
  const NotificationSwitch({super.key});

  @override
  State<NotificationSwitch> createState() => _NotificationSwitchState();
}

class _NotificationSwitchState extends State<NotificationSwitch> {
  _NotificationSwitchState();

  // A bit crazy that I am doing both of these, but could not
  // easily consolidate to just LocalNotificationService...
  late final LocalNotificationService lns;
  final service = FlutterLocalNotificationsPlugin();
  bool toggle = true;

  @override
  void initState() {
    lns = LocalNotificationService();
    lns.intialize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // This is how I determine whether the toggle should be on or off.
    // alternatively, I could store the toggle state in the database.
    int notificationCount = 0;
    getNotificationCount().then((value) {
      notificationCount = value;
      if (notificationCount == 0) {
        toggle = false;
      }
    });

    return Switch(
      // This bool value toggles the switch.
      value: toggle,
      activeColor: Colors.blue,
      onChanged: (bool value) {
        // This is called when the user toggles the switch.
        setState(() {
          toggle = value;
          if (!value) {
            turnOffNotificationsDialog();
          } else {
            turnOnAllNotifications();
          }
        });
      },
    );
  }

  turnOnAllNotifications() {
    lns.scheduleDailyNotification(
        id: 0,
        title: 'Morning Review',
        hour: 9,
        minute: 00,
        payload: '/morning');

    lns.scheduleDailyNotification(
        id: 1,
        title: 'Afternoon Review',
        hour: 12,
        minute: 00,
        payload: '/afternoon');

    lns.scheduleDailyNotification(
        id: 2,
        title: 'Evening Review',
        hour: 20,
        minute: 00,
        payload: '/evening');
  }

  turnOffNotificationsDialog() {
    // set up the buttons
    Widget cancelButton = TextButton(
      child: const Text("Cancel"),
      onPressed: () {
        toggle = true;
        Navigator.pop(context);
        setState(() {});
      },
    );
    Widget continueButton = TextButton(
      child: const Text("Turn Off"),
      onPressed: () async {
        setState(() {});
        var res = await cancelAllNotifications();
        if (kDebugMode) {
          print(res);
        }
        Navigator.pop(context);
      },
    );
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: const Text("Turn Off All Notifications"),
      content:
          const Text("Are you sure you want to turn off all notifications? "
              "Individual notifications can be disabled instead. "),
      actions: [
        cancelButton,
        continueButton,
      ],
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  Future<int> cancelAllNotifications() async {
    var notificationCount;
    var pending = await service.pendingNotificationRequests();

    if (pending.isNotEmpty) {
      await service.cancelAll();
      pending = await service.pendingNotificationRequests();
      notificationCount = pending.length;
    } else {
      notificationCount = pending.length;
    }
    return notificationCount;
  }

  Future<int> getNotificationCount() async {
    var pending = await service.pendingNotificationRequests();
    return pending.length;
  }
}
