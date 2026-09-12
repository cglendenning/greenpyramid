import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:intl/intl.dart';

import '../services/newsfeed_service.dart';
import '../theme/app_colors.dart';
import '../utils/stock_images.dart';

/// D-150: "create a newsfeed that is generated from the users own personal
/// information ... so then in this newsfeed, they can scroll back as far
/// as they want in their newsfeed and see previous items that have cropped
/// up." A plain, always-growing, newest-first list — [_pageSize] items at
/// a time, loading another page as the user nears the bottom, rather than
/// one fixed window, so scrolling back is genuinely unbounded.
///
/// D-154: [highlightDedupeKey], when set, is how a tapped notification
/// gets here — "when you tap the notification, it will go directly to
/// the newsfeed" (and land on the exact item the notification was
/// about). This screen loads exactly as far into the feed as that item's
/// own position, then scrolls to and briefly highlights it.
class NewsfeedScreen extends StatefulWidget {
  const NewsfeedScreen({super.key, this.highlightDedupeKey});

  final String? highlightDedupeKey;

  @override
  State<NewsfeedScreen> createState() => _NewsfeedScreenState();
}

class _NewsfeedScreenState extends State<NewsfeedScreen> {
  static const _pageSize = 20;

  final _service = NewsfeedService.instance;
  final _scrollController = ScrollController();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, GlobalKey> _itemKeys = {};

  final List<Map<String, dynamic>> _items = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _initialLoad = true;
  String? _highlighted;

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'newsfeed');
    _highlighted = widget.highlightDedupeKey;
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

    final target = widget.highlightDedupeKey;
    final targetPosition = target == null ? null : await _service.getItemPosition(target);

    final List<Map<String, dynamic>> page;
    if (targetPosition != null) {
      // Load exactly far enough to include the highlighted item, rather
      // than paging through unrelated history first.
      page = await _service.getFeed(limit: targetPosition + 1, offset: 0);
    } else {
      page = await _service.getFeed(limit: _pageSize, offset: 0);
    }
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      for (final item in page) {
        _itemKeys[item['dedupekey'] as String] = GlobalKey();
      }
      _hasMore = targetPosition != null || page.length == _pageSize;
      _initialLoad = false;
    });

    if (target != null && _itemKeys.containsKey(target)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _itemKeys[target]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 400), alignment: 0.1);
        }
      });
      // The highlight itself fades after a few seconds so it reads as
      // "this is the one you tapped for," not a permanent marker.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlighted = null);
      });
    }
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
      for (final item in page) {
        _itemKeys[item['dedupekey'] as String] = GlobalKey();
      }
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
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    if (index >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.brandGreen)),
                      );
                    }
                    final item = _items[index];
                    final dedupeKey = item['dedupekey'] as String;
                    return _NewsfeedCard(
                      key: _itemKeys[dedupeKey],
                      item: item,
                      highlighted: dedupeKey == _highlighted,
                    );
                  },
                ),
    );
  }
}

// D-154: a small, fixed set of layout templates — image on top, on
// either side, or full-bleed behind the text — so "not each card has
// the same layout." Which template (and which stock image) a given
// card gets is derived from its own dedupeKey, so it's stable across
// rebuilds/scrolling rather than reshuffling every time, while still
// varying from card to card.
enum _CardLayout { imageTop, imageLeft, imageRight, imageBackground }

int _stableHash(String s) {
  var h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h;
}

class _NewsfeedCard extends StatelessWidget {
  const _NewsfeedCard({super.key, required this.item, this.highlighted = false});

  final Map<String, dynamic> item;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final title = item['title'] as String? ?? '';
    final body = item['body'] as String? ?? '';
    final created = DateTime.tryParse(item['created'] as String? ?? '');
    final dedupeKey = item['dedupekey'] as String? ?? title;
    final hash = _stableHash(dedupeKey);
    final layout = _CardLayout.values[hash % _CardLayout.values.length];
    final image = kStockImages[hash % kStockImages.length];

    final cardHeight = MediaQuery.of(context).size.height * 0.5;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: cardHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted
              ? AppColors.brandGreen
              : Colors.white.withValues(alpha: 0.08),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [BoxShadow(color: AppColors.brandGreen.withValues(alpha: 0.35), blurRadius: 16)]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildLayout(layout, image, title, body, created),
    );
  }

  Widget _buildLayout(_CardLayout layout, String image, String title,
      String body, DateTime? created) {
    switch (layout) {
      case _CardLayout.imageTop:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: Image.asset(image, fit: BoxFit.cover)),
            Expanded(
              flex: 6,
              child: _textBlock(title, body, created,
                  padding: const EdgeInsets.all(18)),
            ),
          ],
        );
      case _CardLayout.imageLeft:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: Image.asset(image, fit: BoxFit.cover)),
            Expanded(
              flex: 6,
              child: _textBlock(title, body, created,
                  padding: const EdgeInsets.all(18)),
            ),
          ],
        );
      case _CardLayout.imageRight:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 6,
              child: _textBlock(title, body, created,
                  padding: const EdgeInsets.all(18)),
            ),
            Expanded(flex: 4, child: Image.asset(image, fit: BoxFit.cover)),
          ],
        );
      case _CardLayout.imageBackground:
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(image, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.background.withValues(alpha: 0.55),
                    AppColors.background.withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomLeft,
              child: _textBlock(title, body, created,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18)),
            ),
          ],
        );
    }
  }

  Widget _textBlock(String title, String body, DateTime? created,
      {required EdgeInsetsGeometry padding}) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'Exo2',
                fontWeight: FontWeight.w800,
                fontSize: 22,
                height: 1.15),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'Exo2',
                fontSize: 15,
                height: 1.5),
          ),
          if (created != null) ...[
            const SizedBox(height: 12),
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
