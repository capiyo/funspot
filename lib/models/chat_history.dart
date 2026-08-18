// models/chat_history.dart
// models/chat_history.dart
import 'package:intl/intl.dart';
import './fixture_models.dart'; // Make sure this imports your Fixture class

class ChatHistory {
  final String id;
  final String fixtureId;
  final String matchTitle;
  final String league;
  final DateTime date;
  final String time;
  final int participants;
  final int messages;
  final String matchStatus;
  final int? homeScore;
  final int? awayScore;
  final String homeTeam;
  final String awayTeam;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final bool isPinned;

  ChatHistory({
    required this.id,
    required this.fixtureId,
    required this.matchTitle,
    required this.league,
    required this.date,
    required this.time,
    required this.participants,
    required this.messages,
    required this.matchStatus,
    this.homeScore,
    this.awayScore,
    required this.homeTeam,
    required this.awayTeam,
    required this.lastMessage,
    this.lastMessageTime,
    this.isPinned = false,
  });

  factory ChatHistory.fromFixture(
    Fixture fixture, {
    int participants = 0,
    int messages = 0,
    String lastMessage = '',
    DateTime? lastMessageTime,
  }) {
    return ChatHistory(
      id: fixture.matchId,
      fixtureId: fixture.matchId,
      matchTitle: '${fixture.homeTeam} vs ${fixture.awayTeam}',
      league: fixture.league,
      date: _parseDate(fixture.date),
      time: fixture.time,
      participants: participants,
      messages: messages,
      matchStatus: _getMatchStatus(fixture.status),
      homeScore: fixture.homeScore,
      awayScore: fixture.awayScore,
      homeTeam: fixture.homeTeam,
      awayTeam: fixture.awayTeam,
      lastMessage: lastMessage.isNotEmpty
          ? lastMessage
          : 'Join the conversation!',
      lastMessageTime: lastMessageTime,
      isPinned: false,
    );
  }

  // Additional factory method from JSON (if needed)
  factory ChatHistory.fromJson(Map<String, dynamic> json) {
    return ChatHistory(
      id: json['id']?.toString() ?? '',
      fixtureId:
          json['fixtureId']?.toString() ?? json['fixture_id']?.toString() ?? '',
      matchTitle:
          json['matchTitle']?.toString() ??
          json['match_title']?.toString() ??
          '',
      league: json['league']?.toString() ?? '',
      date: _parseDate(json['date']?.toString() ?? ''),
      time: json['time']?.toString() ?? '',
      participants: json['participants'] as int? ?? 0,
      messages: json['messages'] as int? ?? 0,
      matchStatus:
          json['matchStatus']?.toString() ??
          json['match_status']?.toString() ??
          'upcoming',
      homeScore: json['homeScore'] as int? ?? json['home_score'] as int?,
      awayScore: json['awayScore'] as int? ?? json['away_score'] as int?,
      homeTeam:
          json['homeTeam']?.toString() ?? json['home_team']?.toString() ?? '',
      awayTeam:
          json['awayTeam']?.toString() ?? json['away_team']?.toString() ?? '',
      lastMessage:
          json['lastMessage']?.toString() ??
          json['last_message']?.toString() ??
          'Join the conversation!',
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.tryParse(json['lastMessageTime'])
          : json['last_message_time'] != null
          ? DateTime.tryParse(json['last_message_time'])
          : null,
      isPinned:
          json['isPinned'] as bool? ?? json['is_pinned'] as bool? ?? false,
    );
  }

  static DateTime _parseDate(String dateStr) {
    try {
      // Try different date formats that your API might return
      List<String> formats = [
        'yyyy-MM-dd',
        'dd-MM-yyyy',
        'MM/dd/yyyy',
        'yyyy/MM/dd',
        'dd/MM/yyyy',
      ];

      for (String format in formats) {
        try {
          return DateFormat(format).parse(dateStr);
        } catch (_) {
          continue;
        }
      }

      // If all parsing fails, return current date
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  static String _getMatchStatus(String status) {
    switch (status.toLowerCase()) {
      case 'finished':
      case 'ft':
        return 'Finished';
      case 'live':
      case 'inplay':
      case 'in progress':
        return 'Live';
      case 'upcoming':
      case 'notstarted':
      case 'scheduled':
        return 'Upcoming';
      case 'postponed':
        return 'Postponed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Upcoming';
    }
  }

  // Helper getters
  bool get isLive => matchStatus.toLowerCase() == 'live';
  bool get isFinished => matchStatus.toLowerCase() == 'finished';
  bool get isUpcoming => matchStatus.toLowerCase() == 'upcoming';

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final fixtureDate = DateTime(date.year, date.month, date.day);

    if (fixtureDate.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (fixtureDate.isAtSameMomentAs(
      today.subtract(const Duration(days: 1)),
    )) {
      return 'Yesterday';
    } else if (fixtureDate.isAfter(today.subtract(const Duration(days: 7))) &&
        fixtureDate.isBefore(today)) {
      return '${fixtureDate.difference(today).inDays.abs()} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }

  String get shortTime {
    return time.length > 5 ? time.substring(0, 5) : time;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fixtureId': fixtureId,
      'matchTitle': matchTitle,
      'league': league,
      'date': DateFormat('yyyy-MM-dd').format(date),
      'time': time,
      'participants': participants,
      'messages': messages,
      'matchStatus': matchStatus,
      'homeScore': homeScore,
      'awayScore': awayScore,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'isPinned': isPinned,
    };
  }

  // For displaying in UI
  String get scoreDisplay {
    if (homeScore != null && awayScore != null) {
      return '$homeScore - $awayScore';
    }
    return time;
  }

  String get participantsDisplay {
    if (participants > 1000) {
      return '${(participants / 1000).toStringAsFixed(1)}k';
    }
    return participants.toString();
  }
}
