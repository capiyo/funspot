import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ComradeService {
  static const String baseUrl = 'https://clash-api-m5mr.onrender.com/api';

  // Add comrade (mutual - double comrades)
  static Future<Map<String, dynamic>> addComrade({
    required String userId,
    required String comradeId,
    required String username,
    required String comradeUsername,
    required String comradeNickname,
    required String comradeClub,
    required String comradeCountry,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comrades/comrades/add'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({
          'user_id': userId,
          'comrade_id': comradeId,
          'username': username,
          'comrade_username': comradeUsername,
          'comrade_nickname': comradeNickname,
          'comrade_club': comradeClub,
          'comrade_country': comradeCountry,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Comrade added successfully: $comradeUsername');
        return jsonDecode(response.body);
      } else {
        debugPrint('❌ Failed to add comrade: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return {'success': false, 'message': 'Failed to add comrade'};
      }
    } catch (e) {
      debugPrint('❌ Error adding comrade: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get user's channel count (how many channels they are in)
  static Future<int> getUserChannelCount(
      String userId, String authToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channels/user/$userId/count'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['channel_count'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('Failed to get user channel count: $e');
      return 0;
    }
  }

  // Get channel counts for multiple users in one request
  static Future<Map<String, int>> getBatchUserChannelCounts(
    List<String> userIds,
    String authToken,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channels/users/counts'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_ids': userIds}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, int> result = {};
        for (var entry in data['counts'].entries) {
          result[entry.key] = entry.value;
        }
        return result;
      }
      return {};
    } catch (e) {
      debugPrint('Failed to get batch channel counts: $e');
      return {};
    }
  }

  // CREATE CHANNEL
  static Future<Map<String, dynamic>> createChannel({
    required String name,
    required String createdBy,
    required String createdByUsername,
    required String season,
    required List<Map<String, String>> members,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channels/'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': name,
          'created_by': createdBy,
          'created_by_username': createdByUsername,
          'season': season,
          'members': members,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Channel created successfully: $name');
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        debugPrint('❌ Failed to create channel: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
        return {
          'success': false,
          'message': 'Failed to create channel',
        };
      }
    } catch (e) {
      debugPrint('❌ Error creating channel: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // GET CHANNEL BY ID
  static Future<Map<String, dynamic>?> getChannel(
      String channelId, String authToken) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channels/$channelId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['channel'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting channel: $e');
      return null;
    }
  }

  // GET CHANNEL LEADERBOARD
  static Future<Map<String, dynamic>?> getChannelLeaderboard(
    String channelId,
    String authToken,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channels/$channelId/leaderboard'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting leaderboard: $e');
      return null;
    }
  }

  // GET CHANNEL FIXTURES
  static Future<List<dynamic>?> getChannelFixtures(
    String channelId,
    String authToken,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channels/$channelId/fixtures'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['fixtures'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting channel fixtures: $e');
      return null;
    }
  }

  // INITIALIZE FIXTURE CHAT
  static Future<Map<String, dynamic>?> initializeFixtureChat({
    required String channelId,
    required String fixtureId,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channels/fixture/chat'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channel_id': channelId,
          'fixture_id': fixtureId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return data['chat'];
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error initializing fixture chat: $e');
      return null;
    }
  }

  // SEND MESSAGE
  static Future<bool> sendMessage({
    required String channelId,
    required String? fixtureId,
    required String senderId,
    required String senderName,
    required String text,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channels/messages'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channel_id': channelId,
          'fixture_id': fixtureId,
          'sender_id': senderId,
          'sender_name': senderName,
          'text': text,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }

  // GET MESSAGES
  static Future<List<dynamic>> getMessages({
    required String channelId,
    String? fixtureId,
    int limit = 50,
    int offset = 0,
    required String authToken,
  }) async {
    try {
      final queryParams = {
        'channel_id': channelId,
        'limit': limit.toString(),
        'offset': offset.toString(),
      };
      if (fixtureId != null) {
        queryParams['fixture_id'] = fixtureId;
      }

      final uri = Uri.parse('$baseUrl/channels/messages')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['messages'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting messages: $e');
      return [];
    }
  }

  // CAST VOTE
  static Future<bool> castVote({
    required String channelId,
    required String fixtureId,
    required String userId,
    required String selection,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channels/votes'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channel_id': channelId,
          'fixture_id': fixtureId,
          'user_id': userId,
          'selection': selection,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ Error casting vote: $e');
      return false;
    }
  }

  // ADD MEMBERS TO CHANNEL
  static Future<bool> addMembersToChannel({
    required String channelId,
    required List<Map<String, String>> members,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channels/members/add'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channel_id': channelId,
          'members': members,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ Error adding members: $e');
      return false;
    }
  }

  // LEAVE CHANNEL
  static Future<bool> leaveChannel({
    required String channelId,
    required String userId,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/channels/members/leave'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'channel_id': channelId,
          'user_id': userId,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('❌ Error leaving channel: $e');
      return false;
    }
  }

  // GET USER CHANNELS (all channels a user belongs to)
  static Future<List<dynamic>> getUserChannels(
    String userId,
    String authToken,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channels/user/$userId'),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['channels'] ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting user channels: $e');
      return [];
    }
  }

  // Post a comment on a fixture
  static Future<Map<String, dynamic>> postComment({
    required String userId,
    required String username,
    required String fixtureId,
    required String comment,
    required String selection,
    String? authToken,
  }) async {
    try {
      debugPrint('📤 Posting comment for fixture: $fixtureId');
      debugPrint('📤 Comment: $comment');
      debugPrint('📤 Selection: $selection');

      final headers = {'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final commentData = {
        'voterId': userId,
        'username': username,
        'fixtureId': fixtureId,
        'comment': comment.trim(),
        'selection': selection,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse('$baseUrl/votes/comment'),
        headers: headers,
        body: jsonEncode(commentData),
      );

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Comment posted successfully');
        return {
          'success': true,
          'message': 'Comment posted successfully',
          'data': jsonDecode(response.body),
        };
      } else if (response.statusCode == 401) {
        debugPrint('❌ Authentication failed');
        return {
          'success': false,
          'message': 'Authentication failed. Please log in again.',
        };
      } else {
        debugPrint('❌ Failed to post comment: ${response.statusCode}');
        return {
          'success': false,
          'message':
              'Failed to post comment. Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      debugPrint('❌ Error posting comment: $e');
      return {'success': false, 'message': 'Network error: ${e.toString()}'};
    }
  }

  // Get user's comrades list
  static Future<List<Map<String, dynamic>>> getUserComrades({
    required String userId,
    String? authToken,
  }) async {
    try {
      final headers = <String, String>{};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/comrades/comrades/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ Loaded ${data.length} comrades for user $userId');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No comrades found for user $userId');
        return [];
      } else {
        debugPrint('⚠️ Failed to get comrades: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error getting comrades: $e');
      return [];
    }
  }

  // Get comrade stats (count, limit)
  static Future<Map<String, dynamic>> getComradeStats({
    required String userId,
    String? authToken,
  }) async {
    try {
      final headers = <String, String>{};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/comrades/comrades/$userId/stats'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Comrade stats: ${data['count']}/${data['max_comrades']}');
        return {
          'count': data['count'] ?? 0,
          'max_comrades': data['max_comrades'] ?? 50,
          'remaining': (data['max_comrades'] ?? 50) - (data['count'] ?? 0),
        };
      }
      return {'count': 0, 'max_comrades': 50, 'remaining': 50};
    } catch (e) {
      debugPrint('❌ Error getting comrade stats: $e');
      return {'count': 0, 'max_comrades': 50, 'remaining': 50};
    }
  }

  // Remove comrade (removes both directions)
  static Future<bool> removeComrade({
    required String userId,
    required String comradeId,
    required String authToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/comrades/comrades/remove'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'user_id': userId, 'comrade_id': comradeId}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Comrade removed successfully');
        return true;
      } else {
        debugPrint('❌ Failed to remove comrade: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error removing comrade: $e');
      return false;
    }
  }

  // Check if two users are comrades
  static Future<bool> areComrades({
    required String userId,
    required String otherUserId,
    String? authToken,
  }) async {
    try {
      final comrades = await getUserComrades(
        userId: userId,
        authToken: authToken,
      );
      return comrades.any((c) => c['comrade_id'] == otherUserId);
    } catch (e) {
      debugPrint('❌ Error checking comrade status: $e');
      return false;
    }
  }

  // Get comrade details by ID
  static Future<Map<String, dynamic>?> getComradeDetails({
    required String userId,
    required String comradeId,
    String? authToken,
  }) async {
    try {
      final comrades = await getUserComrades(
        userId: userId,
        authToken: authToken,
      );
      return comrades.firstWhere(
        (c) => c['comrade_id'] == comradeId,
        orElse: () => {},
      );
    } catch (e) {
      debugPrint('❌ Error getting comrade details: $e');
      return null;
    }
  }

  // Search for potential comrades by username or nickname
  static Future<List<Map<String, dynamic>>> searchPotentialComrades({
    required String query,
    required String currentUserId,
    String? authToken,
  }) async {
    try {
      final headers = <String, String>{};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(
        Uri.parse(
          '$baseUrl/comrades/search?q=${Uri.encodeComponent(query)}&exclude=$currentUserId',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ Found ${data.length} potential comrades for "$query"');
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error searching comrades: $e');
      return [];
    }
  }

  // Get comrades who voted on a specific fixture
  static Future<List<Map<String, dynamic>>> getComradesWhoVotedOnFixture({
    required String fixtureId,
    required String userId,
    String? authToken,
  }) async {
    try {
      final headers = <String, String>{};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/comrades/fixture/$fixtureId/user/$userId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint(
          '✅ Found ${data.length} comrades who voted on fixture $fixtureId',
        );
        return data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting comrades who voted: $e');
      return [];
    }
  }

  // Get comrade vote summary for a fixture
  static Future<Map<String, dynamic>> getComradeVoteSummary({
    required String fixtureId,
    required String userId,
    String? authToken,
  }) async {
    try {
      final comrades = await getComradesWhoVotedOnFixture(
        fixtureId: fixtureId,
        userId: userId,
        authToken: authToken,
      );

      final summary = {
        'total': comrades.length,
        'home_votes': 0,
        'away_votes': 0,
        'draw_votes': 0,
        'comrades': comrades,
      };

      for (var comrade in comrades) {
        final selection = comrade['selection'] ?? '';
        if (selection == 'home_team') {
          summary['home_votes'] = (summary['home_votes'] as int) + 1;
        } else if (selection == 'away_team') {
          summary['away_votes'] = (summary['away_votes'] as int) + 1;
        } else if (selection == 'draw') {
          summary['draw_votes'] = (summary['draw_votes'] as int) + 1;
        }
      }

      return summary;
    } catch (e) {
      debugPrint('❌ Error getting comrade vote summary: $e');
      return {
        'total': 0,
        'home_votes': 0,
        'away_votes': 0,
        'draw_votes': 0,
        'comrades': [],
      };
    }
  }

  // Sync comrades list with local storage
  static Future<void> syncComradesToLocal({
    required String userId,
    required String authToken,
    required Function(Set<String>) onSyncComplete,
  }) async {
    try {
      final comrades = await getUserComrades(
        userId: userId,
        authToken: authToken,
      );
      final comradeIds =
          comrades.map((c) => c['comrade_id'].toString()).toSet();
      onSyncComplete(comradeIds);
      debugPrint('✅ Synced ${comradeIds.length} comrades to local storage');
    } catch (e) {
      debugPrint('❌ Error syncing comrades to local: $e');
    }
  }
}
