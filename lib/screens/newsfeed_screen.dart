import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:intl/intl.dart';

import '../services/newsfeed_service.dart';
import '../theme/app_colors.dart';

/// D-150: "create a newsfeed that is generated from the users own personal
/// information ... so then in this newsfeed, they can scroll back as far
/// as they want in their newsfeed and see previous items that have cropped
/// up." A plain, always-growing, newest-first list — [_pageSize] items at
/// a time, loading another page as the user nears the bottom, rather than
/// one fixed window, so scrolling back is genuinely unbounded.
class NewsfeedScreen extends StatefulWidget {
  const NewsfeedScreen({super.key});

  @override
  State<NewsfeedScreen> createState() => _NewsfeedScreenState();
}

class _NewsfeedScreenState extends State<NewsfeedScreen> {
  static const _pageSize = 20;

  final _service = NewsfeedService.instance;
  final _scrollController = ScrollController();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  final List<Map<String, dynamic>> _items = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'newsfeed');
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await _service.generateNewItems();
    final page = await _service.getFeed(limit: _pageSize, offset: 0);
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _hasMore = page.length == _pageSize;
      _initialLoad = false;
    });
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    final page = await _service.getFeed(limit: _pageSize, offset: _items.length);
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _hasMore = page.length == _pageSize;
      _loadingMore = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Your Newsfeed',
            style: TextStyle(color: AppColors.textPrimary, fontFamily: 'Exo2')),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _initialLoad
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandGreen))
          : _items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      "Nothing here yet. As you build streaks and redefine "
                      "what your categories mean to you, you'll see it "
                      'here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary, fontFamily: 'Exo2'),
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.brandGreen)),
                      );
                    }
                    return _NewsfeedCard(item: _items[index]);
                  },
                ),
    );
  }
}

class _NewsfeedCard extends StatelessWidget {
  const _NewsfeedCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final created = DateTime.tryParse(item['created'] as String? ?? '');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['title'] as String? ?? '',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Exo2',
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            item['body'] as String? ?? '',
            style: const TextStyle(
                color: AppColors.textSecondary, fontFamily: 'Exo2', height: 1.4),
          ),
          if (created != null) ...[
            const SizedBox(height: 10),
            Text(
              DateFormat('MMM d, yyyy').format(created),
              style: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 11,
                  fontFamily: 'Exo2'),
            ),
          ],
        ],
      ),
    );
  }
}
