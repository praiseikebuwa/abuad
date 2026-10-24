import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/verification_badge.dart';
import '../../../core/utils/url_validator.dart';
import '../../user/data/user_repository.dart';
import '../../feed/data/post_repository.dart';
import '../../feed/domain/post.dart';
import '../../feed/presentation/widgets/post_card.dart';
import '../data/search_history_service.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';


class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  String _query = '';
  bool _hasSubmitted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                      : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildSearchHeader(isDark),

                // Content View (Discover, Dot Commands, Autocomplete, or Search Results)
                Expanded(
                  child: _query.isEmpty
                      ? _buildDiscoverView(isDark)
                      : (_query.trim().startsWith('.')
                          ? _buildDotCommandsView(isDark)
                          : (_hasSubmitted
                              ? _buildSearchResultsView(isDark)
                              : _buildAutocompleteSuggestionsView(isDark))),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    final canPop = Navigator.of(context).canPop();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Row(
            children: [
              if (canPop) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: isDark ? Colors.white : Colors.black,
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      context.go('/');
                    }
                  },
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1),
                          width: 0.5,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _query = value;
                            _hasSubmitted = false;
                          });
                          if (value.startsWith('@') && _tabController.index != 2) {
                            _tabController.animateTo(2);
                          } else if (value.startsWith('#') && _tabController.index != 3) {
                            _tabController.animateTo(3);
                          }
                        },
                        onSubmitted: (value) {
                          final trimmed = value.trim();
                          if (trimmed.startsWith('.')) {
                            _handleDotCommandSubmit(trimmed);
                            return;
                          }
                          if (value.isNotEmpty) {
                            ref.read(searchHistoryProvider.notifier).addQuery(value.trim());
                            setState(() => _hasSubmitted = true);
                          }
                        },
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Search or type . for screens (.portal, .id)...',
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 14.5,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: 22,
                          ),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.cancel_rounded, size: 20),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _query = '';
                                      _hasSubmitted = false;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Categorized Search Tabs (Shown only when searching and submitted)
          if (_query.isNotEmpty && _hasSubmitted) ...[
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.secondaryTeal,
                labelColor: isDark ? Colors.white : Colors.black,
                unselectedLabelColor: Colors.grey,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: "Top"),
                  Tab(text: "Latest"),
                  Tab(text: "People"),
                  Tab(text: "Hashtags"),
                  Tab(text: "Media"),
                ],
              ),
            ),
          ],

          if (_query.isEmpty) ...[
            const SizedBox(height: 12),
            // Quick Tags (Horizontal)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _TrendChip(
                    label: "🔥 Trending",
                    isDark: isDark,
                    onTap: () {
                      final q = "#trending";
                      setState(() {
                        _searchController.text = q;
                        _query = q;
                      });
                      ref.read(searchHistoryProvider.notifier).addQuery(q);
                    },
                  ),
                  _TrendChip(
                    label: "🎓 News",
                    isDark: isDark,
                    onTap: () {
                      final q = "#news";
                      setState(() {
                        _searchController.text = q;
                        _query = q;
                      });
                      ref.read(searchHistoryProvider.notifier).addQuery(q);
                    },
                  ),
                  _TrendChip(
                    label: "🏆 Sports",
                    isDark: isDark,
                    onTap: () {
                      final q = "#sports";
                      setState(() {
                        _searchController.text = q;
                        _query = q;
                      });
                      ref.read(searchHistoryProvider.notifier).addQuery(q);
                    },
                  ),
                  _TrendChip(
                    label: "🎭 Life",
                    isDark: isDark,
                    onTap: () {
                      final q = "#life";
                      setState(() {
                        _searchController.text = q;
                        _query = q;
                      });
                      ref.read(searchHistoryProvider.notifier).addQuery(q);
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscoverView(bool isDark) {
    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        // Recent History
        _buildHistorySection(isDark),

        // Quick Jump Commands Carousel (Type .)
        _buildQuickJumpCommandsSection(isDark),

        // Suggested Users Carousel
        const _SuggestedUsersCarousel(),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Trending Now",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                "What people are talking about",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),

        // Trending Tags Cloud
        _buildTrendingTags(isDark),

        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            "Discover Campus",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),

        // Masonry Grid for Posts
        const _DiscoverMasonryGrid(),

        const SizedBox(height: 100), // Bottom navigation space
      ],
    );
  }

  void _executeDotCommand(DotCommand command) {
    HapticFeedback.mediumImpact();
    ref.read(searchHistoryProvider.notifier).addQuery(command.trigger);
    _searchController.clear();
    setState(() {
      _query = '';
      _hasSubmitted = false;
    });
    context.push(command.route);
  }

  void _handleDotCommandSubmit(String rawQuery) {
    final clean = rawQuery.trim().toLowerCase();
    final match = _allDotCommands.firstWhere(
      (c) =>
          c.trigger.toLowerCase() == clean ||
          c.aliases.any((a) => a.toLowerCase() == clean),
      orElse: () {
        return _allDotCommands.firstWhere(
          (c) =>
              c.trigger.toLowerCase().startsWith(clean) ||
              clean.startsWith(c.trigger.toLowerCase()) ||
              c.title.toLowerCase().contains(clean.replaceAll('.', '')),
          orElse: () => _allDotCommands.first,
        );
      },
    );
    _executeDotCommand(match);
  }

  Widget _buildQuickJumpCommandsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.secondaryTeal),
              ),
              const SizedBox(width: 8),
              Text(
                'Quick Jump Commands',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TYPE . IN SEARCH',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black54,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _allDotCommands.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cmd = _allDotCommands[index];
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _executeDotCommand(cmd),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                    ),
                    boxShadow: isDark
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cmd.icon, size: 15, color: cmd.gradient.first),
                      const SizedBox(width: 6),
                      Text(
                        cmd.trigger,
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cmd.gradient.first,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cmd.title,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDotCommandsView(bool isDark) {
    final queryText = _query.trim().toLowerCase();
    final filter = queryText.startsWith('.') ? queryText.substring(1) : queryText;

    final matching = _allDotCommands.where((cmd) {
      if (filter.isEmpty) return true;
      final cleanTrigger = cmd.trigger.replaceAll('.', '').toLowerCase();
      final titleMatch = cmd.title.toLowerCase().contains(filter);
      final triggerMatch = cleanTrigger.contains(filter);
      final aliasMatch = cmd.aliases.any((a) => a.replaceAll('.', '').toLowerCase().contains(filter));
      final catMatch = cmd.category.toLowerCase().contains(filter);
      return triggerMatch || titleMatch || aliasMatch || catMatch;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // Command Palette Header Banner
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFFE2E8F0), const Color(0xFFF1F5F9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.secondaryTeal.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.terminal_rounded,
                  color: AppColors.secondaryTeal,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Quick Jump',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryTeal.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'COMMAND PALETTE',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondaryTeal,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      filter.isEmpty
                          ? 'Tap any command to jump to that screen instantly'
                          : 'Showing screens matching ".$filter"',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (matching.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.white30 : Colors.black26),
                const SizedBox(height: 12),
                Text(
                  'No command matching "$_query"',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try popular commands like .portal, .id, .resources, .events, .gpa, .timetable, .map',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isDark ? Colors.white38 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          ...matching.map((cmd) => _buildDotCommandTile(cmd, isDark)),
        ],
      ],
    );
  }

  Widget _buildDotCommandTile(DotCommand cmd, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _executeDotCommand(cmd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Icon with gradient
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: cmd.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: cmd.gradient.first.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(cmd.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),

                // Title, badge, subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: cmd.gradient.first.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: cmd.gradient.first.withValues(alpha: 0.4),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              cmd.trigger,
                              style: GoogleFonts.robotoMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: cmd.gradient.first,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              cmd.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cmd.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Trailing jump pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 10,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAutocompleteSuggestionsView(bool isDark) {
    final cleanQuery = _query.trim().toLowerCase();
    final searchHistory = ref.watch(searchHistoryProvider);
    final matchingHistory = searchHistory
        .where((h) => h.toLowerCase().contains(cleanQuery) && h.toLowerCase() != cleanQuery)
        .take(3)
        .toList();

    final trendingTagsAsync = ref.watch(trendingTagsProvider);
    final rawTagQuery = cleanQuery.replaceAll('#', '');
    final matchingTags = (trendingTagsAsync.value ?? [])
        .where((t) => (t['tag'] as String).toLowerCase().contains(rawTagQuery))
        .take(4)
        .toList();

    final userRepo = ref.watch(userRepositoryProvider);
    final cleanUserQuery = cleanQuery.replaceAll('@', '');

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        // 1. Direct Search Action Tile
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.secondaryTeal.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondaryTeal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_rounded,
                color: AppColors.secondaryTeal,
                size: 20,
              ),
            ),
            title: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                children: [
                  const TextSpan(text: 'Search Nest for '),
                  TextSpan(
                    text: '"$_query"',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryTeal,
                    ),
                  ),
                ],
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey,
            ),
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(searchHistoryProvider.notifier).addQuery(_query.trim());
              setState(() => _hasSubmitted = true);
            },
          ),
        ),

        // 2. Matching Hashtags Section
        if (matchingTags.isNotEmpty || cleanQuery.startsWith('#')) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.tag_rounded, size: 16, color: AppColors.secondaryTeal),
                const SizedBox(width: 6),
                Text(
                  'HASHTAGS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // If user typed a custom hashtag not in top list, allow navigating to it directly
                if (cleanQuery.startsWith('#') &&
                    cleanQuery.length > 1 &&
                    !matchingTags.any((t) => (t['tag'] as String).toLowerCase() == rawTagQuery)) ...[
                  ListTile(
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.tag_rounded, color: AppColors.secondaryTeal, size: 20),
                    ),
                    title: Text(
                      '#$rawTagQuery',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text('Explore hashtag hub', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    trailing: const Icon(Icons.north_east_rounded, size: 16, color: Colors.grey),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(searchHistoryProvider.notifier).addQuery('#$rawTagQuery');
                      context.push('/hashtag/$rawTagQuery');
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                ],
                ...matchingTags.map((t) {
                  final tag = (t['tag'] as String).replaceAll('#', '');
                  final count = t['count'] as int? ?? 1;
                  return ListTile(
                    dense: true,
                    leading: const CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.tag_rounded, color: AppColors.secondaryTeal, size: 18),
                    ),
                    title: Text(
                      '#$tag',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    subtitle: Text('$count posts on campus', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(searchHistoryProvider.notifier).addQuery('#$tag');
                      context.push('/hashtag/$tag');
                    },
                  );
                }),
              ],
            ),
          ),
        ],

        // 3. Matching Accounts Section (Live instant suggestion)
        if (cleanUserQuery.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.person_search_rounded, size: 16, color: AppColors.secondaryTeal),
                const SizedBox(width: 6),
                Text(
                  'ACCOUNTS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          FutureBuilder<List<AppUser>>(
            future: userRepo.searchUsers(cleanUserQuery),
            builder: (context, snapshot) {
              final users = (snapshot.data ?? []).take(3).toList();
              if (users.isEmpty) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: users.map((user) {
                    final handle = user.handle.isNotEmpty ? user.handle : user.displayName;
                    return ListTile(
                      leading: UserAvatar(
                        userId: user.uid,
                        avatarUrl: user.avatarUrl,
                        radius: 18,
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (user.isVerified) ...[
                            const SizedBox(width: 4),
                            VerificationBadge(type: user.verificationType, size: 14),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        '@$handle',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/user/${user.uid}');
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],

        // 4. Matching Recent Searches
        if (matchingHistory.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'RECENT MATCHES',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: matchingHistory.map((item) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.history_rounded, size: 18, color: Colors.grey),
                  title: Text(item, style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.north_west_rounded, size: 16, color: Colors.grey),
                    tooltip: 'Put into search',
                    onPressed: () {
                      _searchController.text = item;
                      setState(() => _query = item);
                    },
                  ),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _searchController.text = item;
                    setState(() {
                      _query = item;
                      _hasSubmitted = true;
                    });
                  },
                );
              }).toList(),
            ),
          ),
        ],

        // 5. Full search CTA Button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(searchHistoryProvider.notifier).addQuery(_query.trim());
              setState(() => _hasSubmitted = true);
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: AppColors.secondaryTeal.withValues(alpha: 0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18, color: AppColors.secondaryTeal),
            label: Text(
              'See all results for "$_query"',
              style: const TextStyle(
                color: AppColors.secondaryTeal,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResultsView(bool isDark) {
    return TabBarView(
      controller: _tabController,
      children: [
        _SearchResultsList(query: _query, filter: 'top'),
        _SearchResultsList(query: _query, filter: 'latest'),
        _PeopleSearchResults(query: _query),
        _HashtagsSearchResults(
          query: _query,
          onSelectTag: (tag) {
            setState(() {
              _searchController.text = tag;
              _query = tag;
            });
            ref.read(searchHistoryProvider.notifier).addQuery(tag);
            _tabController.animateTo(0);
          },
        ),
        _SearchResultsList(query: _query, filter: 'media'),
      ],
    );
  }

  Widget _buildHistorySection(bool isDark) {
    final searchHistory = ref.watch(searchHistoryProvider);
    if (searchHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Recent",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              GestureDetector(
                onTap: () => ref.read(searchHistoryProvider.notifier).clearHistory(),
                child: Text(
                  "Clear all",
                  style: TextStyle(
                    color: AppColors.secondaryTeal,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 36,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: searchHistory.length,
            itemBuilder: (context, index) {
              final query = searchHistory[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InputChip(
                  label: Text(query),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _searchController.text = query;
                      _query = query;
                    });
                    ref.read(searchHistoryProvider.notifier).addQuery(query);
                  },
                  onDeleted: () => ref.read(searchHistoryProvider.notifier).removeQuery(query),
                  deleteIcon: Icon(
                    Icons.close,
                    size: 14,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  side: BorderSide.none,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildTrendingTags(bool isDark) {
    final trendingTagsAsync = ref.watch(trendingTagsProvider);

    return trendingTagsAsync.when(
      data: (tags) {
        if (tags.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text("No trending tags yet", style: TextStyle(color: Colors.grey, fontSize: 13)),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tagData) {
              final tag = tagData['tag'] as String;
              final count = tagData['count'] as int;
              final hashtag = tag.startsWith('#') ? tag : '#$tag';

              return InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final cleanTag = hashtag.replaceAll('#', '').trim();
                  context.push('/hashtag/$cleanTag');
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.secondaryTeal.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hashtag,
                        style: const TextStyle(
                          color: AppColors.secondaryTeal,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      if (count > 1) ...[
                        const SizedBox(width: 4),
                        Text(
                          "• $count",
                          style: TextStyle(
                            color: AppColors.secondaryTeal.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(6, (i) => Shimmer.fromColors(
            baseColor: isDark ? Colors.white10 : Colors.black12,
            highlightColor: isDark ? Colors.white24 : Colors.black26,
            child: Container(
              width: 80 + (i * 10).toDouble(),
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          )),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _TrendChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _TrendChip({
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.8)
                : Colors.black.withValues(alpha: 0.7),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _SuggestedUsersCarousel extends ConsumerWidget {
  const _SuggestedUsersCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Text(
            "Who to follow",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        SizedBox(
          height: 200,
          child: StreamBuilder<List<AppUser>>(
            stream: userRepo.watchPopularUsers(),
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              if (users.isEmpty) return const SizedBox.shrink();

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return GestureDetector(
                    onTap: () => context.push('/user/${user.uid}'),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final isFollowing =
                            ref.watch(isFollowingProvider(user.uid)).value ??
                            false;
                        final currentUid = ref.watch(currentUserIdProvider);
                        final isMe = currentUid == user.uid;

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Stack(
                              children: [
                            UserAvatar(
                              userId: user.uid,
                              avatarUrl: user.avatarUrl,
                              displayName: user.displayName,
                              radius: 30,
                              showStoryRing: true,
                            ),
                                if (user.isVerified)
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: VerificationBadge(
                                        type: user.verificationType,
                                        size: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "@${user.handle}",
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            if (!isMe)
                              ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  if (isFollowing) {
                                    ref
                                        .read(userRepositoryProvider)
                                        .unfollowUser(user.uid);
                                  } else {
                                    ref
                                        .read(userRepositoryProvider)
                                        .followUser(user.uid);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing
                                      ? Colors.transparent
                                      : AppColors.secondaryTeal,
                                  foregroundColor: isFollowing
                                      ? AppColors.secondaryTeal
                                      : Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size(double.infinity, 30),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: isFollowing
                                        ? const BorderSide(
                                            color: AppColors.secondaryTeal,
                                          )
                                        : BorderSide.none,
                                  ),
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  isFollowing ? "Following" : "Follow",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
        ),
      ],
    );
  }
}

class _DiscoverMasonryGrid extends ConsumerWidget {
  const _DiscoverMasonryGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postRepo = ref.watch(postRepositoryProvider);
    return StreamBuilder<List<Post>>(
      stream: postRepo.watchSuggestedPosts(),
      builder: (context, snapshot) {
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: MasonryGridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return _MasonryPostItem(post: post, index: index)
                  .animate(delay: (index * 50).ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.2, end: 0, curve: Curves.easeOutQuart);
            },
          ),
        );
      },
    );
  }
}

class _MasonryPostItem extends StatelessWidget {
  final Post post;
  final int index;

  const _MasonryPostItem({required this.post, required this.index});

  @override
  Widget build(BuildContext context) {
    final hasMedia = post.mediaUrl.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: AspectRatio(
            aspectRatio: (index % 3 == 0) ? 0.8 : 1.1, // Dynamic aspect ratio
            child: Stack(
              children: [
                // Background Content
                Positioned.fill(
                  child: (hasMedia && UrlValidator.isValidUrl(post.mediaUrl))
                      ? CachedNetworkImage(
                          imageUrl: post.mediaUrl,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => _buildPlaceholder(isDark),
                          errorWidget: (context, url, error) => _buildPlaceholder(isDark),
                        )
                      : _buildTextBackground(isDark),
                ),

                // Glassmorphic Overlay & Shine Effect
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.4),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),

                // Diagonal Shine
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.0),
                          Colors.white.withValues(alpha: 0.05),
                          Colors.white.withValues(alpha: 0.0),
                        ],
                        begin: const Alignment(-1.5, -1.0),
                        end: const Alignment(1.5, 1.0),
                        stops: const [0.45, 0.5, 0.55],
                      ),
                    ),
                  ),
                ),

                // Top Left: Content Type Icons
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(height: 8),
                        const Icon(
                          Icons.image_outlined,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Left: Relevance Bubble (Profile + Stats)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            UserAvatar(
                              userId: post.authorId,
                              avatarUrl: post.authorAvatarUrl,
                              displayName: post.authorName,
                              radius: 12,
                              showStoryRing: false,
                              enableDefaultTap: false,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "p.p",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Right: Engagement Bubble (Heart + Count)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.favorite_rounded,
                          color: Colors.pinkAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(post.likesCount),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_outlined,
          color: isDark ? Colors.white10 : Colors.black12,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildTextBackground(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondaryTeal.withValues(alpha: 0.8),
            AppColors.secondaryTeal.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          post.content,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

String _formatCount(int count) {
  if (count >= 1000000) return "${(count / 1000000).toStringAsFixed(1)}M";
  if (count >= 1000) return "${(count / 1000).toStringAsFixed(1)}K";
  return count.toString();
}

class _SearchResultsList extends ConsumerWidget {
  final String query;
  final String filter;

  const _SearchResultsList({required this.query, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postRepo = ref.watch(postRepositoryProvider);

    return StreamBuilder<List<Post>>(
      stream: Stream.fromFuture(postRepo.searchPosts(query)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SearchSkeleton();
        }

        var posts = snapshot.data ?? [];

        // Apply filters
        if (filter == 'top') {
          posts.sort((a, b) => b.likesCount.compareTo(a.likesCount));
        } else if (filter == 'media') {
          posts = posts.where((p) => p.mediaUrl.isNotEmpty).toList();
        }

        if (posts.isEmpty) {
          return _NoResultsView(query: query);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8),
          itemCount: posts.length,
          itemBuilder: (context, index) => PostCard(post: posts[index]),
        );
      },
    );
  }
}

class _PeopleSearchResults extends ConsumerWidget {
  final String query;

  const _PeopleSearchResults({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userRepo = ref.watch(userRepositoryProvider);

    return StreamBuilder<List<AppUser>>(
      stream: Stream.fromFuture(userRepo.searchUsers(query)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SearchSkeleton();
        }

        final users = snapshot.data ?? [];

        if (users.isEmpty) {
          return _NoResultsView(query: query);
        }

        return ListView.separated(
          padding: const EdgeInsets.only(top: 8),
          itemCount: users.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: UserAvatar(
                userId: user.uid,
                avatarUrl: user.avatarUrl,
                radius: 24,
              ),
              title: Row(
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 4),
                    VerificationBadge(type: user.verificationType, size: 14),
                  ],
                ],
              ),
              subtitle: Text(
                "@${user.handle}",
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: Consumer(
                builder: (context, ref, child) {
                  final isFollowing =
                      ref.watch(isFollowingProvider(user.uid)).value ?? false;
                  final currentUid = ref.watch(currentUserIdProvider);
                  if (currentUid == user.uid) return const SizedBox.shrink();

                  return ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      if (isFollowing) {
                        ref.read(userRepositoryProvider).unfollowUser(user.uid);
                      } else {
                        ref.read(userRepositoryProvider).followUser(user.uid);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing
                          ? Colors.transparent
                          : AppColors.secondaryTeal,
                      foregroundColor: isFollowing
                          ? AppColors.secondaryTeal
                          : Colors.white,
                      elevation: 0,
                      side: isFollowing
                          ? const BorderSide(color: AppColors.secondaryTeal)
                          : null,
                      minimumSize: const Size(80, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      isFollowing ? "Following" : "Follow",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
              onTap: () => context.push('/user/${user.uid}'),
            );
          },
        );
      },
    );
  }
}

class _HashtagsSearchResults extends ConsumerWidget {
  final String query;
  final Function(String tag) onSelectTag;

  const _HashtagsSearchResults({
    required this.query,
    required this.onSelectTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trendingTagsAsync = ref.watch(trendingTagsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return trendingTagsAsync.when(
      data: (allTags) {
        final cleanQuery = query.toLowerCase().replaceAll('#', '').trim();
        final List<Map<String, dynamic>> tags;
        if (cleanQuery.isEmpty) {
          tags = allTags;
        } else {
          final filtered = allTags.where((t) {
            final tag = (t['tag'] ?? t['name'] ?? '').toString().toLowerCase();
            return tag.contains(cleanQuery);
          }).toList();

          if (filtered.isEmpty) {
            tags = [
              {
                'tag': '#$cleanQuery',
                'name': cleanQuery,
                'count': 1,
              }
            ];
          } else {
            tags = filtered;
          }
        }

        if (tags.isEmpty) {
          return _NoResultsView(query: query);
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tags.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          ),
          itemBuilder: (context, index) {
            final item = tags[index];
            final rawTag = (item['tag'] ?? item['name'] ?? '').toString();
            final hashtag = rawTag.startsWith('#') ? rawTag : '#$rawTag';
            final count = item['count'] is int ? item['count'] as int : 1;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.secondaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.tag_rounded,
                  color: AppColors.secondaryTeal,
                  size: 24,
                ),
              ),
              title: Text(
                hashtag,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                count == 1 ? '1 post' : '$count posts',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Colors.grey,
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                final cleanTag = hashtag.replaceAll('#', '').trim();
                context.push('/hashtag/$cleanTag');
              },
            );
          },
        );
      },
      loading: () => const _SearchSkeleton(),
      error: (err, stack) => _NoResultsView(query: query),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  final String query;

  const _NoResultsView({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "No results for '$query'",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Try searching for something else",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SearchSkeleton extends StatelessWidget {
  const _SearchSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 100,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

class DotCommand {
  final String trigger;
  final List<String> aliases;
  final String title;
  final String subtitle;
  final String route;
  final IconData icon;
  final List<Color> gradient;
  final String category;

  const DotCommand({
    required this.trigger,
    this.aliases = const [],
    required this.title,
    required this.subtitle,
    required this.route,
    required this.icon,
    required this.gradient,
    required this.category,
  });
}

const List<DotCommand> _allDotCommands = [
  DotCommand(
    trigger: '.portal',
    aliases: ['.studentportal', '.myportal', '.portal'],
    title: 'Student Portal',
    subtitle: 'Academic profile, grades, registrations & records',
    route: '/portal',
    icon: Icons.school_rounded,
    gradient: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.id',
    aliases: ['.idcard', '.studentid', '.badge', '.identity'],
    title: 'Digital Student ID',
    subtitle: 'Official smart student identity card & barcode',
    route: '/student-id',
    icon: Icons.badge_rounded,
    gradient: [Color(0xFF06B6D4), Color(0xFF0891B2)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.resources',
    aliases: ['.resource', '.library', '.notes', '.handouts', '.materials'],
    title: 'Academic Resources',
    subtitle: 'Lecture notes, handouts, slides & past questions',
    route: '/resources',
    icon: Icons.menu_book_rounded,
    gradient: [Color(0xFF10B981), Color(0xFF047857)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.events',
    aliases: ['.event', '.calendar', '.campus-events'],
    title: 'Campus Events',
    subtitle: 'Concerts, academic seminars, sports & hall events',
    route: '/events',
    icon: Icons.celebration_rounded,
    gradient: [Color(0xFFEC4899), Color(0xFFBE185D)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.gpa',
    aliases: ['.cgpa', '.grades', '.calculator', '.calculate-gpa'],
    title: 'GPA / CGPA Calculator',
    subtitle: 'Compute semester GPA & target academic honors',
    route: '/gpa',
    icon: Icons.calculate_rounded,
    gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.timetable',
    aliases: ['.time', '.schedule', '.classes', '.lectures'],
    title: 'Class Timetable',
    subtitle: 'Weekly lecture schedule, halls & time slots',
    route: '/timetable',
    icon: Icons.schedule_rounded,
    gradient: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.map',
    aliases: ['.campusmap', '.directions', '.locations', '.navigate'],
    title: 'Campus Map & GPS',
    subtitle: 'Interactive map of colleges, hostels & landmarks',
    route: '/map',
    icon: Icons.map_rounded,
    gradient: [Color(0xFF14B8A6), Color(0xFF0F766E)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.marketplace',
    aliases: ['.market', '.store', '.buy', '.sell', '.items'],
    title: 'Campus Marketplace',
    subtitle: 'Student deals for textbooks, appliances & gadgets',
    route: '/marketplace',
    icon: Icons.storefront_rounded,
    gradient: [Color(0xFFF97316), Color(0xFFC2410C)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.lost',
    aliases: ['.lostandfound', '.lostfound', '.found'],
    title: 'Lost & Found',
    subtitle: 'Report or recover lost ID cards, keys & valuables',
    route: '/lost-found',
    icon: Icons.find_in_page_rounded,
    gradient: [Color(0xFFEF4444), Color(0xFFB91C1C)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.groups',
    aliases: ['.clubs', '.community', '.fellowship', '.societies'],
    title: 'Student Groups & Clubs',
    subtitle: 'Departmental associations, sports & religious clubs',
    route: '/groups',
    icon: Icons.groups_rounded,
    gradient: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.ai',
    aliases: ['.bot', '.companion', '.assistant', '.ask'],
    title: 'ABUAD AI Companion',
    subtitle: '24/7 intelligent campus tutor & course assistant',
    route: '/ai',
    icon: Icons.auto_awesome_rounded,
    gradient: [Color(0xFF6366F1), Color(0xFF4338CA)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.chat',
    aliases: ['.messages', '.dm', '.inbox', '.conversations'],
    title: 'Chats & Messages',
    subtitle: 'Direct messages, class groups & ephemeral snaps',
    route: '/chat',
    icon: Icons.chat_bubble_rounded,
    gradient: [Color(0xFF10B981), Color(0xFF059669)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.scanner',
    aliases: ['.qr', '.scan', '.barcode'],
    title: 'QR Scanner',
    subtitle: 'Scan student profile codes, gate passes & event tickets',
    route: '/chat/scanner',
    icon: Icons.qr_code_scanner_rounded,
    gradient: [Color(0xFFA855F7), Color(0xFF9333EA)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.profile',
    aliases: ['.me', '.myprofile', '.user'],
    title: 'My Student Profile',
    subtitle: 'Personal bio, department, verification & posts',
    route: '/profile',
    icon: Icons.person_rounded,
    gradient: [Color(0xFF3B82F6), Color(0xFF2563EB)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.notifications',
    aliases: ['.alerts', '.notifs', '.updates'],
    title: 'Alerts & Notifications',
    subtitle: 'Official announcements, course alerts & mentions',
    route: '/notifications',
    icon: Icons.notifications_rounded,
    gradient: [Color(0xFFE11D48), Color(0xFFBE123C)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.settings',
    aliases: ['.config', '.preferences', '.theme'],
    title: 'Settings & Privacy',
    subtitle: 'Appearance, notifications, security & legal',
    route: '/settings',
    icon: Icons.settings_rounded,
    gradient: [Color(0xFF64748B), Color(0xFF475569)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.exam',
    aliases: ['.study', '.countdown', '.finals', '.pomodoro'],
    title: 'Exam Countdown & Study Planner',
    subtitle: 'Visual GST & finals timer with course study checklists',
    route: '/exam-countdown',
    icon: Icons.timer_outlined,
    gradient: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.target',
    aliases: ['.cgpasim', '.simulator', '.gradecheck'],
    title: 'CGPA Target & Semester Simulator',
    subtitle: 'Simulate target honors and calculate required grades',
    route: '/cgpa-simulator',
    icon: Icons.auto_graph_rounded,
    gradient: [Color(0xFF10B981), Color(0xFF059669)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.cbt',
    aliases: ['.practice', '.mock', '.pastquestions', '.quiz'],
    title: 'CBT Practice & Past Questions Hub',
    subtitle: 'Interactive mock exams for GST 111, 112, 211, MTH 101, CHM 101',
    route: '/cbt-practice',
    icon: Icons.quiz_rounded,
    gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.attendance',
    aliases: ['.lecture', '.chapel', '.rules', '.eligibility'],
    title: '75% Attendance & Chapel Tracker',
    subtitle: 'Ensure exam eligibility for lectures & mandatory chapel services',
    route: '/attendance-tracker',
    icon: Icons.fact_check_rounded,
    gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    category: 'Academic',
  ),
  DotCommand(
    trigger: '.hostel',
    aliases: ['.roommate', '.maintenance', '.repairs', '.hall'],
    title: 'Hostel Maintenance & Roommate Hub',
    subtitle: 'Submit maintenance work orders & find compatible hall roommates',
    route: '/hostel-hub',
    icon: Icons.hotel_rounded,
    gradient: [Color(0xFF06B6D4), Color(0xFF0891B2)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.shuttle',
    aliases: ['.ride', '.bus', '.carpool', '.transport'],
    title: 'Campus Shuttle & Travel Board',
    subtitle: 'Live campus shuttle routes & student airport carpool board',
    route: '/shuttle-board',
    icon: Icons.directions_bus_rounded,
    gradient: [Color(0xFF14B8A6), Color(0xFF0D9488)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.gigs',
    aliases: ['.services', '.freelance', '.skills', '.barber', '.tutor'],
    title: 'Student Gigs & Freelance Directory',
    subtitle: 'Campus peer services: tech repairs, hair styling, photography, tutoring',
    route: '/student-gigs',
    icon: Icons.handyman_rounded,
    gradient: [Color(0xFFEC4899), Color(0xFFDB2777)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.polls',
    aliases: ['.debate', '.vote', '.hallclash', '.clash'],
    title: 'Campus Polls & Hall Debates',
    subtitle: 'Real-time voting, debates and student opinions across colleges',
    route: '/campus-polls',
    icon: Icons.how_to_vote_rounded,
    gradient: [Color(0xFF6366F1), Color(0xFF4338CA)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.sports',
    aliases: ['.league', '.vccup', '.football', '.scores', '.fixtures'],
    title: 'Inter-Hall Sports & VC Cup Center',
    subtitle: 'Live match scores, fixtures, and college championship standings',
    route: '/sports-center',
    icon: Icons.sports_soccer_rounded,
    gradient: [Color(0xFF10B981), Color(0xFF047857)],
    category: 'Campus Life',
  ),
  DotCommand(
    trigger: '.studygroup',
    aliases: ['.lounge', '.circle', '.audiostudy', '.groupstudy'],
    title: 'Audio Study Lounges & Circles',
    subtitle: 'Join live peer voice revision rooms and study circles',
    route: '/study-lounges',
    icon: Icons.record_voice_over_rounded,
    gradient: [Color(0xFFA855F7), Color(0xFF7E22CE)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.sos',
    aliases: ['.emergency', '.security', '.panic', '.helpme'],
    title: 'Campus SOS & Security Emergency',
    subtitle: 'Instant panic dispatch to campus security & AMSH emergency hospital',
    route: '/campus-sos',
    icon: Icons.emergency_rounded,
    gradient: [Color(0xFFEF4444), Color(0xFFB91C1C)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.clinic',
    aliases: ['.hospital', '.opd', '.queue', '.pharmacy', '.amsh'],
    title: 'Health Centre OPD & Pharmacy Queue',
    subtitle: 'Live virtual clinic queue ticket and campus medication stock',
    route: '/clinic-queue',
    icon: Icons.local_hospital_rounded,
    gradient: [Color(0xFF14B8A6), Color(0xFF0F766E)],
    category: 'Connect & Tools',
  ),
  DotCommand(
    trigger: '.stickers',
    aliases: ['.sticker', '.gif', '.doodle', '.meme'],
    title: 'Sticker & GIF Creator',
    subtitle: 'Create doodles, photo cutouts & video loop stickers for chats',
    route: '/sticker-creator',
    icon: Icons.auto_awesome,
    gradient: [Color(0xFFF59E0B), Color(0xFFB45309)],
    category: 'Connect & Tools',
  ),
];
