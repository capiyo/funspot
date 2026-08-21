// models/user_channel.dart

// ============================================================================
// SAFE PARSING HELPERS
// Defensive against Mongo Extended JSON shapes ({"$oid": "..."}, {"$date": {...}})
// leaking through from the Rust/BSON backend, and against any other
// unexpected type showing up where a String/int/bool was expected.
// ============================================================================

String _asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  if (value is Map) {
    // Mongo Extended JSON: {"$oid": "..."} or {"$date": {"$numberLong": "..."}}
    if (value.containsKey(r'$oid')) return value[r'$oid']?.toString() ?? fallback;
    if (value.containsKey(r'$date')) {
      final d = value[r'$date'];
      if (d is Map && d.containsKey(r'$numberLong')) {
        final millis = int.tryParse(d[r'$numberLong'].toString());
        if (millis != null) {
          return DateTime.fromMillisecondsSinceEpoch(millis).toIso8601String();
        }
      }
      return d?.toString() ?? fallback;
    }
    // Unknown map shape — don't crash, just stringify as a last resort.
    return value.toString();
  }
  return value.toString();
}

int _asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  if (value is Map) {
    if (value.containsKey(r'$numberInt')) {
      return int.tryParse(value[r'$numberInt'].toString()) ?? fallback;
    }
    if (value.containsKey(r'$numberLong')) {
      return int.tryParse(value[r'$numberLong'].toString()) ?? fallback;
    }
  }
  return fallback;
}

bool _asBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return fallback;
}

/// Safely converts a dynamic list into List<String>, coercing each element
/// individually instead of doing a blind cast (which throws on a single
/// bad element, e.g. Vec<ObjectId> on the Rust side leaking through as
/// [{"$oid": "..."}, ...] instead of ["...", ...]).
List<String> _asStringList(dynamic value) {
  if (value is! List) return [];
  return value.map((e) => _asString(e)).where((s) => s.isNotEmpty).toList();
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  final s = _asString(value);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

// ============================================================================
// USER CHANNEL MODEL
// ============================================================================

class UserChannel {
  final String channelId;
  final String name;
  final int memberCount;
  final String season;
  final bool isAdmin;
  final List<String>? admins;
  final List<String> memberIds;
  final String inviteCode;
  final List<ChannelMember> members;
  final bool isApproved;
  final bool isActive;
  final String? description;
  final DateTime? joinedAt;

  UserChannel({
    required this.channelId,
    required this.name,
    required this.memberCount,
    required this.season,
    this.isAdmin = false,
    this.admins,
    this.memberIds = const [],
    this.inviteCode = '',
    this.members = const [],
    this.isApproved = false,
    this.isActive = true,
    this.description,
    this.joinedAt,
  });

  factory UserChannel.fromJson(Map<String, dynamic> json) {
    // Never let one malformed record take down the whole list —
    // parse defensively and fall back to safe defaults on any failure.
    try {
      final List<dynamic> membersData = json['members'] is List ? json['members'] : [];
      final List<ChannelMember> members = membersData
          .whereType<Map>()
          .map((m) => ChannelMember.fromJson(Map<String, dynamic>.from(m)))
          .toList();

      final bool isApproved = _asBool(
        json['isApproved'] ?? json['is_approved'] ?? json['approved'],
        false,
      );

      final bool isActive = _asBool(
        json['isActive'] ?? json['is_active'],
        true,
      );

      final bool hasAdmin = members.any((m) => m.isAdmin);

      final DateTime? joinedAt =
          _asDateTime(json['joinedAt'] ?? json['joined_at']);

      return UserChannel(
        channelId: _asString(json['channel_id'] ?? json['channelId']),
        name: _asString(
          json['name'] ?? json['channelName'],
          'Unknown Channel',
        ),
        memberCount: _asInt(json['member_count'] ?? json['memberCount']),
        season: _asString(json['season']),
        isAdmin: hasAdmin,
        admins: (json['admins'] != null) ? _asStringList(json['admins']) : null,
        memberIds:
            members.map((m) => m.userId).where((id) => id.isNotEmpty).toList(),
        inviteCode: _asString(json['invite_code'] ?? json['inviteCode']),
        members: members,
        isApproved: isApproved,
        isActive: isActive,
        description: json['description'] != null ? _asString(json['description']) : null,
        joinedAt: joinedAt,
      );
    } catch (e, st) {
      // Last-resort fallback so one bad record never blanks the whole page.
      // ignore: avoid_print
      print('⚠️ UserChannel.fromJson failed, returning safe fallback: $e\n$st\nraw: $json');
      return UserChannel(
        channelId: _asString(json['channel_id'] ?? json['channelId']),
        name: 'Unknown Channel',
        memberCount: 0,
        season: '',
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'channel_id': channelId,
        'name': name,
        'member_count': memberCount,
        'season': season,
        'is_admin': isAdmin,
        'member_ids': memberIds,
        'members': members.map((m) => m.toJson()).toList(),
        'is_approved': isApproved,
        'is_active': isActive,
        if (description != null) 'description': description,
        if (joinedAt != null) 'joined_at': joinedAt!.toIso8601String(),
      };

  // Helper getters
  bool get isMember => isApproved && isActive;
  bool get isPending => !isApproved && isActive;
  bool get isActiveMember => isApproved && isActive;
  bool get isInactive => !isActive;

  bool isUserAdmin(String userId) {
    return members.any((m) => m.userId == userId && m.isAdmin);
  }

  List<ChannelMember> get adminMembers {
    return members.where((m) => m.isAdmin).toList();
  }

  List<ChannelMember> get regularMembers {
    return members.where((m) => !m.isAdmin).toList();
  }

  ChannelMember? getMember(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  UserChannel copyWith({
    String? channelId,
    String? name,
    int? memberCount,
    String? season,
    bool? isAdmin,
    List<String>? admins,
    List<String>? memberIds,
    String? inviteCode,
    List<ChannelMember>? members,
    bool? isApproved,
    bool? isActive,
    String? description,
    DateTime? joinedAt,
  }) {
    return UserChannel(
      channelId: channelId ?? this.channelId,
      name: name ?? this.name,
      memberCount: memberCount ?? this.memberCount,
      season: season ?? this.season,
      isAdmin: isAdmin ?? this.isAdmin,
      admins: admins ?? this.admins,
      memberIds: memberIds ?? this.memberIds,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
      isApproved: isApproved ?? this.isApproved,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }

  @override
  String toString() {
    return 'UserChannel(channelId: $channelId, name: $name, isApproved: $isApproved, members: ${members.length})';
  }
}

// ============================================================================
// CHANNEL MEMBER MODEL
// ============================================================================

class ChannelMember {
  final String userId;
  final String username;
  final String role;
  final DateTime joinedAt;
  final int seasonPoints;
  final int correctVotes;
  final int totalVotes;
  final int msgCount;

  ChannelMember({
    required this.userId,
    required this.username,
    required this.role,
    required this.joinedAt,
    required this.seasonPoints,
    required this.correctVotes,
    required this.totalVotes,
    required this.msgCount,
  });

  factory ChannelMember.fromJson(Map<String, dynamic> json) {
    try {
      return ChannelMember(
        userId: _asString(json['user_id'] ?? json['userId']),
        username: _asString(
          json['username'] ?? json['user_name'],
          'Anonymous',
        ),
        role: _asString(json['role'], 'member').toLowerCase(),
        joinedAt: _asDateTime(json['joined_at'] ?? json['joinedAt']) ??
            DateTime.now(),
        seasonPoints: _asInt(json['season_points'] ?? json['seasonPoints']),
        correctVotes: _asInt(json['correct_votes'] ?? json['correctVotes']),
        totalVotes: _asInt(json['total_votes'] ?? json['totalVotes']),
        msgCount: _asInt(json['msg_count'] ?? json['msgCount']),
      );
    } catch (e, st) {
      // ignore: avoid_print
      print('⚠️ ChannelMember.fromJson failed, returning safe fallback: $e\n$st\nraw: $json');
      return ChannelMember(
        userId: _asString(json['user_id'] ?? json['userId']),
        username: 'Anonymous',
        role: 'member',
        joinedAt: DateTime.now(),
        seasonPoints: 0,
        correctVotes: 0,
        totalVotes: 0,
        msgCount: 0,
      );
    }
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'username': username,
        'role': role,
        'joined_at': joinedAt.toIso8601String(),
        'season_points': seasonPoints,
        'correct_votes': correctVotes,
        'total_votes': totalVotes,
        'msg_count': msgCount,
      };

  bool get isAdmin => role == 'admin' || role == 'owner';
  bool get isModerator =>
      role == 'moderator' || role == 'admin' || role == 'owner';
  bool get isMember => role == 'member';
  bool get isOwner => role == 'owner';

  double get voteAccuracy {
    if (totalVotes == 0) return 0.0;
    return (correctVotes / totalVotes) * 100;
  }

  String get accuracyLabel {
    final accuracy = voteAccuracy;
    if (accuracy >= 80) return '🏆 Excellent';
    if (accuracy >= 60) return '⭐ Good';
    if (accuracy >= 40) return '📊 Average';
    return '📈 Needs Improvement';
  }

  ChannelMember copyWith({
    String? userId,
    String? username,
    String? role,
    DateTime? joinedAt,
    int? seasonPoints,
    int? correctVotes,
    int? totalVotes,
    int? msgCount,
  }) {
    return ChannelMember(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      seasonPoints: seasonPoints ?? this.seasonPoints,
      correctVotes: correctVotes ?? this.correctVotes,
      totalVotes: totalVotes ?? this.totalVotes,
      msgCount: msgCount ?? this.msgCount,
    );
  }

  @override
  String toString() {
    return 'ChannelMember(userId: $userId, username: $username, role: $role, isAdmin: $isAdmin)';
  }
}