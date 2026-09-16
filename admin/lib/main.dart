import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          onSignOut: signOutAndRetry,
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
  final Future<void> Function() onSignOut;
  const Dashboard({
    super.key,
    required this.data,
    required this.onRefresh,
    required this.onSignOut,
  });
  @override
  Widget build(BuildContext context) {
    final f = data['funnel'] as Map<String, dynamic>;
    final c = data['cost'] as Map<String, dynamic>;
    final screens = (data['screenUsage'] as List).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Green Pyramid Admin'),
        actions: [
          IconButton(
            tooltip: 'Run simulation',
            icon: const Icon(Icons.science_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SimulationScreen())),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
          ),
        ],
      ),
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

class SimulationScreen extends StatefulWidget {
  const SimulationScreen({super.key});
  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  final seedController = TextEditingController(text: '1');
  int months = 6;
  String failureMode = 'default';
  final selectedScenarios = <String>{...requiredScenarios};
  Map<String, dynamic>? report;
  String? error;
  bool running = false;

  @override
  void dispose() {
    seedController.dispose();
    super.dispose();
  }

  Future<void> run() async {
    final seed = int.tryParse(seedController.text.trim());
    if (seed == null || seed < 0 || selectedScenarios.isEmpty) {
      setState(
        () => error = 'Choose at least one scenario and enter a valid seed.',
      );
      return;
    }
    setState(() {
      running = true;
      error = null;
      report = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) {
        throw const SimulationException(null, 'authentication_required');
      }
      final response = await http.post(
        Uri.parse('$apiBase/adminSimulation'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'months': months,
          'seed': seed,
          'scenarios': selectedScenarios.toList(),
          'failureMode': failureMode,
        }),
      );
      if (response.statusCode != 200) {
        String? serverError;
        try {
          final payload = jsonDecode(response.body);
          if (payload is Map<String, dynamic> && payload['error'] is String) {
            serverError = payload['error'] as String;
          }
        } catch (_) {
          // Keep the HTTP status when the service did not return JSON.
        }
        throw SimulationException(response.statusCode, serverError);
      }
      if (!mounted) return;
      setState(
        () => report = jsonDecode(response.body) as Map<String, dynamic>,
      );
    } catch (e) {
      if (!mounted) return;
      final detail = e is SimulationException ? e.userMessage : null;
      setState(() => error = detail ?? 'Simulation could not be completed.');
    } finally {
      if (mounted) setState(() => running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scenarios =
        (report?['scenarios'] as List?)?.cast<Map<String, dynamic>>() ??
        const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intervention simulator'),
        actions: [
          IconButton(
            tooltip: 'How the simulator works',
            icon: const Icon(Icons.help_outline),
            onPressed: running
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SimulationGuideScreen(),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Sandbox only. No production data is read or written. The simulator '
            'creates synthetic daily check-ins, runs the same intervention '
            'policy used in production, and reports what the policy and delivery '
            'layer would do over virtual time.',
          ),
          const SizedBox(height: 16),
          const _ExplanationCard(
            title: 'What this tests',
            body:
                'Each selected scenario supplies a different synthetic pattern '
                'of completed and missed check-ins. Every virtual day is evaluated '
                'by the intervention engine, which compares doing nothing with a '
                'bounded reminder. This tests detection, deterministic policy '
                'selection, delivery failures, and the resulting audit timeline; '
                'it does not test real people, notifications, or production data.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: running
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SimulationGuideScreen(),
                      ),
                    ),
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('Open the step-by-step tutorial'),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: months,
            decoration: const InputDecoration(labelText: 'Virtual months'),
            items: [
              for (var i = 1; i <= 6; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: running
                ? null
                : (value) => setState(() => months = value ?? 6),
          ),
          const Text(
            'One virtual month is 30 simulated days. The limit is six months so '
            'a run finishes quickly and remains easy to inspect.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: seedController,
            enabled: !running,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Deterministic seed'),
          ),
          const Text(
            'The seed chooses the repeatable pseudo-random check-in pattern. '
            'The same seed and settings produce the same report.',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: failureMode,
            decoration: const InputDecoration(
              labelText: 'Delivery failure mode',
            ),
            items: const [
              DropdownMenuItem(
                value: 'default',
                child: Text('Default deterministic failures'),
              ),
              DropdownMenuItem(
                value: 'none',
                child: Text('Disable delivery failures'),
              ),
            ],
            onChanged: running
                ? null
                : (value) => setState(() => failureMode = value ?? 'default'),
          ),
          const Text(
            'Default deterministic failures makes every 17th simulated delivery '
            'fail. Disable delivery failures isolates policy decisions from the '
            'delivery-failure path.',
          ),
          const SizedBox(height: 16),
          const Text('Scenarios'),
          const Text(
            'Select the synthetic behavior patterns to compare. Each is a '
            'controlled test case, not a diagnosis of a real user.',
          ),
          Wrap(
            spacing: 8,
            children: requiredScenarios
                .map(
                  (name) => FilterChip(
                    label: Text(name),
                    selected: selectedScenarios.contains(name),
                    onSelected: running
                        ? null
                        : (selected) => setState(
                            () => selected
                                ? selectedScenarios.add(name)
                                : selectedScenarios.remove(name),
                          ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          const _ScenarioGuide(),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: running ? null : run,
            icon: running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow),
            label: Text(running ? 'Running…' : 'Run simulation'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          if (report != null) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Results', style: Theme.of(context).textTheme.titleLarge),
                OutlinedButton.icon(
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: jsonEncode(report)),
                  ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy JSON'),
                ),
              ],
            ),
            Text(
              '${report!['virtualMonths']} virtual months · ${report!['virtualDays']} days · '
              'seed ${report!['seed']} · ${report!['failureMode']} · sandbox',
            ),
            const SizedBox(height: 8),
            const _ExplanationCard(
              title: 'How to read the results',
              body:
                  'Evaluations is the number of virtual days assessed. Delivered '
                  'counts interventions whose delivery succeeded. Failed counts '
                  'simulated delivery failures. NONE means the deterministic '
                  'utility policy chose no intervention—usually because completion '
                  'was already strong, there was not enough history, or recent '
                  'interventions made the reminder burden too high. The JSON also '
                  'includes the timeline, baseline, candidates, burden, safety '
                  'bound, and selectionMode (deterministic_utility) for audit detail.',
            ),
            ...scenarios.map((scenario) {
              final metrics = scenario['metrics'] as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text(scenario['name'] as String),
                  subtitle: Text(
                    '${metrics['evaluations']} evaluations · ${metrics['delivered']} delivered · '
                    '${metrics['failedDelivery']} failed deliveries · ${metrics['none']} NONE decisions',
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    ),
  );
}

class _ScenarioGuide extends StatelessWidget {
  const _ScenarioGuide();

  static const descriptions = <String, String>{
    'autonomous': 'Always completes check-ins; tests the no-intervention path.',
    'responsive': 'Improves after early misses; tests recovery and response.',
    'fatigue':
        'Becomes less consistent after day 45; tests declining adherence.',
    'sequence': 'Misses every fourth day; tests a repeating pattern.',
    'changing': 'Becomes harder after day 60; tests changing circumstances.',
    'difficult': 'Usually misses check-ins; tests a difficult baseline.',
    'mature': 'Improves after day 20; tests a maturing practice.',
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final name in requiredScenarios)
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Text('$name — ${descriptions[name]}'),
        ),
    ],
  );
}

class InterventionEngineGuideScreen extends StatelessWidget {
  const InterventionEngineGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('How the Intervention Engine works')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          'The engine’s job',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'The backend-owned Intervention Engine uses the account’s values, '
          'goals, categories, tasks, schedules and checkbox history to decide '
          'whether the minimum useful intervention is silence or a bounded '
          'semantic intervention. It optimizes for checkbox completion, not '
          'message volume. The client, renderer and delivery service execute '
          'its decisions; they do not choose behavioral policy.',
        ),
        SizedBox(height: 20),
        _EngineFlow(),
        SizedBox(height: 20),
        _GuideSection(
          title: 'What each stage does',
          children: [
            Text(
              '1. Context and history — account-scoped events provide the '
              'current task context and observed completion history. Missing '
              'context is never filled in with invented facts.',
            ),
            Text(
              '2. Baseline — the engine estimates desired checkbox completion '
              'if it stays silent. This is the comparison point, not a promise.',
            ),
            Text(
              '3. Opportunity — the engine looks for meaningful completion risk, '
              'useful information gain, recovery, reflection or target review. '
              'A schedule deficit alone is not enough.',
            ),
            Text(
              '4. Candidates — the engine considers NONE and semantic options '
              'such as REMINDER or RECOVERY. A semantic type has an objective, '
              'target, validity window, measurement window and surface; wording '
              'comes later.',
            ),
            Text(
              '5. Utility and burden — fixed policy rules compare expected '
              'checkbox lift against burden, fatigue, annoyance, dependency, '
              'timing, information value and sequence effects. Silence is both '
              'a control condition and a way for burden to recover.',
            ),
            Text(
              '6. Safety gate — approved safety boundaries run before rendering '
              'and delivery. A prohibited candidate is constrained or suppressed '
              'and the action is auditable without unnecessary sensitive content.',
            ),
            Text(
              '7. Render, deliver and learn — a permitted semantic decision is '
              'rendered with deterministic fallback, then delivery is attempted. '
              'Decision, delivery, viewing, response, outcome, expiry, '
              'cancellation and supersession remain separate states. Checkbox '
              'completion is the primary outcome; technical failure is not a '
              'behavioral treatment failure.',
            ),
          ],
        ),
        SizedBox(height: 16),
        _GuideSection(
          title: 'The most important distinctions',
          children: [
            Text(
              'NONE is an intentional policy decision. Safety suppression means '
              'a safety boundary prevented a prohibited path. Delivery failure '
              'means a permitted decision was selected but transport did not '
              'complete. These are different causes and must not be combined.',
            ),
            Text(
              'deterministic_utility identifies the fixed policy used to compare '
              'candidates in the simulator. It is not an AI model selecting '
              'messages, and it does not mean the result predicts a person.',
            ),
          ],
        ),
      ],
    ),
  );
}

class SimulationGuideScreen extends StatelessWidget {
  const SimulationGuideScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('How the simulator works')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        Text(
          'The goal',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'This is a repeatable safety and behavior test for the Intervention '
          'Engine. It answers: “If these synthetic check-in patterns happened '
          'over time, when would the engine stay silent, choose a reminder, '
          'or encounter a delivery failure?” It is not a prediction about a '
          'person and it does not send notifications.',
        ),
        SizedBox(height: 20),
        _GuideSection(
          title: 'Start here: understand the engine first',
          children: [
            Text(
              'The simulator does not implement a second policy. It sends '
              'options to the same backend endpoint and exercises the same '
              'engine contracts with synthetic data and virtual time.',
            ),
            SizedBox(height: 4),
            _GuideLink(
              label: 'Open “How the Intervention Engine works”',
              screen: InterventionEngineGuideScreen(),
            ),
          ],
        ),
        SizedBox(height: 16),
        _GuideSection(
          title: 'Safety: what it means here',
          children: [
            Text(
              'Safety is a hard boundary around the Intervention Engine. It '
              'means the engine must not create or deliver a prohibited '
              'intervention when an approved safety trigger is present. Safety '
              'is not a score about whether a person is safe, and it is not a '
              'claim that a simulation predicts real-world outcomes.',
            ),
            SizedBox(height: 8),
            Text(
              'The safety gate runs before message wording is rendered and '
              'before delivery is attempted. It can constrain or suppress a '
              'candidate, including replacing it with NONE. The report records '
              'the trigger category, decision ID, action, policy version and '
              'time for audit without copying sensitive trigger content.',
            ),
            SizedBox(height: 8),
            Text(
              'Example: if a synthetic case would enter a prohibited path, the '
              'safety gate suppresses it before the renderer and delivery '
              'provider run. That is different from a delivery failure, where a '
              'permitted reminder was selected but could not be delivered.',
            ),
          ],
        ),
        SizedBox(height: 16),
        _SimulationFlow(),
        SizedBox(height: 24),
        _GuideSection(
          title: 'What the engine is evaluating',
          children: [
            Text(
              'Baseline — the estimated completion pattern if the engine stays '
              'silent. It gives the policy something to compare against.',
            ),
            Text(
              'Opportunity — whether the synthetic pattern shows a meaningful '
              'chance for a bounded reminder to help. Strong completion or too '
              'little history can mean there is no opportunity.',
            ),
            Text(
              'Burden — the modeled cost of prompting repeatedly. Recent '
              'interventions increase burden; silence lets it recover, so the '
              'engine can avoid nagging.',
            ),
            Text(
              'Selection — the policy compares NONE with a permitted reminder '
              'using expected checkbox lift minus burden. '
              'deterministic_utility means fixed server rules make that choice; '
              'it is not an AI prediction.',
            ),
            Text(
              'Lifecycle — a decision, delivery attempt, provider acceptance, '
              'viewing and behavioral outcome are separate events. A selected '
              'reminder is not necessarily delivered, and a failed delivery is '
              'not the same as a missed check-in.',
            ),
          ],
        ),
        SizedBox(height: 16),
        _GuideSection(
          title: 'A concrete example',
          children: [
            Text(
              'Imagine the “difficult” scenario. On a virtual day the '
              'synthetic person misses “Daily practice.” The engine looks '
              'back at recent check-ins, estimates the no-intervention '
              'completion baseline, and compares two candidates: NONE and a '
              'REMINDER. If the expected completion lift is worth the modeled '
              'burden, it selects REMINDER. If not, it selects NONE. The '
              'decision is recorded even when delivery later fails.',
            ),
            SizedBox(height: 8),
            Text(
              'By contrast, “autonomous” completes every check-in. Its '
              'completion is already high, so the engine normally chooses '
              'NONE. Silence is an intentional success condition, not a '
              'missing result.',
            ),
          ],
        ),
        SizedBox(height: 16),
        _GuideSection(
          title: 'What each scenario means',
          children: [
            Text('autonomous — always completes; tests useful silence.'),
            Text('responsive — recovers after early misses.'),
            Text('fatigue — becomes less consistent after day 45.'),
            Text('sequence — misses every fourth day.'),
            Text('changing — becomes harder after day 60.'),
            Text('difficult — usually misses; tests sustained risk.'),
            Text('mature — improves after day 20.'),
          ],
        ),
        SizedBox(height: 16),
        _GuideSection(
          title: 'The terms that are easiest to misread',
          children: [
            Text(
              'deterministic_utility — the policy uses fixed rules to compare '
              'expected checkbox lift with burden. No AI chooses the policy.',
            ),
            Text(
              'NONE — the engine deliberately chooses not to intervene. This '
              'can mean strong autonomous completion, insufficient history, '
              'or too much recent intervention burden.',
            ),
            Text(
              'Default deterministic failures — selected interventions fail '
              'delivery on every 17th simulated day. This tests delivery '
              'handling, not policy selection.',
            ),
            Text(
              'Failed delivery — an intervention was selected but not delivered; '
              'it must not be counted as a successful treatment.',
            ),
            Text(
              'Burden — modeled cost of repeatedly prompting someone. It rises '
              'with recent interventions, while silence can let it recover.',
            ),
          ],
        ),
        SizedBox(height: 16),
        _GuideSection(
          title: 'How to run a useful comparison',
          children: [
            Text(
              '1. Start with one scenario and failure mode “none” so you can '
              'see policy behavior without delivery noise.',
            ),
            Text(
              '2. Repeat with the same seed. The report should match exactly; '
              'that verifies reproducibility.',
            ),
            Text(
              '3. Turn on the default failure mode. Compare delivered versus '
              'failed delivery without expecting policy counts to change.',
            ),
            Text(
              '4. Add scenarios one at a time, then use Copy JSON when you need '
              'the complete day-by-day timeline and audit fields.',
            ),
          ],
        ),
      ],
    ),
  );
}

class _SimulationFlow extends StatelessWidget {
  const _SimulationFlow();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          _FlowStep(
            number: '1',
            title: 'Synthetic person',
            body: 'A controlled check-in pattern is generated.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '2',
            title: 'Virtual day',
            body: 'The clock advances without waiting in real time.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '3',
            title: 'Intervention Engine',
            body:
                'Baseline, opportunity, burden and safety rules are evaluated.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '4',
            title: 'Decision',
            body: 'NONE or a bounded intervention is selected and recorded.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '5',
            title: 'Delivery + report',
            body:
                'Delivery may succeed or fail; metrics and timeline are returned.',
          ),
        ],
      ),
    ),
  );
}

class _EngineFlow extends StatelessWidget {
  const _EngineFlow();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: const [
          _FlowStep(
            number: '1',
            title: 'Context + history',
            body: 'Values, goals, tasks, schedules and observed checkboxes.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '2',
            title: 'Baseline + opportunity',
            body:
                'Estimate silent completion and find a meaningful opportunity.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '3',
            title: 'Candidates + utility',
            body:
                'Compare NONE and bounded semantic interventions against burden.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '4',
            title: 'Safety gate',
            body:
                'Constrain or suppress prohibited paths before rendering/delivery.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '5',
            title: 'Render + lifecycle',
            body:
                'Render, deliver, record separate states and measure outcomes.',
          ),
        ],
      ),
    ),
  );
}

class _GuideLink extends StatelessWidget {
  const _GuideLink({required this.label, required this.screen});
  final String label;
  final Widget screen;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: () =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
    icon: const Icon(Icons.account_tree_outlined),
    label: Text(label),
  );
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.number,
    required this.title,
    required this.body,
  });
  final String number;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CircleAvatar(radius: 14, child: Text(number)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body),
          ],
        ),
      ),
    ],
  );
}

class _FlowArrow extends StatelessWidget {
  const _FlowArrow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(left: 11, top: 3, bottom: 3),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Icon(Icons.arrow_downward, size: 18),
    ),
  );
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

class SimulationException implements Exception {
  const SimulationException(this.statusCode, [this.serverError]);
  final int? statusCode;
  final String? serverError;

  String get userMessage {
    switch (serverError) {
      case 'authentication_required':
        return 'Your admin session expired. Sign in again and retry.';
      case 'admin_required':
        return 'Admin authorization is required for simulations.';
      case 'simulation_options_invalid':
        return 'The simulation options are invalid. Check the selected values.';
      default:
        return statusCode == null
            ? 'Authentication could not be completed.'
            : 'Simulation service returned HTTP $statusCode.';
    }
  }
}

const requiredScenarios = [
  'autonomous',
  'responsive',
  'fatigue',
  'sequence',
  'changing',
  'difficult',
  'mature',
];
