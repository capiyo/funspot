// lib/services/memory_manager.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class MemoryManager {
  static final MemoryManager _instance = MemoryManager._internal();
  factory MemoryManager() => _instance;
  MemoryManager._internal();

  Timer? _cleanupTimer;
  bool _isInBackground = false;
  static const int CLEANUP_INTERVAL_SECONDS = 30;
  static const int MAX_MESSAGES_PER_FIXTURE = 50;

  void startMonitoring() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(
      Duration(seconds: CLEANUP_INTERVAL_SECONDS),
      (_) => _performBackgroundCleanup(),
    );
  }

  void onBackground() {
    _isInBackground = true;
    _aggressiveCleanup();
  }

  void onForeground() {
    _isInBackground = false;
  }

  void _performBackgroundCleanup() {
    if (_isInBackground) {
      _aggressiveCleanup();
    }
  }

  void _aggressiveCleanup() {
    // 1. Trim AppCache messages
    _trimAppCacheMessages();
    
    // 2. Clear image caches
    _clearImageCaches();
    
    // 3. Clear temporary data
    _clearTemporaryData();
    
    // 4. Force garbage collection hint
    if (kDebugMode) {
      debugPrint('🧹 Memory cleanup performed at ${DateTime.now()}');
    }
  }

  void _trimAppCacheMessages() {
    try {
      // Trim fixture messages — keep the most RECENT messages (tail of the
      // list), not the first 50. Messages are stored oldest-first, so
      // take(50) was silently discarding the newest messages every time
      // this ran in the background, which is the opposite of what you want.
      final messages = AppCache.cachedMessages;
      for (var key in messages.keys.toList()) {
        final list = messages[key];
        if (list != null && list.length > MAX_MESSAGES_PER_FIXTURE) {
          messages[key] =
              list.sublist(list.length - MAX_MESSAGES_PER_FIXTURE);
        }
      }

      // Clear channel fixture data for non-essential fixtures
      // Keep only the active channel's data
      final activeFixtureId = AppCache.getActiveFixtureId();
      if (activeFixtureId != null) {
        final keysToKeep = {activeFixtureId};
        AppCache.channelFixtures.removeWhere(
          (key, _) => !keysToKeep.contains(key)
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error trimming AppCache: $e');
    }
  }

  void _clearImageCaches() {
    try {
      // If using cached_network_image
      // CachedNetworkImage.evictAll();
      
      // Clear memory cache for images
      // PaintingBinding.instance.imageCache.clear();
    } catch (e) {
      debugPrint('⚠️ Error clearing image caches: $e');
    }
  }

  void _clearTemporaryData() {
    try {
      // Clear live events older than 5 minutes
      for (var entry in AppCache.cachedMessages.entries) {
        // Keep only essential data
      }
      
      // Clear vote counts for non-active fixtures
      final activeFixtureId = AppCache.getActiveFixtureId();
      if (activeFixtureId != null) {
        AppCache.perChannelVoteCounts.removeWhere(
          (key, _) => key != activeFixtureId
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error clearing temporary data: $e');
    }
  }

  void dispose() {
    _cleanupTimer?.cancel();
  }
}