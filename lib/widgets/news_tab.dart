import 'package:flutter/material.dart';
import '../models/news_model.dart';
import 'news_card.dart';

class NewsTab extends StatelessWidget {
  const NewsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final newsItems = [
      NewsModel(
        title: 'Team Secures Major Victory',
        excerpt:
            'In a stunning display of skill and determination, the team clinched a 3-1 victory...',
        time: '2 hours ago',
        image: '🏆',
      ),
      NewsModel(
        title: 'New Player Signing Announced',
        excerpt:
            'The club is thrilled to announce the signing of midfielder Alex Chen from...',
        time: '5 hours ago',
        image: '⭐',
      ),
      NewsModel(
        title: 'Stadium Renovation Updates',
        excerpt:
            'Construction progresses on schedule for the new south stand expansion...',
        time: '1 day ago',
        image: '🏟️',
      ),
      NewsModel(
        title: 'Youth Academy Success',
        excerpt:
            'Three academy players have been promoted to the first team squad this season...',
        time: '2 days ago',
        image: '🎓',
      ),
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: newsItems.length,
      itemBuilder: (context, index) {
        return NewsCard(news: newsItems[index]);
      },
    );
  }
}
