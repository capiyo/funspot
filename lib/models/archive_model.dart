// ========== BACKEND ARCHIVE MODELS ==========

class ArchiveActivityRequest {
  final String userId;
  final String username;
  final String fixtureId;
  final String homeTeam;
  final String awayTeam;
  final String? selection; // "home_team", "draw", "away_team"
  final bool? isLiked;
  final String? comment;
  final String activityType; // "vote", "like", "comment"
  final String timestamp;

  ArchiveActivityRequest({
    required this.userId,
    required this.username,
    required this.fixtureId,
    required this.homeTeam,
    required this.awayTeam,
    this.selection,
    this.isLiked,
    this.comment,
    required this.activityType,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'username': username,
      'fixtureId': fixtureId,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'selection': selection,
      'isLiked': isLiked,
      'comment': comment,
      'activityType': activityType,
      'timestamp': timestamp,
    };
  }
}
