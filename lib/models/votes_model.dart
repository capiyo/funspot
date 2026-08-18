// models.dart
class RustVoteResponse {
  final bool success;
  final String message;
  final String? voteId;
  final Map<String, dynamic>? data;

  RustVoteResponse({
    required this.success,
    required this.message,
    this.voteId,
    this.data,
  });

  factory RustVoteResponse.fromJson(Map<String, dynamic> json) {
    return RustVoteResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      voteId: json['voteId'],
      data: json['data'],
    );
  }
}

class RustLikeResponse {
  final bool success;
  final String message;
  final String? likeId;
  final int totalLikes;

  RustLikeResponse({
    required this.success,
    required this.message,
    this.likeId,
    required this.totalLikes,
  });

  factory RustLikeResponse.fromJson(Map<String, dynamic> json) {
    return RustLikeResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      likeId: json['likeId'],
      totalLikes: json['totalLikes'] ?? 0,
    );
  }
}

class RustCommentResponse {
  final bool success;
  final String message;
  final String? commentId;
  final Map<String, dynamic>? comment;

  RustCommentResponse({
    required this.success,
    required this.message,
    this.commentId,
    this.comment,
  });

  factory RustCommentResponse.fromJson(Map<String, dynamic> json) {
    return RustCommentResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      commentId: json['commentId'],
      comment: json['comment'],
    );
  }
}

class VoteStatsResponse {
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final int totalVotes;
  final int homeVotes;
  final int drawVotes;
  final int awayVotes;
  final double homePercentage;
  final double drawPercentage;
  final double awayPercentage;

  VoteStatsResponse({
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    required this.totalVotes,
    required this.homeVotes,
    required this.drawVotes,
    required this.awayVotes,
    required this.homePercentage,
    required this.drawPercentage,
    required this.awayPercentage,
  });

  factory VoteStatsResponse.fromJson(Map<String, dynamic> json) {
    return VoteStatsResponse(
      fixtureId: json['fixtureId'] ?? json['fixture_id'] ?? '',
      homeTeam: json['homeTeam'] ?? json['home_team'] ?? '',
      awayTeam: json['awayTeam'] ?? json['away_team'] ?? '',
      totalVotes: json['totalVotes'] ?? json['total_votes'] ?? 0,
      homeVotes: json['homeVotes'] ?? json['home_votes'] ?? 0,
      drawVotes: json['drawVotes'] ?? json['draw_votes'] ?? 0,
      awayVotes: json['awayVotes'] ?? json['away_votes'] ?? 0,
      homePercentage: (json['homePercentage'] ?? json['home_percentage'] ?? 0.0)
          .toDouble(),
      drawPercentage: (json['drawPercentage'] ?? json['draw_percentage'] ?? 0.0)
          .toDouble(),
      awayPercentage: (json['awayPercentage'] ?? json['away_percentage'] ?? 0.0)
          .toDouble(),
    );
  }
}

class LikeStatsResponse {
  final String fixtureId;
  final int totalLikes;
  final bool userHasLiked;

  LikeStatsResponse({
    required this.fixtureId,
    required this.totalLikes,
    required this.userHasLiked,
  });

  factory LikeStatsResponse.fromJson(Map<String, dynamic> json) {
    return LikeStatsResponse(
      fixtureId: json['fixtureId'] ?? json['fixture_id'] ?? '',
      totalLikes: json['totalLikes'] ?? json['total_likes'] ?? 0,
      userHasLiked: json['userHasLiked'] ?? json['user_has_liked'] ?? false,
    );
  }
}
