// chat_modal.dart
import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';
import 'package:intl/intl.dart';

class ChatModal extends StatefulWidget {
  final String voteId;
  final String username;
  final String homeTeam;
  final String awayTeam;
  final String selection;

  const ChatModal({
    super.key,
    required this.voteId,
    required this.username,
    required this.homeTeam,
    required this.awayTeam,
    required this.selection,
  });

  @override
  State<ChatModal> createState() => _ChatModalState();
}

class _ChatModalState extends State<ChatModal> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadChatMessages() async {
    // Simulate loading
    await Future.delayed(const Duration(seconds: 1));

    // Sample messages
    _messages.addAll([
      {
        'id': '1',
        'sender': widget.username,
        'message':
            'I think ${widget.selection == 'home_team' ? widget.homeTeam : widget.awayTeam} will win!',
        'time': DateTime.now().subtract(const Duration(minutes: 30)),
        'isMe': false,
      },
      {
        'id': '2',
        'sender': 'Fan123',
        'message': 'I disagree, the other team has better form',
        'time': DateTime.now().subtract(const Duration(minutes: 25)),
        'isMe': false,
      },
      {
        'id': '3',
        'sender': 'You',
        'message': 'What are your predictions for the score?',
        'time': DateTime.now().subtract(const Duration(minutes: 15)),
        'isMe': true,
      },
    ]);

    setState(() {
      _isLoading = false;
    });
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final newMessage = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'sender': 'You',
      'message': _messageController.text.trim(),
      'time': DateTime.now(),
      'isMe': true,
    };

    setState(() {
      _messages.add(newMessage);
      _messageController.clear();
    });

    // In a real app, you would send this to your backend
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM d').format(time);
  }

  Color _getSelectionColor() {
    switch (widget.selection) {
      case 'home_team':
        return FanColors.primary;
      case 'away_team':
        return FanColors.reactionShare;
      case 'draw':
        return FanColors.draw;
      default:
        return FanColors.textSecondary;
    }
  }

  String _getSelectionLabel() {
    switch (widget.selection) {
      case 'home_team':
        return 'Home';
      case 'away_team':
        return 'Away';
      case 'draw':
        return 'Draw';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: FanColors.background,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: FanColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Chat: ${widget.username}',
          style: FanTypography.body.copyWith(
            color: FanColors.textPrimary,
          ),
        ),
        elevation: 0,
      ),
      backgroundColor: FanColors.background,
      body: Column(
        children: [
          // Match info header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FanColors.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: FanColors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.homeTeam,
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'vs',
                      style: FanTypography.tag.copyWith(
                        color: FanColors.textSecondary,
                      ),
                    ),
                    Text(
                      widget.awayTeam,
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getSelectionColor(),
                    borderRadius: FanRadius.pillAll,
                  ),
                  child: Text(
                    _getSelectionLabel(),
                    style: FanTypography.tag.copyWith(
                      color: FanColors.textInverse,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages list
          Expanded(
            child: _isLoading
                ? Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: FanColors.primary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      final isMe = message['isMe'] as bool;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isMe)
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: FanColors.primaryDim,
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: FanColors.primary,
                                ),
                              ),
                            if (!isMe) const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.7,
                                ),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? FanColors.primary
                                      : FanColors.surface,
                                  borderRadius: FanRadius.lgAll,
                                  border: Border.all(
                                    color: isMe
                                        ? FanColors.primary
                                        : FanColors.border,
                                    width: 1,
                                  ),
                                  boxShadow: isMe ? null : FanShadows.subtle,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        message['sender'],
                                        style: FanTypography.tag.copyWith(
                                          color: FanColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (!isMe) const SizedBox(height: 4),
                                    Text(
                                      message['message'],
                                      style: FanTypography.body.copyWith(
                                        color: isMe
                                            ? FanColors.textInverse
                                            : FanColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(message['time']),
                                      style: FanTypography.tag.copyWith(
                                        color: isMe
                                            ? FanColors.textInverse.withValues(
                                                alpha: 0.8,
                                              )
                                            : FanColors.textTertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isMe) const SizedBox(width: 8),
                            if (isMe)
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: FanColors.primary,
                                child: Icon(
                                  Icons.person,
                                  size: 16,
                                  color: FanColors.textInverse,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FanColors.surface,
              border: Border(
                top: BorderSide(color: FanColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: FanColors.surfaceSunken,
                      borderRadius: FanRadius.pillAll,
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: FanTypography.body.copyWith(
                        color: FanColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: FanTypography.body.copyWith(
                          color: FanColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: FanColors.primary,
                            size: 20,
                          ),
                          onPressed: _sendMessage,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
