import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:intl/intl.dart';

import '../services/db.dart';
import '../services/newsfeed_service.dart';
import '../theme/app_colors.dart';
import '../utils/stock_images.dart';
import 'paywall_screen.dart';

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
  final _db = DatabaseHelper.instance;
  final _scrollController = ScrollController();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Map<String, GlobalKey> _itemKeys = {};

  final List<Map<String, dynamic>> _items = [];
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _initialLoad = true;
  String? _highlighted;

  // D-168: the "Generate new analysis" control is hidden entirely for a
  // non-entitled account (the sample cards' own subscribe links are the
  // upsell surface, not a locked button) and shows/disables against
  // today's remaining on-demand allowance.
  bool _entitled = false;
  int _onDemandRemaining = NewsfeedService.onDemandDailyCap;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _analytics.logEvent(name: 'newsfeed');
    _highlighted = widget.highlightDedupeKey;
    _scrollController.addListener(_onScroll);
    _loadInitial();
    _loadEntitlementState();
  }

  Future<void> _loadEntitlementState() async {
    final account = await _db.getAccountState();
    final entitlement = account[DatabaseHelper.columnEntitlement] as String?;
    final entitled = entitlement == 'trialing' || entitlement == 'subscribed';
    final remaining = await _service.onDemandArticlesRemainingToday();
    if (!mounted) return;
    setState(() {
      _entitled = entitled;
      _onDemandRemaining = remaining;
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await _service.seedSampleCardsIfNeeded();

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
    } else {
      // D-155: the AI-written daily article is generated in the
      // background, never blocking the instant, on-device feed above —
      // it can take a few seconds. Skipped entirely when the screen was
      // opened to focus on one specific (older) item via a notification
      // tap, so a brand-new article never shifts things around mid-view.
      unawaited(_generateArticleInBackground());
    }
  }

  Future<void> _generateArticleInBackground() async {
    await _service.generateArticleIfDue();
    if (!mounted) return;
    final latest = await _service.getFeed(limit: 1, offset: 0);
    if (latest.isEmpty) return;
    final newest = latest.first;
    final key = newest['dedupekey'] as String;
    if (_items.any((i) => i['dedupekey'] == key)) return;
    setState(() {
      _items.insert(0, newest);
      _itemKeys[key] = GlobalKey();
    });
  }

  /// D-168: owner — "I also want subscribed users to be able to generate
  /// a new news item on demand in addition to the news item that gets
  /// generated automatically once per day." Reuses the exact same
  /// generation path (and AI backend call) as the daily automatic
  /// article, just user-triggered and capped separately.
  Future<void> _onGenerateTapped() async {
    if (_generating || _onDemandRemaining <= 0) return;
    setState(() => _generating = true);
    final outcome = await _service.generateArticleOnDemand();
    if (!mounted) return;
    setState(() => _generating = false);

    switch (outcome) {
      case OnDemandArticleOutcome.generated:
        final latest = await _service.getFeed(limit: 1, offset: 0);
        if (latest.isNotEmpty && mounted) {
          final newest = latest.first;
          final key = newest['dedupekey'] as String;
          if (!_items.any((i) => i['dedupekey'] == key)) {
            setState(() {
              _items.insert(0, newest);
              _itemKeys[key] = GlobalKey();
            });
          }
        }
        final remaining = await _service.onDemandArticlesRemainingToday();
        if (mounted) setState(() => _onDemandRemaining = remaining);
        break;
      case OnDemandArticleOutcome.dailyCapReached:
        _showSnack("You've used today's on-demand analyses. More tomorrow.");
        break;
      case OnDemandArticleOutcome.notEntitled:
        // Not reachable in practice — this control is hidden entirely
        // for a non-entitled account — handled defensively regardless.
        break;
      case OnDemandArticleOutcome.failed:
        _showSnack("Couldn't generate an analysis right now — try again shortly.");
        break;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget? _generateButton() {
    if (!_entitled) return null;
    final disabled = _generating || _onDemandRemaining <= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: disabled ? null : _onGenerateTapped,
          icon: _generating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.brandGreen),
                )
              : const Icon(Icons.auto_awesome, size: 18, color: AppColors.brandGreen),
          label: Text(
            _onDemandRemaining <= 0
                ? "Today's analyses used — more tomorrow"
                : 'Generate new analysis ($_onDemandRemaining left today)',
            style: const TextStyle(fontFamily: 'Exo2', color: AppColors.brandGreen),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.brandGreen),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
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
      body: Column(
        children: [
          _generateButton() ?? const SizedBox.shrink(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    return _initialLoad
        ? const Center(child: CircularProgressIndicator(color: AppColors.brandGreen))
        : _items.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    "Nothing here yet. Check back soon for your daily "
                    'analysis.',
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
    final isArticle = item['type'] == 'article';
    final isSample = item['type'] == 'sample';
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
      child: _buildLayout(
          context, layout, image, title, body, created, isArticle, isSample),
    );
  }

  Widget _buildLayout(BuildContext context, _CardLayout layout, String image,
      String title, String body, DateTime? created, bool isArticle, bool isSample) {
    switch (layout) {
      case _CardLayout.imageTop:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 4, child: Image.asset(image, fit: BoxFit.cover)),
            Expanded(
              flex: 6,
              child: _textBlock(context, title, body, created, isArticle, isSample,
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
              child: _textBlock(context, title, body, created, isArticle, isSample,
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
              child: _textBlock(context, title, body, created, isArticle, isSample,
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
              child: _textBlock(context, title, body, created, isArticle, isSample,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18)),
            ),
          ],
        );
    }
  }

  Widget _textBlock(BuildContext context, String title, String body,
      DateTime? created, bool isArticle, bool isSample,
      {required EdgeInsetsGeometry padding}) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // D-155: "make it like an analysis shaped as a news article" —
          // a small section label, the way a real news article carries
          // one, is also the one honest signal to the reader that this
          // particular card was AI-written analysis, not a plain
          // recorded fact like a streak or an essence change.
          if (isArticle) ...[
            const Text(
              'ANALYSIS',
              style: TextStyle(
                  color: AppColors.brandGreen,
                  fontFamily: 'Exo2',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.2),
            ),
            // D-164: owner — "place the date just underneath the
            // 'analysis' keyword" — a byline-style date reads naturally
            // right under a section label, the way a real article
            // dateline sits under its section, rather than trailing at
            // the very bottom of the card underneath the body text.
            if (created != null) ...[
              const SizedBox(height: 4),
              Text(
                DateFormat('MMM d, yyyy').format(created),
                style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 11,
                    fontFamily: 'Exo2'),
              ),
            ],
            const SizedBox(height: 6),
          ],
          // D-168: the sample cards' own designation — "some designation
          // that these are sample newsfeed" — a distinct color from the
          // real ANALYSIS label (brandPurple, not brandGreen) so a
          // sample is never visually confusable with genuine AI
          // analysis of the user's own data.
          if (isSample) ...[
            const Text(
              'SAMPLE',
              style: TextStyle(
                  color: AppColors.brandPurple,
                  fontFamily: 'Exo2',
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.2),
            ),
            const SizedBox(height: 6),
          ],
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
          // D-168: "each one of the cards will have a subscribe link and
          // a short indication that if they subscribe then they are
          // going to get newsfeed items that are tailored to their
          // actual trends and behavior." A distinct, clearly-tappable
          // element — the card body itself stays non-interactive, same
          // as every other card type ("we're not clicking into each
          // news article," D-154).
          if (isSample) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PaywallScreen(
                    reason: 'Get analysis tailored to your own trends'),
              )),
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontFamily: 'Exo2', fontSize: 13, height: 1.4),
                  children: [
                    TextSpan(
                      text: 'This is a sample. ',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    TextSpan(
                      text: 'Subscribe',
                      style: TextStyle(
                        color: AppColors.brandGreen,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.brandGreen,
                      ),
                    ),
                    TextSpan(
                      text: ' to get analysis like this made from your own '
                          'trends and behavior.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (!isArticle && !isSample && created != null) ...[
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
