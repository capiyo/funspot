// lib/services/local_database.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fixture_models.dart';
import '../models/chat_message.dart';
import '../models/user_channel.dart';

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  factory LocalDatabase() => _instance;
  LocalDatabase._internal();

  static const String MESSAGE_BOX = 'messages';
  static const String FIXTURE_BOX = 'fixtures';
  static const String VOTE_BOX = 'votes';
  static const String CHANNEL_BOX = 'channels';
  static const String PROFILE_BOX = 'profile';

  // ==========================================================================
  // MESSAGES
  // ==========================================================================

  Future<void> saveMessages(String fixtureId, List<Map<String, dynamic>> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${MESSAGE_BOX}_$fixtureId';
      
      final limitedMessages = messages.take(50).toList();
      await prefs.setString(key, jsonEncode(limitedMessages));
      
      if (kDebugMode) {
        debugPrint('💾 Saved ${limitedMessages.length} messages for $fixtureId');
      }
    } catch (e) {
      debugPrint('⚠️ Error saving messages: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> getMessages(String fixtureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${MESSAGE_BOX}_$fixtureId';
      final data = prefs.getString(key);
      if (data != null) {
        return List<Map<String, dynamic>>.from(jsonDecode(data));
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting messages: $e');
      return null;
    }
  }

  Future<void> clearMessages(String fixtureId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${MESSAGE_BOX}_$fixtureId';
      await prefs.remove(key);
    } catch (e) {
      debugPrint('⚠️ Error clearing messages: $e');
    }
  }

  // ==========================================================================
  // FIXTURES
  // ==========================================================================

  Future<void> saveFixtures(List<Fixture> fixtures) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = fixtures.map((f) => f.toJson()).toList();
      await prefs.setString(FIXTURE_BOX, jsonEncode(jsonList));
      await prefs.setInt('${FIXTURE_BOX}_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      if (kDebugMode) {
        debugPrint('💾 Saved ${fixtures.length} fixtures');
      }
    } catch (e) {
      debugPrint('⚠️ Error saving fixtures: $e');
    }
  }

  Future<List<Fixture>?> getFixtures() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(FIXTURE_BOX);
      if (data != null) {
        final jsonList = jsonDecode(data) as List;
        return jsonList.map((f) => Fixture.fromJson(f)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting fixtures: $e');
      return null;
    }
  }

  Future<int?> getFixturesTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('${FIXTURE_BOX}_timestamp');
    } catch (e) {
      return null;
    }
  }

  // ==========================================================================
  // VOTES
  // ==========================================================================

  Future<void> saveVote(String fixtureId, String selection) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${VOTE_BOX}_$fixtureId', selection);
    } catch (e) {
      debugPrint('⚠️ Error saving vote: $e');
    }
  }

  Future<Map<String, String>> getVotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final votes = <String, String>{};
      final keys = prefs.getKeys();
      
      for (var key in keys) {
        if (key.startsWith('${VOTE_BOX}_')) {
          final fixtureId = key.substring('${VOTE_BOX}_'.length);
          final selection = prefs.getString(key);
          if (selection != null) {
            votes[fixtureId] = selection;
          }
        }
      }
      return votes;
    } catch (e) {
      debugPrint('⚠️ Error getting votes: $e');
      return {};
    }
  }

  Future<void> clearVotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('${VOTE_BOX}_')) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing votes: $e');
    }
  }

  // ==========================================================================
  // CHANNELS
  // ==========================================================================

  Future<void> saveChannels(List<UserChannel> channels) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = channels.map((c) => c.toJson()).toList();
      await prefs.setString(CHANNEL_BOX, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('⚠️ Error saving channels: $e');
    }
  }

  Future<List<UserChannel>?> getChannels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(CHANNEL_BOX);
      if (data != null) {
        final jsonList = jsonDecode(data) as List;
        return jsonList.map((c) => UserChannel.fromJson(c)).toList();
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting channels: $e');
      return null;
    }
  }

  // ==========================================================================
  // PROFILE
  // ==========================================================================

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(PROFILE_BOX, jsonEncode(profile));
    } catch (e) {
      debugPrint('⚠️ Error saving profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(PROFILE_BOX);
      if (data != null) {
        return jsonDecode(data);
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error getting profile: $e');
      return null;
    }
  }

  // ==========================================================================
  // CLEAR ALL
  // ==========================================================================

  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(MESSAGE_BOX);
      await prefs.remove(FIXTURE_BOX);
      await prefs.remove('${FIXTURE_BOX}_timestamp');
      await prefs.remove(CHANNEL_BOX);
      await prefs.remove(PROFILE_BOX);
      
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith('${VOTE_BOX}_')) {
          await prefs.remove(key);
        }
      }
      
      if (kDebugMode) {
        debugPrint('🗑️ LocalDatabase cleared');
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing database: $e');
    }
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  bool get isAvailable => true;

  Future<void> init() async {
    await SharedPreferences.getInstance();
    if (kDebugMode) {
      debugPrint('✅ LocalDatabase initialized');
    }
  }
}