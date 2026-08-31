// lib/WebView/Hompage/main_content_tabs.dart
import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';
import '../../utils/add_helper.dart';
import 'dart:async';

class MainContentTabs extends StatefulWidget {
  final Widget arenaContent;
  final Widget feedContent;
  final Widget logsContent;

  const MainContentTabs({
    super.key,
    required this.arenaContent,
    required this.feedContent,
    required this.logsContent,
  });

  @override
  State<MainContentTabs> createState() => _MainContentTabsState();
}

class _MainContentTabsState extends State<MainContentTabs> {
  // Carousel state
  List<Map<String, dynamic>> _carouselItems = [];
  int _currentIndex = 0;
  Timer? _carouselTimer;
  bool _isRunning = false;

  final List<Map<String, dynamic>> _sampleComrades = const [
    {'name': '⚽ GoalMachine', 'team': 'Real Madrid'},
    {'name': '🔥 FireStriker', 'team': 'Barcelona'},
    {'name': '🛡️ DefenseWall', 'team': 'Bayern'},
    {'name': '🎯 Sniper', 'team': 'PSG'},
    {'name': '💪 PowerShot', 'team': 'Liverpool'},
    {'name': '✨ MagicFeet', 'team': 'Man City'},
  ];

  @override
  void initState() {
    super.initState();
    _buildCarouselItems();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _buildCarouselItems() {
    final items = <Map<String, dynamic>>[];

    // Add sample comrades
    for (var comrade in _sampleComrades) {
      items.add({
        'type': 'comrade',
        'name': comrade['name'],
        'team': comrade['team'],
      });
    }

    // Add ads (every 3rd item)
    final adIds = AdHelper.carouselAdUnitIds;
    final List<Map<String, dynamic>> finalItems = [];
    int adIndex = 0;

    for (int i = 0; i < items.length; i++) {
      finalItems.add(items[i]);
      if ((i + 1) % 3 == 0 && adIndex < adIds.length) {
        finalItems.add({
          'type': 'ad',
          'adUnitId': adIds[adIndex % adIds.length],
        });
        adIndex++;
      }
    }

    setState(() {
      _carouselItems = finalItems;
    });
  }

  void _startAutoScroll() {
    if (_isRunning) return;
    _isRunning = true;

    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _carouselItems.isEmpty) {
        timer.cancel();
        _isRunning = false;
        return;
      }
      setState(() {
        _currentIndex = (_currentIndex + 1) % _carouselItems.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Arena Tab
        Expanded(
          child: _buildTabContent('Arena', widget.arenaContent),
        ),
        // Feed Tab
        Expanded(
          child: _buildTabContent('Feed', widget.feedContent),
        ),
        // Logs Tab - With horizontal carousel at bottom
        Expanded(
          child: _buildLogsTab(),
        ),
      ],
    );
  }

  Widget _buildTabContent(String label, Widget content) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: FanColors.border.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FanColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Divider(height: 0.5, color: FanColors.border.withValues(alpha: 0.06)),
          Expanded(
            child: content,
          ),
        ],
      ),
    );
  }

  // ✅ Logs Tab with Snackbar-style Carousel at bottom
  Widget _buildLogsTab() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: FanColors.border.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Logs',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: FanColors.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Divider(height: 0.5, color: FanColors.border.withValues(alpha: 0.06)),
          // History content (fills remaining space)
          Expanded(
            child: widget.logsContent,
          ),
          // ✅ Snackbar-style carousel at bottom
          _buildSnackbarCarousel(),
        ],
      ),
    );
  }

  // ==========================================================================
  // SNACKBAR-STYLE CAROUSEL - Horizontal, compact, at bottom
  // ==========================================================================

  Widget _buildSnackbarCarousel() {
    if (_carouselItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final currentItem = _carouselItems[_currentIndex];
    final isAd = currentItem['type'] == 'ad';

    return Container(
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAd
            ? FanColors.primary.withValues(alpha: 0.06)
            : FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAd
              ? FanColors.primary.withValues(alpha: 0.15)
              : FanColors.border.withValues(alpha: 0.06),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Left icon
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: isAd
                  ? FanColors.primary.withValues(alpha: 0.08)
                  : FanColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isAd
                  ? const Text('📢', style: TextStyle(fontSize: 12))
                  : Text(
                      currentItem['name']?.substring(0, 1) ?? '👤',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: FanColors.primary,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 8),
          // Content
          Expanded(
            child: isAd
                ? Row(
                    children: [
                      Text(
                        '✨ ',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: FanColors.primary,
                        ),
                      ),
                      Text(
                        'Support Funzy+',
                        style: TextStyle(
                          fontSize: 10,
                          color: FanColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: FanColors.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Learn',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Text(
                        currentItem['name'] ?? '',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: FanColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: FanColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          currentItem['team'] ?? '',
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.w500,
                            color: FanColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          // Right arrow / navigation
          Container(
            margin: const EdgeInsets.only(right: 4),
            child: Row(
              children: [
                // Dots (mini indicator)
                ...List.generate(
                  _carouselItems.length > 6 ? 6 : _carouselItems.length,
                  (i) {
                    final active = i == _currentIndex % 6;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      width: active ? 10 : 4,
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: active
                            ? FanColors.primary
                            : FanColors.textTertiary.withValues(alpha: 0.2),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: FanColors.textTertiary.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
