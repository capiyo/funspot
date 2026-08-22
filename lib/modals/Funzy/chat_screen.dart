// ============================================================================
// CHAT SCREEN - PITCH LIGHT DESIGN (UPDATED WITH timeElapsed)
// ============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../../utils/io_stub.dart';

import 'package:flutter/material.dart';
import '../../utils/videos/video_thumbnail_generator.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import "../FAB/profile_modal.dart";
import 'package:intl/intl.dart';
import '../Funzy/aftermatch_modal.dart'; // ✅ NEW
import 'package:path_provider/path_provider.dart';
import '../../models/chat_message.dart';
import '../../services/bet_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/fixture_models.dart';
import '../../services/web_soecket.dart';
import '../../services/api_services.dart';
import '../../services/upload_queue.dart';
import 'match_details.dart';
import '../FAB/archive_modal.dart';
import "../../pages/fan_Funzy_design.dart";
import '../../utils/add_helper.dart';
import 'leaderboard.dart';
import '../../services/comrade_service.dart';
import '../../main.dart';
import 'swipabledialogue.dart';

// ============================================================================
// COMRADE CACHE SERVICE
// ============================================================================

class ComradeCacheService {
  static final ComradeCacheService _instance = ComradeCacheService._internal();
  factory ComradeCacheService() => _instance;
  ComradeCacheService._internal();

  static const String _cacheKey = 'chat_cached_comrades';
  static const String _timestampKey = 'chat_comrades_cache_timestamp';
  static const Duration _cacheDuration = Duration(minutes: 30);

  Future<void> cacheComrades(List<Map<String, dynamic>> comrades) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(comrades);
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setString(_timestampKey, DateTime.now().toIso8601String());
      debugPrint('✅ ChatComrades cached: ${comrades.length} users');
    } catch (e) {
      debugPrint('❌ Failed to cache comrades: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCachedComrades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(_timestampKey);
      if (timestampStr != null) {
        final cacheTime = DateTime.parse(timestampStr);
        if (DateTime.now().difference(cacheTime) > _cacheDuration) {
          debugPrint('⚠️ Comrades cache expired');
          return [];
        }
      } else {
        return [];
      }
      final jsonString = prefs.getString(_cacheKey);
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        final comrades = decoded.cast<Map<String, dynamic>>();
        debugPrint('📦 Loaded ${comrades.length} comrades from cache');
        return comrades;
      }
    } catch (e) {
      debugPrint('❌ Failed to load cached comrades: $e');
    }
    return [];
  }

  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_timestampKey);
      debugPrint('🗑️ Comrades cache cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear comrades cache: $e');
    }
  }

  Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestampStr = prefs.getString(_timestampKey);
      if (timestampStr == null) return false;
      final cacheTime = DateTime.parse(timestampStr);
      return DateTime.now().difference(cacheTime) <= _cacheDuration;
    } catch (e) {
      return false;
    }
  }
}

// ============================================================================
// SPEECH BUBBLE CLIPPER
// ============================================================================

class SpeechBubbleClipper extends CustomClipper<Path> {
  final bool isLeftAligned;
  SpeechBubbleClipper({this.isLeftAligned = true});

  @override
  Path getClip(Size size) {
    final path = Path();
    final bubbleRadius = 12.0;
    final tailSize = 10.0;

    if (isLeftAligned) {
      path.moveTo(bubbleRadius, 0);
      path.lineTo(size.width - bubbleRadius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, bubbleRadius);
      path.lineTo(size.width, size.height - bubbleRadius);
      path.quadraticBezierTo(
          size.width, size.height, size.width - bubbleRadius, size.height);
      path.lineTo(bubbleRadius + tailSize, size.height);
      path.lineTo(bubbleRadius, size.height + tailSize);
      path.lineTo(bubbleRadius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - bubbleRadius);
      path.lineTo(0, bubbleRadius);
      path.quadraticBezierTo(0, 0, bubbleRadius, 0);
    } else {
      path.moveTo(bubbleRadius, 0);
      path.lineTo(size.width - bubbleRadius, 0);
      path.quadraticBezierTo(size.width, 0, size.width, bubbleRadius);
      path.lineTo(size.width, size.height - bubbleRadius);
      path.quadraticBezierTo(
          size.width, size.height, size.width - bubbleRadius, size.height);
      path.lineTo(bubbleRadius, size.height);
      path.lineTo(size.width - bubbleRadius, size.height + tailSize);
      path.lineTo(size.width - bubbleRadius, size.height);
      path.quadraticBezierTo(0, size.height, 0, size.height - bubbleRadius);
      path.lineTo(0, bubbleRadius);
      path.quadraticBezierTo(0, 0, bubbleRadius, 0);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ============================================================================
// SPEECH BUBBLE WIDGET - PITCH LIGHT
// ============================================================================

class SpeechBubble extends StatelessWidget {
  final Widget child;
  final Color? color;
  final bool isLeftAligned;
  final EdgeInsets padding;

  
  const SpeechBubble({
    super.key,
    required this.child,
    this.color, // no default here anymore
    this.isLeftAligned = true,
    this.padding = const EdgeInsets.all(10),
  });
  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: SpeechBubbleClipper(isLeftAligned: isLeftAligned),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// ============================================================================
// CAROUSEL ITEM TYPE
// ============================================================================

enum CarouselItemType { gameInfo, voteStats, ad, comrade, matchUpdate }

class CarouselItem {
  final CarouselItemType type;
  final String? adUnitId;
  final Fixture? fixture;
  final int? homeVotes;
  final int? awayVotes;
  final int? drawVotes;
  final String? userVoteSelection;
  final Map<String, dynamic>? comradeData;
  final bool added;
  final Map<String, dynamic>? matchUpdateData;

  const CarouselItem.gameInfo({
    required this.fixture,
    this.userVoteSelection,
  })  : type = CarouselItemType.gameInfo,
        adUnitId = null,
        homeVotes = null,
        awayVotes = null,
        drawVotes = null,
        comradeData = null,
        added = false,
        matchUpdateData = null;

  const CarouselItem.voteStats({
    required this.fixture,
    required this.homeVotes,
    required this.awayVotes,
    required this.drawVotes,
    this.userVoteSelection,
  })  : type = CarouselItemType.voteStats,
        adUnitId = null,
        comradeData = null,
        added = false,
        matchUpdateData = null;

  const CarouselItem.ad({required this.adUnitId})
      : type = CarouselItemType.ad,
        fixture = null,
        homeVotes = null,
        awayVotes = null,
        drawVotes = null,
        userVoteSelection = null,
        comradeData = null,
        added = false,
        matchUpdateData = null;

  const CarouselItem.comrade({
    required this.comradeData,
    this.added = false,
  })  : type = CarouselItemType.comrade,
        fixture = null,
        adUnitId = null,
        homeVotes = null,
        awayVotes = null,
        drawVotes = null,
        userVoteSelection = null,
        matchUpdateData = null;

  const CarouselItem.matchUpdate({
    required this.matchUpdateData,
    required this.fixture,
  })  : type = CarouselItemType.matchUpdate,
        adUnitId = null,
        homeVotes = null,
        awayVotes = null,
        drawVotes = null,
        userVoteSelection = null,
        comradeData = null,
        added = false;
}

// ============================================================================
// FALLBACK AD WIDGET - PITCH LIGHT
// ============================================================================

class FallbackAdWidget extends StatelessWidget {
  final Widget? dotsWidget;
  const FallbackAdWidget({super.key, this.dotsWidget});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: FanColors.surface,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: FanColors.border.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('⚡', style: TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Funzy+',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: FanColors.textPrimary,
                  ),
                ),
                Text(
                  'Remove ads • Rewards',
                  style: TextStyle(fontSize: 7, color: FanColors.textTertiary),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: FanColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.arrow_forward_rounded,
                  size: 12, color: Colors.white),
            ),
          ),
          if (dotsWidget != null) ...[
            const SizedBox(width: 4),
            dotsWidget!,
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// LOCAL DATABASE SERVICE (Fallback only)
// ============================================================================

class ChatDatabaseService {
  static final ChatDatabaseService _instance = ChatDatabaseService._internal();
  factory ChatDatabaseService() => _instance;
  ChatDatabaseService._internal();

  static Database? _database;
  static const String _tableName = 'channel_messages';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath =
        path.join(await getDatabasesPath(), 'fanFunzy_channel_chat.db');
    return await openDatabase(dbPath,
        version: 2, onCreate: _onCreate, onUpgrade: _onUpgrade);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        channel_id TEXT NOT NULL,
        fixture_id TEXT,
        user_id TEXT NOT NULL,
        username TEXT NOT NULL,
        text TEXT NOT NULL,
        selection TEXT,
        timestamp TEXT NOT NULL,
        status INTEGER DEFAULT 1,
        is_seen INTEGER DEFAULT 0,
        reply_to_id TEXT,
        reply_to_text TEXT,
        reply_to_username TEXT,
        reply_to_selection TEXT,
        image_url TEXT,
        video_url TEXT,
        is_image INTEGER DEFAULT 0,
        is_video INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_channel_fixture ON $_tableName(channel_id, fixture_id)');
    await db.execute('CREATE INDEX idx_timestamp ON $_tableName(timestamp)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE $_tableName ADD COLUMN reply_to_selection TEXT');
    }
  }

  Future<void> insertMessage(
      ChatMessage message, String channelId, String? fixtureId) async {
    final db = await database;
    await db.insert(
        _tableName,
        {
          'id': message.id,
          'channel_id': channelId,
          'fixture_id': fixtureId,
          'user_id': message.userId,
          'username': message.username,
          'text': message.text,
          'selection': message.selection,
          'timestamp': message.timestamp.toIso8601String(),
          'status': message.status.index,
          'is_seen': message.isSeen ? 1 : 0,
          'reply_to_id': message.replyTo?.messageId,
          'reply_to_text': message.replyTo?.text,
          'reply_to_username': message.replyTo?.username,
          'reply_to_selection': message.replyTo?.selection,
          'image_url': message.imageUrl,
          'video_url': message.videoUrl,
          'is_image': message.isImage ? 1 : 0,
          'is_video': message.isVideo ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ChatMessage>> getMessages(String channelId, String? fixtureId,
      {int limit = 100}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;
    if (fixtureId == null) {
      maps = await db.query(_tableName,
          where: 'channel_id = ? AND fixture_id IS NULL',
          whereArgs: [channelId],
          orderBy: 'timestamp ASC',
          limit: limit);
    } else {
      maps = await db.query(_tableName,
          where: 'channel_id = ? AND fixture_id = ?',
          whereArgs: [channelId, fixtureId],
          orderBy: 'timestamp ASC',
          limit: limit);
    }
    return maps.map((map) => _fromMap(map)).toList();
  }

  ChatMessage _fromMap(Map<String, dynamic> map) {
    ReplyData? replyTo;
    if (map['reply_to_id'] != null) {
      replyTo = ReplyData(
        messageId: map['reply_to_id'] as String,
        text: map['reply_to_text'] as String? ?? '',
        username: map['reply_to_username'] as String? ?? '',
        selection: map['reply_to_selection'] as String?,
        isMe: false,
      );
    }
    return ChatMessage(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String,
      text: map['text'] as String,
      selection: map['selection'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: MessageStatus.values[map['status'] as int? ?? 1],
      isSeen: (map['is_seen'] as int? ?? 0) == 1,
      replyTo: replyTo,
      imageUrl: map['image_url'] as String?,
      videoUrl: map['video_url'] as String?,
      isImage: (map['is_image'] as int? ?? 0) == 1,
      isVideo: (map['is_video'] as int? ?? 0) == 1,
    );
  }

  Future<void> updateMessageStatus(
      String messageId, MessageStatus status) async {
    final db = await database;
    await db.update(_tableName, {'status': status.index},
        where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [messageId]);
  }
}

// ============================================================================
// VOTER MODEL
// ============================================================================

class Voter {
  final String userId;
  final String username;
  final String selection;
  final bool isComrade;
  final DateTime votedAt;

  Voter({
    required this.userId,
    required this.username,
    required this.selection,
    this.isComrade = false,
    required this.votedAt,
  });

  factory Voter.fromJson(Map<String, dynamic> json) {
    return Voter(
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      username: json['userName']?.toString() ??
          json['user_name']?.toString() ??
          'Anonymous',
      selection: json['selection']?.toString() ?? '',
      isComrade: json['isComrade'] ?? json['is_comrade'] ?? false,
      votedAt: json['votedAt'] != null
          ? DateTime.tryParse(json['votedAt'].toString()) ?? DateTime.now()
          : json['voted_at'] != null
              ? DateTime.tryParse(json['voted_at'].toString()) ?? DateTime.now()
              : DateTime.now(),
    );
  }
}

// ============================================================================
// KEEP ALIVE WRAPPER
// ============================================================================

class KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const KeepAliveWrapper({super.key, required this.child});

  @override
  State<KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

// ============================================================================
// VIDEO PLAYER PAGE
// ============================================================================

class VideoPlayerPage extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerPage({super.key, required this.videoUrl});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _controller.initialize().then((_) {
      setState(() => _isInitialized = true);
      _controller.play();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: _isInitialized
            ? GestureDetector(
                onTap: () => setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                }),
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_controller),
                      if (!_controller.value.isPlaying)
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow,
                              size: 48, color: Colors.white),
                        ),
                    ],
                  ),
                ),
              )
            : const Center(
                child: CircularProgressIndicator(color: Colors.white)),
      ),
    );
  }
}

// ============================================================================
// VIDEO THUMBNAIL
// ============================================================================

class _VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  const _VideoThumbnail({required this.videoUrl});

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  static final Map<String, Uint8List?> _cache = {};
  Uint8List? _thumbnail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    if (_cache.containsKey(widget.videoUrl)) {
      setState(() {
        _thumbnail = _cache[widget.videoUrl];
        _loading = false;
      });
      return;
    }
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 400,
        quality: 70,
        timeMs: 500,
      );
      _cache[widget.videoUrl] = bytes;
      if (mounted) {
        setState(() {
          _thumbnail = bytes;
          _loading = false;
        });
      }
    } catch (e) {
      _cache[widget.videoUrl] = null;
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _thumbnail == null) {
      return Container(
          color: FanColors.surfaceSunken,
          child:  Center(
              child: Icon(Icons.videocam,
                  size: 36, color: FanColors.textTertiary)));
    }
    return Image.memory(_thumbnail!,
        fit: BoxFit.cover, width: double.infinity, height: 160);
  }
}

// ============================================================================
// TYPING ANIMATION WIDGET
// ============================================================================

class TypingAnimationWidget extends StatefulWidget {
  const TypingAnimationWidget({super.key});

  @override
  State<TypingAnimationWidget> createState() => _TypingAnimationWidgetState();
}

class _TypingAnimationWidgetState extends State<TypingAnimationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _buildDot(0),
      const SizedBox(width: 3),
      _buildDot(1),
      const SizedBox(width: 3),
      _buildDot(2),
    ]);
  }

  Widget _buildDot(int index) {
    final animation = CurvedAnimation(
        parent: _controller,
        curve: Interval(index * 0.15, index * 0.15 + 0.4,
            curve: Curves.easeInOut));
    return FadeTransition(
      opacity: animation,
      child: Container(
          width: 6,
          height: 6,
          decoration:
              BoxDecoration(color: FanColors.primary, shape: BoxShape.circle)),
    );
  }
}

// ============================================================================
// MAIN CHAT SCREEN - PITCH LIGHT
// ============================================================================

class ChatScreen extends StatefulWidget {
  final String channelId;
  final String? fixtureId;
  final Fixture? fixture;
  final String userId;
  final String username;
  final String? authToken;
  final bool isLoggedIn;
  final Set<String> comradesList;
  final String? userVoteSelection;

  const ChatScreen({
    super.key,
    required this.channelId,
    this.fixtureId,
    this.fixture,
    required this.userId,
    required this.username,
    this.authToken,
    required this.isLoggedIn,
    required this.comradesList,
    this.userVoteSelection,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  // ==========================================================================
  // DATA
  // ==========================================================================
  final List<ChatMessage> _messages = [];
  final List<String> _typingUsers = [];
  final ChatDatabaseService _db = ChatDatabaseService();
  bool _messageSent = false;
  String? _latestLiveMessageId;
  Timer? _latestLiveHighlightTimer;
  String? _currentUploadId;
  // Add near your other static fields in _ChatScreenState:
static final Map<String, DateTime> _lastCommentaryFetchAt = {};
static const Duration _commentaryFetchCooldown = Duration(seconds: 20);

  // ✅ NEW: Check if game is completed for aftermatch modal
  bool get _isCompletedGame =>
      _matchStatus == 'completed' || _matchStatus == 'finished';

  // ==========================================================================
  // GAME TYPE — tracks live _matchStatus, not the frozen widget.fixture prop.
  // This flips correctly mid-session if a match finishes while you're in chat.
  // ==========================================================================
  bool get _isHistoryGame =>
      _matchStatus == 'completed' || _matchStatus == 'finished';
  late final void Function(Map<String, dynamic>) _onJoinRequestStatus;
  late final void Function(Map<String, dynamic>) _onRoomJoined;

  // Vote data
  int _homeVotes = 0;
  int _awayVotes = 0;
  int _drawVotes = 0;
  String? _userVoteSelection;
  List<Voter> _voters = [];

  // Match update data - ✅ USING timeElapsed ONLY
  int _homeScore = 0;
  int _awayScore = 0;
  double _timeElapsed = 0.0; // ✅ NEW: timeElapsed as double
  String _matchStatus = 'upcoming';
  bool _isLive = false;

  // Comrade data for carousel
  List<Map<String, dynamic>> _realComrades = [];
  bool _loadingComrades = true;
  final Set<String> _addedComradeIds = {};
  bool _isCastingVote = false;

  // ==========================================================================
  // CAROUSEL SYSTEM
  // ==========================================================================
  late PageController _carouselController;
  int _currentCarouselIndex = 0;
  bool _isCarouselRunning = false;
  Timer? _carouselTimer;
  List<CarouselItem> _carouselItems = [];
  final Set<String> _preloadedAdUnitIds = {};

  // ==========================================================================
  // UI STATE
  // ==========================================================================
  bool _loading = true;
  bool _isConnected = false;
  bool _isSendingMessage = false;
  bool _isUploadingMedia = false;
  bool _showVotesSection = false;

  // ==========================================================================
  // CONTROLLERS
  // ==========================================================================
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _chatScroll = ScrollController();
  final ScrollController _voterScroll = ScrollController();
  final FocusNode _focusNode = FocusNode();
  Timer? _typingTimer;
  Timer? _reconnectTimer;
  Timer? _scrollToBottomTimer;

  // ==========================================================================
  // REPLY STATE
  // ==========================================================================
  ReplyData? _replyingTo;

  // ==========================================================================
  // MEDIA PICKER
  // ==========================================================================
  final ImagePicker _picker = ImagePicker();

  // ==========================================================================
  // WEBSOCKET - FIXED: STORED HANDLERS FOR PROPER OFF()
  // ==========================================================================
  final WebSocketService _ws = WebSocketService();
  bool _webSocketSetupDone = false;

  // ==========================================================================
  // CALCULATIVE ORDERING — monotonic sequence + binary-search insertion.
  // Guarantees deterministic placement even when timestamps tie or are close
  // (e.g. optimistic client timestamps vs server-stamped commentary).
  // ==========================================================================
  int _seqCounter = 0;
  int _nextSeq() => _seqCounter++;

  /// Compares two messages by (timestamp, seq) — seq is the tiebreaker so
  /// equal-timestamp items keep a stable, deterministic relative order.
  int _compareMessages(ChatMessage a, ChatMessage b) {
    final cmp = a.timestamp.compareTo(b.timestamp);
    if (cmp != 0) return cmp;
    return a.seq.compareTo(b.seq);
  }

  /// Inserts [message] at its correctly calculated position via binary
  /// search, instead of appending + resorting the whole list. This is what
  /// lets a single commentary entry land exactly between message #5 and #6
  /// instead of always trailing at the bottom.
  void _insertMessageSorted(ChatMessage message) {
    int low = 0;
    int high = _messages.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_compareMessages(_messages[mid], message) <= 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    _messages.insert(low, message);
  }

  // ✅ FIX: Store handler references for proper cleanup
  late final void Function(Map<String, dynamic>) _onChatMessage;
  late final void Function(Map<String, dynamic>) _onVoteUpdate;
  late final void Function(Map<String, dynamic>) _onCommentaryNew;
  late final void Function(Map<String, dynamic>) _onCommentaryBulk;
  late final void Function(Map<String, dynamic>) _onCommentCount;
  late final void Function(Map<String, dynamic>) _onMatchStatus;
  late final void Function(Map<String, dynamic>) _onMatchGoal;
  late final void Function(Map<String, dynamic>) _onMatchEnded;
  late final void Function(Map<String, dynamic>) _onTyping;
  late final void Function(Map<String, dynamic>) _onLike;
  late final void Function(Map<String, dynamic>) _onPledge;
  late final void Function(Map<String, dynamic>) _onBet;
  late final void Function(Map<String, dynamic>) _onConnectedAck;
  late final void Function(Map<String, dynamic>) _onWsError;
  late final void Function(Map<String, dynamic>) _onSubFixtureVote;
  late final void Function(Map<String, dynamic>) _onJoinApproved;
  late final void Function(Map<String, dynamic>) _onJoinRejected;
  late final void Function(Map<String, dynamic>) _onMinuteUpdate;

  StreamSubscription<bool>? _wsConnectionSub;

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================
  static const String _api = 'https://clash-api-m5mr.onrender.com/api';

  // ==========================================================================
  // GETTERS
  // ==========================================================================
  String get _roomId => widget.fixtureId != null
      ? '${widget.channelId}_${widget.fixtureId}'
      : '${widget.channelId}_overall';

  String _adUnitIdForIndex(int index) {
    final ids = AdHelper.carouselAdUnitIds;
    if (ids.isEmpty) return '';
    return ids[index % ids.length];
  }

  int get _totalVotes => _homeVotes + _awayVotes + _drawVotes;
  bool get _hasVotes => _totalVotes > 0;

  // ==========================================================================
  // FETCH COMRADES FOR CAROUSEL - WITH APPCACHE
  // ==========================================================================
  Future<void> _fetchRealComrades({bool forceRefresh = false}) async {
    if (!forceRefresh && AppCache.comrades.isNotEmpty) {
      debugPrint(
          '⚡ INSTANT: ${AppCache.comrades.length} comrades from AppCache');
      setState(() {
        _realComrades = List<Map<String, dynamic>>.from(AppCache.comrades);
        _loadingComrades = false;
      });
      _buildCarouselItems();
      return;
    }

    if (!forceRefresh) {
      final cachedComrades = await ComradeCacheService().getCachedComrades();
      if (cachedComrades.isNotEmpty) {
        debugPrint(
            '📦 Using disk cached comrades (${cachedComrades.length} users)');
        setState(() {
          _realComrades = cachedComrades;
          _loadingComrades = false;
        });
        _buildCarouselItems();
        _fetchRealComradesFromApi(forceRefresh: true);
        return;
      }
    }

    await _fetchRealComradesFromApi(forceRefresh: forceRefresh);
  }

  Future<void> _fetchRealComradesFromApi({bool forceRefresh = false}) async {
    setState(() => _loadingComrades = true);
    try {
      final url = '$_api/profile/profiles';
      final headers = {'Content-Type': 'application/json'};
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Authorization'] = 'Bearer ${widget.authToken}';
      }

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(response.body);
        final List<Map<String, dynamic>> profiles =
            data.cast<Map<String, dynamic>>();

        List<Map<String, dynamic>> availableUsers;
        if (widget.isLoggedIn && widget.userId.isNotEmpty) {
          availableUsers = profiles.where((profile) {
            final profileUserId = profile['user_id']?.toString() ?? '';
            return profileUserId != widget.userId;
          }).toList();
        } else {
          availableUsers = List.from(profiles);
        }

        final formattedComrades = availableUsers
            .map((item) => {
                  'id': item['user_id']?.toString() ?? '',
                  'nickname': item['nickname']?.toString() ??
                      item['username']?.toString() ??
                      'Fan',
                  'club': item['club_fan']?.toString() ?? 'Football Fan',
                  'country': item['country_fan']?.toString() ?? 'World',
                  'username': item['username']?.toString() ?? 'user',
                })
            .toList();

        AppCache.comrades = formattedComrades;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_comrades', jsonEncode(formattedComrades));

        if (mounted) {
          setState(() {
            _realComrades = formattedComrades;
            _loadingComrades = false;
          });
          _buildCarouselItems();
        }
      } else {
        if (mounted) {
          setState(() => _loadingComrades = false);
          _buildCarouselItems();
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching users: $e');
      if (mounted) {
        setState(() => _loadingComrades = false);
        _buildCarouselItems();
      }
    }
  }

  // ==========================================================================
  // BUILD CAROUSEL ITEMS - WITH MATCH UPDATES
  // ==========================================================================
  void _buildCarouselItems() {
    if (!mounted) return;

    final List<CarouselItem> newItems = [];

    // Always add game info if fixture exists
    if (widget.fixture != null) {
      // ✅ Use timeElapsed to create a proper Fixture
      final updatedFixture = Fixture(
        id: widget.fixture!.id,
        matchId: widget.fixture!.matchId,
        homeTeam: widget.fixture!.homeTeam,
        awayTeam: widget.fixture!.awayTeam,
        league: widget.fixture!.league,
        homeWin: widget.fixture!.homeWin,
        awayWin: widget.fixture!.awayWin,
        draw: widget.fixture!.draw,
        date: widget.fixture!.date,
        time: widget.fixture!.time,
        homeScore: _homeScore,
        awayScore: _awayScore,
        status: _matchStatus,
        isLive: _isLive,
        availableForVoting: widget.fixture!.availableForVoting,
        source: widget.fixture!.source,
        scrapedAt: widget.fixture!.scrapedAt,
        dateIso: widget.fixture!.dateIso,
        subFixtures: widget.fixture!.subFixtures,
        timeElapsed: _timeElapsed, // ✅ NEW: use timeElapsed
      );

      newItems.add(CarouselItem.matchUpdate(
        matchUpdateData: {
          'homeScore': _homeScore,
          'awayScore': _awayScore,
          'timeElapsed': _timeElapsed, // ✅ NEW
          'status': _matchStatus,
          'isLive': _isLive,
        },
        fixture: updatedFixture,
      ));

      newItems.add(CarouselItem.gameInfo(
        fixture: updatedFixture,
        userVoteSelection: _userVoteSelection,
      ));
    }

    if (widget.fixtureId != null) {
      newItems.add(CarouselItem.voteStats(
        fixture: widget.fixture,
        homeVotes: _homeVotes,
        awayVotes: _awayVotes,
        drawVotes: _drawVotes,
        userVoteSelection: _userVoteSelection,
      ));

      if (_realComrades.isNotEmpty) {
        final comradesToShow = _realComrades.take(2).toList();
        for (var comrade in comradesToShow) {
          final isAlreadyComrade =
              widget.comradesList.contains(comrade['id']) ||
                  _addedComradeIds.contains(comrade['id']);
          newItems.add(CarouselItem.comrade(
            comradeData: {
              'id': comrade['id'] ?? '',
              'nickname': comrade['nickname'] ?? 'Fan',
              'username': comrade['username'] ?? 'user',
              'club': comrade['club'] ?? 'Football',
              'country': comrade['country'] ?? 'World',
              'votedFor': 'No vote yet',
              'fixture': widget.fixture?.homeTeam ?? 'Match',
            },
            added: isAlreadyComrade,
          ));
        }
      }
    }

    // Insert ads
    if (newItems.isNotEmpty) {
      final adIds = AdHelper.carouselAdUnitIds;
      if (adIds.isNotEmpty && adIds[0].isNotEmpty) {
        if (newItems.length >= 2 && adIds.length > 1) {
          newItems.insert(1, CarouselItem.ad(adUnitId: adIds[1]));
        }
        newItems.add(CarouselItem.ad(adUnitId: adIds[0]));
      }
    }

    // Fallback fixture
    if (newItems.isEmpty) {
      final now = DateTime.now();
      final fallbackFixture = Fixture(
        id: 'default',
        matchId: 'default_match',
        homeTeam: 'Funzy',
        awayTeam: 'Chat',
        league: 'Funzy Chat',
        homeWin: 0.0,
        awayWin: 0.0,
        draw: 0.0,
        date:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        status: 'upcoming',
        isLive: false,
        availableForVoting: true,
        source: 'fallback',
        scrapedAt: now,
        dateIso: now.toIso8601String(),
        subFixtures: [],
        timeElapsed: 0.0,
      );

      newItems.add(CarouselItem.gameInfo(
        fixture: fallbackFixture,
        userVoteSelection: null,
      ));
    }

    if (mounted) {
      setState(() => _carouselItems = newItems);
      if (_carouselItems.length > 1 && !_isCarouselRunning) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _carouselController.hasClients) {
            _startCarouselAutoScroll();
          }
        });
      }
    }
  }

  StreamSubscription? _appCacheSubscription;

  // Add this method to load vote from AppCache
  void _loadUserVoteFromAppCache() {
    if (widget.fixtureId != null) {
      final vote = AppCache.getUserVote(widget.fixtureId!);
      if (vote != null && vote != _userVoteSelection) {
        setState(() {
          _userVoteSelection = vote;
          debugPrint('🔄 ChatScreen: Loaded vote from AppCache: $vote');
        });
        _buildCarouselItems();
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _carouselController = PageController(initialPage: 0);

    // ✅ NEW: seed match status and timeElapsed from the fixture immediately
    _matchStatus = widget.fixture?.status ?? 'upcoming';
    _isLive = widget.fixture?.isLive ?? false;
    _homeScore = widget.fixture?.homeScore ?? 0;
    _awayScore = widget.fixture?.awayScore ?? 0;
    _timeElapsed = widget.fixture?.timeElapsed ?? 0.0; // ✅ NEW

    // ✅ LOAD VOTE FROM APPCACHE
    _loadUserVoteFromAppCache();

    // ✅ LISTEN TO APPCACHE VOTE CHANGES
    _appCacheSubscription = AppCache.votesStream.listen((_) {
      _loadUserVoteFromAppCache();
    });

    // ✅ CALL _loadMessages() HERE
    _loadMessages();

    // Load comrades
    _fetchRealComrades();

    // Fetch vote counts
    _fetchVoteCounts();

    // Setup WebSocket
    _setupWebSocketListeners();
    _connectWebSocket();

    // Preload ads
    _preloadInitialAds();

    // Start carousel
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_carouselItems.length > 1) {
        _startCarouselAutoScroll();
      }
    });

    // Lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _fetchMessagesFromApi() async {
    try {
      String url;
      if (widget.fixtureId != null) {
        url = '$_api/channels/${widget.channelId}/messages'
            '?fixture_id=${widget.fixtureId}'
            '&limit=100';
      } else {
        url = '$_api/channels/${widget.channelId}/messages'
            '?limit=100';
      }

      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> messagesData = data['messages'] ?? [];

        if (messagesData.isEmpty) {
          debugPrint('📭 No messages from API');
          return;
        }

        final existingIds = _messages.map((m) => m.id).toSet();
        List<ChatMessage> newMessages = [];

        for (var item in messagesData) {
          String id = item['message_id'] ?? '';
          if (id.isEmpty) {
            final idObj = item['_id'];
            if (idObj is Map && idObj['\$oid'] != null) {
              id = idObj['\$oid'];
            } else if (idObj is String) {
              id = idObj;
            }
          }

          if (id.isEmpty || existingIds.contains(id)) continue;

          ReplyData? replyTo;
          final replyToData = item['reply_to'];
          if (replyToData != null && replyToData is Map) {
            replyTo = ReplyData(
              messageId: replyToData['messageId'] ?? '',
              text: replyToData['text'] ?? '',
              username: replyToData['username'] ?? '',
              selection: replyToData['selection'],
              isMe: replyToData['isMe'] ?? false,
            );
          }

          DateTime timestamp;
          final sentAt = item['sent_at'];
          if (sentAt is Map) {
            final dateObj = sentAt['\$date'];
            if (dateObj is Map && dateObj['\$numberLong'] != null) {
              final milliseconds =
                  int.parse(dateObj['\$numberLong'].toString());
              timestamp = DateTime.fromMillisecondsSinceEpoch(milliseconds);
            } else if (dateObj is String) {
              timestamp = _parseServerTimestamp(dateObj);
            } else {
              timestamp = DateTime.now();
            }
          } else if (sentAt is String) {
            timestamp = _parseServerTimestamp(sentAt);
          } else {
            timestamp = DateTime.now();
          }

          if (id.isEmpty || existingIds.contains(id)) continue;

          final message = ChatMessage(
            id: id,
            userId: item['sender_id'] ?? '',
            username: item['sender_name'] ?? 'Anonymous',
            text: item['text'] ?? '',
            selection: item['selection'],
            timestamp: timestamp,
            status: MessageStatus.delivered,
            replyTo: replyTo,
            imageUrl: item['image_url'],
            videoUrl: item['video_url'],
            isImage: item['is_image'] ?? false,
            isVideo: item['is_video'] ?? false,
            seq: _nextSeq(),
          );

          newMessages.add(message);
        }

        if (newMessages.isNotEmpty && mounted) {
          setState(() {
            for (final m in newMessages) {
              _insertMessageSorted(m);
            }
          });

          _saveMessagesToAppCache();
          debugPrint('📥 Added ${newMessages.length} messages from API');
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('❌ API fetch error: $e');
    }
  }

  void _startCarouselAutoScroll() {
    if (_isCarouselRunning) return;
    if (_carouselItems.length <= 1) return;
    if (!_carouselController.hasClients) return;

    _isCarouselRunning = true;
    _carouselTimer?.cancel();

    bool goingForward = true;
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted || !_isCarouselRunning) {
        timer.cancel();
        _isCarouselRunning = false;
        return;
      }
      if (!_carouselController.hasClients) {
        timer.cancel();
        _isCarouselRunning = false;
        return;
      }

      final itemCount = _carouselItems.length;
      if (itemCount <= 1) {
        timer.cancel();
        _isCarouselRunning = false;
        return;
      }

      int currentPage =
          _carouselController.page?.round() ?? _currentCarouselIndex;
      int nextIndex;
      if (goingForward) {
        nextIndex = currentPage + 1;
        if (nextIndex >= itemCount) {
          goingForward = false;
          nextIndex = currentPage - 1;
        }
      } else {
        nextIndex = currentPage - 1;
        if (nextIndex < 0) {
          goingForward = true;
          nextIndex = currentPage + 1;
        }
      }
      nextIndex = nextIndex.clamp(0, itemCount - 1);
      _carouselController.animateToPage(nextIndex,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic);
    });
  }

  void _stopCarouselAutoScroll() {
    _isCarouselRunning = false;
    _carouselTimer?.cancel();
    _carouselTimer = null;
  }

  // ==========================================================================
  // CAROUSEL ITEM WIDGETS - PITCH LIGHT
  // ==========================================================================

  Widget _buildMatchUpdateCard(Fixture f, Map<String, dynamic> updateData) {
    final isLeftAligned = _currentCarouselIndex % 2 == 0;
    final homeScore = updateData['homeScore'] ?? 0;
    final awayScore = updateData['awayScore'] ?? 0;
    final timeElapsed = updateData['timeElapsed'] ?? 0.0; // ✅ NEW
    final minutes = timeElapsed.floor();
    final status = updateData['status'] ?? 'upcoming';
    final isLive = updateData['isLive'] ?? false;

    String statusText;
    Color statusColor;
    if (status == 'live' || isLive) {
      if (minutes == 45 || (timeElapsed >= 44 && timeElapsed <= 46)) {
        statusText = '⚡ HT';
        statusColor = FanColors.draw;
      } else if (minutes >= 90) {
        statusText = '🏁 FT';
        statusColor = FanColors.away;
      } else {
        statusText = '🔴 LIVE';
        statusColor = FanColors.live;
      }
    } else if (status == 'completed') {
      statusText = '✅ FT';
      statusColor = FanColors.primary;
    } else if (status == 'upcoming') {
      statusText = '⏳ UPCOMING';
      statusColor = FanColors.textTertiary;
    } else if (status == 'soon') {
      statusText = '🔜 SOON';
      statusColor = FanColors.draw;
    } else {
      statusText = status.toUpperCase();
      statusColor = FanColors.textTertiary;
    }

    // ✅ Format minute display from timeElapsed
    String minuteDisplay;
    if (timeElapsed > 0) {
      final seconds = ((timeElapsed % 1) * 60).round();
      if (seconds > 0) {
        minuteDisplay = "${minutes}'${seconds.toString().padLeft(2, '0')}";
      } else {
        minuteDisplay = "${minutes}'";
      }
    } else {
      minuteDisplay = "0'";
    }

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: SpeechBubble(
        isLeftAligned: isLeftAligned,
        color: isLive ? FanColors.live.withOpacity(0.06) : FanColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isLive
                    ? FanColors.live.withOpacity(0.08)
                    : FanColors.primaryDim,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$homeScore - $awayScore',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isLive ? FanColors.live : FanColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: FanColors.surfaceSunken,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                minuteDisplay,
                style: TextStyle(
                  fontSize: 7,
                  color: FanColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    f.homeTeam,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: FanColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'vs',
                    style: TextStyle(
                      fontSize: 7,
                      color: FanColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    f.awayTeam,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: FanColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_carouselItems.length > 1) _buildCarouselDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildGameInfoCard(Fixture f, String? userVoteSelection) {
    final isLeftAligned = _currentCarouselIndex % 2 == 0;

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: SpeechBubble(
        isLeftAligned: isLeftAligned,
        color: FanColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                f.homeTeam,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: FanColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                    color: FanColors.primaryDim,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  f.homeScore != null && f.awayScore != null
                      ? '${f.homeScore} - ${f.awayScore}'
                      : (f.league.isNotEmpty == true ? f.league : 'VS'),
                  style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      color: FanColors.primary),
                ),
              ),
            ),
            Expanded(
              child: Text(
                f.awayTeam,
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: FanColors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            if (_carouselItems.length > 1) _buildCarouselDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselDots() {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_carouselItems.length, (i) {
          final active = i == _currentCarouselIndex;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: active ? 4 : 2,
            height: active ? 4 : 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? FanColors.primary
                  : FanColors.textTertiary.withOpacity(0.3),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCarouselItemWidget(CarouselItem item, int index) {
    switch (item.type) {
      case CarouselItemType.matchUpdate:
        return _buildMatchUpdateCard(item.fixture!, item.matchUpdateData!);
      case CarouselItemType.gameInfo:
        return _buildGameInfoCard(item.fixture!, item.userVoteSelection);
      case CarouselItemType.voteStats:
        return _buildVoteStatsCard(item.fixture!, item.homeVotes!,
            item.awayVotes!, item.drawVotes!, item.userVoteSelection);
      case CarouselItemType.comrade:
        return _buildComradeCard(item.comradeData!, item.added, index);
      case CarouselItemType.ad:
        return FallbackAdWidget(
          dotsWidget: _carouselItems.length > 1 ? _buildCarouselDots() : null,
        );
    }
  }

  Widget _buildCarousel() {
    if (_carouselItems.isEmpty) {
      return const SizedBox(height: 50);
    }

    return SizedBox(
      height: 50,
      child: PageView.builder(
        controller: _carouselController,
        onPageChanged: (index) => setState(() => _currentCarouselIndex = index),
        itemCount: _carouselItems.length,
        itemBuilder: (context, index) {
          final item = _carouselItems[index];
          return KeepAliveWrapper(
            key: ValueKey('carousel_item_$index'),
            child: _buildCarouselItemWidget(item, index),
          );
        },
      ),
    );
  }

  Widget _buildVoteStatsCard(Fixture f, int homeVotes, int awayVotes,
      int drawVotes, String? userVoteSelection) {
    final total = homeVotes + awayVotes + drawVotes;
    final isLeftAligned = _currentCarouselIndex % 2 == 0;

    if (total == 0) {
      return Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: SpeechBubble(
          isLeftAligned: isLeftAligned,
          color: FanColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: _isCastingVote
                    ? const Center(
                        child: SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickVoteChip(
                              f.homeTeam, 'home_team', FanColors.primary),
                          _buildQuickVoteChip('Draw', 'draw', FanColors.draw),
                          _buildQuickVoteChip(
                              f.awayTeam, 'away_team', FanColors.away),
                        ],
                      ),
              ),
              if (_carouselItems.length > 1) _buildCarouselDots(),
            ],
          ),
        ),
      );
    }

    final homeP = ((homeVotes / total) * 100).round();
    final awayP = ((awayVotes / total) * 100).round();
    final drawP = 100 - homeP - awayP;

    return GestureDetector(
      onTap: _openVotesModal,
      child: Container(
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: SpeechBubble(
          isLeftAligned: isLeftAligned,
          color: FanColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: [
              Expanded(
                flex: homeP,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: FanColors.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(3),
                      bottomLeft: Radius.circular(3),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: drawP,
                child: Container(
                  height: 4,
                  color: FanColors.draw,
                ),
              ),
              Expanded(
                flex: awayP,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: FanColors.away,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(3),
                      bottomRight: Radius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$total',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: FanColors.textPrimary,
                ),
              ),
              if (_carouselItems.length > 1) _buildCarouselDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickVoteChip(String label, String selection, Color color) {
    return GestureDetector(
      onTap: () => _castQuickVote(selection),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2), width: 0.5),
        ),
        child: Text(
          label,
          style:
              TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildComradeCard(
      Map<String, dynamic> comrade, bool added, int index) {
    final isLeftAligned = index % 2 == 0;

    final nickname = comrade['nickname'] ?? 'Fan';
    final username = comrade['username'] ?? 'user';
    final team = comrade['votedFor'] ?? 'No vote';
    final fixtureText = comrade['fixture'] ?? 'Match';
    final isLoading = nickname == 'Loading...';
    final isPrompt = comrade['id'] == 'prompt';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: SpeechBubble(
        isLeftAligned: isLeftAligned,
        color: FanColors.surface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: isLoading || isPrompt
                  ? null
                  : () => _showComradeProfile(comrade),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isLoading || isPrompt
                      ? FanColors.textTertiary.withOpacity(0.15)
                      : FanColors.primaryDim,
                  shape: BoxShape.circle,
                ),
                child: isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.2),
                        ),
                      )
                    : Center(
                        child: Text(
                          isPrompt ? '➕' : nickname[0].toUpperCase(),
                          style: TextStyle(
                            fontSize: isPrompt ? 14 : 12,
                            fontWeight: FontWeight.w600,
                            color: isPrompt
                                ? FanColors.primary
                                : FanColors.primary,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        nickname,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              isPrompt ? FontWeight.w600 : FontWeight.w600,
                          color: isPrompt
                              ? FanColors.primary
                              : FanColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        isPrompt ? '' : '@$username',
                        style: TextStyle(
                            fontSize: 7, color: FanColors.textTertiary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: isPrompt
                          ? FanColors.primaryDim
                          : FanColors.primaryDim,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPrompt ? Icons.group_add : Icons.how_to_vote,
                          size: 8,
                          color: isPrompt
                              ? FanColors.primary
                              : FanColors.primary.withOpacity(0.7),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          isPrompt
                              ? 'Add comrades to see votes!'
                              : 'voted $team in $fixtureText',
                          style: TextStyle(
                            fontSize: 7,
                            color: isPrompt
                                ? FanColors.primary
                                : FanColors.textTertiary,
                            fontWeight:
                                isPrompt ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!isPrompt)
              GestureDetector(
                onTap: () {
                  if (added) return;
                  if (!widget.isLoggedIn) return;
                  if (isLoading) return;
                  _addComradeDirectly(comrade);
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: added
                        ? FanColors.primaryDim
                        : (isLoading
                            ? FanColors.textTertiary.withOpacity(0.2)
                            : FanColors.primary),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: added
                        ? Icon(
                            Icons.check,
                            size: 12,
                            color: FanColors.primary,
                          )
                        : Icon(
                            isLoading
                                ? Icons.access_time
                                : Icons.person_add_alt_rounded,
                            size: 12,
                            color: isLoading
                                ? FanColors.textTertiary
                                : Colors.white,
                          ),
                  ),
                ),
              ),
            if (_carouselItems.length > 1) _buildCarouselDots(),
          ],
        ),
      ),
    );
  }

  DateTime _parseServerTimestamp(String raw) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      // Handle bson::DateTime's "YYYY-MM-DD HH:mm:ss.SSS +00:00:00" format
      final fixed = raw
          .replaceFirst(' ', 'T')
          .replaceFirst(RegExp(r'\s*\+00:00:00$'), 'Z')
          .replaceFirst(RegExp(r'\s*\+(\d{2}):(\d{2}):\d{2}$'), '+\$1:\$2');
      try {
        return DateTime.parse(fixed);
      } catch (_) {
        debugPrint('⚠️ Unparseable server timestamp: $raw');
        return DateTime.now();
      }
    }
  }

  // ==========================================================================
  // VOTE METHODS
  // ==========================================================================

  void _openVotesModal() async {
  if (widget.fixture == null) return;

  final bool isCompleted =
      _matchStatus == 'completed' || _matchStatus == 'finished';

  if (isCompleted) {
    final bool showFullModal = await _checkVotesButtonVisibility(); // ← ADD THIS LINE

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeableAftermatchReviewModal(
        fixture: widget.fixture!,
        userId: widget.userId,
        username: widget.username,
        authToken: widget.authToken,
        channelId: widget.channelId,
        isLoggedIn: widget.isLoggedIn,
        showPledgesTab: showFullModal,      // ← ADD
        showBetsTab: showFullModal,         // ← ADD
        showSubFixturesTab: showFullModal,  // ← ADD
      ),
    );
    return;
  }

  // Original logic for live/upcoming games — already correct, unchanged
  final bool showFullModal = await _checkVotesButtonVisibility();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SwipeableVotePledgeModal(
      fixture: widget.fixture!,
      userId: widget.userId,
      username: widget.username,
      authToken: widget.authToken,
      isLoggedIn: widget.isLoggedIn,
      hasUserVoted: _userVoteSelection != null,
      userVoteSelection: _userVoteSelection,
      comradesList: widget.comradesList,
      showPledgesTab: showFullModal,
      showBetsTab: showFullModal,
      showSubFixturesTab: showFullModal,
      channelId: widget.channelId,
      onVote: _castQuickVote,
      onPledge: _handlePledge,
    ),
  );
}
  // ============================================================================
// MEDIA PICKER METHODS - WITH CAPTION DIALOG
// ============================================================================

  /// ✅ Show caption dialog after selecting image
 
 Future<void> _pickAndSendVideo() async {
  if (_isUploadingMedia) return;

  final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
  if (video == null) return;

  final caption = await _showCaptionDialog(
    hintText: 'Add a caption to your video...',
    isImage: false,
  );

  if (caption == null) return;

  setState(() => _isUploadingMedia = true);

  try {
    final videoBytes = await video.readAsBytes();

    Uint8List? thumbnailBytes;
    String thumbnailName =
        'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';

    if (kIsWeb) {
      // Try a real client-side frame grab first — loads the video into a
      // hidden <video> element, seeks in, and draws to a <canvas>.
      final webThumb = await generateWebVideoThumbnail(
        videoBytes,
        maxWidth: 400,
        quality: 0.75,
      );

      if (webThumb != null) {
        thumbnailBytes = webThumb;
      } else {
        // Frame grab failed (unsupported codec in this browser, etc.) —
        // fall back to a 1x1 transparent placeholder rather than blocking
        // the send. enqueueChatVideo/_runChatVideoUpload require *some*
        // thumbnail bytes for the upload payload.
        thumbnailBytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
          0x00,
          0x00,
          0x00,
          0x0D,
          0x49,
          0x48,
          0x44,
          0x52,
          0x00,
          0x00,
          0x00,
          0x01,
          0x00,
          0x00,
          0x00,
          0x01,
          0x08,
          0x06,
          0x00,
          0x00,
          0x00,
          0x1F,
          0x15,
          0xC4,
          0x89,
          0x00,
          0x00,
          0x00,
          0x0A,
          0x49,
          0x44,
          0x41,
          0x54,
          0x78,
          0x9C,
          0x63,
          0x00,
          0x01,
          0x00,
          0x00,
          0x05,
          0x00,
          0x01,
          0x0D,
          0x0A,
          0x2D,
          0xB4,
          0x00,
          0x00,
          0x00,
          0x00,
          0x49,
          0x45,
          0x4E,
          0x44,
          0xAE,
          0x42,
          0x60,
          0x82,
        ]);
      }
    } else {
      final String? thumbnailPath = await VideoThumbnail.thumbnailFile(
        video: video.path,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.JPEG,
        quality: 75,
        maxHeight: 200,
        maxWidth: 200,
      );

      if (thumbnailPath == null) {
        _flashError('Failed to generate thumbnail');
        setState(() => _isUploadingMedia = false);
        return;
      }

      thumbnailBytes = await File(thumbnailPath).readAsBytes();
      thumbnailName = thumbnailPath.split('/').last;
    }

    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${widget.userId}';

    // ✅ Show optimistic message immediately
    final optimisticMessage = ChatMessage.pending(
      tempId: tempId,
      userId: widget.userId,
      username: widget.username,
      text: caption,
      isVideo: true,
      videoUrl: 'uploading...',
      replyTo: _replyingTo,
    );

    setState(() {
      _insertMessageSorted(optimisticMessage);
    });
    _saveMessagesToAppCache();
    _cancelReply();
    _scrollToBottom();

    // ✅ Enqueue background upload
    final uploadId = UploadQueueService().enqueueChatVideo(
      userId: widget.userId,
      userName: widget.username,
      videoBytes: videoBytes,
      videoName: video.name,
      thumbnailBytes: thumbnailBytes,
      thumbnailName: thumbnailName,
      caption: caption.isNotEmpty ? caption : null,
      channelId: widget.channelId,
      fixtureId: widget.fixtureId,
      tempId: tempId,
      authToken: widget.authToken,
      onSuccess: (videoUrl, thumbnailUrl) {
        // ✅ Upload complete - send the message via WebSocket
        _sendMediaMessageWithUrl(
          videoUrl: videoUrl,
          thumbnailUrl: thumbnailUrl,
          isImage: false,
          isVideo: true,
          caption: caption,
          tempId: tempId,
        );
      },
    );

    _currentUploadId = uploadId;
    setState(() => _isUploadingMedia = false);
  } catch (e) {
    _flashError('Failed to upload video: $e');
    setState(() => _isUploadingMedia = false);
  }
}
  Future<void> _pickAndSendImage() async {
    if (_isUploadingMedia) return;

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    final caption = await _showCaptionDialog(
      hintText: 'Add a caption to your image...',
      isImage: true,
    );

    if (caption == null) return;

    setState(() => _isUploadingMedia = true);

    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${widget.userId}';

    // ✅ Show optimistic message immediately
    final optimisticMessage = ChatMessage.pending(
      tempId: tempId,
      userId: widget.userId,
      username: widget.username,
      text: caption,
      isImage: true,
      imageUrl: 'uploading...',
      replyTo: _replyingTo,
    );

    setState(() {
      _insertMessageSorted(optimisticMessage);
    });
    _saveMessagesToAppCache();
    _cancelReply();
    _scrollToBottom();

    // Read bytes from the XFile — works on both web (blob URL) and
    // mobile (real file path), unlike File(image.path) which throws
    // on web since dart:io has no filesystem there.
    final imageBytes = await image.readAsBytes();

    // ✅ Enqueue background upload - this uploads the bytes, then calls onSuccess
    final uploadId = UploadQueueService().enqueueChatImage(
      userId: widget.userId,
      userName: widget.username,
      imageBytes: imageBytes,
      imageName: image.name,
      caption: caption.isNotEmpty ? caption : null,
      channelId: widget.channelId,
      fixtureId: widget.fixtureId,
      tempId: tempId,
      authToken: widget.authToken,
      onSuccess: (imageUrl) {
        // ✅ Upload complete - send the message via WebSocket
        _sendMediaMessageWithUrl(
          imageUrl: imageUrl,
          isImage: true,
          isVideo: false,
          caption: caption,
          tempId: tempId,
        );
      },
    );

    _currentUploadId = uploadId;
    setState(() => _isUploadingMedia = false);
  }

// ============================================================================
// CAPTION DIALOG
// ============================================================================
  /// ✅ Enhanced caption dialog with emoji support
  Future<String?> _showCaptionDialog({
    required String hintText,
    required bool isImage,
  }) async {
    final TextEditingController captionController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    final Completer<String?> completer = Completer<String?>();
    bool isEmojiPickerVisible = false;

    // Pre-filled with emoji suggestions
    final List<String> emojis = [
      '😂',
      '🔥',
      '❤️',
      '👏',
      '💯',
      '🎉',
      '🤣',
      '💪',
      '👀',
      '😍'
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: FanColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: const BoxConstraints(maxWidth: 380),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isImage
                                ? FanColors.primaryDim
                                : FanColors.draw.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isImage
                                ? Icons.image_rounded
                                : Icons.videocam_rounded,
                            color: isImage ? FanColors.primary : FanColors.draw,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isImage ? 'Add Image Caption' : 'Add Video Caption',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: FanColors.textPrimary,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            completer.complete(null);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: FanColors.surfaceSunken,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: FanColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Emoji quick picker
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: emojis.map((emoji) {
                        return GestureDetector(
                          onTap: () {
                            captionController.text += emoji;
                            setState(() {});
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: FanColors.surfaceSunken,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // Caption Input
                    TextField(
                      controller: captionController,
                      focusNode: focusNode,
                      maxLines: 3,
                      maxLength: 500,
                      autofocus: true,
                      style: TextStyle(
                        fontSize: 14,
                        color: FanColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: FanColors.textTertiary.withOpacity(0.6),
                        ),
                        filled: true,
                        fillColor: FanColors.surfaceSunken,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: FanColors.primary,
                            width: 1.5,
                          ),
                        ),
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) {
                        final text = captionController.text.trim();
                        Navigator.pop(context);
                        completer.complete(text);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            completer.complete(null);
                          },
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 13,
                              color: FanColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final text = captionController.text.trim();
                            Navigator.pop(context);
                            completer.complete(text);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: FanColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Send',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.send_rounded, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Focus the text field after dialog is shown
    Future.delayed(const Duration(milliseconds: 300), () {
      focusNode.requestFocus();
    });

    return completer.future;
  }

  Future<bool> _handlePledge(String selection, double amount) async {
    if (!widget.isLoggedIn) {
      Fluttertoast.showToast(msg: '🔒 Log in to pledge');
      return false;
    }

    if (widget.fixtureId == null) {
      Fluttertoast.showToast(msg: '❌ No fixture selected');
      return false;
    }

    try {
      final result = await BetService.createBet(
        fixtureId: widget.fixtureId!,
        starterId: widget.userId,
        starterName: widget.username,
        starterSelection: selection,
        amount: amount,
        channelId: widget.channelId,
        authToken: widget.authToken,
      );

      if (result['success'] == true) {
        Fluttertoast.showToast(
          msg: '✅ Bet of KES ${amount.toStringAsFixed(2)} placed!',
          backgroundColor: FanColors.primary,
        );
        return true;
      } else {
        Fluttertoast.showToast(
          msg: result['message'] ?? '❌ Bet failed',
          backgroundColor: FanColors.away,
        );
        return false;
      }
    } catch (e) {
      debugPrint('❌ Bet error: $e');
      Fluttertoast.showToast(
        msg: '❌ Network error creating bet',
        backgroundColor: FanColors.away,
      );
      return false;
    }
  }

  // ============================================================================
  // CAST QUICK VOTE - UPDATED WITH APPCACHE
  // ============================================================================
  Future<bool> _castQuickVote(String localSelection) async {
    if (widget.fixtureId == null) return false;
    if (!widget.isLoggedIn) {
      Fluttertoast.showToast(msg: '🔒 Log in to vote');
      return false;
    }
    if (_userVoteSelection != null || _isCastingVote) return false;

    final backendSelection = localSelection == 'home_team'
        ? 'home'
        : localSelection == 'away_team'
            ? 'away'
            : 'draw';

    setState(() => _isCastingVote = true);

    try {
      final response = await http
          .post(
            Uri.parse('$_api/actions/vote/cast'),
            headers: _headers(),
            body: json.encode({
              'fixture_id': widget.fixtureId,
              'user_id': widget.userId,
              'username': widget.username,
              'selection': backendSelection,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // ✅ UPDATE LOCAL STATE
          setState(() {
            _userVoteSelection = localSelection;
            if (localSelection == 'home_team') _homeVotes++;
            if (localSelection == 'away_team') _awayVotes++;
            if (localSelection == 'draw') _drawVotes++;
          });

          final fixtureId = widget.fixtureId!;

          // ✅ UPDATE APPCACHE
          AppCache.setUserVote(fixtureId, localSelection);
          AppCache.applyUpdate(
            fixtureId: fixtureId,
            updateType: 'vote',
            value: _homeVotes + _awayVotes + _drawVotes,
            extraData: {
              'channelId': widget.channelId,
              'homeVotes': _homeVotes,
              'awayVotes': _awayVotes,
              'drawVotes': _drawVotes,
            },
          );
          await AppCache.saveVoteCount(
              fixtureId, _homeVotes + _awayVotes + _drawVotes);
          await AppCache.saveUserVotes();

          // ✅ SEND VIA WEBSOCKET
          final ws = WebSocketService();
          if (ws.isConnected) {
            ws.send('vote.update', {
              'fixture_id': fixtureId,
              'user_id': widget.userId,
              'user_vote': backendSelection,
              'home_votes': _homeVotes,
              'away_votes': _awayVotes,
              'draw_votes': _drawVotes,
              'channel_id': widget.channelId,
            });
          }

          _buildCarouselItems();
          _fetchVoteCounts();
          Fluttertoast.showToast(msg: '✅ Vote submitted!');
          return true;
        } else {
          Fluttertoast.showToast(msg: data['message'] ?? 'Vote failed');
          return false;
        }
      } else if (response.statusCode == 409) {
        Fluttertoast.showToast(msg: 'You already voted for this fixture');
        _fetchVoteCounts();
        return false;
      } else {
        Fluttertoast.showToast(msg: 'Failed to submit vote');
        return false;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: 'Network error casting vote');
      return false;
    } finally {
      if (mounted) setState(() => _isCastingVote = false);
    }
  }

  // ==========================================================================
  // MATCH UPDATE HANDLERS - UPDATED WITH timeElapsed
  // ==========================================================================

  void _handleMatchStatusUpdate(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    if (fixtureId != widget.fixtureId) return;

    final status = payload['status']?.toString() ?? 'live';
    final homeScore = payload['home_score'] as int? ?? _homeScore;
    final awayScore = payload['away_score'] as int? ?? _awayScore;

    // ✅ USE timeElapsed
    final timeElapsed =
        (payload['timeElapsed'] as num?)?.toDouble() ?? _timeElapsed;
    final isLive = status == 'live' || status == 'half_time';

    setState(() {
      _matchStatus = status;
      _homeScore = homeScore;
      _awayScore = awayScore;
      _timeElapsed = timeElapsed;
      _isLive = isLive;
    });

    // Update AppCache fixtures
    final updatedFixtures = AppCache.fixtures.map((f) {
      if (f.matchId == fixtureId) {
        return Fixture(
          id: f.id,
          matchId: f.matchId,
          homeTeam: f.homeTeam,
          awayTeam: f.awayTeam,
          league: f.league,
          homeWin: f.homeWin,
          awayWin: f.awayWin,
          draw: f.draw,
          date: f.date,
          time: f.time,
          homeScore: homeScore,
          awayScore: awayScore,
          status: status,
          isLive: isLive,
          availableForVoting: f.availableForVoting,
          source: f.source,
          scrapedAt: f.scrapedAt,
          dateIso: f.dateIso,
          subFixtures: f.subFixtures,
          timeElapsed: timeElapsed,
        );
      }
      return f;
    }).toList();

    AppCache.fixtures = updatedFixtures;
    AppCache.notifyFixturesChanged();
    AppCache.saveFixtures(updatedFixtures);

    _buildCarouselItems();
  }

  void _handleGoalEvent(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id']?.toString();
    if (fixtureId != widget.fixtureId) return;

    final homeScore = payload['home_score'] as int? ?? _homeScore;
    final awayScore = payload['away_score'] as int? ?? _awayScore;

    // ✅ USE timeElapsed
    final timeElapsed =
        (payload['timeElapsed'] as num?)?.toDouble() ?? _timeElapsed;
    final scorer = payload['scorer']?.toString() ?? 'Unknown';

    setState(() {
      _homeScore = homeScore;
      _awayScore = awayScore;
      _timeElapsed = timeElapsed;
    });

    // Update AppCache fixtures
    final updatedFixtures = AppCache.fixtures.map((f) {
      if (f.matchId == fixtureId) {
        return Fixture(
          id: f.id,
          matchId: f.matchId,
          homeTeam: f.homeTeam,
          awayTeam: f.awayTeam,
          league: f.league,
          homeWin: f.homeWin,
          awayWin: f.awayWin,
          draw: f.draw,
          date: f.date,
          time: f.time,
          homeScore: homeScore,
          awayScore: awayScore,
          status: f.status,
          isLive: f.isLive,
          availableForVoting: f.availableForVoting,
          source: f.source,
          scrapedAt: f.scrapedAt,
          dateIso: f.dateIso,
          subFixtures: f.subFixtures,
          timeElapsed: timeElapsed,
        );
      }
      return f;
    }).toList();

    AppCache.fixtures = updatedFixtures;
    AppCache.notifyFixturesChanged();
    AppCache.saveFixtures(updatedFixtures);

    _buildCarouselItems();

    // Format minute display for toast
    final minutes = timeElapsed.floor();
    final seconds = ((timeElapsed % 1) * 60).round();
    final minuteDisplay = seconds > 0
        ? "${minutes}'${seconds.toString().padLeft(2, '0')}"
        : "${minutes}'";

    Fluttertoast.showToast(
      msg: "⚽ GOAL! $scorer scores at $minuteDisplay",
      backgroundColor: FanColors.primary,
    );
  }

  Future<void> _fetchVoteCounts() async {
    if (widget.fixtureId == null) return;
    try {
      final response = await http.get(
          Uri.parse(
              '$_api/channels/channel/${widget.channelId}/fixtures/${widget.fixtureId}/votes'),
          headers: _headers());
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _homeVotes = data['home_votes'] ?? 0;
          _awayVotes = data['away_votes'] ?? 0;
          _drawVotes = data['draw_votes'] ?? 0;

          final userVote = data['user_vote']?.toString();
          if (userVote != null && userVote.isNotEmpty) {
            String frontendSelection;
            if (userVote == 'home') {
              frontendSelection = 'home_team';
            } else if (userVote == 'away') {
              frontendSelection = 'away_team';
            } else if (userVote == 'draw') {
              frontendSelection = 'draw';
            } else {
              frontendSelection = userVote;
            }

            if (frontendSelection != _userVoteSelection) {
              _userVoteSelection = frontendSelection;
              AppCache.setUserVote(widget.fixtureId!, frontendSelection);
            }
          }
        });
        _buildCarouselItems();
      }
    } catch (e) {
      debugPrint('Error fetching vote counts: $e');
    }
  }

  void _handleVoteUpdate(Map<String, dynamic> payload) {
    final fixtureId = payload['fixture_id'] as String?;
    if (fixtureId != widget.fixtureId) return;
    setState(() {
      _homeVotes = payload['home_votes'] ?? _homeVotes;
      _awayVotes = payload['away_votes'] ?? _awayVotes;
      _drawVotes = payload['draw_votes'] ?? _drawVotes;
    });
    _buildCarouselItems();
    _fetchVoters();
  }

  // ==========================================================================
  // VOTERS
  // ==========================================================================

  Future<void> _fetchVoters() async {
    if (widget.fixtureId == null) return;
    try {
      final response = await http
          .get(
            Uri.parse('$_api/actions/vote/fixture/${widget.fixtureId}/voters'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['voters'] is List) {
          final votersList = data['voters'] as List;
          final List<Voter> voters = [];
          for (var voter in votersList) {
            final uid = voter['userId']?.toString() ?? '';
            final uname = voter['userName']?.toString() ?? 'Anonymous';
            final sel = voter['selection']?.toString() ?? '';
            if (uid.isNotEmpty && sel.isNotEmpty) {
              if (widget.comradesList.contains(uid) || uid == widget.userId) {
                voters.add(Voter(
                    userId: uid,
                    username: uname,
                    selection: sel,
                    isComrade: widget.comradesList.contains(uid),
                    votedAt: DateTime.now()));
              }
            }
          }
          voters.sort((a, b) {
            if (a.userId == widget.userId) return -1;
            if (b.userId == widget.userId) return 1;
            return a.username.compareTo(b.username);
          });
          setState(() => _voters = voters);
        }
      }
    } catch (e) {
      debugPrint('Error fetching voters: $e');
    }
  }

  // ==========================================================================
  // MESSAGES - WITH APPCACHE
  // ==========================================================================

 Future<void> _loadMessages() async {
    final cachedMessages =
        await AppCache.getCachedMessagesAsync(widget.channelId, widget.fixtureId);

    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      final messages = cachedMessages.map((msgMap) {
        ReplyData? replyTo;
        final replyData = msgMap['replyTo'];
        if (replyData != null && replyData is Map<String, dynamic>) {
          replyTo = ReplyData(
            messageId: replyData['messageId'] ?? '',
            text: replyData['text'] ?? '',
            username: replyData['username'] ?? '',
            selection: replyData['selection'],
            isMe: replyData['isMe'] ?? false,
          );
        }

        return ChatMessage(
          id: msgMap['id'] ?? '',
          userId: msgMap['userId'] ?? '',
          username: msgMap['username'] ?? '',
          text: msgMap['text'] ?? '',
          selection: msgMap['selection'],
          timestamp: DateTime.parse(
              msgMap['timestamp'] ?? DateTime.now().toIso8601String()),
          status: MessageStatus.values[msgMap['status'] ?? 1],
          isSeen: msgMap['isSeen'] ?? false,
          isCommentary: msgMap['isCommentary'] ?? false,
          commentaryType: msgMap['commentaryType'],
          replyTo: replyTo,
          imageUrl: msgMap['imageUrl'],
          videoUrl: msgMap['videoUrl'],
          isImage: msgMap['isImage'] ?? false,
          isVideo: msgMap['isVideo'] ?? false,
          seq: _nextSeq(),
        );
      }).toList();

      setState(() {
        _messages.clear();
        _messages.addAll(messages);
        _sortMessages();
      });
      _scrollToBottom();
      debugPrint('📦 Loaded ${_messages.length} messages from AppCache');
    }

    // ✅ Only ever hit the network once per fixture per app run. Re-entering
    // this screen later in the same session (from FixturesPage or History)
    // is pure AppCache + whatever WebSocket already delivered — no refetch.
    if (!AppCache.isMessagesHydrated(widget.channelId, widget.fixtureId)) {
      AppCache.markMessagesHydrated(widget.channelId, widget.fixtureId);
      await _fetchMessagesFromApi();
    } else {
      debugPrint('⚡ Messages already hydrated this session — skipping refetch');
    }

    await _loadCommentary();
  }

  // ==========================================================================
  // COMMENTARY LOADING
  // ==========================================================================
 Future<void> _loadCommentary() async {
  if (widget.fixtureId == null) return;
  final fixtureId = widget.fixtureId!;

  final cached = AppCache.getCachedMessages(widget.channelId, widget.fixtureId);
  final cachedCommentary =
      cached?.where((m) => m['isCommentary'] == true).toList() ?? [];

  if (cachedCommentary.isNotEmpty) {
    _hydrateCommentaryFromCache(cachedCommentary);
  }

  if (_isHistoryGame) {
    if (cachedCommentary.isNotEmpty || AppCache.isCommentaryHydrated(fixtureId)) {
      debugPrint('📜 History game — cache is authoritative, no refetch');
      return;
    }
    AppCache.markCommentaryHydrated(fixtureId);
    await _fetchHistoryCommentaryFromApi();
    return;
  }

  // ✅ Live/upcoming: refetch if we haven't fetched recently, not just
  // "haven't fetched this session ever". A stale permanent flag was the
  // bug — it blocked refetches for the rest of the app's lifetime.
  final lastFetch = _lastCommentaryFetchAt[fixtureId];
  final isStale = lastFetch == null ||
      DateTime.now().difference(lastFetch) > _commentaryFetchCooldown;

  if (!isStale) {
    debugPrint('⚡ Commentary fetched recently — skipping refetch');
    return;
  }
  await _fetchCommentaryFromApi();
}
  // ==========================================================================
  // Hydrate _messages with cached commentary entries (dedup by id).
  // ==========================================================================
  void _hydrateCommentaryFromCache(
      List<Map<String, dynamic>> cachedCommentary) {
    final existingIds = _messages.map((m) => m.id).toSet();
    final entries = cachedCommentary
        .where((msg) => !existingIds.contains(msg['id']))
        .map((msg) => ChatMessage(
              id: msg['id'] ?? '',
              userId: msg['userId'] ?? '__commentary__',
              username: msg['username'] ?? 'Live Commentary',
              text: msg['text'] ?? '',
              selection: msg['selection'],
              timestamp: DateTime.parse(
                  msg['timestamp'] ?? DateTime.now().toIso8601String()),
              status: MessageStatus.delivered,
              isCommentary: true,
              commentaryType: msg['commentaryType'],
              seq: _nextSeq(),
            ))
        .toList();

    if (entries.isEmpty) return;

    setState(() {
      for (final e in entries) {
        _insertMessageSorted(e);
      }
    });
    _scrollToBottom();
  }

  void _saveMessagesToAppCache() {
    // ✅ Save to AppCache in background - don't await
    // This prevents UI jank
    AppCache.saveChatMessages(
      widget.channelId,
      widget.fixtureId,
      _messages,
    );
  }

  Future<void> _syncFromServer() async {
    try {
      String url;
      if (widget.fixtureId != null) {
        url = '$_api/channels/${widget.channelId}/messages'
            '?fixture_id=${widget.fixtureId}'
            '&limit=100';
      } else {
        url = '$_api/channels/${widget.channelId}/messages'
            '?limit=100';
      }

      final response = await http
          .get(Uri.parse(url), headers: _headers())
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final List<dynamic> messagesData = data['messages'] ?? [];

        final existingIds = _messages.map((m) => m.id).toSet();
        bool hasNew = false;

        for (var item in messagesData) {
          String id = item['message_id'] ?? '';
          if (id.isEmpty) {
            final idObj = item['_id'];
            if (idObj is Map && idObj['\$oid'] != null) {
              id = idObj['\$oid'];
            } else if (idObj is String) {
              id = idObj;
            }
          }

          if (id.isEmpty || existingIds.contains(id)) continue;

          hasNew = true;

          ReplyData? replyTo;
          final replyToData = item['reply_to'];
          if (replyToData != null && replyToData is Map) {
            replyTo = ReplyData(
              messageId: replyToData['messageId'] ?? '',
              text: replyToData['text'] ?? '',
              username: replyToData['username'] ?? '',
              selection: replyToData['selection'],
              isMe: replyToData['isMe'] ?? false,
            );
          }

          DateTime timestamp;
          final sentAt = item['sent_at'];
          if (sentAt is Map) {
            final dateObj = sentAt['\$date'];
            if (dateObj is Map && dateObj['\$numberLong'] != null) {
              final milliseconds =
                  int.parse(dateObj['\$numberLong'].toString());
              timestamp = DateTime.fromMillisecondsSinceEpoch(milliseconds);
            } else if (dateObj is String) {
              timestamp = _parseServerTimestamp(dateObj);
            } else {
              timestamp = DateTime.now();
            }
          } else if (sentAt is String) {
            timestamp = _parseServerTimestamp(sentAt);
          } else {
            timestamp = DateTime.now();
          }

          final message = ChatMessage(
            id: id,
            userId: item['sender_id'] ?? '',
            username: item['sender_name'] ?? 'Anonymous',
            text: item['text'] ?? '',
            selection: item['selection'],
            timestamp: timestamp,
            status: MessageStatus.delivered,
            replyTo: replyTo,
            imageUrl: item['image_url'],
            videoUrl: item['video_url'],
            isImage: item['is_image'] ?? false,
            isVideo: item['is_video'] ?? false,
            seq: _nextSeq(),
          );

          if (mounted) {
            setState(() => _insertMessageSorted(message));
          }
        }

        if (hasNew && mounted) {
          _saveMessagesToAppCache();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Sync error: $e');
    }
  }

  // ==========================================================================
  // HANDLE INCOMING MESSAGE (REAL-TIME)
  // ==========================================================================

  // ==========================================================================
  // SEND MESSAGE
  // ==========================================================================

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();

    if (text.isEmpty) {
      Fluttertoast.showToast(
          msg: '📝 Type a message first', backgroundColor: FanColors.draw);
      return;
    }

    if (_isSendingMessage) {
      Fluttertoast.showToast(
          msg: '⏳ Already sending...', backgroundColor: FanColors.draw);
      return;
    }

    _isSendingMessage = true;
    setState(() {});

    // ✅ Generate temp ID
    final tempId =
        'temp_${DateTime.now().millisecondsSinceEpoch}_${widget.userId}';
    final timestamp = DateTime.now();

    Map<String, dynamic>? replyToMap;
    if (_replyingTo != null) {
      replyToMap = {
        'messageId': _replyingTo!.messageId,
        'text': _replyingTo!.text,
        'username': _replyingTo!.username,
        'selection': _replyingTo!.selection,
        'isMe': _replyingTo!.isMe,
      };
    }

    // ✅ Create optimistic with tempId
    final optimisticMessage = ChatMessage(
      id: tempId,
      tempId: tempId,
      userId: widget.userId,
      username: widget.username,
      text: text,
      selection: _userVoteSelection,
      timestamp: timestamp,
      status: MessageStatus.pending,
      isPending: true,
      replyTo: _replyingTo,
      seq: _nextSeq(),
    );

    setState(() {
      _insertMessageSorted(optimisticMessage);
    });

    // ✅ Save to AppCache immediately
    _saveMessagesToAppCache();

    _messageCtrl.clear();
    _cancelReply();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    // ✅ Send via WebSocket — reconnect-and-retry, shared with History/Fixtures.
    // sendChatMessageReliable() only returns true once the message was
    // actually handed to a connected socket; if the socket is mid-reconnect
    // it will attempt _connectWebSocket() via onReconnectAttempt and poll
    // briefly before giving up.
    final sent = await _ws.sendChatMessageReliable(
      message: text,
      selection: _userVoteSelection ?? '',
      username: widget.username,
      messageId: tempId,
      replyTo: replyToMap,
      imageUrl: null,
      videoUrl: null,
      isImage: false,
      isVideo: false,
      channelId: widget.channelId,
       fixtureId: widget.fixtureId ?? '',
      tempId: tempId,
      onReconnectAttempt: () async => _connectWebSocket(),
    );

    if (!sent) {
      debugPrint('❌ WebSocket send failed for $tempId — reverting');
      setState(() {
        _messages.removeWhere((m) => m.tempId == tempId);
      });
      _saveMessagesToAppCache();
      Fluttertoast.showToast(
        msg: 'Not connected to chat server',
        backgroundColor: FanColors.away,
      );
    } else {
      _messageSent = true;
    }

    _isSendingMessage = false;
    setState(() {});
  }

  // ==========================================================================
  // TYPING INDICATOR
  // ==========================================================================

  void _sendTypingIndicator() {
    if (!_ws.isConnected) return;

    _ws.send('typing', {
      'isTyping': true,
      'username': widget.username,
    });

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_ws.isConnected && mounted) {
        _ws.send('typing', {
          'isTyping': false,
          'username': widget.username,
        });
      }
    });
  }

  void _handleTypingIndicator(Map<String, dynamic> payload) {
    final fromUserId = payload['fromUserId'] as String?;
    if (fromUserId == null || fromUserId == widget.userId) return;
    if (!widget.comradesList.contains(fromUserId)) return;
    final isTyping = payload['isTyping'] as bool? ?? false;
    final username = payload['username'] as String? ?? 'Someone';
    setState(() {
      if (isTyping && !_typingUsers.contains(username)) {
        _typingUsers.add(username);
      } else if (!isTyping && _typingUsers.contains(username)) {
        _typingUsers.remove(username);
      }
    });
  }

  // ==========================================================================
  // REPLY
  // ==========================================================================

  void _setReplyTo(ChatMessage message) {
    final bool isCommentary = message.isCommentary;
    final String displayName = isCommentary
        ? message.username
        : (message.userId == widget.userId ? 'yourself' : message.username);

    setState(() {
      _replyingTo = ReplyData(
        messageId: message.id,
        text: message.text.isEmpty
            ? (message.isImage
                ? '📷 Image'
                : (message.isVideo ? '🎥 Video' : 'Media'))
            : message.text,
        username: displayName,
        selection: message.selection,
        isMe: message.userId == widget.userId && !isCommentary,
      );
    });

    _focusNode.requestFocus();
    _scrollToBottom();

    if (isCommentary) {
      _flashError('💬 Replying to commentary...');
    }
  }

  void _cancelReply() => setState(() => _replyingTo = null);

  // ==========================================================================
  // MESSAGE OPTIONS
  // ==========================================================================

  void _showMessageOptions(ChatMessage message) {
    final bool isCommentary = message.isCommentary;
    final bool isMe = message.userId == widget.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: FanColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: FanColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(
                isCommentary ? Icons.sports_soccer : Icons.reply,
                color: isCommentary ? FanColors.draw : FanColors.primary,
                size: 18,
              ),
              title: Text(
                isCommentary ? 'Reply to Commentary' : 'Reply',
                style: TextStyle(color: FanColors.textPrimary, fontSize: 13),
              ),
              onTap: () {
                Navigator.pop(context);
                _setReplyTo(message);
              },
            ),
            if (message.text.isNotEmpty)
              ListTile(
                leading:
                    Icon(Icons.copy, color: FanColors.textTertiary, size: 18),
                title: Text(
                  'Copy text',
                  style: TextStyle(color: FanColors.textPrimary, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.text));
                  _flashError('Copied to clipboard');
                },
              ),
            if (isMe && !isCommentary)
              ListTile(
                leading:
                    Icon(Icons.delete_outline, color: FanColors.away, size: 18),
                title: Text(
                  'Delete',
                  style: TextStyle(color: FanColors.away, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(message);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteMessage(ChatMessage message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FanColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Delete Message',
            style: TextStyle(color: FanColors.textPrimary, fontSize: 14)),
        content: Text('Are you sure you want to delete this message?',
            style: TextStyle(color: FanColors.textSecondary, fontSize: 12)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel',
                  style:
                      TextStyle(color: FanColors.textSecondary, fontSize: 12))),
          TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _db.deleteMessage(message.id);
                setState(
                    () => _messages.removeWhere((m) => m.id == message.id));
                _flashError('Message deleted');
              },
              child: Text('Delete',
                  style: TextStyle(color: FanColors.away, fontSize: 12))),
        ],
      ),
    );
  }

  // ==========================================================================
  // MESSAGE BUBBLE - PITCH LIGHT
  // ==========================================================================

  Widget _buildMediaPreview(ChatMessage message) {
    // Handle optimistic "uploading" placeholder before hitting the network image path
    final bool isUploadingPlaceholder = message.imageUrl == 'uploading...' ||
        message.videoUrl == 'uploading...';

    if (isUploadingPlaceholder) {
      return Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (message.isImage &&
        message.imageUrl != null &&
        message.imageUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          iconTheme: const IconThemeData(color: Colors.white)),
                      body: Center(
                          child: InteractiveViewer(
                              child: CachedNetworkImage(
                                  imageUrl: message.imageUrl!))),
                    ))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: CachedNetworkImage(
            imageUrl: message.imageUrl!,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, _) => Container(
                height: 160,
                color: FanColors.surfaceSunken,
                child: const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 1.5)))),
            errorWidget: (context, error, _) => Container(
                height: 160,
                color: FanColors.surfaceSunken,
                child: Icon(Icons.broken_image,
                    size: 32, color: FanColors.textTertiary)),
          ),
        ),
      );
    }
    if (message.isVideo &&
        message.videoUrl != null &&
        message.videoUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => VideoPlayerPage(videoUrl: message.videoUrl!))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _VideoThumbnail(videoUrl: message.videoUrl!),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(4)),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.videocam, size: 10, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Video',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w500))
                      ])),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, int index) {
    final bool isCommentary = message.isCommentary;
    final bool effectiveIsMe = isCommentary ? false : isMe;
    final bool isLatestLiveArrival = message.id == _latestLiveMessageId;

    final commentaryPurple = FanColors.draw;
    final liveHighlight = FanColors.primary;

    final bubbleColor = isLatestLiveArrival
        ? liveHighlight.withOpacity(0.08)
        : isCommentary
            ? commentaryPurple.withOpacity(0.08)
            : (effectiveIsMe ? FanColors.primaryDim : FanColors.surface);

    final bool replyingToCommentary = message.replyTo != null &&
        (message.replyTo!.username.contains('Commentary') ||
            message.replyTo!.username.contains('Live Commentary'));

    // Whether this message actually has an image or video attached
    final bool hasMedia = message.hasMedia();

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment:
            effectiveIsMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Username header
          if (!effectiveIsMe)
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 2),
              child: isCommentary
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.sports_soccer,
                            size: 9, color: commentaryPurple),
                        const SizedBox(width: 3),
                        Text(
                          message.username,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: commentaryPurple,
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: () =>
                          _showArchiveModal(message.userId, message.username),
                      child: Text(
                        message.username,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: FanColors.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
            ),

          // Message bubble with reply preview
          GestureDetector(
            onLongPress: () =>
                _showMessageOptions(message), // Remove the null condition
            child: Row(
              mainAxisAlignment: effectiveIsMe
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar
                if (!effectiveIsMe) ...[
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isCommentary
                          ? commentaryPurple.withOpacity(0.1)
                          : FanColors.primaryDim,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isCommentary
                          ? Icon(Icons.sports_soccer,
                              size: 12, color: commentaryPurple)
                          : Text(
                              message.username[0].toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: FanColors.primary,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],

                Flexible(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(12),
                        topRight: const Radius.circular(12),
                        bottomLeft: Radius.circular(effectiveIsMe ? 12 : 3),
                        bottomRight: Radius.circular(effectiveIsMe ? 3 : 12),
                      ),
                      border: isLatestLiveArrival
                          ? Border.all(
                              color: liveHighlight.withOpacity(0.3), width: 0.5)
                          : isCommentary
                              ? Border.all(
                                  color: commentaryPurple.withOpacity(0.15),
                                  width: 0.5)
                              : null,
                    ),
                    // Media renders full-bleed inside the bubble, so drop the
                    // horizontal/vertical padding when there's media and let
                    // the text/timestamp keep their own inner padding instead.
                    padding: hasMedia
                        ? const EdgeInsets.all(4)
                        : const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (message.replyTo != null) ...[
                          Padding(
                            padding: hasMedia
                                ? const EdgeInsets.fromLTRB(6, 2, 6, 0)
                                : EdgeInsets.zero,
                            child: Container(
                              padding: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(
                                    color: replyingToCommentary
                                        ? commentaryPurple.withOpacity(0.4)
                                        : (effectiveIsMe
                                            ? FanColors.primary.withOpacity(0.4)
                                            : FanColors.textTertiary
                                                .withOpacity(0.3)),
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    replyingToCommentary
                                        ? Icons.sports_soccer
                                        : Icons.reply_outlined,
                                    size: 10,
                                    color: replyingToCommentary
                                        ? commentaryPurple
                                        : FanColors.textTertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          replyingToCommentary
                                              ? '↳ ${message.replyTo!.username}'
                                              : '↳ ${message.replyTo!.isMe ? 'You' : message.replyTo!.username}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: replyingToCommentary
                                                ? commentaryPurple
                                                : FanColors.primary,
                                          ),
                                        ),
                                        Text(
                                          message.replyTo!.text,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: FanColors.textTertiary,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: hasMedia ? 2 : 4),
                          Divider(
                            height: 1,
                            color: FanColors.border.withOpacity(0.3),
                          ),
                          const SizedBox(height: 4),
                        ],

                        // ✅ Media preview (image/video) — was built but never inserted
                        if (hasMedia) ...[
                          _buildMediaPreview(message),
                          const SizedBox(height: 4),
                        ],

                        // Main message text (skip entirely if it's media with no caption)
                        if (message.text.trim().isNotEmpty)
                          Padding(
                            padding: hasMedia
                                ? const EdgeInsets.symmetric(horizontal: 6)
                                : EdgeInsets.zero,
                            child: Text(
                              message.text,
                              style: TextStyle(
                                fontSize: 12,
                                color: FanColors.textPrimary,
                                fontStyle: isCommentary
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                        if (message.text.trim().isNotEmpty)
                          const SizedBox(height: 2),

                        // Timestamp
                        Padding(
                          padding: hasMedia
                              ? const EdgeInsets.fromLTRB(6, 0, 6, 2)
                              : EdgeInsets.zero,
                          child: Text(
                            _timeAgo(message.timestamp),
                            style: TextStyle(
                                fontSize: 8, color: FanColors.textTertiary),
                          ),
                        ),
                      ],
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

  // ==========================================================================
  // LOAD COMMENTARY - APPCACHE FIRST
  // ==========================================================================

  Future<void> _loadCommentaryFromAppCache() async {
    if (widget.fixtureId == null) return;

    final cachedMessages =
        AppCache.getCachedMessages(widget.channelId, widget.fixtureId);

    if (cachedMessages != null && cachedMessages.isNotEmpty) {
      final commentaryMessages = cachedMessages
          .where((msg) => msg['isCommentary'] == true)
          .map((msg) => ChatMessage(
                id: msg['id'] ?? '',
                userId: msg['userId'] ?? '__commentary__',
                username: msg['username'] ?? 'Live Commentary',
                text: msg['text'] ?? '',
                selection: msg['selection'],
                timestamp: DateTime.parse(
                    msg['timestamp'] ?? DateTime.now().toIso8601String()),
                status: MessageStatus.delivered,
                isCommentary: true,
                commentaryType: msg['commentaryType'],
              ))
          .toList();

      if (commentaryMessages.isNotEmpty) {
        debugPrint(
            '📦 Loaded ${commentaryMessages.length} commentary from AppCache');
        setState(() {
          _messages.addAll(commentaryMessages);
          _sortMessages();
        });
        _scrollToBottom();
        return;
      }
    }

    if (_isHistoryGame) {
      debugPrint('📜 History game - fetching commentary from API');
      await _fetchHistoryCommentaryFromApi();
    } else {
      debugPrint('🔴 Live/upcoming game - fetching commentary from API');
      await _fetchCommentaryFromApi();
    }
  }

  Future<void> _fetchHistoryCommentaryFromApi() async {
    if (widget.fixtureId == null) return;

    try {
      final response = await http
          .get(
            Uri.parse('$_api/games/history/${widget.fixtureId}'),
            headers: _headers(),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        final historyGame = data['data'];

        if (historyGame != null) {
          final commentaryList = historyGame['commentary'] ?? [];

          final entries = commentaryList
              .whereType<Map>()
              .map((e) => ChatMessage.commentary(
                    minute: e['minute'] ?? 0,
                    text: e['text'] ?? '',
                    type: e['type'] ?? 'update',
                    createdAt: _parseCommentaryTimestamp(e['createdAt']),
                    seq: _nextSeq(),
                  ))
              .toList();

          final existingIds = _messages.map((m) => m.id).toSet();
          final newEntries =
              entries.where((c) => !existingIds.contains(c.id)).toList();

          if (newEntries.isNotEmpty) {
            debugPrint(
                '📜 Loaded ${newEntries.length} commentary from history');
            setState(() {
              for (final entry in newEntries) {
                _insertMessageSorted(entry);
              }
            });
            _saveMessagesToAppCache();
            _scrollToBottom();
          }
        }
      } else {
        debugPrint('⚠️ History endpoint failed, trying regular commentary');
        await _fetchCommentaryFromApi();
      }
    } catch (e) {
      debugPrint('❌ Error fetching history commentary: $e');
      await _fetchCommentaryFromApi();
    }
  }

 Future<void> _fetchCommentaryFromApi() async {
  if (widget.fixtureId == null) return;
  try {
    final response = await http
        .get(
          Uri.parse(
              '$_api/games/${widget.fixtureId}/commentary/latest?limit=100'),
          headers: _headers(),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200 && mounted) {
      // ✅ Record fetch time regardless of whether new entries came back —
      // a successful fetch means the cache is now verified-fresh either
      // way. This is what lets _loadCommentary() skip the redundant
      // refetch on a quick close-and-reopen.
      _lastCommentaryFetchAt[widget.fixtureId!] = DateTime.now();

      final data = json.decode(response.body);
      final List<dynamic> raw = data['commentary'] ?? [];

      final entries = raw
          .whereType<Map>()
          .map((e) => ChatMessage.commentary(
                minute: e['minute'] ?? 0,
                text: e['text'] ?? '',
                type: e['type'] ?? 'update',
                createdAt: _parseCommentaryTimestamp(e['createdAt']),
                seq: _nextSeq(),
              ))
          .toList();

      final existingIds = _messages.map((m) => m.id).toSet();
      final newEntries =
          entries.where((c) => !existingIds.contains(c.id)).toList();

      if (newEntries.isNotEmpty) {
        setState(() {
          for (final entry in newEntries) {
            _insertMessageSorted(entry);
          }
        });
        _saveMessagesToAppCache();
        _scrollToBottom();
      }
    }
  } catch (e) {
    debugPrint('❌ Error fetching commentary: $e');
  }
}

  // ==========================================================================
  // HANDLE NEW COMMENTARY FROM WEBSOCKET (REAL-TIME)
  // ==========================================================================
  void _handleNewCommentary(Map<String, dynamic> payload) {
    if (_isHistoryGame) return;

    final entryData = payload['payload'] ?? payload;
    final createdAt = _parseCommentaryTimestamp(entryData['createdAt']);

    final entry = ChatMessage.commentary(
      minute: entryData['minute'] ?? 0,
      text: entryData['text'] ?? '',
      type: entryData['type'] ?? 'update',
      createdAt: createdAt,
    );

    if (_messages.any((m) => m.id == entry.id)) return;

    debugPrint('📢 New commentary: ${entry.text}');

    if (mounted) {
      setState(() {
        _messages.add(entry);
        _sortMessages();
      });

      _saveMessagesToAppCache();
      _markAsLatestLiveArrival(entry.id);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _handleServerConnectedAck(Map<String, dynamic> payload) {
    debugPrint('✅ Server confirmed WebSocket connection');
    if (widget.fixtureId != null && !_isHistoryGame) {
      _ws.send('get.commentary', {'fixtureId': widget.fixtureId});
    }
  }

  void _markAsLatestLiveArrival(String messageId) {
    setState(() => _latestLiveMessageId = messageId);

    _latestLiveHighlightTimer?.cancel();
    _latestLiveHighlightTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _latestLiveMessageId == messageId) {
        setState(() => _latestLiveMessageId = null);
      }
    });
  }

  DateTime _parseCommentaryTimestamp(dynamic raw) {
    if (raw is Map) {
      final d = raw['\$date'];
      if (d is Map && d['\$numberLong'] != null) {
        return DateTime.fromMillisecondsSinceEpoch(
            int.parse(d['\$numberLong'].toString()));
      }
      if (d is String) {
        final parsed = DateTime.tryParse(d);
        if (parsed != null) return parsed;
      }
    } else if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }
    debugPrint('⚠️ Unparseable commentary timestamp: $raw');
    return DateTime.now();
  }

  // ==========================================================================
  // REPLY INDICATOR
  // ==========================================================================

  Widget _buildReplyIndicator() {
    if (_replyingTo == null) return const SizedBox.shrink();

    final bool replyingToCommentary =
        _replyingTo!.username.contains('Commentary') ||
            _replyingTo!.username.contains('Live Commentary');

    final Color replyColor =
        replyingToCommentary ? FanColors.draw : FanColors.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: replyColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: replyColor.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            replyingToCommentary ? Icons.sports_soccer : Icons.reply,
            size: 14,
            color: replyColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      replyingToCommentary
                          ? 'Replying to commentary'
                          : 'Replying to ${_replyingTo!.isMe ? 'yourself' : '@${_replyingTo!.username}'}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: replyColor,
                      ),
                    ),
                    if (replyingToCommentary) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: FanColors.draw.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 6,
                            fontWeight: FontWeight.w700,
                            color: FanColors.draw,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  _replyingTo!.text.length > 50
                      ? '${_replyingTo!.text.substring(0, 50)}...'
                      : _replyingTo!.text,
                  style: TextStyle(
                    fontSize: 9,
                    color: FanColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _cancelReply,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: FanColors.textTertiary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 12,
                color: FanColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TYPING INDICATOR WIDGET
  // ==========================================================================

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();
    final text = _typingUsers.length == 1
        ? '${_typingUsers[0]} is typing...'
        : '${_typingUsers.length} people are typing...';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 16, height: 16, child: TypingAnimationWidget()),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  color: FanColors.textTertiary)),
        ],
      ),
    );
  }

  // ==========================================================================
  // VOTES SECTION
  // ==========================================================================

  String _displayVote(String sel) {
    if (widget.fixture == null) return sel;
    if (sel == 'home_team') return widget.fixture!.homeTeam;
    if (sel == 'away_team') return widget.fixture!.awayTeam;
    if (sel == 'draw') return 'Draw';
    return sel;
  }

  Color _getVoteColor(String sel) {
    switch (sel) {
      case 'home_team':
        return FanColors.primary;
      case 'away_team':
        return FanColors.away;
      case 'draw':
        return FanColors.draw;
      default:
        return FanColors.textTertiary;
    }
  }

  String _initials(String name) =>
      name.isNotEmpty ? name[0].toUpperCase() : 'U';

  Widget _buildVotesSection() {
    if (_voters.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Center(
            child: Column(children: [
          Icon(Icons.how_to_vote_outlined,
              size: 28, color: FanColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 4),
          Text('No votes yet',
              style: TextStyle(fontSize: 10, color: FanColors.textTertiary)),
        ])),
      );
    }

    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
      decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                        color: FanColors.primaryDim, shape: BoxShape.circle),
                    child:  Icon(Icons.how_to_vote,
                        size: 14, color: FanColors.primary)),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('Votes (${_voters.length})',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: FanColors.textPrimary))),
                GestureDetector(
                  onTap: () => setState(() => _showVotesSection = false),
                  child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: FanColors.surfaceSunken,
                          shape: BoxShape.circle),
                      child: Icon(Icons.close,
                          size: 12, color: FanColors.textTertiary)),
                ),
              ],
            ),
          ),
           Divider(height: 0.5, color: FanColors.border),
          Expanded(
            child: ListView.builder(
              controller: _voterScroll,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _voters.length,
              itemBuilder: (context, index) {
                final voter = _voters[index];
                final isMe = voter.userId == widget.userId;
                final voteColor = _getVoteColor(voter.selection);
                final voteDisplay = _displayVote(voter.selection);
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                  child: Row(
                    children: [
                      Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                              color: voteColor.withOpacity(0.08),
                              shape: BoxShape.circle),
                          child: Center(
                              child: Text(_initials(voter.username),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: voteColor)))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(isMe ? 'You' : voter.username,
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isMe
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isMe
                                            ? FanColors.primary
                                            : FanColors.textPrimary)),
                                if (voter.isComrade && !isMe) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                          color: FanColors.primaryDim,
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text('comrade',
                                          style: TextStyle(
                                              fontSize: 6,
                                              color: FanColors.primary))),
                                ],
                              ],
                            ),
                            Text('Voted for $voteDisplay',
                                style: TextStyle(
                                    fontSize: 8,
                                    color: FanColors.textTertiary)),
                          ],
                        ),
                      ),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: voteColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(voteDisplay,
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: voteColor))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // INPUT BAR - PITCH LIGHT
  // ==========================================================================

  Future<bool> _checkVotesButtonVisibility() async {
    try {
      final response = await http.get(
        Uri.parse('$_api/visibility/votes_button_show'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['value'] ?? true;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error checking visibility: $e');
      return true;
    }
  }

  // ==========================================================================
  // EMPTY STATE
  // ==========================================================================

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 40, color: FanColors.textTertiary.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text('No messages yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: FanColors.textTertiary)),
          Text('Be the first to send a message!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 10,
                  color: FanColors.textTertiary.withOpacity(0.6))),
        ],
      ),
    );
  }

  // ==========================================================================
  // COMRADE METHODS
  // ==========================================================================

  void _showComradeProfile(Map<String, dynamic> comrade) {
    if (!widget.isLoggedIn) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SwipeableProfileModal(
        apiBaseUrl: 'https://clash-api-m5mr.onrender.com',
        userId: comrade['id'].toString(),
        username: comrade['username'].toString(),
        phone: comrade['phone']?.toString() ?? '',
        onUserUpdated: (updatedUserData) {},
        onLogout: () {},
      ),
    );
  }

  void _addComradeDirectly(Map<String, dynamic> comrade) {
    if (!widget.isLoggedIn) return;
    if (widget.comradesList.contains(comrade['id'])) {
      _flashError('${comrade['nickname']} is already your comrade');
      return;
    }
    setState(() => _addedComradeIds.add(comrade['id']));
    _flashError('Added ${comrade['nickname']} as comrade! 🎉');
    _addComradeToBackend(comrade);
  }

  Future<void> _addComradeToBackend(Map<String, dynamic> comrade) async {
    if (widget.authToken == null) return;
    await ComradeService.addComrade(
      userId: widget.userId,
      comradeId: comrade['id'].toString(),
      username: widget.username,
      comradeUsername: comrade['username'].toString(),
      comradeNickname: comrade['nickname'].toString(),
      comradeClub: comrade['club']?.toString() ?? '',
      comradeCountry: comrade['country']?.toString() ?? '',
      authToken: widget.authToken!,
    );
  }

  void _showLeaderboard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComradeModal(
        isOpen: true,
        onClose: () => Navigator.pop(context),
        currentUserId: widget.userId,
        currentUserName: widget.username,
        authToken: widget.authToken,
        channelId: widget.channelId,
        channelName: null,
        fixture: widget.fixture,
        comradesList: widget.comradesList,
        comradesVoteMap: {},
        hasUserVoted: _userVoteSelection != null,
        userVoteSelection: _userVoteSelection,
      ),
    );
  }

  void _showArchiveModal(String userId, String username) {
    showArchiveModal(
      context: context,
      userId: userId,
      userName: username,
      authToken: widget.authToken,
      displayName: username,
      isCurrentUser: userId == widget.userId,
    );
  }

  void _openMatchDetails() {
    if (widget.fixture != null) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MatchDetailsModal(
          fixture: widget.fixture!,
          userId: widget.userId,
          username: widget.username,
          authToken: widget.authToken,
        ),
      );
    }
  }

  // ==========================================================================
  // WEBSOCKET - COMPLETE WITH COMMENTARY - FIXED LISTENER LEAK
  // ==========================================================================

  // ============================================================================
// WEB SOCKET LISTENER SETUP - COMPLETE WITH DEDICATED MINUTE UPDATES
// ============================================================================

  void _setupWebSocketListeners() {
    if (_webSocketSetupDone) return;
    _webSocketSetupDone = true;

    // ==========================================================================
    // CHAT MESSAGE - WITH APPCACHE BACKGROUND UPDATE
    // ==========================================================================
    _onChatMessage = (payload) async {
      final fromUserId = payload['userId'] as String?;
      final tempId = payload['tempId'] as String?;

      // ✅ Check if this is a confirmation of our own pending message
      if (tempId != null && tempId.isNotEmpty) {
        final pendingIndex =
            _messages.indexWhere((m) => m.tempId == tempId && m.isPending);

        if (pendingIndex != -1) {
          final serverMessageId = payload['messageId'] as String? ??
              payload['id'] as String? ??
              _generateMessageId();

          // ✅ Update existing message - NO REPLACEMENT
          setState(() {
            _messages[pendingIndex] = _messages[pendingIndex].copyWith(
              id: serverMessageId,
              tempId: null,
              isPending: false,
              status: MessageStatus.sent,
            );
          });

          // ✅ Update AppCache in background
          _saveMessagesToAppCache();
          debugPrint('✅ Message confirmed via WebSocket: $serverMessageId');
          return;
        }
      }

      // ✅ Skip if from us (safety check)
      if (fromUserId == null || fromUserId == widget.userId) return;

      final messageId = payload['messageId'] as String? ??
          payload['id'] as String? ??
          _generateMessageId();

      if (_messages.any((m) => m.id == messageId)) return;

      DateTime timestamp;
      if (payload['timestamp'] != null) {
        timestamp = DateTime.parse(payload['timestamp'] as String);
      } else {
        timestamp = DateTime.now();
      }

      ReplyData? replyTo;
      if (payload['replyTo'] != null && payload['replyTo'] is Map) {
        final replyData = payload['replyTo'] as Map<String, dynamic>;
        replyTo = ReplyData(
          messageId: replyData['messageId'] ?? '',
          text: replyData['text'] ?? '',
          username: replyData['username'] ?? '',
          selection: replyData['selection'],
          isMe: replyData['isMe'] ?? false,
          imageUrl: replyData['imageUrl'],
          videoUrl: replyData['videoUrl'],
          isImage: replyData['isImage'] ?? false,
          isVideo: replyData['isVideo'] ?? false,
        );
      }

      final message = ChatMessage(
        id: messageId,
        userId: fromUserId,
        username: payload['username'] as String? ?? 'Anonymous',
        text: payload['message'] as String? ?? '',
        selection: payload['selection'] as String?,
        timestamp: timestamp,
        status: MessageStatus.delivered,
        replyTo: replyTo,
        imageUrl: payload['imageUrl'] as String?,
        videoUrl: payload['videoUrl'] as String?,
        videoThumbnailUrl: payload['videoThumbnailUrl'] as String?,
        isImage: payload['isImage'] as bool? ?? false,
        isVideo: payload['isVideo'] as bool? ?? false,
        seq: _nextSeq(),
      );

      debugPrint('💬 New message from ${message.username}: ${message.text}');
      if (message.replyTo != null) {
        debugPrint(
            '🔁 Reply to: ${message.replyTo!.username} - "${message.replyTo!.text}"');
      }

      if (mounted) {
        // ✅ Update UI immediately
        setState(() {
          _insertMessageSorted(message);
        });

        // ✅ Update AppCache in background (no await)
        _saveMessagesToAppCache();
        _markAsLatestLiveArrival(messageId);

        // ✅ Update comment counts in AppCache (background)
        if (widget.fixtureId != null) {
          final currentCount = AppCache.getCommentCount(widget.fixtureId!) ?? 0;
          final newCount = currentCount + 1;

          AppCache.applyUpdate(
            fixtureId: widget.fixtureId!,
            updateType: 'comment',
            value: newCount,
            extraData: {'channelId': widget.channelId},
          );
          AppCache.saveCommentCount(widget.fixtureId!, newCount);

          final replyText = message.replyTo != null
              ? '↳ ${message.replyTo!.username}: ${message.replyTo!.text}'
              : null;

          AppCache.applyUpdate(
            fixtureId: widget.fixtureId!,
            updateType: 'latest_comment',
            value: 1,
            extraData: {
              'comment': message.text,
              'username': message.username,
              'selection': message.selection,
              'replyTo': replyText,
              'isReply': message.replyTo != null,
            },
          );
          AppCache.saveLatestComment(
            widget.fixtureId!,
            message.text,
            message.username,
            replyToText: replyText,
          );
        }

        // ✅ Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    };

    // ==========================================================================
    // VOTE UPDATE - WITH APPCACHE BACKGROUND UPDATE
    // ==========================================================================
    _onVoteUpdate = (payload) async {
      final fixtureId = payload['fixture_id'] as String?;
      if (fixtureId != widget.fixtureId) return;

      final homeVotes = payload['home_votes'] as int? ?? 0;
      final awayVotes = payload['away_votes'] as int? ?? 0;
      final drawVotes = payload['draw_votes'] as int? ?? 0;
      final userVote = payload['user_vote'] as String?;

      // ✅ Update UI immediately
      setState(() {
        _homeVotes = homeVotes;
        _awayVotes = awayVotes;
        _drawVotes = drawVotes;
      });

      // ✅ Update AppCache in background
      if (mounted && fixtureId != null) {
        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'vote',
          value: homeVotes + awayVotes + drawVotes,
          extraData: {
            'channelId': widget.channelId,
            'homeVotes': homeVotes,
            'awayVotes': awayVotes,
            'drawVotes': drawVotes,
          },
        );
        AppCache.saveVoteCount(fixtureId, homeVotes + awayVotes + drawVotes);

        if (userVote != null && userVote.isNotEmpty) {
          String frontendSelection;
          if (userVote == 'home') {
            frontendSelection = 'home_team';
          } else if (userVote == 'away') {
            frontendSelection = 'away_team';
          } else if (userVote == 'draw') {
            frontendSelection = 'draw';
          } else {
            frontendSelection = userVote;
          }

          if (frontendSelection != _userVoteSelection) {
            setState(() {
              _userVoteSelection = frontendSelection;
            });
            AppCache.setUserVote(fixtureId, frontendSelection);
            debugPrint('✅ User vote updated via WebSocket: $frontendSelection');
          }
        }
      }

      _buildCarouselItems();
      _fetchVoters();
    };

    // ==========================================================================
    // COMMENTARY NEW - WITH APPCACHE BACKGROUND UPDATE
    // ==========================================================================
    _onCommentaryNew = (payload) async {
      if (_isHistoryGame) return;

      final entryData = payload['payload'] ?? payload;
      final createdAt = _parseCommentaryTimestamp(entryData['createdAt']);

      final entry = ChatMessage.commentary(
        minute: entryData['minute'] ?? 0,
        text: entryData['text'] ?? '',
        type: entryData['type'] ?? 'update',
        createdAt: createdAt,
        seq: _nextSeq(),
      );

      if (_messages.any((m) => m.id == entry.id)) return;

      debugPrint('📢 New commentary: ${entry.text}');

      if (mounted) {
        // ✅ Update UI immediately
        setState(() {
          _insertMessageSorted(entry);
        });

        // ✅ Update AppCache in background
        _saveMessagesToAppCache();
        _markAsLatestLiveArrival(entry.id);

        if (widget.fixtureId != null) {
          AppCache.applyUpdate(
            fixtureId: widget.fixtureId!,
            updateType: 'latest_comment',
            value: 1,
            extraData: {
              'comment': entry.text,
              'username': entry.username,
              'selection': null,
            },
          );
          AppCache.saveLatestComment(
            widget.fixtureId!,
            entry.text,
            entry.username,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    };

    // ==========================================================================
    // COMMENTARY BULK
    // ==========================================================================
    _onCommentaryBulk = (payload) async {
      if (_isHistoryGame) return;

      final entries = payload['payload'] ?? payload;
      if (entries is! List) return;

      bool addedAny = false;
      for (final raw in entries) {
        if (raw is! Map) continue;
        final entryData = raw;
        final createdAt = _parseCommentaryTimestamp(entryData['createdAt']);
        final entry = ChatMessage.commentary(
          minute: entryData['minute'] ?? 0,
          text: entryData['text'] ?? '',
          type: entryData['type'] ?? 'update',
          createdAt: createdAt,
          seq: _nextSeq(),
        );
        if (_messages.any((m) => m.id == entry.id)) continue;
        _insertMessageSorted(entry);
        addedAny = true;
        _markAsLatestLiveArrival(entry.id);
      }

      if (addedAny && mounted) {
        // ✅ Update UI
        setState(() {});
        // ✅ Update AppCache in background
        _saveMessagesToAppCache();
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    };

    // ==========================================================================
    // COMMENT COUNT
    // ==========================================================================
    _onCommentCount = (payload) async {
      final fixtureId = payload['fixture_id'] as String?;
      final count = payload['count'] as int?;
      if (fixtureId != null && fixtureId == widget.fixtureId && count != null) {
        debugPrint('📊 Comment count update for fixture $fixtureId: $count');
        // ✅ Update AppCache in background
        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'comment',
          value: count,
          extraData: {'channelId': widget.channelId},
        );
        AppCache.saveCommentCount(fixtureId, count);
      }
    };

    // ==========================================================================
    // MATCH STATUS - WITH APPCACHE BACKGROUND UPDATE
    // ==========================================================================
    _onMatchStatus = (payload) async {
      final fixtureId = payload['fixture_id']?.toString();
      if (fixtureId != widget.fixtureId) return;

      final status = payload['status']?.toString() ?? 'live';
      final homeScore = payload['home_score'] as int? ?? _homeScore;
      final awayScore = payload['away_score'] as int? ?? _awayScore;
      final timeElapsed =
          (payload['timeElapsed'] as num?)?.toDouble() ?? _timeElapsed;
      final isLive = status == 'live' || status == 'half_time';

      // ✅ Update UI immediately
      setState(() {
        _matchStatus = status;
        _homeScore = homeScore;
        _awayScore = awayScore;
        _timeElapsed = timeElapsed;
        _isLive = isLive;
      });

      // ✅ Update AppCache fixtures in background
      final updatedFixtures = AppCache.fixtures.map((f) {
        if (f.matchId == fixtureId) {
          return Fixture(
            id: f.id,
            matchId: f.matchId,
            homeTeam: f.homeTeam,
            awayTeam: f.awayTeam,
            league: f.league,
            homeWin: f.homeWin,
            awayWin: f.awayWin,
            draw: f.draw,
            date: f.date,
            time: f.time,
            homeScore: homeScore,
            awayScore: awayScore,
            status: status,
            isLive: isLive,
            availableForVoting: f.availableForVoting,
            source: f.source,
            scrapedAt: f.scrapedAt,
            dateIso: f.dateIso,
            subFixtures: f.subFixtures,
            timeElapsed: timeElapsed,
          );
        }
        return f;
      }).toList();

      AppCache.fixtures = updatedFixtures;
      AppCache.notifyFixturesChanged();
      AppCache.saveFixtures(updatedFixtures);

      _buildCarouselItems();
    };

    // ==========================================================================
    // MATCH GOAL - WITH APPCACHE BACKGROUND UPDATE
    // ==========================================================================
    _onMatchGoal = (payload) async {
      final fixtureId = payload['fixture_id']?.toString();
      if (fixtureId != widget.fixtureId) return;

      final homeScore = payload['home_score'] as int? ?? _homeScore;
      final awayScore = payload['away_score'] as int? ?? _awayScore;
      final timeElapsed =
          (payload['timeElapsed'] as num?)?.toDouble() ?? _timeElapsed;
      final scorer = payload['scorer']?.toString() ?? 'Unknown';

      // ✅ Update UI immediately
      setState(() {
        _homeScore = homeScore;
        _awayScore = awayScore;
        _timeElapsed = timeElapsed;
      });

      // ✅ Update AppCache fixtures in background
      final updatedFixtures = AppCache.fixtures.map((f) {
        if (f.matchId == fixtureId) {
          return Fixture(
            id: f.id,
            matchId: f.matchId,
            homeTeam: f.homeTeam,
            awayTeam: f.awayTeam,
            league: f.league,
            homeWin: f.homeWin,
            awayWin: f.awayWin,
            draw: f.draw,
            date: f.date,
            time: f.time,
            homeScore: homeScore,
            awayScore: awayScore,
            status: f.status,
            isLive: f.isLive,
            availableForVoting: f.availableForVoting,
            source: f.source,
            scrapedAt: f.scrapedAt,
            dateIso: f.dateIso,
            subFixtures: f.subFixtures,
            timeElapsed: timeElapsed,
          );
        }
        return f;
      }).toList();

      AppCache.fixtures = updatedFixtures;
      AppCache.notifyFixturesChanged();
      AppCache.saveFixtures(updatedFixtures);

      _buildCarouselItems();

      // Format minute display for toast
      final minutes = timeElapsed.floor();
      final seconds = ((timeElapsed % 1) * 60).round();
      final minuteDisplay = seconds > 0
          ? "${minutes}'${seconds.toString().padLeft(2, '0')}"
          : "${minutes}'";

      Fluttertoast.showToast(
        msg: "⚽ GOAL! $scorer scores at $minuteDisplay",
        backgroundColor: FanColors.primary,
      );
    };

    // ==========================================================================
    // MATCH ENDED
    // ==========================================================================
    _onMatchEnded = (payload) async {
      final fixtureId = payload['fixture_id'] as String?;
      if (fixtureId != null && fixtureId == widget.fixtureId) {
        // ✅ Update UI immediately
        setState(() {
          _matchStatus = 'completed';
          _isLive = false;
        });

        // ✅ Update AppCache in background
        final updatedFixtures = AppCache.fixtures.map((f) {
          if (f.matchId == fixtureId) {
            return Fixture(
              id: f.id,
              matchId: f.matchId,
              homeTeam: f.homeTeam,
              awayTeam: f.awayTeam,
              league: f.league,
              homeWin: f.homeWin,
              awayWin: f.awayWin,
              draw: f.draw,
              date: f.date,
              time: f.time,
              homeScore: f.homeScore,
              awayScore: f.awayScore,
              status: 'completed',
              isLive: false,
              availableForVoting: f.availableForVoting,
              source: f.source,
              scrapedAt: f.scrapedAt,
              dateIso: f.dateIso,
              subFixtures: f.subFixtures,
              timeElapsed: f.timeElapsed,
            );
          }
          return f;
        }).toList();

        AppCache.fixtures = updatedFixtures;
        AppCache.notifyFixturesChanged();
        AppCache.saveFixtures(updatedFixtures);

        _buildCarouselItems();
      }
    };

    // ==========================================================================
    // TYPING INDICATOR
    // ==========================================================================
    _onTyping = (payload) {
      final fromUserId = payload['fromUserId'] as String?;
      if (fromUserId == null || fromUserId == widget.userId) return;
      if (!widget.comradesList.contains(fromUserId)) return;
      final isTyping = payload['isTyping'] as bool? ?? false;
      final username = payload['username'] as String? ?? 'Someone';
      setState(() {
        if (isTyping && !_typingUsers.contains(username)) {
          _typingUsers.add(username);
        } else if (!isTyping && _typingUsers.contains(username)) {
          _typingUsers.remove(username);
        }
      });
    };

    // ==========================================================================
    // LIKE UPDATE - WITH APPCACHE
    // ==========================================================================
    _onLike = (payload) async {
      final fixtureId = payload['fixture_id'] as String?;
      final totalLikes = payload['total_likes'] as int?;
      if (fixtureId != null &&
          fixtureId == widget.fixtureId &&
          totalLikes != null) {
        debugPrint('❤️ Like update: $fixtureId → $totalLikes');
        // ✅ Update AppCache in background
        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'like',
          value: totalLikes,
          extraData: {'liked': payload['liked'] as bool?},
        );
        AppCache.saveLikeCount(fixtureId, totalLikes);
      }
    };

    // ==========================================================================
    // PLEDGE UPDATE - WITH APPCACHE
    // ==========================================================================
    _onPledge = (payload) async {
      final fixtureId = payload['fixture_id'] as String?;
      final totalPledges = payload['total_pledges'] as int?;
      if (fixtureId != null &&
          fixtureId == widget.fixtureId &&
          totalPledges != null) {
        debugPrint('💰 Pledge update: $fixtureId → $totalPledges');
        // ✅ Update AppCache in background
        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'pledge',
          value: totalPledges,
          extraData: {'channelId': widget.channelId},
        );
      }
    };

    // ==========================================================================
    // BET UPDATE - WITH APPCACHE
    // ==========================================================================
    _onBet = (payload) async {
      final fixtureId = payload['fixture_id'] as String?;
      final totalBets = payload['total_bets'] as int?;
      if (fixtureId != null &&
          fixtureId == widget.fixtureId &&
          totalBets != null) {
        debugPrint('🎯 Bet update: $fixtureId → $totalBets');
        // ✅ Update AppCache in background
        AppCache.applyUpdate(
          fixtureId: fixtureId,
          updateType: 'bet',
          value: totalBets,
          extraData: {'channelId': widget.channelId},
        );
      }
    };

    // ==========================================================================
    // DEDICATED MINUTE UPDATE - NEW ✅
    // ==========================================================================
    _onMinuteUpdate = (payload) async {
      final fixtureId = payload['fixture_id']?.toString();
      if (fixtureId != widget.fixtureId) return;

      final minute = (payload['minute'] as num?)?.toDouble() ?? _timeElapsed;
      final minuteDisplay =
          payload['minute_display']?.toString() ?? "${minute.floor()}'";
      final status = payload['status']?.toString() ?? 'live';

      debugPrint('⏱️ Minute update: $fixtureId → $minuteDisplay');

      // ✅ Update UI immediately
      setState(() {
        _timeElapsed = minute;
        if (status == 'half_time') {
          _matchStatus = 'half_time';
          _isLive = true;
        } else if (status == 'full_time') {
          _matchStatus = 'completed';
          _isLive = false;
        } else if (status == 'live' || status == 'injury_time') {
          _matchStatus = 'live';
          _isLive = true;
        }
      });

      // ✅ Update AppCache fixtures in background
      final updatedFixtures = AppCache.fixtures.map((f) {
        if (f.matchId == fixtureId) {
          return Fixture(
            id: f.id,
            matchId: f.matchId,
            homeTeam: f.homeTeam,
            awayTeam: f.awayTeam,
            league: f.league,
            homeWin: f.homeWin,
            awayWin: f.awayWin,
            draw: f.draw,
            date: f.date,
            time: f.time,
            homeScore: f.homeScore,
            awayScore: f.awayScore,
            status: _matchStatus,
            isLive: _isLive,
            availableForVoting: f.availableForVoting,
            source: f.source,
            scrapedAt: f.scrapedAt,
            dateIso: f.dateIso,
            subFixtures: f.subFixtures,
            timeElapsed: minute,
          );
        }
        return f;
      }).toList();

      AppCache.fixtures = updatedFixtures;
      AppCache.notifyFixturesChanged();
      AppCache.saveFixtures(updatedFixtures);

      _buildCarouselItems();

      // Add to commentary as a system entry
      final entry = ChatMessage.commentary(
        minute: minute.floor(),
        text: minuteDisplay == 'HT'
            ? '🔄 Half Time'
            : minuteDisplay == 'FT'
                ? '🏁 Full Time'
                : '⏱️ $minuteDisplay',
        type: status == 'half_time'
            ? 'half_time'
            : status == 'full_time'
                ? 'full_time'
                : 'minute',
        createdAt: DateTime.now(),
        seq: _nextSeq(),
      );

      if (!_messages.any((m) => m.id == entry.id)) {
        setState(() {
          _insertMessageSorted(entry);
        });
        _saveMessagesToAppCache();
        _markAsLatestLiveArrival(entry.id);
      }
    };

    // ==========================================================================
    // CONNECTION ACKS
    // ==========================================================================
   _onConnectedAck = (payload) {
      debugPrint('✅ Server confirmed WebSocket connection');
      if (widget.fixtureId != null && !_isHistoryGame) {
        _ws.send('get.commentary', {'fixtureId': widget.fixtureId});
        // ✅ Added channelId so the server doesn't have to reverse-engineer it
        // by scanning joined_rooms — matches get.minute's existing pattern.
        _ws.send('get.latest.comment', {
          'fixtureId': widget.fixtureId,
          'channelId': widget.channelId,
        });

        // ✅ Request current minute on connect
        _ws.send('get.minute', {
          'fixtureId': widget.fixtureId,
          'channelId': widget.channelId,
        });
      }
    };

    _onRoomJoined = (payload) {
  debugPrint('🔀 Room joined ack received');
  if (widget.fixtureId != null && !_isHistoryGame) {
    _ws.send('get.commentary', {'fixtureId': widget.fixtureId});
    _ws.send('get.latest.comment', {
      'fixtureId': widget.fixtureId,
      'channelId': widget.channelId,
    });

    // ✅ Request current minute on room join
    _ws.send('get.minute', {
      'fixtureId': widget.fixtureId,
      'channelId': widget.channelId,
    });
  }
};
    

    _onWsError = (payload) {
      final error = payload['message']?.toString() ?? 'Unknown error';
      debugPrint('❌ WebSocket error: $error');
    };

    // ==========================================================================
    // SUB-FIXTURE / JOIN EVENTS
    // ==========================================================================
    _onSubFixtureVote = (payload) {
      final fixtureId = payload['fixture_id'] as String?;
      final subFixtureId = payload['sub_fixture_id'] as String?;
      final selection = payload['selection'] as String?;
      if (fixtureId != null && fixtureId == widget.fixtureId) {
        debugPrint('📊 Sub-fixture vote update: $subFixtureId → $selection');
      }
    };

    _onJoinApproved = (data) {
      final channelId = data['channel_id']?.toString();
      final channelName = data['channel_name']?.toString() ?? 'Unknown';
      if (channelId != null && mounted) {
        debugPrint('✅ Join approved: $channelName');
      }
    };

    _onJoinRejected = (data) {
      final channelName = data['channel_name']?.toString() ?? 'Unknown';
      final reason = data['reason']?.toString() ?? 'No reason provided';
      if (mounted) {
        debugPrint('❌ Join rejected: $channelName - $reason');
      }
    };

    _onJoinRequestStatus = (data) {
      final status = data['status']?.toString();
      final channelName = data['channel_name']?.toString() ?? 'Unknown';
      if (mounted) {
        debugPrint('📨 Join request status: $status for $channelName');
      }
    };

    // ==========================================================================
    // REGISTER ALL HANDLERS
    // ==========================================================================
    _ws.on('chat.message', _onChatMessage);
    _ws.on('vote.update', _onVoteUpdate);
    _ws.on('commentary.new', _onCommentaryNew);
    _ws.on('commentary.bulk', _onCommentaryBulk);
    _ws.on('comment.count', _onCommentCount);
    _ws.on('match.status', _onMatchStatus);
    _ws.on('match.goal', _onMatchGoal);
    _ws.on('match.ended', _onMatchEnded);
    _ws.on('typing', _onTyping);
    _ws.on('like', _onLike);
    _ws.on('pledge.update', _onPledge);
    _ws.on('bet.update', _onBet);
    _ws.on('minute.update', _onMinuteUpdate); // ✅ NEW
    _ws.on('connected', _onConnectedAck);
    _ws.on('room.joined', _onRoomJoined);
    _ws.on('error', _onWsError);
    _ws.on('sub_fixture.vote', _onSubFixtureVote);
    _ws.on('join_approved', _onJoinApproved);
    _ws.on('join_rejected', _onJoinRejected);
    _ws.on('join_request_status', _onJoinRequestStatus);

    // ==========================================================================
    // CONNECTION STATUS STREAM
   _wsConnectionSub = _ws.connectionStatus.listen((connected) {
      if (mounted) {
        setState(() => _isConnected = connected);
        if (connected) {
          debugPrint('✅ WebSocket connected');
          _fetchVoteCounts();

          if (!AppCache.isMessagesHydrated(
              widget.channelId, widget.fixtureId)) {
            _syncFromServer(); // only if we haven't caught up yet this run
          }

          if (widget.fixtureId != null && !_isHistoryGame) {
            _ws.send('get.commentary', {'fixtureId': widget.fixtureId});
            _ws.send('get.latest.comment', {
              'fixtureId': widget.fixtureId,
              'channelId': widget.channelId,
            });
            _ws.send('get.minute', {
              'fixtureId': widget.fixtureId,
              'channelId': widget.channelId,
            });
            // no _fetchCommentaryFromApi() here anymore — _loadCommentary()
            // already did the one-shot catch-up in initState via _loadMessages()
          }
        }
      }
    });
    // ==========================================================================
   
  }
  // ==========================================================================
  // TEARDOWN WEBSOCKET
  // ==========================================================================

  void _teardownWebSocketListeners() {
    _ws.off('chat.message', _onChatMessage);
    _ws.off('vote.update', _onVoteUpdate);
    _ws.off('commentary.new', _onCommentaryNew);
    _ws.off('commentary.bulk', _onCommentaryBulk);
    _ws.off('comment.count', _onCommentCount);
    _ws.off('match.status', _onMatchStatus);
    _ws.off('match.goal', _onMatchGoal);
    _ws.off('match.ended', _onMatchEnded);
    _ws.off('typing', _onTyping);
    _ws.off('like', _onLike);
    _ws.off('pledge.update', _onPledge);
    _ws.off('bet.update', _onBet);
    _ws.off('connected', _onConnectedAck);
    _ws.off('room.joined', _onRoomJoined);
    _ws.off('error', _onWsError);
    _ws.off('sub_fixture.vote', _onSubFixtureVote);
    _ws.off('join_approved', _onJoinApproved);
    _ws.off('join_rejected', _onJoinRejected);
    _ws.off('join_request_status', _onJoinRequestStatus);

    _wsConnectionSub?.cancel();
    _wsConnectionSub = null;

    _webSocketSetupDone = false;
    debugPrint('🧹 WebSocket listeners cleaned up');
  }

 Future<void> _connectWebSocket() async {
  if (!widget.isLoggedIn) {
    Fluttertoast.showToast(msg: '❌ Not logged in', backgroundColor: FanColors.away);
    return;
  }

  try {
    await _ws.connect(
      widget.userId,
      widget.authToken ?? '',
      widget.channelId,
      widget.username,
      fixtureId: widget.fixtureId,
    );
    _ws.joinChannelFixtureRoom(widget.channelId, fixtureId: widget.fixtureId);

    // ✅ Always request catch-up here, unconditionally — don't depend on
    // 'connected' or 'room.joined' firing, since the socket/room may
    // already have been connected/joined by FixturesPage before this
    // screen ever opened, in which case neither event re-fires.
    if (widget.fixtureId != null && !_isHistoryGame) {
      _ws.send('get.commentary', {'fixtureId': widget.fixtureId});
      _ws.send('get.latest.comment', {
        'fixtureId': widget.fixtureId,
        'channelId': widget.channelId,
      });
      _ws.send('get.minute', {
        'fixtureId': widget.fixtureId,
        'channelId': widget.channelId,
      });
    }
  } catch (e) {
    _scheduleReconnect();
  }
}
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) _connectWebSocket();
    });
  }

  void _reconnectIfNeeded() {
    if (!_ws.isConnected && mounted) _connectWebSocket();
  }

  // ==========================================================================
  // UTILITIES
  // ==========================================================================

  String _generateMessageId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${widget.userId}_${DateTime.now().microsecondsSinceEpoch}';

  Map<String, String> _headers() {
    final headers = {'Content-Type': 'application/json'};
    if (widget.authToken != null && widget.authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer ${widget.authToken}';
    }
    return headers;
  }

  void _sortMessages() {
    _messages.sort(_compareMessages);
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return DateFormat('MMM d').format(time);
  }

  void _flashError(String msg) => Fluttertoast.showToast(
      msg: msg, backgroundColor: FanColors.away, textColor: Colors.white);

  void _scrollToBottom() {
    _scrollToBottomTimer?.cancel();
    _scrollToBottomTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted || !_chatScroll.hasClients) return;
      final maxExtent = _chatScroll.position.maxScrollExtent;
      if (maxExtent > 0) {
        _chatScroll.animateTo(
          maxExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _markChatAsRead() async {
    if (!widget.isLoggedIn) return;
    try {
      final response = await http.put(
        Uri.parse(
            '$_api/channels/${widget.channelId}/fixtures/${widget.fixtureId ?? 'overall'}/read/${widget.userId}'),
        headers: _headers(),
      );
      if (response.statusCode == 200) {
        debugPrint('✅ Chat marked as read on backend');
      }
    } catch (e) {
      debugPrint('❌ Error marking chat as read: $e');
    }
  }

  // ==========================================================================
  // MEDIA PICKER METHODS
  // ==========================================================================

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: FanColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: FanColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FanColors.primaryDim,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.image_rounded,
                  color: FanColors.primary,
                  size: 18,
                ),
              ),
              title: Text(
                'Gallery',
                style: TextStyle(color: FanColors.textPrimary, fontSize: 13),
              ),
              subtitle: Text(
                'Select an image to share',
                style: TextStyle(color: FanColors.textTertiary, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(); // ✅ Will show caption dialog
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FanColors.draw.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.videocam_rounded,
                  color: FanColors.draw,
                  size: 18,
                ),
              ),
              title: Text(
                'Video',
                style: TextStyle(color: FanColors.textPrimary, fontSize: 13),
              ),
              subtitle: Text(
                'Select a video to share',
                style: TextStyle(color: FanColors.textTertiary, fontSize: 11),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendVideo(); // ✅ Will show caption dialog
              },
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  // ============================================================================
// MEDIA PICKER METHODS - FIXED
// ============================================================================

  // In ChatScreen - Updated media picker methods

  // ============================================================================
// MEDIA PICKER METHODS - FIXED WITH BACKGROUND UPLOAD
// ============================================================================

  /// ✅ Send media message after upload completes
  /// ✅ Send media message after upload completes - WEBSOCKET ONLY
  /// ✅ Send media message after upload completes - WEBSOCKET ONLY, with
  /// reconnect-and-retry (same contract as _sendMessage).
  Future<void> _sendMediaMessageWithUrl({
    String? imageUrl,
    String? videoUrl,
    String? thumbnailUrl,
    required bool isImage,
    required bool isVideo,
    required String caption,
    required String tempId,
  }) async {
    if (_isSendingMessage) return;

    _isSendingMessage = true;

    try {
      // ✅ ONLY WebSocket - NO REST, with reconnect-and-retry
      final sent = await _ws.sendChatMessageReliable(
        message: caption,
        selection: _userVoteSelection ?? '',
        username: widget.username,
        messageId: tempId,
        replyTo: _replyingTo?.toJson(),
        imageUrl: imageUrl,
        videoUrl: videoUrl,
        videoThumbnailUrl: thumbnailUrl,
        isImage: isImage,
        isVideo: isVideo,
        channelId: widget.channelId,
         fixtureId: widget.fixtureId ?? '',
        tempId: tempId,
        onReconnectAttempt: () async => _connectWebSocket(),
      );

      if (sent) {
        _messageSent = true;

        // ✅ Update the pending message in UI
        final index = _messages.indexWhere((m) => m.tempId == tempId);
        if (index != -1) {
          setState(() {
            _messages[index] = _messages[index].copyWith(
              id: tempId,
              isPending: true,
              imageUrl: imageUrl,
              videoUrl: videoUrl,
              videoThumbnailUrl: thumbnailUrl,
              status: MessageStatus.pending,
            );
          });
          _saveMessagesToAppCache();
        }

        debugPrint('✅ Media message sent via WebSocket with tempId: $tempId');
      } else {
        _flashError('Not connected to chat server');
        // Mark as failed
        final index = _messages.indexWhere((m) => m.tempId == tempId);
        if (index != -1) {
          setState(() {
            _messages[index] = _messages[index].copyWith(
              status: MessageStatus.failed,
              isPending: false,
            );
          });
          _saveMessagesToAppCache();
        }
      }
    } catch (e) {
      debugPrint('❌ Error sending media message: $e');
      _flashError('Failed to send media message: $e');

      // ✅ Mark as failed
      final index = _messages.indexWhere((m) => m.tempId == tempId);
      if (index != -1) {
        setState(() {
          _messages[index] = _messages[index].copyWith(
            status: MessageStatus.failed,
            isPending: false,
          );
        });
        _saveMessagesToAppCache();
      }
    } finally {
      _isSendingMessage = false;
      setState(() {});
      _currentUploadId = null;
    }
  }
  // ==========================================================================
  // LIFECYCLE
  // ==========================================================================

  void _preloadInitialAds() {
    final adIds = AdHelper.carouselAdUnitIds;
    if (adIds.isNotEmpty) {
      for (int i = 0; i < adIds.length && i < 4; i++) {
        final adUnitId = adIds[i];
        if (adUnitId.isNotEmpty && !_preloadedAdUnitIds.contains(adUnitId)) {
          _preloadedAdUnitIds.add(adUnitId);
        }
      }
    }
  }

  @override
void dispose() {
  _appCacheSubscription?.cancel();
  _markChatAsRead();

  _teardownWebSocketListeners();

  // ✅ Actually leave this fixture's room now instead of just clearing a
  // pin — this sends room.leave to the server so it stops forwarding
  // this fixture's chat/commentary/vote broadcasts to our connection,
  // without touching any other rooms (e.g. FixturesPage's live-fixture
  // rooms) that share the same underlying socket.
  _ws.leaveChannelFixtureRoom(widget.channelId, fixtureId: widget.fixtureId);

  _stopCarouselAutoScroll();
  _carouselTimer?.cancel();
  _carouselController.dispose();
  _typingTimer?.cancel();
  _reconnectTimer?.cancel();
  _scrollToBottomTimer?.cancel();
  _focusNode.dispose();
  _messageCtrl.dispose();
  _chatScroll.dispose();
  _latestLiveHighlightTimer?.cancel();
  _voterScroll.dispose();

  WidgetsBinding.instance.removeObserver(this);
  super.dispose();
}


 @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    _reconnectIfNeeded();
    if (widget.fixtureId != null && !_isHistoryGame) {
      _fetchCommentaryFromApi(); // ✅ catch up on anything missed while backgrounded
    }
    if (_carouselItems.length > 1 && !_isCarouselRunning) {
      _startCarouselAutoScroll();
    }
  } else if (state == AppLifecycleState.paused) {
    _stopCarouselAutoScroll();
  }
}

  // ==========================================================================
  // BUILD - PITCH LIGHT
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FanColors.background,
      appBar: AppBar(
        backgroundColor: FanColors.background,
        elevation: 0,
        leadingWidth: widget.fixture != null ? 72 : 48,
        leading: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded,
                  color: FanColors.textPrimary, size: 18),
              padding: const EdgeInsets.only(left: 4),
              onPressed: () => Navigator.pop(context, _messageSent),
            ),
            if (widget.fixture != null)
              IconButton(
                icon: Icon(Icons.info_outline_rounded,
                    color: FanColors.textPrimary, size: 16),
                padding: EdgeInsets.zero,
                onPressed: _openMatchDetails,
                tooltip: 'Match Details',
              ),
          ],
        ),
        title: _buildCarousel(),
        actions: [
          IconButton(
            icon:
                Icon(Icons.people_alt, color: FanColors.textPrimary, size: 18),
            padding: const EdgeInsets.only(right: 8),
            onPressed: _showLeaderboard,
          ),
        ],
      ),
      body: Column(
        children: [
          // Votes Section (animated)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _showVotesSection && _voters.isNotEmpty
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildVotesSection(),
            secondChild: const SizedBox.shrink(),
          ),

          // Chat Messages
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _chatScroll,
                    padding: const EdgeInsets.only(
                        left: 8, right: 8, top: 6, bottom: 60),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(
                          message, message.userId == widget.userId, index);
                    },
                  ),
          ),

          // Typing Indicator
          _buildTypingIndicator(),

          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    final canComment = widget.isLoggedIn;

    // 🚀 KEY LOGIC: Determine if voting is required
    // Only upcoming and soon games require a vote
    final bool isUpcomingOrSoon =
        _matchStatus == 'upcoming' || _matchStatus == 'soon';
    final bool requireVoteToChat = isUpcomingOrSoon && widget.fixtureId != null;

    // For live/completed games, chat is open regardless of vote status
    final bool canSendMessage =
        canComment && !_isSendingMessage && !_isUploadingMedia;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          if (_replyingTo != null) _buildReplyIndicator(),
          if (_isUploadingMedia)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: FanColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                Text('Uploading media...',
                    style:
                        TextStyle(fontSize: 10, color: FanColors.textTertiary)),
              ]),
            ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Vote Button
                GestureDetector(
                  onTap: _openVotesModal,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: _userVoteSelection == null && requireVoteToChat
                          ? FanColors.draw.withOpacity(0.1)
                          : FanColors.surfaceSunken,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _userVoteSelection == null && requireVoteToChat
                            ? FanColors.draw.withOpacity(0.3)
                            : FanColors.border.withOpacity(0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      _userVoteSelection == null && requireVoteToChat
                          ? Icons.warning_amber_rounded
                          : Icons.how_to_vote,
                      size: 14,
                      color: _userVoteSelection == null && requireVoteToChat
                          ? FanColors.draw
                          : FanColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        // Attachment button (only when user can send)
                        if (canComment &&
                            !_isSendingMessage &&
                            !_isUploadingMedia &&
                            !(requireVoteToChat && _userVoteSelection == null))
                          GestureDetector(
                            onTap: _showAttachmentMenu,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.attach_file,
                                size: 16,
                                color: FanColors.textTertiary,
                              ),
                            ),
                          ),
                        Expanded(
                          child: _buildInputField(
                            canComment: canComment,
                            requireVoteToChat: requireVoteToChat,
                            hasVoted: _userVoteSelection != null,
                            isSending: _isSendingMessage || _isUploadingMedia,
                          ),
                        ),
                        // Send button
                        if (canComment &&
                            _messageCtrl.text.trim().isNotEmpty &&
                            !_isSendingMessage &&
                            !_isUploadingMedia &&
                            !(requireVoteToChat && _userVoteSelection == null))
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: GestureDetector(
                              onTap: _sendMessage,
                              child: Icon(
                                Icons.send_rounded,
                                size: 16,
                                color: FanColors.primary,
                              ),
                            ),
                          ),
                        if (_isSendingMessage || _isUploadingMedia)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                          ),
                      ],
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

  Widget _buildInputField({
    required bool canComment,
    required bool requireVoteToChat,
    required bool hasVoted,
    required bool isSending,
  }) {
    // Case 1: User not logged in
    if (!canComment) {
      return _buildDisabledInput('Log in to chat', Icons.lock_outline);
    }

    // Case 2: Currently sending
    if (isSending) {
      return _buildDisabledInput('Sending...', Icons.send_rounded);
    }

    // Case 3: Upcoming/soon game - MUST VOTE FIRST
    if (requireVoteToChat && !hasVoted) {
      return GestureDetector(
        onTap: () {
          Fluttertoast.showToast(
            msg: '🗳️ Vote on this match to join the chat',
            backgroundColor: FanColors.draw,
            toastLength: Toast.LENGTH_LONG,
          );
          _openVotesModal();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: FanColors.surfaceSunken,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: FanColors.draw.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 12, color: FanColors.draw),
              const SizedBox(width: 4),
              Text(
                _matchStatus == 'soon'
                    ? 'Vote before game starts 💬'
                    : 'Vote to chat 💬',
                style: TextStyle(
                  fontSize: 11,
                  color: FanColors.draw,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Case 4: Active chat - free to type
    return TextField(
      controller: _messageCtrl,
      focusNode: _focusNode,
      maxLines: null,
      maxLength: 500,
      enabled: true,
      style: TextStyle(fontSize: 12, color: FanColors.textPrimary),
      decoration: InputDecoration(
        hintText: _buildHintText(),
        hintStyle: TextStyle(
          fontSize: 12,
          color: FanColors.textTertiary.withOpacity(0.6),
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
        counterText: '',
        fillColor: Colors.transparent,
        filled: false,
      ),
      onChanged: (text) {
        setState(() {});
        if (text.isNotEmpty && canComment && !_isSendingMessage) {
          _sendTypingIndicator();
        }
      },
      onSubmitted: (_) => _sendMessage(),
    );
  }

  String _buildHintText() {
    if (!widget.isLoggedIn) return 'Log in to chat';
    if (_isSendingMessage || _isUploadingMedia) return 'Sending...';

    // For live games - show special hint
    if (_isLive) return '🔴 Live - Join the conversation!';

    // For completed games
    if (_isHistoryGame) return '📊 Game finished - Discuss the match!';

    // For upcoming/soon games with vote
    return 'Type a message...';
  }

  Widget _buildDisabledInput(String hint, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 12, color: FanColors.textTertiary),
          const SizedBox(width: 4),
          Text(
            hint,
            style: TextStyle(
              fontSize: 11,
              color: FanColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
