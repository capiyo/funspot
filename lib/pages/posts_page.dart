import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../models/post_models.dart';
import '../modals/feed/chat_modal.dart';
import '../modals/feed/post_comments.dart';
import '../modals/FAB/archive_modal.dart';
import '../utils/add_helper.dart';
import '../services/notification_service.dart';
import 'fan_Funzy_design.dart';
import '../services/auth_service.dart';
import '../modals/login_modal.dart';
import 'package:flutter/foundation.dart';
import '../widgets/web_native_ad_card.dart';
import '../main.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

// ========== GLOBAL POSTS CACHE MANAGER ==========
class _NativeAdCard extends StatefulWidget {
  final String adUnitId;
  const _NativeAdCard({required this.adUnitId});

  @override
  State<_NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<_NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _ad = NativeAd(
      adUnitId: widget.adUnitId,
      factoryId: 'listTile', // must be registered natively on Android/iOS
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ Native ad failed: $error');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      constraints: const BoxConstraints(minHeight: 90, maxHeight: 350),
      child: AdWidget(ad: _ad!),
    );
  }
}



class GlobalPostsCacheManager {
  static final GlobalPostsCacheManager _instance =
      GlobalPostsCacheManager._internal();
  factory GlobalPostsCacheManager() => _instance;
  GlobalPostsCacheManager._internal();

  List<Post>? _cachedPosts;
  Map<int, Map<String, dynamic>>? _cachedCardStates;
  Map<String, String>? _cachedUserAvatars;
  Map<String, double>? _cachedImageAspectRatios;
  DateTime? _lastFetchTime;
  String? _lastEtag;
  int? _lastServerTimestamp;

  static const Duration _cacheDuration = Duration(days: 7);
  static const Duration _minFetchInterval = Duration(seconds: 10);

  bool get isCacheValid {
    if (_lastFetchTime == null) return false;
    return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
  }

  bool get canFetch {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _minFetchInterval;
  }

  void clearCache() {
    _cachedPosts = null;
    _cachedCardStates = null;
    _cachedUserAvatars = null;
    _cachedImageAspectRatios = null;
    _lastFetchTime = null;
    _lastEtag = null;
    _lastServerTimestamp = null;
  }

  List<Post>? get posts => _cachedPosts;
  set posts(List<Post>? value) {
    _cachedPosts = value;
    if (value != null) _lastFetchTime = DateTime.now();
  }

  Map<int, Map<String, dynamic>>? get cardStates => _cachedCardStates;
  set cardStates(Map<int, Map<String, dynamic>>? value) =>
      _cachedCardStates = value;

  Map<String, String>? get userAvatars => _cachedUserAvatars;
  set userAvatars(Map<String, String>? value) => _cachedUserAvatars = value;

  Map<String, double>? get imageAspectRatios => _cachedImageAspectRatios;
  set imageAspectRatios(Map<String, double>? value) =>
      _cachedImageAspectRatios = value;

  String? get lastEtag => _lastEtag;
  set lastEtag(String? value) => _lastEtag = value;

  int? get lastServerTimestamp => _lastServerTimestamp;
  set lastServerTimestamp(int? value) => _lastServerTimestamp = value;
}

// ==========================================================================
// VIDEO PLAYER WIDGET — Clean autoplay, no play symbol, fits width/height
// ==========================================================================
class _VideoPostWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl; // ✅ NEW
  final double maxWidth;
  final double maxHeight;
  final bool autoPlay;

  const _VideoPostWidget({
    required this.videoUrl,
    this.thumbnailUrl, // ✅ NEW
    required this.maxWidth,
    required this.maxHeight,
    this.autoPlay = true,
  });

  @override
  State<_VideoPostWidget> createState() => _VideoPostWidgetState();
}

class _VideoPostWidgetState extends State<_VideoPostWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  double? _aspectRatio;
  bool _showThumbnail = true; // ✅ NEW

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _aspectRatio = _controller.value.aspectRatio;
            _showThumbnail = false;

            if (widget.autoPlay) {
              _controller
                  .setVolume(kIsWeb ? 0.0 : 1.0); // 👈 mute for web autoplay
              _controller.play().catchError((e) {
                debugPrint('❌ Video play() rejected: $e');
              });
              _isPlaying = true;
            }
          });
        }
      }).catchError((e, stack) {
        debugPrint('❌ Video init error: $e');
        debugPrint(
            '   Stack: $stack'); // 👈 log the real error, not just swallow it
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _showThumbnail = false;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

 @override
Widget build(BuildContext context) {
  if (!_isInitialized || _aspectRatio == null) {
    // ✅ Show thumbnail while loading if available
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: widget.maxWidth,
          height: widget.maxHeight * 0.6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: widget.thumbnailUrl!,
                fit: BoxFit.cover,
                placeholder: (context, _) => Container(
                  color: FanColors.surface,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FanColors.primary,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: FanColors.surface,
                  child: Center(
                    child: Icon(
                      Icons.videocam,
                      size: 36,
                      color: FanColors.textTertiary,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.videocam, color: Colors.white, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        'Video',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Fallback loading state
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: widget.maxWidth,
        height: widget.maxHeight * 0.6,
        color: FanColors.surface,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: FanColors.primary,
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Same fix as _SmartPostImage: width always fills the available
  // space, height is capped, and overflow is cropped via BoxFit.cover
  // (through a FittedBox, since VideoPlayer has no native `fit` param)
  // instead of shrinking the whole box down to a narrower width.
  final double width = widget.maxWidth;
  double height = width / _aspectRatio!;
  if (height > widget.maxHeight) {
    height = widget.maxHeight;
  }

  return GestureDetector(
    onTap: () {
      setState(() {
        if (_controller.value.isPlaying) {
          _controller.pause();
          _isPlaying = false;
        } else {
          _controller.play();
          _isPlaying = true;
        }
      });
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller.value.size.width,
                height: _controller.value.size.height,
                child: VideoPlayer(_controller),
              ),
            ),
            if (!_controller.value.isPlaying && _isInitialized)
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Paused',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}

// ==========================================================================
// SMART IMAGE — resolves real aspect ratio, then sizes itself to fit inside
// a max box without cropping and without stretching.
// ==========================================================================
class _SmartPostImage extends StatefulWidget {
  final String imageUrl;
  final double maxWidth;
  final double maxHeight;
  final Map<String, double> ratioCache;
  final VoidCallback onRatioResolved;

  const _SmartPostImage({
    required this.imageUrl,
    required this.maxWidth,
    required this.maxHeight,
    required this.ratioCache,
    required this.onRatioResolved,
  });

  @override
  State<_SmartPostImage> createState() => _SmartPostImageState();
}

class _SmartPostImageState extends State<_SmartPostImage> {
  double? _aspectRatio;
  ImageStreamListener? _listener;
  ImageStream? _stream;

  @override
  void initState() {
    super.initState();
    final cached = widget.ratioCache[widget.imageUrl];
    if (cached != null) {
      _aspectRatio = cached;
    } else {
      _resolveAspectRatio();
    }
  }

  void _resolveAspectRatio() {
  final provider = CachedNetworkImageProvider(widget.imageUrl);
  _stream = provider.resolve(const ImageConfiguration());
  _listener = ImageStreamListener(
    (info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (h == 0) return;
      final ratio = w / h;
      widget.ratioCache[widget.imageUrl] = ratio;
      widget.onRatioResolved();
      if (mounted) setState(() => _aspectRatio = ratio);
    },
    onError: (error, stackTrace) {
      debugPrint('❌ Aspect ratio probe failed for ${widget.imageUrl}: $error');
      // Fall back to a sane default instead of spinning forever.
      // CachedNetworkImage's own errorWidget still handles a true load failure.
      widget.ratioCache[widget.imageUrl] = 1.0;
      widget.onRatioResolved();
      if (mounted) setState(() => _aspectRatio = 1.0);
    },
  );
  _stream!.addListener(_listener!);
}

  @override
  void dispose() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    super.dispose();
  }

 @override
  Widget build(BuildContext context) {
    if (_aspectRatio == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: widget.maxWidth,
          height: widget.maxHeight * 0.6,
          color: FanColors.surface,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: FanColors.primary,
              ),
            ),
          ),
        ),
      );
    }

    // ✅ Always fill the available width. Only the height is capped —
    // tall media gets center-cropped (BoxFit.cover) instead of shrinking
    // the whole box down to a narrower width.
    final double width = widget.maxWidth;
    double height = width / _aspectRatio!;
    if (height > widget.maxHeight) {
      height = widget.maxHeight;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: CachedNetworkImage(
          imageUrl: widget.imageUrl,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          placeholder: (context, _) => Container(
            color: FanColors.surface,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: FanColors.primary,
                ),
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            width: width,
            height: height,
            color: FanColors.surface,
            child: Center(
              child: Icon(
                Icons.broken_image,
                size: 20,
                color: FanColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PostsPage extends StatefulWidget {
  final String currentUserId;
  final String currentUsername;
  final String? authToken;
  final ScrollController? scrollController;
  final VoidCallback? onLogout;
  final bool isLoggedIn;

  const PostsPage({
    super.key,
    required this.currentUserId,
    required this.currentUsername,
    this.authToken,
    this.scrollController,
    this.onLogout,
    this.isLoggedIn = false,
  });

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> with WidgetsBindingObserver {
  // Auth service
  late final AuthService _authService;

  // Global cache
  final GlobalPostsCacheManager _cache = GlobalPostsCacheManager();

  // Data
  List<Post> posts = [];
  bool loading = true;
  bool refreshing = false;
  bool _isFetching = false;
  String error = '';

  // Background sync
  Timer? _backgroundSyncTimer;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  static const Duration _backgroundSyncInterval = Duration(minutes: 30);
  static const Duration _minSyncInterval = Duration(minutes: 5);
  final int _adFrequency = 3;
  static const int _maxAdSlots = 40;
  final bool _showAds = true;

  // Logout flags
  bool _isLoggingOut = false;
  bool _hasShownLogoutSnackbar = false;

  // App lifecycle
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;

  // Avatar URLs
  static const List<String> _avatarUrls = [
    'https://i.pravatar.cc/150?img=1',
    'https://i.pravatar.cc/150?img=2',
    'https://i.pravatar.cc/150?img=3',
    'https://i.pravatar.cc/150?img=4',
    'https://i.pravatar.cc/150?img=5',
    'https://i.pravatar.cc/150?img=6',
    'https://i.pravatar.cc/150?img=7',
    'https://i.pravatar.cc/150?img=8',
    'https://i.pravatar.cc/150?img=9',
    'https://i.pravatar.cc/150?img=10',
    'https://i.pravatar.cc/150?img=11',
    'https://i.pravatar.cc/150?img=12',
    'https://i.pravatar.cc/150?img=13',
    'https://i.pravatar.cc/150?img=14',
    'https://i.pravatar.cc/150?img=15',
  ];

  final Map<String, String> _userAvatarMap = {};
  final Map<String, double> _imageAspectRatios = {};

  // Cache keys
  static const String _cacheKey = 'posts_cache';
  static const String _timestampKey = 'posts_timestamp';
  static const String _etagKey = 'posts_etag';
  static const String _serverTimestampKey = 'posts_server_timestamp';
  static const String _avatarCacheKey = 'user_avatars_cache';
  static const String _aspectRatiosCacheKey = 'image_aspect_ratios_cache';
  static const String _cardStatesCacheKey = 'card_states_cache';
  static const String _lastViewedKey = 'last_viewed_posts';

  // Modal states
  bool isChatOpen = false;
  bool isCommentsOpen = false;
  bool isShareOpen = false;
  int? selectedPostIndex;

  // UI states
  final Map<int, Map<String, dynamic>> _cardStates = {};
  bool _isDisposed = false;
  final Map<String, Timer> _likeDebounceTimers = {};
  final Map<int, bool> _processingLikes = {};

  // API
  final String apiBaseUrl = 'https://clash-api-m5mr.onrender.com/api';

  // Ads
  List<bool> _feedAdsLoaded = [];
  List<bool> _feedAdsFailed = [];
  bool _isLoadingAds = false;
  bool _adsSystemReady = false;

  // Image constants
  static const double _defaultAspectRatio = 16 / 9;

  // Last viewed timestamp
  DateTime? _lastViewedTime;
  final Map<String, bool> _isNewPost = {};

  // Helper getters
  bool get _isUserLoggedIn => widget.isLoggedIn;
  String get _userId => widget.currentUserId;
  String get _username => widget.currentUsername;

  @override
  void initState() {
    super.initState();
     FanTheme.controller.addListener(_onThemeChanged);

    _authService = AuthService();
    _authService.addListener(_onAuthStateChanged);

    WidgetsBinding.instance.addObserver(this);

    _loadLastViewedTime();
    _initializePosts();
  }
  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  // ==========================================================================
  // POST SORTING HELPER - ENFORCES NEWEST FIRST
  // ==========================================================================

  List<Post> _sortPostsNewestFirst(List<Post> unsortedPosts) {
    final sorted = List<Post>.from(unsortedPosts);
    sorted.sort((a, b) {
      final aTime = a.timestamp ?? 0;
      final bTime = b.timestamp ?? 0;
      return bTime.compareTo(aTime);
    });
    return sorted;
  }

  void _debugPostOrder(List<Post> postsToCheck, {String context = ''}) {
    if (!kDebugMode) return;
    if (postsToCheck.isEmpty) return;
    debugPrint('📋 POST ORDER [$context]: ${postsToCheck.length} posts');
  }

  // ==========================================================================
  // POSTS INITIALIZATION
  // ==========================================================================

  Future<void> _initializePosts() async {
    final loadedFromCache = await _loadFromCacheAndDisplay();

    if (loadedFromCache) {
      _startBackgroundSync();
      _checkForServerUpdates();
    } else {
      await _fetchPostsFromNetwork();
      _startBackgroundSync();
    }
  }

  void _updatePosts(List<Post> newPosts) {
    final sortedPosts = _sortPostsNewestFirst(newPosts);
    _debugPostOrder(sortedPosts, context: 'After sorting');

    _safeSetState(() {
      posts = sortedPosts;
      _initializeCardStates(sortedPosts);
      loading = false;
      refreshing = false;
      error = '';
    });

    _saveToGlobalCache();
  }

  Future<bool> _loadFromCacheAndDisplay() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final cachedJson = prefs.getString(_cacheKey);
      final cachedTimestamp = prefs.getInt(_timestampKey);

      final cachedAvatarsJson = prefs.getString(_avatarCacheKey);
      if (cachedAvatarsJson != null) {
        try {
          final Map<String, dynamic> avatarsMap = jsonDecode(cachedAvatarsJson);
          _userAvatarMap.clear();
          avatarsMap.forEach((key, value) {
            _userAvatarMap[key] = value.toString();
          });
        } catch (e) {}
      }

      if (cachedJson != null && cachedTimestamp != null) {
        final List<dynamic> jsonList = jsonDecode(cachedJson);
        var cachedPosts = jsonList.map((json) => Post.fromJson(json)).toList();
        cachedPosts = _sortPostsNewestFirst(cachedPosts);

        if (cachedPosts.isNotEmpty) {
          _markNewPosts(cachedPosts);

          _safeSetState(() {
            posts = cachedPosts;
            for (int i = 0; i < posts.length; i++) {
              if (!_cardStates.containsKey(i)) {
                final isLiked =
                    _isUserLoggedIn && posts[i].isLikedBy(widget.currentUserId);
                _cardStates[i] = {
                  'isLiked': isLiked,
                  'isFollowing': false,
                  'likeCount': posts[i].likesCount ?? 0,
                  'commentCount': posts[i].commentsCount ?? 0,
                };
              }
            }
            loading = false;
            error = '';
          });

          _cache.posts = cachedPosts;
          _cache.cardStates = Map.from(_cardStates);
          _cache.userAvatars = Map.from(_userAvatarMap);
          _cache.imageAspectRatios = Map.from(_imageAspectRatios);

          debugPrint('✅ Loaded ${posts.length} posts from cache');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Cache load error: $e');
      return false;
    }
  }

  Future<void> _saveToCache(List<Post> postsList) async {
    try {
      final sortedPosts = _sortPostsNewestFirst(postsList);
      final prefs = await SharedPreferences.getInstance();
      final jsonList = sortedPosts.map((p) => p.toJson()).toList();
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await prefs.setString(_cacheKey, jsonEncode(jsonList));
      await prefs.setInt(_timestampKey, timestamp);

      if (_userAvatarMap.isNotEmpty) {
        await prefs.setString(_avatarCacheKey, jsonEncode(_userAvatarMap));
      }

      if (_cardStates.isNotEmpty) {
        final statesMap = <String, dynamic>{};
        _cardStates.forEach((key, value) {
          statesMap[key.toString()] = value;
        });
        await prefs.setString(_cardStatesCacheKey, jsonEncode(statesMap));
      }

      debugPrint('✅ Saved ${sortedPosts.length} posts to cache');
    } catch (e) {
      debugPrint('❌ Cache save error: $e');
    }
  }

    Future<void> _fetchPostsFromNetwork() async {
    if (_isFetching || _isLoggingOut) return;

    _isFetching = true;

    if (!loading) {
      _safeSetState(() => refreshing = true);
    }

    try {
      debugPrint('🌐 Fetching posts from network...');

      final headers = await _buildHeaders(forceRefresh: true);
      // ✅ FIX: cache-bust the URL. On Flutter Web, http calls go through
      // the browser's fetch()/XHR layer and are subject to normal HTTP
      // caching. Without a varying query param (and with the backend not
      // sending Cache-Control/ETag on this endpoint), the browser was free
      // to keep serving a stale response for an unbounded amount of time —
      // this is the other half of why deleted posts kept showing up.
      final response = await http
          .get(
            Uri.parse(
                '$apiBaseUrl/posts?_=${DateTime.now().millisecondsSinceEpoch}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final postsData = data['posts'] as List<dynamic>;
          var newPosts = postsData.map((p) => Post.fromJson(p)).toList();
          newPosts = _sortPostsNewestFirst(newPosts);

          _markNewPosts(newPosts);
          await _saveToCache(newPosts);

          _updatePosts(newPosts);

          _lastSyncTime = DateTime.now();
          _saveToGlobalCache();
          debugPrint('✅ Loaded ${posts.length} posts from network');
        }
      } else if (response.statusCode == 401) {
        _safeSetState(() {
          loading = false;
          refreshing = false;
          if (posts.isEmpty) error = 'Please login to view posts';
        });
      }
    } catch (e) {
      debugPrint('❌ Network fetch error: $e');
      _safeSetState(() {
        refreshing = false;
        if (posts.isEmpty) {
          loading = false;
          error = 'Failed to load posts';
        }
      });
    } finally {
      _isFetching = false;
    }
  }

    Future<void> _checkForServerUpdates() async {
    if (_isFetching || _isSyncing || _isLoggingOut) return;

    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < _minSyncInterval) {
      return;
    }

    // ✅ FIX: previously this did an HTTP HEAD and only called
    // _syncPostsInBackground() if the response ETag differed from
    // _cache.lastEtag. The backend never sends an ETag header on
    // /api/posts, so newEtag was always null, the comparison never
    // matched, and this method silently did nothing — meaning deleted
    // posts (and new posts) never got picked up outside of a manual
    // pull-to-refresh. Just run the real sync directly; it already does
    // its own _havePostsChanged() diff before touching state/cache, so
    // this isn't materially more expensive than the old HEAD request.
    await _syncPostsInBackground();
  }

   Future<void> _syncPostsInBackground() async {
    if (_isSyncing || _isFetching || _isLoggingOut) return;

    _isSyncing = true;

    try {
      final headers = await _buildHeaders(forceRefresh: true);
      // ✅ FIX: same cache-busting as _fetchPostsFromNetwork — this is the
      // path that now actually runs periodically (see _checkForServerUpdates
      // fix above), so it needs the same protection against the browser's
      // HTTP cache silently returning a stale post list.
      final response = await http
          .get(
            Uri.parse(
                '$apiBaseUrl/posts?_=${DateTime.now().millisecondsSinceEpoch}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final postsData = data['posts'] as List<dynamic>;
          var newPosts = postsData.map((p) => Post.fromJson(p)).toList();
          newPosts = _sortPostsNewestFirst(newPosts);

          if (_havePostsChanged(newPosts)) {
            _markNewPosts(newPosts);
            await _saveToCache(newPosts);
            _updatePosts(newPosts);

            _saveToGlobalCache();
          }
          _cache.lastEtag = response.headers['etag'];
          _lastSyncTime = DateTime.now();
        }
      }
    } catch (e) {
      debugPrint('❌ Background sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  void _startBackgroundSync() {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer.periodic(_backgroundSyncInterval, (_) {
      if (mounted &&
          !_isLoggingOut &&
          _appLifecycleState == AppLifecycleState.resumed) {
        _checkForServerUpdates();
      }
    });
  }

  void _onAuthStateChanged() {
    if (!mounted) return;
    if (_authService.isLoggedIn && !_isLoggingOut) {
      _refreshUserDataOnly();
    } else if (!_authService.isLoggedIn && !_isLoggingOut) {
      _forceLogout();
    }
  }

  void _forceLogout() {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    _likeDebounceTimers.forEach((_, timer) => timer.cancel());
    _likeDebounceTimers.clear();
    _isFetching = false;
    _backgroundSyncTimer?.cancel();

    _safeSetState(() {
      _cardStates.clear();
      _processingLikes.clear();
      refreshing = false;
    });

    widget.onLogout?.call();

    if (mounted && !_hasShownLogoutSnackbar) {
      _hasShownLogoutSnackbar = true;
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
          content: Text('Logged out'),
          backgroundColor: FanColors.draw,
          duration: Duration(seconds: 2),
        ),
      );
    }

    _initializeCardStates(posts);
    _isLoggingOut = false;
    _startBackgroundSync();
  }

  void _showLoginModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LoginModal(
        messengerKey: messengerKey,
        onLoginSuccess: (String userId, String username) async {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Loading your data...'),
              duration: Duration(seconds: 1),
            ),
          );
          await _refreshUserDataOnly();
          if (mounted) Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, $username!'),
              backgroundColor: FanColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  void _saveToGlobalCache() {
    _cache.posts = List.from(posts);
    _cache.cardStates = Map.from(_cardStates);
    _cache.userAvatars = Map.from(_userAvatarMap);
    _cache.imageAspectRatios = Map.from(_imageAspectRatios);
  }

  Future<void> _refreshUserDataOnly() async {
    if (_isLoggingOut) return;
    debugPrint('🔄 Refreshing user data only...');

    for (int i = 0; i < posts.length; i++) {
      final post = posts[i];
      if (post.id != null && post.id!.isNotEmpty) {
        final isLiked = _isUserLoggedIn && post.isLikedBy(widget.currentUserId);
        if (_cardStates.containsKey(i)) {
          _cardStates[i]!['isLiked'] = isLiked;
        } else {
          _cardStates[i] = {
            'isLiked': isLiked,
            'isFollowing': false,
            'likeCount': post.likesCount ?? 0,
            'commentCount': post.commentsCount ?? 0,
          };
        }
      }
    }

    _saveToGlobalCache();
    _safeSetState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _appLifecycleState = state;
    if (state == AppLifecycleState.resumed && !_isLoggingOut) {
      _checkForServerUpdates();
      _saveLastViewedTime();
      _markNewPosts(posts);
      _safeSetState(() {});
    }
  }

  @override
  void dispose() {
    _saveLastViewedTime();

  FanTheme.controller.removeListener(_onThemeChanged);

    _authService.removeListener(_onAuthStateChanged);
    WidgetsBinding.instance.removeObserver(this);
    _isDisposed = true;
    _backgroundSyncTimer?.cancel();

    _likeDebounceTimers.forEach((_, timer) => timer.cancel());
    _likeDebounceTimers.clear();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_isDisposed && mounted) setState(fn);
  }

  Future<void> _sendNotificationSafe({
    required String userId,
    required String notificationType,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      final success = await NotificationService.sendNotification(
        userId: userId,
        notificationType: notificationType,
        title: title,
        body: body,
        data: data,
      );
      if (success) {
        debugPrint('✅ Notification delivered to $userId');
      }
    } catch (e) {
      debugPrint('❌ Notification exception for $userId: $e');
    }
  }

  Future<void> _sendLikeNotification(
    String postId,
    String postOwnerId,
    String postOwnerName,
  ) async {
    if (postOwnerId == widget.currentUserId) return;

    await _sendNotificationSafe(
      userId: postOwnerId,
      notificationType: 'like',
      title: '❤️ like',
      body: '@${widget.currentUsername} liked your post',
      data: {
        'post_id': postId,
        'sender_id': widget.currentUserId,
        'sender_name': widget.currentUsername,
        'type': 'like',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  String _getAvatarForUser(String userId) {
    if (_userAvatarMap.containsKey(userId)) return _userAvatarMap[userId]!;
    final int index = userId.hashCode.abs() % _avatarUrls.length;
    final String avatarUrl = _avatarUrls[index];
    _userAvatarMap[userId] = avatarUrl;
    _saveToGlobalCache();
    return avatarUrl;
  }

  Widget _buildUserAvatar(String userId, String? userName) {
    final String avatarUrl = _getAvatarForUser(userId);
    final initials = _getInitials(userName);

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: FanColors.primary.withValues(alpha: 0.1),
        border: Border.all(color: FanColors.primary.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: ClipOval(
          child: Image.network(
            avatarUrl,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorBuilder: (context, error, _) => Text(
              initials,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: FanColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }

  Future<Map<String, String>> _buildHeaders({bool forceRefresh = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (_isUserLoggedIn &&
        _authService.authToken != null &&
        _authService.authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${_authService.authToken}';
    } else if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${widget.authToken}';
    }

    headers['Cache-Control'] = forceRefresh ? 'no-cache' : 'max-age=300';
    return headers;
  }

  bool _havePostsChanged(List<Post> newPosts) {
    if (posts.length != newPosts.length) return true;
    for (int i = 0; i < posts.length && i < 10; i++) {
      if (posts[i].id != newPosts[i].id) return true;
      if (posts[i].likesCount != newPosts[i].likesCount) return true;
      if (posts[i].commentsCount != newPosts[i].commentsCount) return true;
    }
    return false;
  }

  void _handleLike(int index) {
    if (!_isUserLoggedIn) {
      _showLoginModal();
      return;
    }

    if (_processingLikes[index] == true) return;
    if (index >= posts.length) return;

    final post = posts[index];
    if (post.id == null || post.id!.isEmpty) return;

    _processingLikes[index] = true;
    _toggleLike(index, post.id!);
  }

  void _handleShare(int index) {
    Fluttertoast.showToast(
      msg: "share coming soon",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: FanColors.primary,
      textColor: Colors.white,
      fontSize: 12,
    );
  }

  Future<void> _toggleLike(int index, String postId) async {
    if (_processingLikes[index] != true) return;

    final isCurrentlyLiked = _cardStates[index]!['isLiked'] as bool;
    final originalLikeCount = _cardStates[index]!['likeCount'] as int;
    final post = posts[index];

    _safeSetState(() {
      _cardStates[index]!['isLiked'] = !isCurrentlyLiked;
      _cardStates[index]!['likeCount'] =
          isCurrentlyLiked ? originalLikeCount - 1 : originalLikeCount + 1;
    });
    _saveToGlobalCache();

    _likeDebounceTimers[postId]?.cancel();

    final timer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final url = Uri.parse('$apiBaseUrl/posts/$postId/like');
        final headers = await _buildHeaders();
        final body = jsonEncode({
          'user_id': widget.currentUserId,
          'user_name': widget.currentUsername,
        });

        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final postData = data['post'];
            if (postData != null) {
              _safeSetState(() {
                _cardStates[index]!['likeCount'] = postData['likes_count'] ??
                    (isCurrentlyLiked
                        ? originalLikeCount - 1
                        : originalLikeCount + 1);
              });
              _saveToGlobalCache();

              if (!isCurrentlyLiked && post.userId != null) {
                _sendLikeNotification(
                  post.id!,
                  post.userId!,
                  post.userName ?? 'User',
                ).catchError((e) => debugPrint('❌ Like notification failed'));
              }
            }
          } else {
            _revertLikeState(index, isCurrentlyLiked, originalLikeCount);
          }
        } else if (response.statusCode == 401) {
          _revertLikeState(index, isCurrentlyLiked, originalLikeCount);
          _showLoginModal();
        } else {
          _revertLikeState(index, isCurrentlyLiked, originalLikeCount);
        }
      } catch (e) {
        _revertLikeState(index, isCurrentlyLiked, originalLikeCount);
      } finally {
        _likeDebounceTimers.remove(postId);
        _processingLikes[index] = false;
      }
    });

    _likeDebounceTimers[postId] = timer;
  }

  void _revertLikeState(int index, bool originalLikedState, int originalCount) {
    _safeSetState(() {
      _cardStates[index]!['isLiked'] = originalLikedState;
      _cardStates[index]!['likeCount'] = originalCount;
    });
    _saveToGlobalCache();
  }

  final customCacheManager = CacheManager(
    Config(
      'image_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );

  // ==========================================================================
  // BUILD MEDIA CONTENT - UPDATED FOR NEW POST MODEL
  // ==========================================================================

  Widget _buildMediaContent(Post post) {
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth - 20;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    debugPrint('📹 Building media for post: ${post.id}');
    debugPrint('   - hasVideo: ${post.hasVideo()}, videoUrl: ${post.videoUrl}');
    debugPrint('   - hasThumbnail: ${post.hasVideoThumbnail()}');

    // Priority: Video > Image
    if (post.hasVideo() && post.videoUrl != null && post.videoUrl!.isNotEmpty) {
      debugPrint('🎬 Displaying video: ${post.videoUrl}');
      return _VideoPostWidget(
        videoUrl: post.videoUrl!,
        thumbnailUrl: post.videoThumbnailUrl, // ✅ Pass thumbnail
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        autoPlay: true,
      );
    }

    // Check Cloudinary image first, then Firebase image
    final imageUrl = post.bestImageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      debugPrint('🖼️ Displaying image: $imageUrl');
      return _SmartPostImage(
        imageUrl: imageUrl,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        ratioCache: _imageAspectRatios,
        onRatioResolved: _saveToGlobalCache,
      );
    }

    debugPrint('⚠️ No media found for post ${post.id}');
    return const SizedBox.shrink();
  }

  void _initializeCardStates(List<Post> postsList) {
    for (var i = 0; i < postsList.length; i++) {
      final post = postsList[i];
      if (post.id == null || post.id!.isEmpty) continue;

      if (!_cardStates.containsKey(i)) {
        final isLiked = _isUserLoggedIn && post.isLikedBy(widget.currentUserId);

        _cardStates[i] = {
          'isLiked': isLiked,
          'isFollowing': false,
          'likeCount': post.likesCount ?? 0,
          'commentCount': post.commentsCount ?? 0,
        };
      }
    }
    _saveToGlobalCache();
  }

  void _openCommentsModal(int index) {
    if (!_isUserLoggedIn) {
      _showLoginModal();
      return;
    }

    final post = posts[index];

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PostComments(
        isOpen: true,
        onClose: () => Navigator.pop(context),
        post: post,
        currentUserId: _userId,
        currentUsername: _username,
        authToken: widget.authToken,
      ),
    );
  }

  void _handleFollow(int index) {
    if (!_isUserLoggedIn) {
      _showLoginModal();
      return;
    }

    _safeSetState(() => _cardStates[index]!['isFollowing'] = true);
    _saveToGlobalCache();
  }

  Future<void> _loadLastViewedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_lastViewedKey);
      if (timestamp != null) {
        _lastViewedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    } catch (e) {}
  }

  Future<void> _saveLastViewedTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastViewedKey, DateTime.now().millisecondsSinceEpoch);
      _lastViewedTime = DateTime.now();
    } catch (e) {}
  }

  void _markNewPosts(List<Post> newPosts) {
    _isNewPost.clear();
    if (_lastViewedTime == null) {
      for (var post in newPosts) {
        _isNewPost[post.id ?? ''] = false;
      }
      _saveLastViewedTime();
      return;
    }

    for (var post in newPosts) {
      final postTime = DateTime.fromMillisecondsSinceEpoch(
        (post.timestamp ?? 0) * 1000,
      );
      _isNewPost[post.id ?? ''] = postTime.isAfter(_lastViewedTime!);
    }
  }

  void _openHistoryModal(Post post) {
    if (post.userId == null || post.userId!.isEmpty) {
      Fluttertoast.showToast(
        msg: "user info not available",
        toastLength: Toast.LENGTH_SHORT,
        backgroundColor: FanColors.draw,
      );
      return;
    }

    String? authToken = widget.authToken;
    if (authToken == null && _authService.authToken != null) {
      authToken = _authService.authToken;
    }

    showArchiveModal(
      context: context,
      userId: post.userId!,
      userName: post.userName ?? 'User',
      authToken: authToken,
      displayName: post.userName,
      isCurrentUser: post.userId == widget.currentUserId,
    );
  }

  // ==========================================================================
  // BUILD POST CARD - UPDATED WITH CAPTION SUPPORT
  // ==========================================================================

  Widget _buildPostCard(Post post, int index) {
    if (post.id == null || post.id!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!_cardStates.containsKey(index)) {
      final isLiked = _isUserLoggedIn && post.isLikedBy(widget.currentUserId);
      _cardStates[index] = {
        'isLiked': isLiked,
        'isFollowing': false,
        'likeCount': post.likesCount ?? 0,
        'commentCount': post.commentsCount ?? 0,
      };
    }

    final cardState = _cardStates[index]!;
    final isLiked = cardState['isLiked'] as bool;
    final likeCount = cardState['likeCount'] as int;
    final commentCount = cardState['commentCount'] as int;
    final hasMedia = post.hasImage() || post.hasVideo();
    final hasCaption = post.hasCaption();
    final isNew = _isNewPost[post.id] ?? false;

    // Get the best caption to display
    final displayCaption = post.displayCaption;

    return GestureDetector(
      onTap: () => _openCommentsModal(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: FanColors.surfaceElevated,
          border: Border(
            bottom: BorderSide(
              color: FanColors.border.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                _buildUserAvatar(post.userId ?? '', post.userName),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        post.userName ?? 'user',
                        style: FanTypography.tag.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: FanColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        post.formattedDate,
                        style: FanTypography.tag.copyWith(
                          fontSize: 9,
                          color: FanColors.textTertiary,
                        ),
                      ),
                      if (isNew) ...[
                        const SizedBox(width: 6),
                        _statusPillSmall('NEW', FanColors.primary),
                      ],
                      // Post type badge
                      if (post.postType != null && post.postType!.isNotEmpty)
                        _statusPillSmall(
                          post.postTypeDisplay,
                          FanColors.textTertiary,
                        ),
                      if (!(cardState['isFollowing'] as bool) &&
                          post.userId != widget.currentUserId &&
                          _isUserLoggedIn) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _handleFollow(index),
                          child: Text(
                            'follow',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: FanColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // ✅ Caption - uses the best available caption
            if (hasCaption && displayCaption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(
                  displayCaption,
                  style: FanTypography.body.copyWith(
                    color: FanColors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),

            // ✅ Show image caption if different from main caption
            if (post.hasImageCaption() && post.imageCaption != displayCaption)
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(
                  '📷 ${post.imageCaption}',
                  style: FanTypography.caption.copyWith(
                    color: FanColors.textTertiary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // ✅ Show video caption if different from main caption
            if (post.hasVideoCaption() && post.videoCaption != displayCaption)
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: Text(
                  '🎬 ${post.videoCaption}',
                  style: FanTypography.caption.copyWith(
                    color: FanColors.textTertiary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Media (Image or Video)
            if (hasMedia) ...[
              const SizedBox(height: 8),
              _buildMediaContent(post),
            ],

            const SizedBox(height: 6),

            // Footer action bar
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleLike(index),
                    child: _footerPill(
                      icon: isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: '$likeCount',
                      color: isLiked
                          ? FanColors.reactionLike
                          : FanColors.textSecondary,
                      filled: isLiked,
                      fillColor: FanColors.reactionLike.withValues(alpha: 0.12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openCommentsModal(index),
                    child: _footerPill(
                      icon: Icons.chat_bubble_rounded,
                      label: '$commentCount',
                      color: FanColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openHistoryModal(post),
                    child: _footerPill(
                      icon: Icons.history_rounded,
                      label: '',
                      color: FanColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _handleShare(index),
                    child: _footerPill(
                      icon: Icons.share_outlined,
                      label: '',
                      color: FanColors.textSecondary,
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

  Widget _footerPill({
    required IconData icon,
    required String label,
    required Color color,
    bool filled = false,
    Color? fillColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? (fillColor ?? color.withValues(alpha: 0.12))
            : FanColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusPillSmall(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD METHOD
  // ==========================================================================

    @override
  Widget build(BuildContext context) {
    List<Widget> children = [];

    if (loading && posts.isEmpty) {
      children.add(_buildLoadingState());
    } else if (error.isNotEmpty && posts.isEmpty) {
      children.add(_buildErrorState());
    } else {
      int adSlotsUsed = 0;
      for (int i = 0; i < posts.length; i++) {
        children.add(_buildPostCard(posts[i], i));

        final shouldInsertAd = _showAds &&
            (i + 1) % _adFrequency == 0 &&
            adSlotsUsed < _maxAdSlots;

        if (shouldInsertAd) {
          children.add(
            kIsWeb
                ? WebNativeAdCard(slotIndex: adSlotsUsed)
                : _NativeAdCard(adUnitId: AdHelper.postsFeedNativeAdUnitId),
          );
          adSlotsUsed++;
        }
      }

      if (posts.isEmpty && !loading) {
        children.add(_buildEmptyState());
      }

      if (refreshing) {
        children.add(
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: FanColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          _lastSyncTime = null;
          await _fetchPostsFromNetwork();
        },
        color: FanColors.primary,
        backgroundColor: FanColors.surface,
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(0),
                child: Column(children: children),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: FanColors.primary, strokeWidth: 2),
            const SizedBox(height: 12),
            Text(
              'loading...',
              style: FanTypography.body.copyWith(
                color: FanColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 48, color: FanColors.primary),
          const SizedBox(height: 12),
          Text(error, style: FanTypography.body),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _fetchPostsFromNetwork(),
            style: ElevatedButton.styleFrom(
              backgroundColor: FanColors.primary,
            ),
            child: const Text('retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.feed_outlined, size: 48, color: FanColors.textSecondary),
          const SizedBox(height: 12),
          Text('no posts yet', style: FanTypography.body),
        ],
      ),
    );
  }
}
