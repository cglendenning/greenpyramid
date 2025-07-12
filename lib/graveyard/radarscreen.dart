import 'package:flutter/material.dart';
import 'package:life_ops/radarchart.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class RadarScreen extends StatefulWidget {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;

  const RadarScreen(this.cat1Future, this.cat2Future, this.cat3Future,
      this.cat4Future, this.cat5Future, this.cat6Future);

  @override
  _RadarScreenState createState() => _RadarScreenState(
      cat1Future, cat2Future, cat3Future, cat4Future, cat5Future, cat6Future);
}

class _RadarScreenState extends State<RadarScreen> {
  final Future cat1Future;
  final Future cat2Future;
  final Future cat3Future;
  final Future cat4Future;
  final Future cat5Future;
  final Future cat6Future;

  _RadarScreenState(this.cat1Future, this.cat2Future, this.cat3Future,
      this.cat4Future, this.cat5Future, this.cat6Future);

  double numberOfFeatures = 6;

  @override
  void initState() {
    super.initState();
  }

  FirebaseAnalytics analytics = FirebaseAnalytics.instance;

  @override
  Widget build(BuildContext context) {
    analytics.logEvent(name: 'radarscreen');
    List<Map<String, String>> radarList = [];
    // I initialize this, then assume it exists with 6 entries,
    // which is sub-optimal.
    radarList = [
      {
        'cat': '',
        'pct': '0',
      },
      {
        'cat': '',
        'pct': '0',
      },
      {
        'cat': '',
        'pct': '0',
      },
      {
        'cat': '',
        'pct': '0',
      },
      {
        'cat': '',
        'pct': '0',
      },
      {
        'cat': '',
        'pct': '0',
      },
    ];

    const ticks = [20, 40, 60, 80, 100];

    var features = [
      radarList[0]['cat']!,
      radarList[1]['cat']!,
      radarList[2]['cat']!,
      radarList[3]['cat']!,
      radarList[4]['cat']!,
      radarList[5]['cat']!
    ];

    int cat1Pct = int.parse(radarList[0]['pct']!);
    int cat2Pct = int.parse(radarList[1]['pct']!);
    int cat3Pct = int.parse(radarList[2]['pct']!);
    int cat4Pct = int.parse(radarList[3]['pct']!);
    int cat5Pct = int.parse(radarList[4]['pct']!);
    int cat6Pct = int.parse(radarList[5]['pct']!);

    var data1 = [
      [cat1Pct, cat1Pct, 0, 0, 0, 0]
    ];

    var data2 = [
      [0, 0, 0, 0, 0, 0],
      [0, cat2Pct, cat2Pct, 0, 0, 0]
    ];

    var data3 = [
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, cat3Pct, cat3Pct, 0, 0]
    ];

    var data4 = [
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, cat4Pct, cat4Pct, 0]
    ];

    var data5 = [
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, cat5Pct, cat5Pct]
    ];

    var data6 = [
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [0, 0, 0, 0, 0, 0],
      [cat6Pct, 0, 0, 0, 0, cat6Pct]
    ];

    features = features.sublist(0, numberOfFeatures.floor());

    data1 = data1
        .map((graph) => graph.sublist(0, numberOfFeatures.floor()))
        .toList();

    data2 = data2
        .map((graph) => graph.sublist(0, numberOfFeatures.floor()))
        .toList();

    var mainTextStyle = const TextStyle(
        fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'SourceSans3');

    SizedBox smallSpacer =
        SizedBox(height: MediaQuery.of(context).size.width * 0.82 * .07);

    return Stack(
        // A bit hacky. I just overlay the chart multiple times re-drawing the
        // chart with new data each time in order to produce a chart like
        // the better life wheel.
        children: <Widget>[
          Center(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                smallSpacer,
                Text(
                  'Balance',
                  style: mainTextStyle,
                )
              ])),
          FutureBuilder(
              future: cat1Future,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                Widget display;
                if (!snapshot.hasData) {
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features,
                    data: data1,
                    reverseAxis: false,
                    useSides: false,
                  );
                } else {
                  List<String> features1 = [
                    snapshot.data.cat!,
                    radarList[1]['cat']!,
                    radarList[2]['cat']!,
                    radarList[3]['cat']!,
                    radarList[4]['cat']!,
                    radarList[5]['cat']!
                  ];
                  cat1Pct = snapshot.data.pctComplete!;
                  data1 = [
                    [cat1Pct, cat1Pct, 0, 0, 0, 0]
                  ];
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features1,
                    data: data1,
                    reverseAxis: false,
                    useSides: false,
                  );
                }
                return display;
              }),
          FutureBuilder(
              future: cat2Future,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                Widget display;
                if (!snapshot.hasData) {
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features,
                    data: data2,
                    reverseAxis: false,
                    useSides: false,
                  );
                } else {
                  List<String> features2 = [
                    radarList[0]['cat']!,
                    snapshot.data.cat!,
                    radarList[2]['cat']!,
                    radarList[3]['cat']!,
                    radarList[4]['cat']!,
                    radarList[5]['cat']!
                  ];
                  cat2Pct = snapshot.data.pctComplete!;
                  data2 = [
                    [0, 0, 0, 0, 0, 0],
                    [0, cat2Pct, cat2Pct, 0, 0, 0]
                  ];
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features2,
                    data: data2,
                    reverseAxis: false,
                    useSides: false,
                  );
                }
                return display;
              }),
          FutureBuilder(
              future: cat3Future,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                Widget display;
                if (!snapshot.hasData) {
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features,
                    data: data3,
                    reverseAxis: false,
                    useSides: false,
                  );
                } else {
                  List<String> features3 = [
                    radarList[0]['cat']!,
                    radarList[1]['cat']!,
                    snapshot.data.cat!,
                    radarList[3]['cat']!,
                    radarList[4]['cat']!,
                    radarList[5]['cat']!
                  ];
                  cat3Pct = snapshot.data.pctComplete!;
                  data3 = [
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, cat3Pct, cat3Pct, 0, 0]
                  ];
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features3,
                    data: data3,
                    reverseAxis: false,
                    useSides: false,
                  );
                }
                return display;
              }),
          FutureBuilder(
              future: cat4Future,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                Widget display;
                if (!snapshot.hasData) {
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features,
                    data: data4,
                    reverseAxis: false,
                    useSides: false,
                  );
                } else {
                  List<String> features4 = [
                    radarList[0]['cat']!,
                    radarList[1]['cat']!,
                    radarList[2]['cat']!,
                    snapshot.data.cat!,
                    radarList[4]['cat']!,
                    radarList[5]['cat']!
                  ];
                  cat4Pct = snapshot.data.pctComplete!;
                  var data4 = [
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, cat4Pct, cat4Pct, 0]
                  ];
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features4,
                    data: data4,
                    reverseAxis: false,
                    useSides: false,
                  );
                }
                return display;
              }),
          FutureBuilder(
              future: cat5Future,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                Widget display;
                if (!snapshot.hasData) {
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features,
                    data: data5,
                    reverseAxis: false,
                    useSides: false,
                  );
                } else {
                  List<String> features5 = [
                    radarList[0]['cat']!,
                    radarList[1]['cat']!,
                    radarList[2]['cat']!,
                    radarList[3]['cat']!,
                    snapshot.data.cat!,
                    radarList[5]['cat']!
                  ];
                  cat5Pct = snapshot.data.pctComplete!;
                  var data5 = [
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, cat5Pct, cat5Pct]
                  ];
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features5,
                    data: data5,
                    reverseAxis: false,
                    useSides: false,
                  );
                }
                return display;
              }),
          FutureBuilder(
              future: cat6Future,
              builder: (BuildContext context, AsyncSnapshot snapshot) {
                Widget display;
                if (!snapshot.hasData) {
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features,
                    data: data6,
                    reverseAxis: false,
                    useSides: false,
                  );
                } else {
                  List<String> features6 = [
                    radarList[0]['cat']!,
                    radarList[1]['cat']!,
                    radarList[2]['cat']!,
                    radarList[3]['cat']!,
                    radarList[4]['cat']!,
                    snapshot.data.cat!
                  ];
                  cat6Pct = snapshot.data.pctComplete!;
                  data6 = [
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [0, 0, 0, 0, 0, 0],
                    [cat6Pct, 0, 0, 0, 0, cat6Pct]
                  ];
                  display = RadarChart.light(
                    ticks: ticks,
                    features: features6,
                    data: data6,
                    reverseAxis: false,
                    useSides: false,
                  );
                }
                return display;
              }),
        ]);
  }
}
