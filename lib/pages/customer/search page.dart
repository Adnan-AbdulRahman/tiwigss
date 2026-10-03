import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

import 'booking form.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH PAGE
//  • Real-time search against Firestore 'wigs' collection
//  • Searches by name, category, description, hairType, color
//  • Filter chips: All, Wig Making, Revamping, Styling, Factory Wig
//  • Tapping a result opens BookingFormPage directly
// ─────────────────────────────────────────────────────────────────────────────
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  final _searchCtrl   = TextEditingController();
  final _focusNode    = FocusNode();

  String _query           = '';
  String _selectedFilter  = 'All';
  List<QueryDocumentSnapshot> _allDocs  = [];
  List<QueryDocumentSnapshot> _results  = [];
  bool   _loading = true;

  static const _filters = [
    {'key': 'All',         'emoji': '👑'},
    {'key': 'Wig Making',  'emoji': '🪡'},
    {'key': 'Revamping',   'emoji': '✨'},
    {'key': 'Styling',     'emoji': '💇‍♀️'},
    {'key': 'Factory Wig', 'emoji': '🏭'},
  ];

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    // Auto-focus keyboard when page opens
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _focusNode.requestFocus();
    });

    _loadAllWigs();
    _searchCtrl.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Load all wigs once — filter client-side for instant results ─────────────
  Future<void> _loadAllWigs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('wigs')
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;
      setState(() {
        _allDocs = snapshot.docs;
        _loading = false;
      });
      _runFilter();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQueryChanged() {
    setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    _runFilter();
  }

  void _runFilter() {
    List<QueryDocumentSnapshot> filtered = List.from(_allDocs);

    // Category filter
    if (_selectedFilter != 'All') {
      filtered = filtered
          .where((d) =>
      (d['category'] as String? ?? '') == _selectedFilter)
          .toList();
    }

    // Text search across multiple fields
    if (_query.isNotEmpty) {
      filtered = filtered.where((d) {
        final data = d.data() as Map<String, dynamic>;
        final name     = (data['name']        as String? ?? '').toLowerCase();
        final desc     = (data['description'] as String? ?? '').toLowerCase();
        final cat      = (data['category']    as String? ?? '').toLowerCase();
        final hairType = (data['hairType']    as String? ?? '').toLowerCase();
        final color    = (data['color']       as String? ?? '').toLowerCase();
        final wigType  = (data['wigType']     as String? ?? '').toLowerCase();
        final brand    = (data['brand']       as String? ?? '').toLowerCase();

        return name.contains(_query)     ||
            desc.contains(_query)     ||
            cat.contains(_query)      ||
            hairType.contains(_query) ||
            color.contains(_query)    ||
            wigType.contains(_query)  ||
            brand.contains(_query);
      }).toList();
    }

    setState(() => _results = filtered);
  }

  void _onFilterChanged(String filter) {
    setState(() => _selectedFilter = filter);
    _runFilter();
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _query = '');
    _runFilter();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwTheme.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: TwTheme.bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top bar ──────────────────────────────────────────────
                _buildTopBar(context),

                const SizedBox(height: 14),

                // ── Filter chips ─────────────────────────────────────────
                _buildFilterChips(),

                const SizedBox(height: 14),

                // ── Results count ────────────────────────────────────────
                if (!_loading && _query.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      _results.isEmpty
                          ? 'No results for "$_query"'
                          : '${_results.length} result${_results.length == 1 ? '' : 's'} for "$_query"',
                      style: TwTheme.caption.copyWith(fontSize: 11),
                    ),
                  ),

                // ── Content ──────────────────────────────────────────────
                Expanded(child: _buildContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Top search bar + back ──────────────────────────────────────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Back
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TwTheme.cardBg,
                border: Border.all(color: TwTheme.primary.withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: TwTheme.textMid, size: 18),
            ),
          ),
          const SizedBox(width: 12),

          // Search input
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TwTheme.radiusMd),
                color: TwTheme.cardBg,
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? TwTheme.primary.withOpacity(0.6)
                      : TwTheme.primary.withOpacity(0.2),
                  width: _focusNode.hasFocus ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                focusNode: _focusNode,
                style: const TextStyle(
                    color: TwTheme.textHigh, fontSize: 14),
                cursorColor: TwTheme.accent,
                decoration: InputDecoration(
                  hintText: 'Search wigs, styles, services…',
                  hintStyle: const TextStyle(
                      color: TwTheme.textLow, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: TwTheme.textLow, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                    onTap: _clearSearch,
                    child: const Icon(Icons.close_rounded,
                        color: TwTheme.textLow, size: 18),
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
                onChanged: (_) {},
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter chips ───────────────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f      = _filters[i];
          final active = _selectedFilter == f['key'];
          return GestureDetector(
            onTap: () => _onFilterChanged(f['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active ? TwTheme.primary : TwTheme.cardBg,
                border: Border.all(
                  color: active
                      ? TwTheme.primary
                      : TwTheme.primary.withOpacity(0.2),
                ),
                boxShadow: active
                    ? [BoxShadow(
                    color: TwTheme.primary.withOpacity(0.35),
                    blurRadius: 10)]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(f['emoji']!,
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 6),
                  Text(f['key']!,
                      style: TextStyle(
                        color: active ? Colors.white : TwTheme.textMid,
                        fontWeight: active
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Main content area ──────────────────────────────────────────────────────
  Widget _buildContent() {
    if (_loading) return const _SearchSkeleton();

    // No query yet → show suggestions / popular
    if (_query.isEmpty) return _buildSuggestions();

    // Has query but no results
    if (_results.isEmpty) return _buildNoResults();

    // Results grid
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.68,
      ),
      itemCount: _results.length,
      itemBuilder: (_, i) {
        final data = _results[i].data() as Map<String, dynamic>;
        return _SearchResultCard(
          docId: _results[i].id,
          data: data,
          query: _query,
          index: i,
        );
      },
    );
  }

  // ── Suggestions when nothing typed ────────────────────────────────────────
  Widget _buildSuggestions() {
    final popular = _allDocs.take(4).toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick search suggestions
          Text('POPULAR SEARCHES',
              style: TwTheme.label.copyWith(fontSize: 10)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: const [
              'Lace Front', 'Human Hair', '18 inches',
              'Natural Black', 'Full Lace', 'Styling', 'Revamping',
            ].map((s) => _SuggestionPill(
              label: s,
              onTap: () {
                _searchCtrl.text = s;
                setState(() => _query = s.toLowerCase());
                _runFilter();
              },
            )).toList(),
          ),

          if (popular.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('ALL SERVICES',
                style: TwTheme.label.copyWith(fontSize: 10)),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: popular.length,
              itemBuilder: (_, i) {
                final data =
                popular[i].data() as Map<String, dynamic>;
                return _SearchResultCard(
                  docId: popular[i].id,
                  data: data,
                  query: '',
                  index: i,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  // ── No results ─────────────────────────────────────────────────────────────
  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TwTheme.primary.withOpacity(0.1),
                border: Border.all(
                    color: TwTheme.primary.withOpacity(0.25)),
              ),
              child: const Center(
                  child: Text('🔍',
                      style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 20),
            Text('No results for\n"$_query"',
                textAlign: TextAlign.center,
                style: TwTheme.displayMd),
            const SizedBox(height: 8),
            Text(
              'Try a different keyword or\nchange the category filter.',
              textAlign: TextAlign.center,
              style: TwTheme.body,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _clearSearch,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: TwTheme.primaryGradient,
                  boxShadow: TwTheme.primaryGlow,
                ),
                child: const Text('Clear Search',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SEARCH RESULT CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SearchResultCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String query;
  final int    index;

  const _SearchResultCard({
    required this.docId,
    required this.data,
    required this.query,
    required this.index,
  });

  @override
  State<_SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<_SearchResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;
  late AnimationController _pressCtrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 50 * widget.index), () {
      if (mounted) _ctrl.forward();
    });

    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Wig Making':  return TwTheme.primary;
      case 'Revamping':   return const Color(0xFF7A3A8B);
      case 'Styling':     return TwTheme.accent;
      case 'Factory Wig': return const Color(0xFF3A6B8B);
      default:            return TwTheme.primary;
    }
  }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'Wig Making':  return '🪡';
      case 'Revamping':   return '✨';
      case 'Styling':     return '💇‍♀️';
      case 'Factory Wig': return '🏭';
      default:            return '👑';
    }
  }

  @override
  Widget build(BuildContext context) {
    final name     = widget.data['name']        as String? ?? 'Service';
    final price    = (widget.data['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = widget.data['imageUrl']    as String? ?? '';
    final category = widget.data['category']    as String? ?? '';
    final inStock  = widget.data['inStock']     as bool?   ?? true;
    final desc     = widget.data['description'] as String? ?? '';
    final featured = widget.data['featured']    as bool?   ?? false;
    final color    = _categoryColor(category);
    final emoji    = _categoryEmoji(category);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            if (!inStock) return;
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (_, __, ___) => BookingFormPage(
                  serviceId:   widget.docId,
                  serviceData: widget.data,
                ),
                transitionsBuilder: (_, anim, __, child) =>
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(1, 0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                          parent: anim, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                transitionDuration: const Duration(milliseconds: 350),
              ),
            );
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TwTheme.radiusMd),
                color: TwTheme.cardBg,
                border: Border.all(color: color.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image ─────────────────────────────────────────────
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(TwTheme.radiusMd)),
                          child: imageUrl.isNotEmpty
                              ? Image.network(imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _ImgPlaceholder(
                                      color: color, emoji: emoji))
                              : _ImgPlaceholder(
                              color: color, emoji: emoji),
                        ),

                        // Unavailable overlay
                        if (!inStock)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(TwTheme.radiusMd)),
                              child: Container(
                                color: Colors.black.withOpacity(0.6),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: TwTheme.error,
                                      borderRadius:
                                      BorderRadius.circular(20),
                                    ),
                                    child: const Text('Unavailable',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Category badge
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: TwTheme.darkBg.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: color.withOpacity(0.4)),
                            ),
                            child: Text('$emoji $category',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),

                        // Featured star
                        if (featured)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: TwTheme.accent.withOpacity(0.9),
                              ),
                              child: const Center(
                                  child: Text('⭐',
                                      style: TextStyle(fontSize: 12))),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Info ──────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Highlighted name
                        _HighlightedText(
                            text: name, query: widget.query),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(desc,
                              style: TwTheme.body.copyWith(fontSize: 10),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GH₵ ${price.toStringAsFixed(0)}',
                                style: TwTheme.label
                                    .copyWith(fontSize: 13)),
                            if (inStock)
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: TwTheme.primaryGradient,
                                ),
                                child: const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white,
                                    size: 13),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HIGHLIGHTED TEXT  — bolds matching query text in results
// ─────────────────────────────────────────────────────────────────────────────
class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;

  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) {
      return Text(text,
          style: TwTheme.titleSm.copyWith(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
    }

    final lower = text.toLowerCase();
    final idx   = lower.indexOf(query.toLowerCase());

    if (idx == -1) {
      return Text(text,
          style: TwTheme.titleSm.copyWith(fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TwTheme.titleSm.copyWith(fontSize: 12),
        children: [
          if (idx > 0)
            TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + query.length),
            style: const TextStyle(
              color: TwTheme.accent,
              fontWeight: FontWeight.w900,
              backgroundColor: Color(0x22D4A853),
            ),
          ),
          if (idx + query.length < text.length)
            TextSpan(
                text: text.substring(idx + query.length)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUGGESTION PILL
// ─────────────────────────────────────────────────────────────────────────────
class _SuggestionPill extends StatelessWidget {
  final String       label;
  final VoidCallback onTap;

  const _SuggestionPill({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: TwTheme.cardBg,
          border:
          Border.all(color: TwTheme.primary.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded,
                color: TwTheme.textLow, size: 13),
            const SizedBox(width: 6),
            Text(label,
                style: TwTheme.body.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  IMAGE PLACEHOLDER
// ─────────────────────────────────────────────────────────────────────────────
class _ImgPlaceholder extends StatelessWidget {
  final Color  color;
  final String emoji;
  const _ImgPlaceholder({required this.color, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withOpacity(0.1),
      child: Center(
        child: Text(emoji,
            style: TextStyle(
                fontSize: 36, color: color.withOpacity(0.4))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SKELETON LOADER
// ─────────────────────────────────────────────────────────────────────────────
class _SearchSkeleton extends StatefulWidget {
  const _SearchSkeleton();

  @override
  State<_SearchSkeleton> createState() => _SearchSkeletonState();
}

class _SearchSkeletonState extends State<_SearchSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.6)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            color: TwTheme.cardBg.withOpacity(_anim.value),
          ),
        ),
      ),
    );
  }
}