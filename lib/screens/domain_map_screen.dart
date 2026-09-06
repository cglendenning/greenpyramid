import 'package:flutter/material.dart';

import '../services/db.dart';
import '../theme/app_colors.dart';
import '../widgets/radarchart.dart';

/// D-049/D-068: the four domains as a user-facing map — a destination the
/// user visits deliberately, never interposed in the daily path. Domain
/// state is derived entirely from accumulated findings (D-048), never
/// asked of the user directly (D-049's own acceptance criterion).
///
/// Disclosed simplification: no scoring formula is specified in the spec
/// for how findings become an axis value. This uses a simple, defensible
/// one — the count of findings in that domain, capped at 10 — rather than
/// inventing a weighted-recency model the spec never asked for.
class DomainMapScreen extends StatefulWidget {
  const DomainMapScreen({super.key});

  @override
  State<DomainMapScreen> createState() => _DomainMapScreenState();
}

class _DomainMapScreenState extends State<DomainMapScreen> {
  static const _domainOrder = ['biological', 'psychological', 'relational', 'environmental'];
  // D-068: exactly these user-facing labels, in the same order as _domainOrder.
  static const _labels = ['Body', 'Mind', 'People', 'Place'];

  late Future<Map<String, List<Map<String, dynamic>>>> _findings;

  @override
  void initState() {
    super.initState();
    _findings = DatabaseHelper.instance.queryDomainFindingsByDomain();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Your domain map'),
      ),
      body: FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
        future: _findings,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final byDomain = snapshot.data!;
          final total = byDomain.values.fold<int>(0, (sum, l) => sum + l.length);

          if (total == 0) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Nothing here yet. As you talk with the Council, what '
                  'supports you and what works against you will start to '
                  'take shape here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
                ),
              ),
            );
          }

          final values = _domainOrder
              .map((d) => (byDomain[d]?.length ?? 0).clamp(0, 10))
              .toList();

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(
                  height: 320,
                  child: RadarChart.dark(
                    ticks: const [0, 2, 4, 6, 8, 10],
                    features: _labels,
                    data: [values],
                    useSides: true,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Built from what you\'ve named to the Council — never a '
                  'questionnaire.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
