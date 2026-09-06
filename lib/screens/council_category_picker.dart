import 'package:flutter/material.dart';

import '../services/db.dart';
import '../theme/app_colors.dart';
import 'council_screen.dart';
import 'paywall_screen.dart';

/// D-061: Settings' "Revisit a category with the Council" entry point.
/// Lists the six categories; choosing one opens a Council session scoped to
/// it (D-028), gated behind D-016's entitlement check.
///
/// D-013: this is the app's first value-triggered paywall placement — the
/// user has already named the exact next step (deepen this category with
/// the Council) before ever seeing a price.
class CouncilCategoryPicker extends StatefulWidget {
  const CouncilCategoryPicker({super.key});

  @override
  State<CouncilCategoryPicker> createState() => _CouncilCategoryPickerState();
}

class _CouncilCategoryPickerState extends State<CouncilCategoryPicker> {
  late Future<List<Map<String, dynamic>>> _categories;

  @override
  void initState() {
    super.initState();
    _categories = DatabaseHelper.instance.queryCategories();
  }

  static int _tierFor(int position) {
    if (position <= 3) return 1;
    if (position <= 5) return 2;
    return 3;
  }

  Future<void> _open(int categoryId, String categoryName, int tier) async {
    final account = await DatabaseHelper.instance.getAccountState();
    final entitlement = account[DatabaseHelper.columnEntitlement] as String?;
    final entitled = entitlement == 'trialing' || entitlement == 'subscribed';

    if (!mounted) return;

    if (!entitled) {
      final subscribed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => PaywallScreen(
            reason: 'Revisit $categoryName with the Council',
          ),
        ),
      );
      if (subscribed != true || !mounted) return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CouncilScreen(
          categoryId: categoryId,
          categoryName: categoryName,
          categoryTier: tier,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Revisit a category with the Council'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _categories,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data!
            ..sort((a, b) => (a[DatabaseHelper.columnPosition] as int? ?? 0)
                .compareTo(b[DatabaseHelper.columnPosition] as int? ?? 0));
          return ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final row = categories[index];
              final id = row[DatabaseHelper.columnCategoryId] as int;
              final name = row[DatabaseHelper.columnCat] as String? ?? '';
              final position = row[DatabaseHelper.columnPosition] as int? ?? id;
              return ListTile(
                title:
                    Text(name, style: const TextStyle(color: AppColors.textPrimary)),
                onTap: () => _open(id, name, _tierFor(position)),
              );
            },
          );
        },
      ),
    );
  }
}
