// lib/modals/homepage/notifications_list_modal.dart
//
// Shared notifications list modal — renders the `_notifications` list that
// HomePage / HomePageWeb already collect (via _addToNotificationList) but
// never actually display anywhere. Works on both mobile and web since it
// only depends on FanColors/FanTypography/FanRadius and plain data.

import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';

class NotificationsListModal extends StatefulWidget {
  /// The raw notification maps, newest first. Each item is expected to have:
  /// 'type', 'title', 'body', 'data', 'timestamp' (ISO8601 string), 'isUnread'.
  final List<Map<String, dynamic>> notifications;

  /// Called when the modal wants to persist "all read" / per-item read state
  /// back to the parent (which then calls _saveNotifications()).
  final VoidCallback onMarkAllRead;

  /// Called with the tapped notification's data payload, so the parent can
  /// route to the right screen (chat, fixture, profile, etc). May be null
  /// if the notification type has nowhere to go.
  final void Function(Map<String, dynamic> notification)? onNotificationTap;

  /// Optional: clear the whole list.
  final VoidCallback? onClearAll;

  const NotificationsListModal({
    super.key,
    required this.notifications,
    required this.onMarkAllRead,
    this.onNotificationTap,
    this.onClearAll,
  });

  @override
  State<NotificationsListModal> createState() =>
      _NotificationsListModalState();
}

class _NotificationsListModalState extends State<NotificationsListModal> {
  late List<Map<String, dynamic>> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, dynamic>>.from(widget.notifications);
    // Mark everything read the moment the modal is opened — matches the
    // existing _onNotificationsViewed contract (tap = viewed = read).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMarkAllRead();
    });
  }

  String _iconFor(String type) {
    switch (type) {
      case 'join_request':
        return '📥';
      case 'join_approved':
        return '✅';
      case 'join_rejected':
        return '❌';
      case 'comrade_added':
        return '🎉';
      case 'vote_supporter':
        return '🎉';
      case 'vote_rival':
        return '⚔️';
      case 'fixture_comment':
      case 'fixture_comment_push':
        return '💬';
      case 'fixture_like':
        return '❤️';
      case 'channel_invite':
        return '📨';
      case 'join_link':
        return '🔗';
      default:
        return '🔔';
    }
  }

  String _formatTimeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final dt = DateTime.tryParse(isoString);
    if (dt == null) return '';

    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays > 7) return '${diff.inDays ~/ 7}w ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: BoxDecoration(
        color: FanColors.background,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(FanRadius.xl),
          topRight: Radius.circular(FanRadius.xl),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FanColors.border.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: FanColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(Icons.notifications_none_rounded,
                        size: 22, color: FanColors.primary),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _items.isEmpty
                            ? 'You\'re all caught up'
                            : '${_items.length} notification${_items.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_items.isNotEmpty && widget.onClearAll != null)
                  GestureDetector(
                    onTap: () {
                      widget.onClearAll?.call();
                      setState(() => _items = []);
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: FanColors.primary,
                        ),
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: FanColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: FanColors.border),
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 48, color: FanColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No notifications yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'We\'ll let you know when something happens',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = _items[index];
                      final type = n['type']?.toString() ?? 'general';
                      final title = n['title']?.toString() ?? 'Notification';
                      final body = n['body']?.toString() ?? '';
                      final timestamp = n['timestamp']?.toString();
                      final data = n['data'] is Map
                          ? Map<String, dynamic>.from(n['data'])
                          : <String, dynamic>{};
                      final wasUnread = n['isUnread'] == true;

                      return GestureDetector(
                        onTap: () {
                          widget.onNotificationTap?.call({
                            'type': type,
                            'data': data,
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: wasUnread
                                ? FanColors.primary.withValues(alpha: 0.06)
                                : FanColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: wasUnread
                                ? Border.all(
                                    color: FanColors.primary
                                        .withValues(alpha: 0.25),
                                    width: 0.75,
                                  )
                                : null,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: FanColors.primary
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    _iconFor(type),
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (body.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        body,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white
                                              .withValues(alpha: 0.65),
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTimeAgo(timestamp),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.white
                                            .withValues(alpha: 0.35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (wasUnread)
                                Container(
                                  margin: const EdgeInsets.only(left: 6, top: 2),
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
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
      ),
    );
  }
}