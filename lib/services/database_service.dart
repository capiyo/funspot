// services/database_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fixture_models.dart';
import '../models/chat_history.dart';

class DatabaseService {
  static const String baseUrl = 'https://clash-api-m5mr.onrender.com/api';

  // Fetch fixtures that user participated in (voted or commented)
  static Future<List<ChatHistory>> getUserParticipatedGames(
    String userId,
  ) async {
    try {
      // Step 1: Get all fixtures
      final fixtures = await getAllFixtures();

      // Step 2: Get votes by user
      final userVotes = await getVotesByUser(userId);

      // Step 3: Get comments by user
      final userComments = await getCommentsByUser(userId);

      // Step 4: Combine unique fixture IDs from votes and comments
      final Set<String> participatedFixtureIds = {};

      // Add fixture IDs from votes
      for (var vote in userVotes) {
        if (vote['fixture_id'] != null) {
          participatedFixtureIds.add(vote['fixture_id'].toString());
        }
      }

      // Add fixture IDs from comments
      for (var comment in userComments) {
        if (comment['fixture_id'] != null) {
          participatedFixtureIds.add(comment['fixture_id'].toString());
        }
      }

      // Step 5: Filter fixtures that user participated in
      final participatedFixtures = fixtures
          .where((fixture) => participatedFixtureIds.contains(fixture.matchId))
          .toList();

      // Step 6: Convert to ChatHistory with stats
      final chatHistories = await Future.wait(
        participatedFixtures.map((fixture) async {
          // Get chat stats for this fixture
          final stats = await getChatStats(fixture.matchId);
          return ChatHistory.fromFixture(
            fixture,
            participants: stats['participants'],
            messages: stats['messages'],
            lastMessage: stats['lastMessage'],
            lastMessageTime: stats['lastMessageTime'],
          );
        }),
      );

      return chatHistories;
    } catch (e) {
      print('Error fetching participated games: $e');
      return [];
    }
  }

  // Fetch all fixtures
  static Future<List<Fixture>> getAllFixtures() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/games'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Fixture.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load fixtures: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching fixtures: $e');
      return [];
    }
  }

  // Fetch votes by user ID
  static Future<List<Map<String, dynamic>>> getVotesByUser(
    String userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/votes/votes/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print('Failed to load votes: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching votes: $e');
      return [];
    }
  }

  // Fetch comments by user ID
  static Future<List<Map<String, dynamic>>> getCommentsByUser(
    String userId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/votes/comments/user/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data);
      } else {
        print('Failed to load comments: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching comments: $e');
      return [];
    }
  }

  // Get chat statistics for a fixture
  static Future<Map<String, dynamic>> getChatStats(String fixtureId) async {
    try {
      // Get all votes for this fixture
      final votesResponse = await http.get(
        Uri.parse('$baseUrl/votes/votes/fixture/$fixtureId'),
      );

      // Get all comments for this fixture
      final commentsResponse = await http.get(
        Uri.parse('$baseUrl/votes/comments/fixture/$fixtureId'),
      );

      int participants = 0;
      int messages = 0;
      String lastMessage = '';
      DateTime? lastMessageTime;

      if (votesResponse.statusCode == 200) {
        final votesData = json.decode(votesResponse.body) as List;
        participants = votesData.length;
      }

      if (commentsResponse.statusCode == 200) {
        final commentsData = json.decode(commentsResponse.body) as List;
        messages = commentsData.length;

        // Get latest comment
        if (commentsData.isNotEmpty) {
          // Sort by date to get latest
          commentsData.sort((a, b) {
            final timeA = DateTime.tryParse(a['created_at'] ?? '');
            final timeB = DateTime.tryParse(b['created_at'] ?? '');
            if (timeA == null || timeB == null) return 0;
            return timeB.compareTo(timeA);
          });

          final latestComment = commentsData.first;
          lastMessage = latestComment['comment']?.toString() ?? '';
          lastMessageTime = DateTime.tryParse(
            latestComment['created_at'] ?? '',
          );
        }
      }

      return {
        'participants': participants,
        'messages': messages,
        'lastMessage': lastMessage,
        'lastMessageTime': lastMessageTime,
      };
    } catch (e) {
      print('Error fetching chat stats: $e');
      return {
        'participants': 0,
        'messages': 0,
        'lastMessage': '',
        'lastMessageTime': null,
      };
    }
  }
}
