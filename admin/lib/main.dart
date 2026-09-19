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
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.admin_panel_settings_outlined, size: 34),
                    SizedBox(height: 8),
                    Text('Green Pyramid Admin', style: TextStyle(fontSize: 20)),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_outlined),
                title: const Text('Product pulse'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.feedback_outlined),
                title: const Text('App feedback'),
                subtitle: const Text('Read user-submitted feedback'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminFeedbackScreen()),
                ),
              ),
              // D-165-AC-07: read-only billing, budget, and Functions diagnostic.
              ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: const Text('Platform health'),
                subtitle: const Text('Billing, budgets, quotas, and Functions'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PlatformHealthScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: const Text('Users'),
                subtitle: const Text('Accounts, subscriptions, and usage'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.science_outlined),
                title: const Text('Intervention simulator'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SimulationScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Intervention engine debugger'),
                subtitle: const Text('Step through a synthetic pyramid day by day'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const InterventionDebuggerScreen(),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('How the intervention engine works'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const InterventionEngineGuideScreen()),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.card_giftcard_outlined),
                title: const Text('Generate lifetime subscription code'),
                subtitle: const Text('Create a single-use gift code'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LifetimeCodeScreen()),
                ),
              ),
            ],
          ),
        ),
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

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  late Future<List<Map<String, dynamic>>> feedbackFuture;

  @override
  void initState() {
    super.initState();
    feedbackFuture = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    final response = await http.get(
      Uri.parse('$apiBase/adminFeedback?limit=500'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw AdminMetricsException(response.statusCode);
    }
    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    return (payload['feedback'] as List).cast<Map<String, dynamic>>();
  }

  void refresh() => setState(() => feedbackFuture = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('App feedback'),
      actions: [
        IconButton(
          tooltip: 'Refresh feedback',
          icon: const Icon(Icons.refresh),
          onPressed: refresh,
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: feedbackFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Feedback could not be loaded: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final entries = snapshot.data!;
        if (entries.isEmpty) {
          return const Center(child: Text('No user feedback has been submitted yet.'));
        }
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                child: ListTile(
                  leading: Icon(_feedbackIcon(entry['category'] as String?)),
                  title: Text(_feedbackLabel(entry['category'] as String?)),
                  subtitle: Text(
                    '${entry['comment']?.toString().isEmpty == true ? '(No comment)' : entry['comment']}\n${_formatDate(entry['createdAt'])}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminFeedbackDetailScreen(entry: entry),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    ),
  );

  String _feedbackLabel(String? category) => switch (category) {
    'bug' => 'Report a bug',
    'idea' => 'Suggest an idea',
    'confusing' => "Something's confusing",
    'love_it' => "What's working",
    _ => 'Other feedback',
  };

  IconData _feedbackIcon(String? category) => switch (category) {
    'bug' => Icons.bug_report_outlined,
    'idea' => Icons.lightbulb_outline,
    'confusing' => Icons.help_outline,
    'love_it' => Icons.favorite_border,
    _ => Icons.feedback_outlined,
  };

  String _formatDate(dynamic value) {
    if (value is! String) return 'Date unavailable';
    return value.replaceFirst('T', ' ').replaceFirst('Z', ' UTC');
  }
}

class AdminFeedbackDetailScreen extends StatelessWidget {
  const AdminFeedbackDetailScreen({super.key, required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Feedback detail')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _label(entry['category'] as String?),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              (entry['comment'] as String?)?.isNotEmpty == true
                  ? entry['comment'] as String
                  : 'No comment was included.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Submission details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        _row('Submitted', '${entry['createdAt'] ?? 'Unknown'}'),
        _row('Platform', '${entry['platform'] ?? 'Unknown'}'),
        _row('App version', '${entry['appVersion'] ?? 'Unknown'}'),
        _row('Build number', '${entry['buildNumber'] ?? 'Unknown'}'),
        _row('Anonymous user hash', '${entry['uidHash'] ?? 'Unknown'}'),
        _row('Feedback record', '${entry['id'] ?? 'Unknown'}'),
        const SizedBox(height: 16),
        const Text(
          'The user hash is an operator-safe identifier. The admin app does not expose the user’s raw Firebase UID or personal account data here.',
        ),
      ],
    ),
  );

  static String _label(String? category) => switch (category) {
    'bug' => 'Report a bug',
    'idea' => 'Suggest an idea',
    'confusing' => "Something's confusing",
    'love_it' => "What's working",
    _ => 'Other feedback',
  };

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text('$label: $value'),
  );
}

class PlatformHealthScreen extends StatefulWidget {
  const PlatformHealthScreen({super.key});

  @override
  State<PlatformHealthScreen> createState() => _PlatformHealthScreenState();
}

class _PlatformHealthScreenState extends State<PlatformHealthScreen> {
  late Future<Map<String, dynamic>> healthFuture;

  @override
  void initState() {
    super.initState();
    healthFuture = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    final response = await http.get(
      Uri.parse('$apiBase/adminPlatformHealth'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw AdminMetricsException(response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void refresh() => setState(() => healthFuture = _load());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Platform health'),
      actions: [
        IconButton(
          tooltip: 'Refresh platform health',
          icon: const Icon(Icons.refresh),
          onPressed: refresh,
        ),
      ],
    ),
    body: FutureBuilder<Map<String, dynamic>>(
      future: healthFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Platform health could not be loaded: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final health = snapshot.data!;
        final billing = _map(health['billing']);
        final budgets = _map(health['budgets']);
        final functions = _map(health['functions']);
        final functionRows = (functions['functions'] as List? ?? const [])
            .cast<Map<String, dynamic>>();
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text('Google Cloud checks', style: Theme.of(context).textTheme.headlineSmall),
              Text('Project: ${health['projectId'] ?? 'unknown'}'),
              const SizedBox(height: 16),
              _healthCard(
                context,
                icon: Icons.account_balance_outlined,
                title: 'Billing account',
                state: '${billing['state'] ?? 'unknown'}',
                body: billing['state'] == 'enabled'
                    ? 'Billing is enabled for ${billing['billingAccount'] ?? 'the project'}.'
                    : 'Billing status could not be confirmed. This must be resolved before treating a runtime failure as an app defect.',
              ),
              _healthCard(
                context,
                icon: Icons.savings_outlined,
                title: 'Budget visibility',
                state: '${budgets['state'] ?? 'unknown'}',
                body: _budgetDescription(budgets),
              ),
              _healthCard(
                context,
                icon: Icons.functions_outlined,
                title: 'Firebase Functions',
                state: '${functions['state'] ?? 'unknown'}',
                body: functions['state'] == 'healthy'
                    ? '${functions['count'] ?? 0} deployed Functions report ACTIVE.'
                    : 'One or more Function states need operator review, or the Functions API could not be read.',
              ),
              if (functionRows.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Deployed Functions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ...functionRows.map((fn) => ListTile(
                  dense: true,
                  title: Text('${fn['name'] ?? 'unknown'}'),
                  subtitle: Text('${fn['region'] ?? 'unknown region'}'),
                  trailing: Text('${fn['state'] ?? 'UNKNOWN'}'),
                )),
              ],
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'These checks are read-only. A Google Cloud budget is normally an alert threshold, not an automatic execution stop. The app’s per-account AI spend cap and external-provider credit balance are separate from Firebase/Google Cloud billing. Unknown budget visibility never means “no budget.”',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text('Checked ${health['checkedAt'] ?? 'unknown'}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        );
      },
    ),
  );

  Map<String, dynamic> _map(dynamic value) => value is Map
      ? value.cast<String, dynamic>()
      : <String, dynamic>{'state': 'unknown'};

  String _budgetDescription(Map<String, dynamic> budgets) {
    if (budgets['state'] == 'available') {
      return '${budgets['count'] ?? 0} budget(s) are visible. Review their thresholds in Google Cloud Billing.';
    }
    if (budgets['reason'] == 'api_disabled') {
      return 'The Cloud Billing Budget API is disabled, so the app cannot inspect budget thresholds. This does not prove that no budget exists and is not itself a Functions execution cap.';
    }
    if (budgets['reason'] == 'permission_denied') {
      return 'The runtime identity cannot read budget thresholds. Grant read-only Billing Budget Viewer access if operators need this check in the app.';
    }
    return 'Budget state is not currently readable (${budgets['reason'] ?? 'unknown reason'}).';
  }

  Widget _healthCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String state,
    required String body,
  }) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(body),
      ),
      trailing: Text(state.toUpperCase()),
      isThreeLine: true,
    ),
  );
}

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<Map<String, dynamic>> future;
  @override
  void initState() { super.initState(); future = _load(); }
  Future<Map<String, dynamic>> _load() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    final response = await http.get(Uri.parse('$apiBase/adminUsers'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw AdminMetricsException(response.statusCode);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  void refresh() => setState(() => future = _load());
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Users'), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: refresh)]),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Users could not be loaded: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final summary = (snap.data!['summary'] as Map).cast<String, dynamic>();
        final users = (snap.data!['users'] as List).cast<Map<String, dynamic>>();
        return RefreshIndicator(
          onRefresh: () async => refresh(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _metric('Users', summary['totalUsers']),
                _metric('Subscribed', summary['subscribed']),
                _metric('Lifetime', summary['lifetimeSubscribers']),
                _metric('Trialing', summary['trialing']),
                _metric('Lapsed', summary['lapsed']),
                _metric('Setup complete', summary['setupComplete']),
              ]),
              const SizedBox(height: 20),
              Text('${users.length} accounts', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...users.map((user) => Card(child: ListTile(
                title: Text(user['displayName']?.toString() ?? 'Unnamed user'),
                subtitle: Text('${user['email'] ?? 'No email'} · ${user['entitlement'] ?? 'unknown'}${user['lifetimeAccess'] == true ? ' · Lifetime' : ''}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminUserDetailScreen(uid: user['uid'] as String))),
              ))),
            ],
          ),
        );
      },
    ),
  );
  Widget _metric(String label, dynamic value) => Chip(label: Text('$label: $value'));
}

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.uid});
  final String uid;
  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  late Future<Map<String, dynamic>> future;
  bool mutating = false;
  @override
  void initState() { super.initState(); future = _load(); }
  Future<Map<String, dynamic>> _load() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
    final response = await http.get(Uri.parse('$apiBase/adminUsers/${widget.uid}'), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode != 200) throw AdminMetricsException(response.statusCode);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
  Future<void> _mutate(bool grant) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: Text(grant ? 'Grant lifetime access?' : 'Revoke lifetime access?'),
      content: Text(grant ? 'This gives the account access that does not expire.' : 'This removes only the lifetime gift. An active Apple or RevenueCat subscription remains active.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(grant ? 'Grant' : 'Revoke'))],
    ));
    if (confirmed != true) return;
    setState(() => mutating = true);
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
      final response = await http.post(Uri.parse('$apiBase/adminUsers/${widget.uid}/${grant ? 'lifetimeGrant' : 'lifetimeRevoke'}'), headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'});
      if (response.statusCode != 200) throw AdminMetricsException(response.statusCode);
      if (mounted) { setState(() => future = _load()); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(grant ? 'Lifetime access granted.' : 'Lifetime access revoked.'))); }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The lifetime access change could not be completed.')));
    } finally { if (mounted) setState(() => mutating = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('User details')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('User details could not be loaded: ${snap.error}'));
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final user = snap.data!;
        final usage = (user['usage'] as Map).cast<String, dynamic>();
        final lifetime = user['lifetimeAccess'] == true;
        return ListView(padding: const EdgeInsets.all(20), children: [
          Text(user['displayName']?.toString() ?? 'Unnamed user', style: Theme.of(context).textTheme.headlineSmall),
          _row('Email', user['email']), _row('User ID', user['uid']), _row('Providers', (user['providers'] as List).join(', ')),
          _row('Entitlement', user['entitlement']), _row('Subscription source', user['subscriptionSource']), _row('Subscription expiry', user['subscriptionExpiresAtMs']),
          _row('Lifetime access', lifetime ? 'Yes' : 'No'), _row('Setup complete', user['setupComplete'] == true ? 'Yes' : 'No'),
          _row('Total AI spend', '\$${(user['totalSpendUsd'] ?? 0).toStringAsFixed(2)}'), _row('AI calls', user['aiCalls']),
          const SizedBox(height: 16), Text('Usage', style: Theme.of(context).textTheme.titleLarge),
          ...usage.entries.map((entry) => _row(entry.key, entry.value)),
          const SizedBox(height: 20),
          FilledButton(onPressed: mutating ? null : () => _mutate(!lifetime), child: Text(mutating ? 'Working…' : lifetime ? 'Revoke lifetime access' : 'Grant lifetime access')),
        ]);
      },
    ),
  );
  Widget _row(String label, dynamic value) => Padding(padding: const EdgeInsets.only(top: 10), child: Text('$label: ${value ?? 'Not available'}'));
}

class LifetimeCodeScreen extends StatefulWidget {
  const LifetimeCodeScreen({super.key});

  @override
  State<LifetimeCodeScreen> createState() => _LifetimeCodeScreenState();
}

class _LifetimeCodeScreenState extends State<LifetimeCodeScreen> {
  String? code;
  String? error;
  bool generating = false;

  Future<void> generate() async {
    setState(() { generating = true; error = null; code = null; });
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken(true);
      final response = await http.post(
        Uri.parse('$apiBase/adminLifetimeCode'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode != 200) {
        throw AdminMetricsException(response.statusCode);
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final generated = payload['code'] as String?;
      if (generated == null || generated.isEmpty) {
        throw const AdminMetricsException(500);
      }
      if (mounted) setState(() => code = generated);
    } catch (_) {
      if (mounted) setState(() => error = 'The lifetime code could not be generated.');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lifetime subscription code')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Generate a one-time gift code for lifetime Green Pyramid access. The code is shown only here and is never stored in readable form. Send it to the recipient securely.',
        ),
        const SizedBox(height: 20),
        if (code != null) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                code!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: code!)),
            icon: const Icon(Icons.copy),
            label: const Text('Copy code'),
          ),
          const SizedBox(height: 8),
          const Text('This code can be redeemed once. Keep it private and treat it like a gift card.', textAlign: TextAlign.center),
        ] else
          FilledButton.icon(
            onPressed: generating ? null : generate,
            icon: generating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.add),
            label: Text(generating ? 'Generating…' : 'Generate code'),
          ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
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
                'bounded set of intervention type candidates. This tests '
                'evidence-triggered taxonomy selection, delivery failures, and '
                'the resulting audit timeline; '
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
                  'utility policy chose no intervention. The policy records why: '
                  'strong completion or insufficient history can remove the '
                  'opportunity; same-type cooldown or the tier-specific burden '
                  'limit can suppress an otherwise useful candidate. The JSON also '
                  'includes the timeline, baseline, candidates, burden, safety '
                  'bound, derived evidence, supportTier, typeCooldownDays, '
                  'maxRecentNonSilent, suppressionReason, selected type, and selectionMode '
                  '(deterministic_utility) for audit detail.',
            ),
            _InterventionTypeSummary(
              counts:
                  (report!['selectedTypes'] as Map?)?.cast<String, dynamic>() ??
                  const {},
            ),
            ...scenarios.map((scenario) {
              final metrics = scenario['metrics'] as Map<String, dynamic>;
              return Card(
                child: ListTile(
                  title: Text(scenario['name'] as String),
                  subtitle: Text(
                    '${metrics['evaluations']} evaluations · ${metrics['delivered']} delivered · '
                    '${metrics['failedDelivery']} failed deliveries · ${metrics['none']} NONE decisions · '
                    '${(metrics['evaluations'] as num) - (metrics['none'] as num)} non-silent selections',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SimulationScenarioDetailsScreen(scenario: scenario),
                    ),
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

class _InterventionTypeSummary extends StatelessWidget {
  const _InterventionTypeSummary({required this.counts});
  final Map<String, dynamic> counts;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries
        .where((entry) => (entry.value as num?)?.toInt() != 0)
        .toList();
    return _ExplanationCard(
      title: 'Selected intervention types',
      body: entries.isEmpty
          ? 'No intervention type was selected in this run. The engine intentionally chose NONE for every evaluation.'
          : entries.map((entry) => '${entry.key}: ${entry.value}').join(' · '),
    );
  }
}

class SimulationScenarioDetailsScreen extends StatelessWidget {
  const SimulationScenarioDetailsScreen({super.key, required this.scenario});
  final Map<String, dynamic> scenario;

  @override
  Widget build(BuildContext context) {
    final timeline = (scenario['timeline'] as List)
        .cast<Map<String, dynamic>>();
    final metrics = scenario['metrics'] as Map<String, dynamic>;
    return Scaffold(
      appBar: AppBar(title: Text('${scenario['name']} details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Every virtual day is shown below. A decision is recorded before delivery is attempted; a failed delivery does not change the decision.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _detailStat('Evaluations', '${metrics['evaluations']}'),
              _detailStat('Delivered', '${metrics['delivered']}'),
              _detailStat('Failed', '${metrics['failedDelivery']}'),
              _detailStat('NONE', '${metrics['none']}'),
            ],
          ),
          const SizedBox(height: 12),
          _InterventionTypeSummary(
            counts:
                (metrics['selectedTypes'] as Map?)?.cast<String, dynamic>() ??
                const {},
          ),
          const SizedBox(height: 20),
          ...timeline.map((entry) => _DecisionDayTile(entry: entry)),
        ],
      ),
    );
  }

  Widget _detailStat(String label, String value) =>
      Chip(label: Text('$label: $value'), padding: const EdgeInsets.all(8));
}

class _DecisionDayTile extends StatelessWidget {
  const _DecisionDayTile({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final decision = entry['decision'] as Map<String, dynamic>;
    final activity = entry['activity'] as Map<String, dynamic>;
    final policy = (decision['policy'] as Map?)?.cast<String, dynamic>();
    final baseline = (decision['baseline'] as Map?)?.cast<String, dynamic>();
    final delivery = entry['deliveryState'] as String;
    final delivered = delivery == 'sent';
    return Card(
      child: ExpansionTile(
        title: Text('Day ${entry['day']} · ${decision['type']}'),
        subtitle: Text(
          '${activity['checked'] == true ? 'Checked' : 'Missed'} · '
          '${delivered
              ? 'Delivered'
              : delivery == 'failed'
              ? 'Delivery failed'
              : 'Not sent'}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _field('Time', '${entry['at']}'),
          _field(
            'Observed check-in',
            '${activity['taskdescription']} · ${activity['checked'] == true ? 'complete' : 'missed'}',
          ),
          _field('Decision ID', '${decision['decisionId']}'),
          _field('Decision', '${decision['type']} — ${decision['rationale']}'),
          _field('Target', '${decision['target'] ?? 'none'}'),
          _field('Objective', '${decision['objective'] ?? 'none'}'),
          _field('Delivery', delivery),
          if (baseline != null) _field('Silent baseline', _formatMap(baseline)),
          if (policy != null) _field('Policy comparison', _formatMap(policy)),
          if (decision['context'] != null)
            _field(
              'Context used',
              _formatMap((decision['context'] as Map).cast<String, dynamic>()),
            ),
          if (decision['lifecycle'] != null)
            _field(
              'Lifecycle',
              _formatMap(
                (decision['lifecycle'] as Map).cast<String, dynamic>(),
              ),
            ),
          if (decision['safety'] != null)
            _field(
              'Safety',
              _formatMap((decision['safety'] as Map).cast<String, dynamic>()),
            ),
        ],
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text('$label: $value'),
    ),
  );

  String _formatMap(Map<String, dynamic> value) =>
      value.entries.map((entry) => '${entry.key}=${entry.value}').join(' · ');
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
          'Start with this simple picture: each time a person checks or misses '
          'a task, Green Pyramid records that event. The cloud-based '
          'Intervention Engine receives the current task, recent checkbox '
          'history, values, goals, schedules, prior interventions and current '
          'time. It examines that information once and decides whether support '
          'could increase future checkbox completion. It returns either NONE '
          '(stay silent) or one intervention type from the complete list. The '
          'app, renderer and delivery service carry out that decision; they do '
          'not choose the intervention.',
        ),
        SizedBox(height: 12),
        Text(
          'The engine does not create or '
          'train a predictive model from a person’s data. It estimates a '
          'short-term completion baseline if it sends nothing, checks whether '
          'there is a useful chance to help, compares the available choices, '
          'and applies safety and timing limits. “Deterministic” means the same '
          'information, policy version and time produce the same choice; it does '
          'not mean the engine predicts a person. Model-generated wording, when '
          'used, happens after the intervention type is chosen and cannot choose '
          'whether to intervene.',
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
              '3. Opportunity — completion risk means evidence that the next '
              'checkbox is more likely to be missed or abandoned without support. '
              'It is not a judgment about the person. The engine also looks for '
              'useful information gain, recovery, reflection or target review. '
              'A schedule deficit alone is not enough.',
            ),
            Text(
              '4. Candidates — the engine considers NONE and evidence-triggered '
              'intervention types such as REMINDER, RECOVERY, PLAN_PROMPT, or '
              'TARGET_REVIEW. Each type has a purpose, '
              'target, validity window, measurement window and surface; wording '
              'comes later.',
            ),
            Text(
              '5. Utility and burden — fixed policy rules compare expected '
              'checkbox lift against intervention cost: fatigue, annoyance, '
              'prompt dependence, distraction, timing, information value, '
              'sequence effects, and the possibility that repeated prompts reduce '
              'future check-ins or checkbox completion. Silence is both a control '
              'condition and a way for burden to recover.',
            ),
            Text(
              '6. Safety check — five approved stop categories are checked before '
              'rendering and delivery: self_harm, medical_crisis, illegal_activity, '
              'abuse_or_coercion, and privacy_or_security. If one is present, the '
              'proposed intervention is replaced with NONE and is not sent. The '
              'category is recorded for audit without saving sensitive trigger text. '
              'This is separate from completion risk.',
            ),
            Text(
              '7. Render, deliver and learn — a permitted intervention decision is '
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
              'one of the five safety stop categories prevented an intervention. Delivery failure '
              'means a permitted decision was selected but transport did not '
              'complete. These are different causes and must not be combined.',
            ),
            Text(
              'deterministic_utility identifies the fixed policy used to compare '
              'candidates in the simulator. It is not an AI model selecting '
              'messages, and it does not mean the result predicts a person.',
            ),
            Text(
              'Completion risk means a greater chance of a missed future checkbox. '
              'Intervention cost means the possible downside of prompting. Safety '
              'means a hard rule that blocks a prohibited intervention. These terms '
              'are separate and should not be read as judgments about the user.',
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
          'choose a type-specific bounded intervention, or encounter a delivery failure?” It is not a prediction about a '
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
              'Safety means a specific stop rule. If an approved category is present, the engine '
              'stops the proposed intervention before it is written or sent, '
              'returns NONE, and records the category without storing sensitive '
              'trigger text. This is different from completion risk, which is '
              'only evidence that a checkbox may be missed.',
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
              'permitted intervention was selected but could not be delivered.',
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
              'chance for a bounded intervention to help. Strong completion or too '
              'little history can mean there is no opportunity.',
            ),
            Text(
              'Burden — the modeled cost of prompting repeatedly. Recent '
              'interventions increase burden; silence lets it recover, so the '
              'engine can avoid nagging.',
            ),
            Text(
              'Adaptive support cadence — stable completion stays quiet: a '
              '7-day same-type cooldown and at most one non-silent intervention '
              'per rolling 7 days. Emerging difficulty (two misses or completion '
              'below 80%) uses a 3-day cooldown and at most two. Persistent '
              'difficulty (three consecutive misses or at least three observations '
              'at 50% completion or below) uses a 2-day cooldown and at most four. '
              'A new miss is new evidence; a completed check-in lets support '
              'burden recover.',
            ),
            Text(
              'Selection — the policy compares NONE with permitted intervention '
              'candidates using expected checkbox lift minus burden and a '
              'small success-continuity value for acknowledgment/reflection. '
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
              'completion baseline, and compares NONE with a type-specific '
              'candidate such as RECOVERY, PLAN_PROMPT, or REMINDER. If the '
              'expected completion lift is worth the modeled burden, it selects '
              'that intervention type. If not, it selects NONE. The '
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
              'same-type cooldown, a tier-specific burden limit, low utility, '
              'or no eligible candidate. Inspect suppressionReason, supportTier, '
              'typeCooldownDays, and maxRecentNonSilent in the JSON to tell which '
              'case occurred.',
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
            title: 'Cloud receives current facts',
            body: 'Tasks, check-ins, values, goals, schedules and prior decisions.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '2',
            title: 'Estimate doing nothing',
            body: 'Estimate future checkbox completion without sending support.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '3',
            title: 'List and compare choices',
            body:
                'Compare NONE and evidence-supported intervention types against prompt cost.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '4',
            title: 'Apply five safety stop rules',
            body:
                'If one matches, replace the proposed intervention with NONE before it is written or sent.',
          ),
          _FlowArrow(),
          _FlowStep(
            number: '5',
            title: 'Return, deliver, and measure',
            body:
                'Return one result; downstream services write, send, record, and measure it.',
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

// D-173: interactive companion to the named-scenario simulator above. It does
// not touch SimulationScreen, its scenarios, or /adminSimulation — it is a
// separate screen backed by separate endpoints. Instead of an auto-generated
// check-in pattern, the operator authors a stock pyramid's outcomes one
// virtual day at a time and inspects the full decision trace the shared
// production policy produced for that day.

const safetyTriggerCategories = [
  'self_harm',
  'medical_crisis',
  'illegal_activity',
  'abuse_or_coercion',
  'privacy_or_security',
];

class DebuggerException implements Exception {
  const DebuggerException(this.statusCode, [this.serverError]);
  final int? statusCode;
  final String? serverError;

  String get userMessage {
    switch (serverError) {
      case 'authentication_required':
        return 'Your admin session expired. Sign in again and retry.';
      case 'admin_required':
        return 'Admin authorization is required for the debugger.';
      case 'seed_invalid':
        return 'Enter a valid whole-number seed.';
      default:
        return statusCode == null
            ? 'Authentication could not be completed.'
            : 'Debugger service returned HTTP $statusCode.';
    }
  }
}

String? _debuggerServerError(String body) {
  try {
    final payload = jsonDecode(body);
    if (payload is Map<String, dynamic> && payload['error'] is String) {
      return payload['error'] as String;
    }
  } catch (_) {
    // Keep the HTTP status when the service did not return JSON.
  }
  return null;
}

class InterventionDebuggerScreen extends StatefulWidget {
  const InterventionDebuggerScreen({super.key});
  @override
  State<InterventionDebuggerScreen> createState() =>
      _InterventionDebuggerScreenState();
}

class _InterventionDebuggerScreenState
    extends State<InterventionDebuggerScreen> {
  final seedController = TextEditingController(text: '1');
  List<Map<String, dynamic>>? categories;
  List<Map<String, dynamic>>? tasks;
  final List<Map<String, dynamic>> recentActivity = [];
  final List<Map<String, dynamic>> priorInterventions = [];
  final List<Map<String, dynamic>> timeline = [];
  int currentDay = 0;
  DateTime currentDate = DateTime.utc(2026, 1, 1, 12);
  bool generating = false;
  bool evaluating = false;
  String? error;

  @override
  void dispose() {
    seedController.dispose();
    super.dispose();
  }

  Future<String> _authToken() async {
    final user = FirebaseAuth.instance.currentUser!;
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw const DebuggerException(null, 'authentication_required');
    }
    return token;
  }

  Future<void> generatePyramid() async {
    final seed = int.tryParse(seedController.text.trim());
    if (seed == null || seed < 0) {
      setState(() => error = 'Enter a valid seed.');
      return;
    }
    setState(() {
      generating = true;
      error = null;
    });
    try {
      final token = await _authToken();
      final response = await http.post(
        Uri.parse('$apiBase/adminInterventionDebuggerPyramid'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'seed': seed}),
      );
      if (response.statusCode != 200) {
        throw DebuggerException(
          response.statusCode,
          _debuggerServerError(response.body),
        );
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        categories = (payload['categories'] as List)
            .cast<Map<String, dynamic>>();
        tasks = (payload['tasks'] as List)
            .map((task) => Map<String, dynamic>.from(task as Map))
            .toList();
        recentActivity.clear();
        priorInterventions.clear();
        timeline.clear();
        currentDay = 0;
        currentDate = DateTime.utc(2026, 1, 1, 12);
      });
    } catch (e) {
      if (!mounted) return;
      final detail = e is DebuggerException ? e.userMessage : null;
      setState(() => error = detail ?? 'The pyramid could not be generated.');
    } finally {
      if (mounted) setState(() => generating = false);
    }
  }

  Future<void> nextDay(Map<String, Map<String, dynamic>> outcomes) async {
    final activeTasks = tasks!
        .where((task) => task['active'] != false)
        .toList();
    final todaysActivity = activeTasks.map((task) {
      final outcome =
          outcomes[task['id']] ?? const {'checked': true, 'reason': ''};
      final entry = <String, dynamic>{
        'taskdate': currentDate.toIso8601String(),
        'taskdescription': task['description'],
        'checked': outcome['checked'],
      };
      final reason = (outcome['reason'] as String?)?.trim();
      if (outcome['checked'] != true && reason != null && reason.isNotEmpty) {
        entry['missreason'] = reason;
      }
      return entry;
    }).toList();
    // Only a task still marked missed carries its safety flag, matching how
    // the miss reason is treated. Otherwise a flag set before the task was
    // flipped back to checked would silently keep suppressing the day.
    final safetyTriggers = activeTasks
        .where((task) => outcomes[task['id']]?['checked'] != true)
        .map((task) => outcomes[task['id']]?['safetyType'])
        .whereType<String>()
        .toSet()
        .map((type) => {'type': type})
        .toList();

    setState(() {
      evaluating = true;
      error = null;
    });
    try {
      final token = await _authToken();
      final response = await http.post(
        Uri.parse('$apiBase/adminInterventionDebuggerEvaluate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'profile': {'categories': categories},
          'tasks': tasks,
          'recentActivity': [...recentActivity, ...todaysActivity],
          'priorInterventions': priorInterventions,
          'safetyTriggers': safetyTriggers,
          'now': currentDate.toIso8601String(),
        }),
      );
      if (response.statusCode != 200) {
        throw DebuggerException(
          response.statusCode,
          _debuggerServerError(response.body),
        );
      }
      final decision = jsonDecode(response.body) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        timeline.insert(0, {
          'day': currentDay,
          'date': currentDate.toIso8601String(),
          'activity': todaysActivity,
          'decision': decision,
        });
        recentActivity.addAll(todaysActivity);
        priorInterventions.add(decision);
        currentDay += 1;
        currentDate = currentDate.add(const Duration(days: 1));
      });
    } catch (e) {
      if (!mounted) return;
      final detail = e is DebuggerException ? e.userMessage : null;
      setState(() => error = detail ?? 'The day could not be evaluated.');
    } finally {
      if (mounted) setState(() => evaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Intervention engine debugger'),
      actions: [
        IconButton(
          tooltip: 'How the intervention engine works',
          icon: const Icon(Icons.help_outline),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const InterventionEngineGuideScreen(),
            ),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Sandbox only. No production data is read or written. Generate a '
          'stock synthetic pyramid, then author each virtual day yourself — '
          'mark every task checked or missed, optionally explain a miss, and '
          'advance one day at a time to watch the same production policy used '
          'by the simulator above decide what it would do.',
        ),
        const SizedBox(height: 12),
        const _ExplanationCard(
          title: 'How this differs from the simulator',
          body:
              'The simulator above auto-generates a check-in pattern for a '
              'named scenario and reports a whole run at once. This debugger '
              'starts from one realistic pyramid — six categories, two or '
              'three tasks each, the same fields the production engine reads '
              '— and lets you decide what happens each day, one day at a '
              'time, so you can build a novel behavior pattern and watch the '
              'engine reason about it as it happens.',
        ),
        const SizedBox(height: 16),
        if (categories == null) ...[
          TextField(
            controller: seedController,
            enabled: !generating,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pyramid seed'),
          ),
          const SizedBox(height: 8),
          const Text(
            'The seed chooses the stock category/task pattern. The same seed '
            'always produces the same pyramid.',
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: generating ? null : generatePyramid,
            icon: generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined),
            label: Text(
              generating ? 'Generating…' : 'Generate stock pyramid',
            ),
          ),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day $currentDay',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              OutlinedButton.icon(
                onPressed: generating || evaluating
                    ? null
                    : () => setState(() {
                        categories = null;
                        tasks = null;
                      }),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset session'),
              ),
            ],
          ),
          Text(
            currentDate.toIso8601String().substring(0, 10),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          _DayForm(
            key: ValueKey('day-$currentDay'),
            categories: categories!,
            tasks: tasks!,
            evaluating: evaluating,
            onNextDay: nextDay,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: const TextStyle(color: Colors.red)),
        ],
        if (timeline.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Timeline', style: Theme.of(context).textTheme.titleLarge),
          const Text(
            'Most recent day first. Each card is the full decision trace for '
            'that day.',
          ),
          const SizedBox(height: 8),
          ...timeline.map((entry) => _DebuggerDayTile(entry: entry)),
        ],
      ],
    ),
  );
}

/// One virtual day's input form: every active task's outcome, plus an
/// attribute editor so the operator can deliberately steer which candidate
/// branch a later miss will exercise. Rebuilt fresh (via the parent's
/// ValueKey) at the start of every day so outcomes never leak across days;
/// task attribute edits persist because they mutate the shared task map.
class _DayForm extends StatefulWidget {
  const _DayForm({
    super.key,
    required this.categories,
    required this.tasks,
    required this.evaluating,
    required this.onNextDay,
  });
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> tasks;
  final bool evaluating;
  final void Function(Map<String, Map<String, dynamic>> outcomes) onNextDay;

  @override
  State<_DayForm> createState() => _DayFormState();
}

class _DayFormState extends State<_DayForm> {
  late final Map<String, Map<String, dynamic>> outcomes = {
    for (final task in widget.tasks)
      task['id'] as String: {'checked': true, 'reason': '', 'safetyType': null},
  };

  // The cards read `checked` straight out of this shared map, so flipping the
  // values and rebuilding is enough to update every segmented control.
  void setAll(bool checked) {
    setState(() {
      for (final outcome in outcomes.values) {
        outcome['checked'] = checked;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.evaluating ? null : () => setAll(false),
              icon: const Icon(Icons.close),
              label: const Text('All missed'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.evaluating ? null : () => setAll(true),
              icon: const Icon(Icons.check),
              label: const Text('All checked'),
            ),
          ),
        ],
      ),
      const Text(
        'Sets every task for this day at once; individual tasks can still be '
        'changed afterwards.',
      ),
      for (final category in widget.categories) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            '${category['cat']}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final task in widget.tasks.where(
          (t) => t['categoryId'] == category['position'],
        ))
          _TaskOutcomeCard(
            task: task,
            outcome: outcomes[task['id']]!,
            onOutcomeChanged: () => setState(() {}),
          ),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: widget.evaluating ? null : () => widget.onNextDay(outcomes),
        icon: widget.evaluating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.arrow_forward),
        label: Text(widget.evaluating ? 'Evaluating…' : 'Next day'),
      ),
    ],
  );
}

class _TaskOutcomeCard extends StatefulWidget {
  const _TaskOutcomeCard({
    required this.task,
    required this.outcome,
    required this.onOutcomeChanged,
  });
  final Map<String, dynamic> task;
  final Map<String, dynamic> outcome;
  final VoidCallback onOutcomeChanged;

  @override
  State<_TaskOutcomeCard> createState() => _TaskOutcomeCardState();
}

class _TaskOutcomeCardState extends State<_TaskOutcomeCard> {
  bool get checked => widget.outcome['checked'] == true;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ExpansionTile(
      title: Text(widget.task['description'] as String),
      subtitle: Text(checked ? 'Checked' : 'Missed'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: true,
              label: Text('Checked'),
              icon: Icon(Icons.check),
            ),
            ButtonSegment(
              value: false,
              label: Text('Missed'),
              icon: Icon(Icons.close),
            ),
          ],
          selected: {checked},
          onSelectionChanged: (selection) => setState(() {
            widget.outcome['checked'] = selection.first;
            widget.onOutcomeChanged();
          }),
        ),
        if (!checked) ...[
          const SizedBox(height: 12),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Miss reason (optional, free text)',
            ),
            onChanged: (value) => widget.outcome['reason'] = value,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: widget.outcome['safetyType'] as String?,
            decoration: const InputDecoration(
              labelText: 'Safety trigger (optional)',
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('None')),
              for (final category in safetyTriggerCategories)
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) => setState(() {
              widget.outcome['safetyType'] = value;
              widget.onOutcomeChanged();
            }),
          ),
        ],
        const Divider(height: 24),
        Text(
          'Task attributes (persist across days)',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.task['scheduledTime'] as String? ?? '',
          decoration: const InputDecoration(labelText: 'Scheduled time'),
          onChanged: (value) => widget.task['scheduledTime'] =
              value.trim().isEmpty ? null : value.trim(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.task['cue'] as String? ?? '',
          decoration: const InputDecoration(labelText: 'Cue'),
          onChanged: (value) =>
              widget.task['cue'] = value.trim().isEmpty ? null : value.trim(),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: widget.task['plan'] as String? ?? '',
          decoration: const InputDecoration(labelText: 'Plan'),
          onChanged: (value) =>
              widget.task['plan'] = value.trim().isEmpty ? null : value.trim(),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Commitment required'),
          value: widget.task['commitmentRequired'] == true,
          onChanged: (value) =>
              setState(() => widget.task['commitmentRequired'] = value),
        ),
      ],
    ),
  );
}

/// The full decision trace for one evaluated virtual day: the exact
/// intervention delivered (or NONE and why), every candidate the policy
/// compared, the derived signals behind that comparison, the safety audit
/// and the lifecycle status. This is the "decision tree" view.
class _DebuggerDayTile extends StatelessWidget {
  const _DebuggerDayTile({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final decision = entry['decision'] as Map<String, dynamic>;
    final activity = (entry['activity'] as List).cast<Map<String, dynamic>>();
    final policy = (decision['policy'] as Map?)?.cast<String, dynamic>();
    final signals = (policy?['derivedSignals'] as Map?)
        ?.cast<String, dynamic>();
    final candidates = (policy?['candidates'] as List?)
        ?.cast<Map<String, dynamic>>();
    final safety = (decision['safety'] as Map?)?.cast<String, dynamic>();
    final lifecycle = (decision['lifecycle'] as Map?)?.cast<String, dynamic>();
    final rendered = (decision['rendered'] as Map?)?.cast<String, dynamic>();
    final missed = activity.where((a) => a['checked'] != true).toList();

    return Card(
      child: ExpansionTile(
        title: Text('Day ${entry['day']} · ${decision['type']}'),
        subtitle: Text(
          missed.isEmpty
              ? 'All ${activity.length} tasks checked'
              : '${missed.length} of ${activity.length} tasks missed',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _section(context, 'What happened', [
            for (final a in activity)
              Text(
                '${a['taskdescription']}: ${a['checked'] == true ? 'checked' : 'missed'}'
                '${a['missreason'] != null ? ' — "${a['missreason']}"' : ''}',
              ),
          ]),
          _section(context, 'Decision', [
            Text('${decision['type']} — ${decision['rationale']}'),
            Text('Target: ${decision['target'] ?? 'none'}'),
            Text('Objective: ${decision['objective'] ?? 'none'}'),
          ]),
          if (policy != null)
            _section(context, 'Candidates considered (decision tree)', [
              if (candidates != null)
                for (final candidate in candidates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${candidate['type']}'
                      '${candidate['type'] == decision['type'] ? ' (selected)' : ''}'
                      ' — utility ${(candidate['utilityScore'] as num?)?.toStringAsFixed(3)}'
                      ', lift ${(candidate['predictedLift'] as num?)?.toStringAsFixed(2)}'
                      ', burden ${(candidate['burden'] as num?)?.toStringAsFixed(2)}'
                      '${candidate['cooldownBlocked'] == true ? ', cooldown-blocked' : ''}'
                      ' — ${candidate['rationale']}',
                    ),
                  ),
              if (policy['suppressionReason'] != null)
                Text('Suppression reason: ${policy['suppressionReason']}'),
              Text('Support tier: ${policy['burdenAssumptions']?['supportTier']}'),
            ]),
          if (signals != null)
            _section(context, 'Derived signals', [
              Text('Reason class: ${signals['reasonClass']}'),
              Text(
                'Missed streak: ${signals['missedStreak']} · Completed streak: ${signals['completedStreak']}',
              ),
              Text(
                'Has cue: ${signals['hasCue']} · Has plan: ${signals['hasPlan']} · '
                'Value context: ${signals['hasValueContext']} · Mixed history: ${signals['mixedHistory']}',
              ),
              Text('Commitment needed: ${signals['commitmentNeeded']}'),
            ]),
          if (safety != null)
            _section(context, 'Safety', [
              Text(
                'Action: ${safety['action']}'
                '${safety['triggerType'] != null ? ' (${safety['triggerType']})' : ''}',
              ),
            ]),
          if (lifecycle != null)
            _section(context, 'Lifecycle', [
              Text('Status: ${lifecycle['status']}${lifecycle['reason'] != null ? ' (${lifecycle['reason']})' : ''}'),
            ]),
          if (rendered != null && (rendered['title'] as String).isNotEmpty)
            _section(context, 'Rendered copy', [
              Text('${rendered['title']}'),
              Text('${rendered['body']}'),
            ]),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      );
}
