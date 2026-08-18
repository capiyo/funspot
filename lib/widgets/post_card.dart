import 'package:flutter/material.dart';
import '../models/post_models.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final Function(Post) onLike;
  final Function(Post) onSave;
  final Function(Post) onComment;
  final Function(Post) onShare;
  final int index;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onSave,
    required this.onComment,
    required this.onShare,
    required this.index,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool showFullCaption = false;
  final footballImages = [
    'https://images.unsplash.com/photo-1574629810360-7efbbe195018?w=800&h=600&fit=crop',
    'https://images.unsplash.com/photo-1575361204480-aadea25e6e68?w=800&h=600&fit=crop',
    'https://images.unsplash.com/photo-1599058917212-d750089bc07e?w=800&h=600&fit=crop',
    'https://images.unsplash.com/photo-1522778119026-d647f0596c20?w=800&h=600&fit=crop',
    'https://images.unsplash.com/photo-1594744803329-e58b31de8bf5?w=800&h=600&fit=crop',
  ];

  String getInitials(String name) {
    return name
        .split(' ')
        .map((part) => part.isNotEmpty ? part[0] : '')
        .join('')
        .toUpperCase()
        .substring(0, name.length > 1 ? 2 : 1);
  }

  String getOutcomeText(String outcome) {
    switch (outcome) {
      case 'win':
        return 'Won';
      case 'loss':
        return 'Lost';
      default:
        return 'Live';
    }
  }

  Color getOutcomeColor(String outcome) {
    switch (outcome) {
      case 'win':
        return Colors.green;
      case 'loss':
        return Colors.red;
      default:
        return Colors.amber;
    }
  }

  Color getOutcomeBgColor(String outcome) {
    switch (outcome) {
      case 'win':
        return Colors.green.withValues(alpha: 0.2);
      case 'loss':
        return Colors.red.withValues(alpha: 0.2);
      default:
        return Colors.amber.withValues(alpha: 0.2);
    }
  }

  IconData getOutcomeIcon(String outcome) {
    switch (outcome) {
      case 'win':
        return Icons.emoji_events;
      case 'loss':
        return Icons.trending_down;
      default:
        return Icons.local_fire_department;
    }
  }

  String formatTimeAgo(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${date.month}/${date.day}';
  }

  String getRandomImage() {
    return footballImages[DateTime.now().millisecond % footballImages.length];
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final shouldTruncate = post.caption != null && post.caption!.length > 100;
    final displayCaption = shouldTruncate && !showFullCaption
        ? '${post.caption!.substring(0, 100)}...'
        : post.caption;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey.shade900.withValues(alpha: 0.3),
            Colors.black.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade800.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(
                    0xFF10B981,
                  ).withValues(alpha: 0.3),
                  child: Text(
                    getInitials(post.userName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.userName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  getOutcomeBgColor(
                                    post.betOutcome ?? 'pending',
                                  ),
                                  getOutcomeBgColor(
                                    post.betOutcome ?? 'pending',
                                  ).withValues(alpha: 0.5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: getOutcomeColor(
                                  post.betOutcome ?? 'pending',
                                ).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  getOutcomeIcon(post.betOutcome ?? 'pending'),
                                  size: 12,
                                  color: getOutcomeColor(
                                    post.betOutcome ?? 'pending',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  getOutcomeText(post.betOutcome ?? 'pending'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: getOutcomeColor(
                                      post.betOutcome ?? 'pending',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatTimeAgo(post.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: Icon(
                    Icons.more_vert,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bet Info
            if (post.betAmount != null && post.betAmount! > 0)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.1),
                      const Color(0xFF10B981).withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildBetInfoItem(
                      Icons.bolt,
                      'Stake',
                      'Ksh ${post.betAmount!.toStringAsFixed(0)}',
                      Colors.orange,
                    ),
                    _buildBetInfoItem(
                      Icons.trending_up,
                      'Odds',
                      post.odds ?? '1.00',
                      const Color(0xFF10B981),
                    ),
                    _buildBetInfoItem(
                      Icons.emoji_events,
                      'Win',
                      'Ksh ${(post.betAmount! * double.parse(post.odds ?? '1.00')).toStringAsFixed(0)}',
                      Colors.green,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Caption
            if (post.caption != null && post.caption!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayCaption!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      height: 1.4,
                    ),
                  ),
                  if (shouldTruncate)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          showFullCaption = !showFullCaption;
                        });
                      },
                      child: Text(
                        showFullCaption ? 'Show less' : 'Show more',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
              ),

            // Image
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade800.withValues(alpha: 0.5),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  getRandomImage(),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey.shade900,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFF10B981),
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                          size: 48,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => widget.onLike(post),
                        icon: Icon(
                          post.isLiked == true
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 20,
                          color: post.isLiked == true
                              ? Colors.red
                              : Colors.grey.shade400,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '${post.likesCount ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => widget.onComment(post),
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '${post.commentsCount ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => widget.onShare(post),
                        icon: Icon(
                          Icons.share,
                          size: 20,
                          color: Colors.grey.shade400,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Text(
                        '${post.sharesCount ?? 0}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => widget.onSave(post),
                    icon: Icon(
                      post.isSaved == true
                          ? Icons.bookmark
                          : Icons.bookmark_border,
                      size: 20,
                      color: post.isSaved == true
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade400,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // Quick Comment Input
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: const Color(
                    0xFF10B981,
                  ).withValues(alpha: 0.3),
                  child: const Text(
                    'Y',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              hintStyle: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBetInfoItem(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
