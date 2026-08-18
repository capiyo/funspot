// models/user_channel.dart

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
    final List<dynamic> membersData = json['members'] ?? [];
    final List<ChannelMember> members = membersData
        .map((m) => ChannelMember.fromJson(m as Map<String, dynamic>))
        .toList();

    final bool isApproved =
        json['isApproved'] ?? json['is_approved'] ?? json['approved'] ?? false;

    final bool isActive = json['isActive'] ?? json['is_active'] ?? true;

    final bool hasAdmin = members.any((m) => m.isAdmin);

    DateTime? joinedAt;
    if (json['joinedAt'] != null) {
      joinedAt = DateTime.tryParse(json['joinedAt'].toString());
    } else if (json['joined_at'] != null) {
      joinedAt = DateTime.tryParse(json['joined_at'].toString());
    }

    return UserChannel(
      channelId:
          json['channel_id']?.toString() ?? json['channelId']?.toString() ?? '',
      name: json['name']?.toString() ??
          json['channelName']?.toString() ??
          'Unknown Channel',
      memberCount:
          json['member_count']?.toInt() ?? json['memberCount']?.toInt() ?? 0,
      season: json['season']?.toString() ?? '',
      isAdmin: hasAdmin,
      admins: json['admins'] != null ? List<String>.from(json['admins']) : null,
      memberIds:
          members.map((m) => m.userId).where((id) => id.isNotEmpty).toList(),
      inviteCode: json['invite_code']?.toString() ??
          json['inviteCode']?.toString() ??
          '',
      members: members,
      isApproved: isApproved,
      isActive: isActive,
      description: json['description']?.toString(),
      joinedAt: joinedAt,
    );
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
    return ChannelMember(
      userId: json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      username: json['username']?.toString() ??
          json['user_name']?.toString() ??
          'Anonymous',
      role: json['role']?.toString()?.toLowerCase() ?? 'member',
      joinedAt: DateTime.tryParse(json['joined_at']?.toString() ??
              json['joinedAt']?.toString() ??
              '') ??
          DateTime.now(),
      seasonPoints:
          json['season_points']?.toInt() ?? json['seasonPoints']?.toInt() ?? 0,
      correctVotes:
          json['correct_votes']?.toInt() ?? json['correctVotes']?.toInt() ?? 0,
      totalVotes:
          json['total_votes']?.toInt() ?? json['totalVotes']?.toInt() ?? 0,
      msgCount: json['msg_count']?.toInt() ?? json['msgCount']?.toInt() ?? 0,
    );
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
