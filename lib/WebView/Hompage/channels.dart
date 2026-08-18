// lib/models/channel_model.dart
class Channel {
  final String id;
  final String name;
  final String icon;
  final int memberCount;
  final bool isActive;
  final String lastActivity;

  Channel({
    required this.id,
    required this.name,
    required this.icon,
    required this.memberCount,
    this.isActive = false,
    this.lastActivity = 'Just now',
  });
}

class MockChannelData {
  static List<Channel> getChannels() {
    return [
      Channel(
        id: '1',
        name: 'Premier League',
        icon: '⚽',
        memberCount: 234,
        isActive: true,
        lastActivity: '2 min ago',
      ),
      Channel(
        id: '2',
        name: 'La Liga',
        icon: '🇪🇸',
        memberCount: 189,
        lastActivity: '15 min ago',
      ),
      Channel(
        id: '3',
        name: 'Bundesliga',
        icon: '🇩🇪',
        memberCount: 156,
        lastActivity: '1 hour ago',
      ),
      Channel(
        id: '4',
        name: 'Serie A',
        icon: '🇮🇹',
        memberCount: 134,
        lastActivity: '3 hours ago',
      ),
      Channel(
        id: '5',
        name: 'Ligue 1',
        icon: '🇫🇷',
        memberCount: 98,
        lastActivity: '5 hours ago',
      ),
      Channel(
        id: '6',
        name: 'Champions League',
        icon: '🏆',
        memberCount: 312,
        lastActivity: '1 day ago',
      ),
    ];
  }
}
