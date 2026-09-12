import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:life_ops/services/db.dart';
import 'package:life_ops/services/dbtools.dart';
import 'package:life_ops/screens/tasklist.dart';
import 'package:life_ops/services/utils.dart' as utils;
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:life_ops/theme/app_colors.dart';
import 'package:life_ops/widgets/pyramid_stack.dart';

enum Calendar { day, week, month, year }

class Pyramid extends StatefulWidget {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;
  final Future totalPctCompleteFuture;
  final ValueChanged<int>? onTimeScaleChanged;
  final VoidCallback? onReturnFromTaskList;

  const Pyramid(
      this.cat1Future,
      this.cat2Future,
      this.cat3Future,
      this.cat4Future,
      this.cat5Future,
      this.cat6Future,
      this.totalPctCompleteFuture,
      {this.onTimeScaleChanged, this.onReturnFromTaskList});

  @override
  State<Pyramid> createState() => _Pyramid();
}

class _Pyramid extends State<Pyramid> {
  Calendar calendarView = Calendar.week;

  int pctDays = 6;

  String? selectedMood;
  String? selectedCategory;

  final DBTools dbtools = DBTools();
  final dbHelper = DatabaseHelper.instance;

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'pyramid');

    double pyramidWidth = MediaQuery.of(context).size.width * 0.87;

    // D-131: text now sits over a full-bleed photo (was previously over a
    // plain default background) — explicit light colors so it stays
    // legible against the scrim below.
    var mainTextStyle = const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        fontFamily: 'Exo2',
        color: AppColors.textPrimary);

    var pctCompleteTextStyle = const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        fontFamily: 'Exo2',
        color: AppColors.textPrimary);

    var timeScaleTextStyle = const TextStyle(fontSize: 10, color: AppColors.textPrimary);

    return Stack(
      children: [
        // D-131: the jungle background now fills the entire screen (was
        // bounded to a small rounded card behind the pyramid). A gradient
        // scrim keeps the title/percent text and the segmented control
        // legible against the photo, same technique OnboardingBackdrop
        // already uses for onboarding screens — heavier at the very top
        // and bottom where text sits, lighter through the middle so the
        // photo (and the pyramid itself) still reads clearly.
        Positioned.fill(
          child: Image.asset(
            'images/jungle_bg.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.55),
                  AppColors.background.withValues(alpha: 0.15),
                  AppColors.background.withValues(alpha: 0.15),
                  AppColors.background.withValues(alpha: 0.6),
                ],
                stops: const [0.0, 0.25, 0.75, 1.0],
              ),
            ),
          ),
        ),
        _pyramidContent(pyramidWidth, mainTextStyle, pctCompleteTextStyle, timeScaleTextStyle),
      ],
    );
  }

  Widget _pyramidContent(
    double pyramidWidth,
    TextStyle mainTextStyle,
    TextStyle pctCompleteTextStyle,
    TextStyle timeScaleTextStyle,
  ) {
    double pyramidHeight = pyramidWidth / 0.87 * 0.82;
    SizedBox smallSpacer = SizedBox(height: pyramidHeight * .07);

    return SingleChildScrollView(
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        smallSpacer,
        Text(
          'Green Pyramid',
          style: mainTextStyle,
        ),
        smallSpacer,
        Container(
            margin: EdgeInsets.symmetric(horizontal: 0.05 * pyramidWidth),
            child: SegmentedButton<Calendar>(
              segments: <ButtonSegment<Calendar>>[
                ButtonSegment<Calendar>(
                    value: Calendar.day,
                    label: Text('Day', style: timeScaleTextStyle),
                    icon: const Icon(Icons.calendar_view_day)),
                ButtonSegment<Calendar>(
                    value: Calendar.week,
                    label: Text('Week', style: timeScaleTextStyle),
                    icon: const Icon(Icons.calendar_view_week)),
                ButtonSegment<Calendar>(
                    value: Calendar.month,
                    label: Text('Month', style: timeScaleTextStyle),
                    icon: const Icon(Icons.calendar_view_month)),
                ButtonSegment<Calendar>(
                    value: Calendar.year,
                    label: Text('Year', style: timeScaleTextStyle),
                    icon: const Icon(Icons.calendar_today)),
              ],
              selected: <Calendar>{calendarView},
              onSelectionChanged: (Set<Calendar> newSelection) {
                setState(() {
                  // By default there is only a single segment that can be
                  // selected at one time, so its value is always the first
                  // item in the selected set.
                  calendarView = newSelection.first;

                  // getCompletionPercentage is inclusive of today.
                  switch (calendarView) {
                    case Calendar.day:
                      pctDays = 0;
                      break;
                    case Calendar.week:
                      pctDays = 6;
                      break;
                    case Calendar.month:
                      pctDays = 29;
                      break;
                    case Calendar.year:
                      pctDays = 364;
                      break;
                  }
                  if (widget.onTimeScaleChanged != null) {
                    widget.onTimeScaleChanged!(pctDays);
                  }
                  setFutures();
                });
              },
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity(horizontal: -3, vertical: -3),
              ),
            )),
        smallSpacer,
        _jungleScene(
          pyramidWidth,
          PyramidStack(
            cat1Future: widget.cat1Future,
            cat2Future: widget.cat2Future,
            cat3Future: widget.cat3Future,
            cat4Future: widget.cat4Future,
            cat5Future: widget.cat5Future,
            cat6Future: widget.cat6Future,
            size: pyramidWidth,
            onCategoryTap: (index, category) {
              final today =
                  intl.DateFormat('yyyy-MM-dd').format(DateTime.now());
              navigateToTaskList(context, category.cat, today);
            },
          ),
        ),
        smallSpacer,
        FutureBuilder(
            future: widget.totalPctCompleteFuture,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              Widget display;
              if (!snapshot.hasData || snapshot.data == '') {
                display = Text(
                  '0 Percent Complete',
                  style: pctCompleteTextStyle,
                );
              } else {
                display = Text(
                  '${snapshot.data} Percent Complete',
                  style: pctCompleteTextStyle,
                );
              }
              return display;
            }),
      ]),
    );
  }

  // D-131: the photo-real jungle clearing is now the whole screen's
  // background (build()'s own Stack), not a card bounded to this widget —
  // this just centers the pyramid over it, no separate image of its own.
  Widget _jungleScene(double pyramidWidth, Widget pyramid) {
    return Align(alignment: Alignment.topCenter, child: pyramid);
  }

  void navigateToTaskList(
      BuildContext context, String cat, String today) async {
    utils.Utils().changeSystemColor(Brightness.dark);
    await Navigator.push(context,
            MaterialPageRoute(builder: (context) => TaskList(cat, today)))
        .then((_) {
      setState(() {
        utils.Utils().changeSystemColor(Brightness.light);
        setFutures();
      });
      if (widget.onReturnFromTaskList != null) {
        widget.onReturnFromTaskList!();
      }
    });
  }

  setFutures() {
    // These are now passed as widget parameters, so we don't need to re-fetch them here.
    // The FutureBuilders will handle their own updates.
  }
}
