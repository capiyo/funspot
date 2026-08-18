// lib/widgets/main_content_tabs.dart
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
            child: _buildPane('Arena', Icons.shield_outlined, arenaContent)),
        _buildDivider(),
        Expanded(
            child: _buildPane('Feed', Icons.newspaper_outlined, feedContent)),
        _buildDivider(),
        Expanded(
            child: _buildPane('Logs', Icons.history_outlined, logsContent)),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      color: FanColors.border.withValues(alpha: 0.3),
    );
  }

  Widget _buildPane(String label, IconData icon, Widget content) {
    return Column(
      children: [
        Container(
          height: 44,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: FanColors.surfaceElevated,
            border: Border(
              bottom: BorderSide(
                color: FanColors.border.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: FanColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: FanColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: content),
      ],
    );
  }
}
