import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBase = 'https://us-central1-life-ops.cloudfunctions.net/api';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Green Pyramid Admin',
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff6bd968),
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    home: const AdminGate(),
  );
}

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});
  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  String? error;
  late Future<Map<String, dynamic>> metricsFuture;

  @override
  void initState() {
    super.initState();
    metricsFuture = _load();
  }

  Future<void> signIn() async {
    try {
      await FirebaseAuth.instance.signInWithProvider(AppleAuthProvider());
      final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
      if (token == null) throw StateError('missing_id_token');
      if (mounted) {
        setState(() {
          error = null;
          metricsFuture = _load();
        });
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Sign in could not be completed.');
    }
  }

  Future<void> signOutAndRetry() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) setState(() => error = null);
  }

  @override
  Widget build(BuildContext context) {
    if (FirebaseAuth.instance.currentUser == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: signIn,
                child: const Text('Continue with Apple'),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: metricsFuture,
      builder: (context, snap) {
        if (snap.hasError) {
          final unauthorized =
              snap.error is AdminMetricsException &&
              (snap.error as AdminMetricsException).statusCode == 401;
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    unauthorized
                        ? 'Admin authorization is required.'
                        : 'Admin access is unavailable.',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snap.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: signOutAndRetry,
                    child: const Text('Sign out and sign in again'),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Dashboard(
          data: snap.data!,
          onRefresh: () async {
            setState(() => metricsFuture = _load());
            await metricsFuture;
          },
        );
      },
    );
  }

  Future<Map<String, dynamic>> _load() async {
    final user = FirebaseAuth.instance.currentUser!;
    final token = await user.getIdToken(true);
    final r = await http.get(
      Uri.parse('$apiBase/adminMetrics'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (r.statusCode != 200) {
      throw AdminMetricsException(r.statusCode);
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

class AdminMetricsException implements Exception {
  const AdminMetricsException(this.statusCode);
  final int statusCode;
  @override
  String toString() => 'admin_metrics_$statusCode';
}

class Dashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Future<void> Function() onRefresh;
  const Dashboard({super.key, required this.data, required this.onRefresh});
  @override
  Widget build(BuildContext context) {
    final f = data['funnel'] as Map<String, dynamic>;
    final c = data['cost'] as Map<String, dynamic>;
    final screens = (data['screenUsage'] as List).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: const Text('Green Pyramid Admin')),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Product pulse',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const Text(
              'A private view of use, conversion, and operating cost.',
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metric('Setup starts', '${f['anonymousStarts']}'),
                _metric('Account links', '${f['accountLinks']}'),
                _metric('Completions', '${f['setupCompletions']}'),
                _metric(
                  'Monthly cost',
                  '\$${(c['totalUsd'] as num).toStringAsFixed(2)}',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Conversion'),
            _bar('Link rate', f['linkRate'] as num),
            _bar('Completion rate', f['completionRate'] as num),
            _bar('Subscription rate', f['subscriptionRate'] as num),
            const SizedBox(height: 24),
            const Text('Screen utilization'),
            if (screens.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No screen telemetry yet.'),
                ),
              )
            else
              ...screens.map(
                (s) => ListTile(
                  title: Text(s['screenKey'] as String),
                  subtitle: Text(
                    '${s['opens']} opens · ${s['uniqueUsers']} users',
                  ),
                  trailing: const Icon(Icons.bar_chart),
                ),
              ),
            const SizedBox(height: 24),
            const Text('Top users by spend'),
            if ((data['topUsers'] as List).isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No cost data yet.'),
                ),
              )
            else
              ...((data['topUsers'] as List).map((u) {
                final m = u as Map;
                return ListTile(
                  title: Text(m['uidHash'] as String),
                  trailing: Text(
                    '\$${(m['spendUsd'] as num).toStringAsFixed(2)}',
                  ),
                );
              })),
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, String value) => SizedBox(
    width: 155,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            Text(label),
          ],
        ),
      ),
    ),
  );
  Widget _bar(String label, num value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(width: 130, child: Text(label)),
        Expanded(child: LinearProgressIndicator(value: value.toDouble())),
        const SizedBox(width: 10),
        Text('${(value * 100).round()}%'),
      ],
    ),
  );
}
