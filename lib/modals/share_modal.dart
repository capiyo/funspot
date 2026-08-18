// Add this import
import 'package:flutter/material.dart';
import '../models/post_models.dart';

class ShareModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Post post;

  const ShareModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.post,
  });

  @override
  State<ShareModal> createState() => _ShareModalState();
}

class _ShareModalState extends State<ShareModal> {
  final List<Map<String, dynamic>> _shareOptions = [
    {
      'icon': Icons.copy,
      'title': 'Copy Link',
      'description': 'Copy post link to clipboard',
      'color': Colors.blue,
    },
    {
      'icon': Icons.message,
      'title': 'Direct Message',
      'description': 'Share via direct message',
      'color': Color(0xFF10B981),
    },
    {
      'icon': Icons.people,
      'title': 'Share to Story',
      'description': 'Add to your story',
      'color': Colors.purple,
    },
    {
      'icon': Icons.bookmark,
      'title': 'Save Post',
      'description': 'Save to your collection',
      'color': Colors.yellow.shade700,
    },
    {
      'icon': Icons.qr_code,
      'title': 'QR Code',
      'description': 'Generate QR code for post',
      'color': Colors.black,
    },
  ];

  final List<Map<String, dynamic>> _socialOptions = [
    {
      'icon': Icons.chat_bubble_outline,
      'title': 'Twitter',
      'color': Color(0xFF1DA1F2),
    },
    {'icon': Icons.facebook, 'title': 'Facebook', 'color': Color(0xFF1877F2)},
    {'icon': Icons.chat, 'title': 'WhatsApp', 'color': Color(0xFF25D366)},
    {'icon': Icons.telegram, 'title': 'Telegram', 'color': Color(0xFF0088CC)},
    {'icon': Icons.facebook, 'title': 'Instagram', 'color': Color(0xFFE4405F)},
    {'icon': Icons.reddit, 'title': 'Reddit', 'color': Color(0xFFFF5700)},
  ];

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return Material(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          //border: Border.all(color: const Color(0xFF10B981), width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),

            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade800, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  // Title
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Post',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Share: "${_truncateCaption(widget.post.caption ?? "")}"',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Close Button
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: widget.onClose,
                      icon: Icon(
                        Icons.close,
                        color: Colors.grey.shade400,
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),

            // Share Options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quick Actions Section
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Quick Actions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    ..._shareOptions.map(
                      (option) => _buildShareOption(
                        icon: option['icon'],
                        title: option['title'],
                        description: option['description'],
                        color: option['color'],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Social Media Section
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Social Media',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade800,
                          width: 0.5,
                        ),
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.2,
                            ),
                        itemCount: _socialOptions.length,
                        itemBuilder: (context, index) {
                          final option = _socialOptions[index];
                          return _buildSocialOption(
                            icon: option['icon'],
                            title: option['title'],
                            color: option['color'],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Additional Options
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'More Options',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade800,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildMoreOption(
                            icon: Icons.email,
                            title: 'Share via Email',
                            color: Colors.grey.shade400,
                          ),
                          const Divider(
                            color: Colors.grey,
                            height: 1,
                            thickness: 0.5,
                            indent: 12,
                            endIndent: 12,
                          ),
                          _buildMoreOption(
                            icon: Icons.sms,
                            title: 'Share via SMS',
                            color: Colors.grey.shade400,
                          ),
                          const Divider(
                            color: Colors.grey,
                            height: 1,
                            thickness: 0.5,
                            indent: 12,
                            endIndent: 12,
                          ),
                          _buildMoreOption(
                            icon: Icons.print,
                            title: 'Print Post',
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                border: Border(top: BorderSide(color: Colors.grey.shade800)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share with friends',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Spread the word about this post',
                          style: TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Share',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to truncate caption
  String _truncateCaption(String caption) {
    if (caption.length <= 30) return caption;
    return '${caption.substring(0, 30)}...';
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        // Handle share option tap
        _onShareOptionSelected(title);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialOption({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        _onSocialShareSelected(title);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade800, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreOption({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        _onMoreOptionSelected(title);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade500, size: 20),
          ],
        ),
      ),
    );
  }

  void _onShareOptionSelected(String option) {
    // Handle share option selection
    print('Selected: $option');
    // You can add actual sharing logic here
  }

  void _onSocialShareSelected(String platform) {
    // Handle social media sharing
    print('Sharing to: $platform');
  }

  void _onMoreOptionSelected(String option) {
    // Handle more options
    print('Selected option: $option');
  }
}
