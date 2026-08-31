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
        // Logs Tab
        Expanded(
          child: _buildTabContent('Logs', logsContent),
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
}
