// lib/WebView/Hompage/main_content_tabs.dart
import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';

class MainContentTabs extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Arena Tab
        Expanded(
          child: _buildTabContent('Arena', arenaContent),
        ),
        // Feed Tab
        Expanded(
          child: _buildTabContent('Feed', feedContent),
        ),
        // Logs Tab - Contains History + Right Panel Carousel
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

  // ✅ Logs Tab with Right Panel Carousel
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
          Expanded(
            child: Row(
              children: [
                // History content (takes most space)
                Expanded(
                  flex: 3,
                  child: logsContent,
                ),
                // ✅ Right panel carousel (only on logs tab)
                _buildRightPanelCarousel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPanelCarousel() {
    // This will be replaced by the actual carousel from HomePageWeb
    // For now, show a placeholder
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: FanColors.surfaceSunken,
        border: Border(
          left: BorderSide(
            color: FanColors.border.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                Icon(Icons.people_outline,
                    size: 12, color: FanColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  'Community',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textTertiary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 0.5, color: FanColors.border.withValues(alpha: 0.06)),
          Expanded(
            child: Center(
              child: Text(
                'Carousel placeholder',
                style: TextStyle(
                  fontSize: 10,
                  color: FanColors.textTertiary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
