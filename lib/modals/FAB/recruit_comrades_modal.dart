import 'package:flutter/material.dart';
import '../../pages/fan_Funzy_design.dart';

class ComradeUser {
  final String id;
  final String userId;
  final String username;
  final String nickname;
  final String club;
  final String country;
  final String? avatarUrl;
  final bool isSelected;
  final bool isMutual;

  ComradeUser({
    required this.id,
    required this.userId,
    required this.username,
    required this.nickname,
    required this.club,
    required this.country,
    this.avatarUrl,
    this.isSelected = false,
    this.isMutual = false,
  });

  ComradeUser copyWith({bool? isSelected, bool? isMutual}) {
    return ComradeUser(
      id: id,
      userId: userId,
      username: username,
      nickname: nickname,
      club: club,
      country: country,
      avatarUrl: avatarUrl,
      isSelected: isSelected ?? this.isSelected,
      isMutual: isMutual ?? this.isMutual,
    );
  }
}

// 30 MOCK USERS
final List<ComradeUser> mockUsers = [
  // East Africa
  ComradeUser(
    id: '1',
    userId: 'u1',
    username: 'capiyo_fan',
    nickname: 'Capiyo',
    club: 'Manchester United',
    country: 'France',
    isMutual: false,
  ),
  ComradeUser(
    id: '2',
    userId: 'u2',
    username: 'gunner_king',
    nickname: 'GunnersKing',
    club: 'Arsenal',
    country: 'Kenya',
    isMutual: true,
  ),
  ComradeUser(
    id: '3',
    userId: 'u3',
    username: 'liver_bird',
    nickname: 'RedBird',
    club: 'Liverpool',
    country: 'Kenya',
    isMutual: false,
  ),
  ComradeUser(
    id: '4',
    userId: 'u4',
    username: 'chelsea_blue',
    nickname: 'BlueLion',
    club: 'Chelsea',
    country: 'Tanzania',
    isMutual: false,
  ),
  ComradeUser(
    id: '5',
    userId: 'u5',
    username: 'spur_hero',
    nickname: 'SpurHero',
    club: 'Tottenham',
    country: 'Uganda',
    isMutual: false,
  ),
  ComradeUser(
    id: '6',
    userId: 'u6',
    username: 'city_zen',
    nickname: 'CityZen',
    club: 'Manchester City',
    country: 'Rwanda',
    isMutual: true,
  ),
  ComradeUser(
    id: '7',
    userId: 'u7',
    username: 'barca_mes',
    nickname: 'BarcaMes',
    club: 'Barcelona',
    country: 'Ethiopia',
    isMutual: false,
  ),
  ComradeUser(
    id: '8',
    userId: 'u8',
    username: 'madrid_gal',
    nickname: 'MadridGal',
    club: 'Real Madrid',
    country: 'Kenya',
    isMutual: false,
  ),

  // West Africa
  ComradeUser(
    id: '9',
    userId: 'u9',
    username: 'super_eagle',
    nickname: 'SuperEagle',
    club: 'Arsenal',
    country: 'Nigeria',
    isMutual: true,
  ),
  ComradeUser(
    id: '10',
    userId: 'u10',
    username: 'black_star',
    nickname: 'BlackStar',
    club: 'Manchester United',
    country: 'Ghana',
    isMutual: false,
  ),
  ComradeUser(
    id: '11',
    userId: 'u11',
    username: 'lion_teranga',
    nickname: 'TerangaLion',
    club: 'Chelsea',
    country: 'Senegal',
    isMutual: false,
  ),
  ComradeUser(
    id: '12',
    userId: 'u12',
    username: 'elephant_ci',
    nickname: 'ElephantCI',
    club: 'Liverpool',
    country: 'Ivory Coast',
    isMutual: false,
  ),

  // Europe
  ComradeUser(
    id: '13',
    userId: 'u13',
    username: 'red_devil',
    nickname: 'RedDevil',
    club: 'Manchester United',
    country: 'England',
    isMutual: true,
  ),
  ComradeUser(
    id: '14',
    userId: 'u14',
    username: 'blaugrana',
    nickname: 'Blaugrana',
    club: 'Barcelona',
    country: 'Spain',
    isMutual: false,
  ),
  ComradeUser(
    id: '15',
    userId: 'u15',
    username: 'die_mannschaft',
    nickname: 'DieMannschaft',
    club: 'Bayern Munich',
    country: 'Germany',
    isMutual: false,
  ),
  ComradeUser(
    id: '16',
    userId: 'u16',
    username: 'rossoneri',
    nickname: 'Rossoneri',
    club: 'AC Milan',
    country: 'Italy',
    isMutual: false,
  ),
  ComradeUser(
    id: '17',
    userId: 'u17',
    username: 'les_bleus',
    nickname: 'LesBleus',
    club: 'Paris Saint-Germain',
    country: 'France',
    isMutual: true,
  ),

  // South America
  ComradeUser(
    id: '18',
    userId: 'u18',
    username: 'selecao',
    nickname: 'Selecao',
    club: 'Real Madrid',
    country: 'Brazil',
    isMutual: false,
  ),
  ComradeUser(
    id: '19',
    userId: 'u19',
    username: 'albiceleste',
    nickname: 'Albiceleste',
    club: 'Barcelona',
    country: 'Argentina',
    isMutual: false,
  ),
  ComradeUser(
    id: '20',
    userId: 'u20',
    username: 'charrua',
    nickname: 'Charrua',
    club: 'Liverpool',
    country: 'Uruguay',
    isMutual: false,
  ),
  ComradeUser(
    id: '21',
    userId: 'u21',
    username: 'cafetero',
    nickname: 'Cafetero',
    club: 'Manchester United',
    country: 'Colombia',
    isMutual: true,
  ),

  // Asia
  ComradeUser(
    id: '22',
    userId: 'u22',
    username: 'samurai_blue',
    nickname: 'SamuraiBlue',
    club: 'Arsenal',
    country: 'Japan',
    isMutual: false,
  ),
  ComradeUser(
    id: '23',
    userId: 'u23',
    username: 'tiger_red',
    nickname: 'TigerRed',
    club: 'Tottenham',
    country: 'South Korea',
    isMutual: false,
  ),
  ComradeUser(
    id: '24',
    userId: 'u24',
    username: 'green_falcon',
    nickname: 'GreenFalcon',
    club: 'Manchester City',
    country: 'Saudi Arabia',
    isMutual: false,
  ),
  ComradeUser(
    id: '25',
    userId: 'u25',
    username: 'blue_tiger',
    nickname: 'BlueTiger',
    club: 'Chelsea',
    country: 'India',
    isMutual: true,
  ),

  // North America
  ComradeUser(
    id: '26',
    userId: 'u26',
    username: 'stars_stripes',
    nickname: 'StarsStripes',
    club: 'Manchester United',
    country: 'USA',
    isMutual: false,
  ),
  ComradeUser(
    id: '27',
    userId: 'u27',
    username: 'el_tri',
    nickname: 'ElTri',
    club: 'Real Madrid',
    country: 'Mexico',
    isMutual: false,
  ),
  ComradeUser(
    id: '28',
    userId: 'u28',
    username: 'maple_leaf',
    nickname: 'MapleLeaf',
    club: 'Liverpool',
    country: 'Canada',
    isMutual: false,
  ),

  // More Africans
  ComradeUser(
    id: '29',
    userId: 'u29',
    username: 'pharaoh_king',
    nickname: 'PharaohKing',
    club: 'Arsenal',
    country: 'Egypt',
    isMutual: true,
  ),
  ComradeUser(
    id: '30',
    userId: 'u30',
    username: 'bafana_boy',
    nickname: 'BafanaBoy',
    club: 'Manchester City',
    country: 'South Africa',
    isMutual: false,
  ),
];

class RecruitComradesModal extends StatefulWidget {
  final String userId;
  final String nickname;
  final String club;
  final String country;
  final VoidCallback? onComplete;
  final VoidCallback? onSkip;

  const RecruitComradesModal({
    super.key,
    required this.userId,
    required this.nickname,
    required this.club,
    required this.country,
    this.onComplete,
    this.onSkip,
  });

  @override
  State<RecruitComradesModal> createState() => _RecruitComradesModalState();
}

class _RecruitComradesModalState extends State<RecruitComradesModal> {
  List<ComradeUser> _users = [];
  final List<String> _selectedComradeIds = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final int _maxComrades = 50;

  @override
  void initState() {
    super.initState();
    _loadMockData();
  }

  void _loadMockData() {
    Future.delayed(const Duration(milliseconds: 500), () {
      setState(() {
        _users = List.from(mockUsers);
        _isLoading = false;
      });
    });
  }

  List<ComradeUser> get _filteredUsers {
    var filtered = List<ComradeUser>.from(_users);

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        return user.nickname.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
            user.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user.club.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            user.country.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    filtered.sort((a, b) {
      final aSameClub = a.club == widget.club;
      final bSameClub = b.club == widget.club;
      if (aSameClub && !bSameClub) return -1;
      if (!aSameClub && bSameClub) return 1;
      if (a.isMutual != b.isMutual) return b.isMutual ? 1 : -1;
      return a.nickname.compareTo(b.nickname);
    });

    return filtered;
  }

  void _toggleSelection(ComradeUser user) {
    if (_selectedComradeIds.contains(user.userId)) {
      setState(() {
        _selectedComradeIds.remove(user.userId);
        final index = _users.indexWhere((u) => u.userId == user.userId);
        if (index != -1) {
          _users[index] = user.copyWith(isSelected: false);
        }
      });
    } else {
      if (_selectedComradeIds.length >= _maxComrades) {
        _showToast(
          'Your battalion is full. Upgrade to add more comrades.',
          isWarning: true,
        );
        return;
      }
      setState(() {
        _selectedComradeIds.add(user.userId);
        final index = _users.indexWhere((u) => u.userId == user.userId);
        if (index != -1) {
          _users[index] = user.copyWith(isSelected: true);
        }
      });
    }
  }

  void _showToast(String message, {bool isWarning = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: FanTypography.body),
        backgroundColor: isWarning ? FanColors.draw : FanColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: FanRadius.lgAll),
      ),
    );
  }

  void _handleComplete() {
    _showToast(
      '${_selectedComradeIds.length} comrades added to your battalion!',
    );
    widget.onComplete?.call();
  }

  void _handleSkip() {
    widget.onSkip?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: FanColors.surface,
          borderRadius: FanRadius.xlAll,
          border: Border.all(color: FanColors.border),
          boxShadow: FanShadows.elevated,
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FanColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _buildHeader(),
            _buildBattalionProgress(),
            _buildSearchBar(),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _filteredUsers.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) =>
                              _buildUserTile(_filteredUsers[index]),
                        ),
            ),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FanColors.primary,
              shape: BoxShape.circle,
              boxShadow: FanShadows.glow,
            ),
            child:  Icon(
              Icons.groups,
              color: FanColors.textInverse,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Build Your Battalion',
                  style: FanTypography.headline.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add comrades to see their votes',
                  style: FanTypography.caption.copyWith(
                    color: FanColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: FanColors.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(color: FanColors.border),
              ),
              child: Icon(
                Icons.close,
                color: FanColors.textPrimary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBattalionProgress() {
    final progress = _selectedComradeIds.length / _maxComrades;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: FanRadius.lgAll,
        border: Border.all(color: FanColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Battalion',
                style: FanTypography.caption.copyWith(
                  color: FanColors.textSecondary,
                ),
              ),
              Text(
                '${_selectedComradeIds.length}/$_maxComrades',
                style: FanTypography.statValue.copyWith(
                  fontSize: 14,
                  color: FanColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: FanColors.border,
              valueColor:  AlwaysStoppedAnimation<Color>(
                FanColors.primary,
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: FanColors.surfaceSunken,
          borderRadius: FanRadius.lgAll,
          border: Border.all(color: FanColors.border, width: 1),
        ),
        child: TextField(
          style: FanTypography.body.copyWith(
            color: FanColors.textPrimary,
            fontSize: 14,
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search by name, club, or country...',
            hintStyle: FanTypography.caption.copyWith(
              color: FanColors.textTertiary,
              fontSize: 13,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: FanColors.textTertiary,
              size: 18,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(ComradeUser user) {
    final isSelected = _selectedComradeIds.contains(user.userId);
    final isSameClub = user.club == widget.club;
    final isSameCountry = user.country == widget.country;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected ? FanColors.primaryDim : FanColors.surfaceSunken,
        borderRadius: FanRadius.lgAll,
        border: Border.all(
          color: isSelected
              ? FanColors.primary.withValues(alpha: 0.3)
              : FanColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FanColors.primaryDim,
              shape: BoxShape.circle,
              border: Border.all(
                color: FanColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                user.nickname.substring(0, 1).toUpperCase(),
                style: FanTypography.title.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: FanColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      user.nickname,
                      style: FanTypography.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (user.isMutual) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: FanRadius.pillAll,
                        ),
                        child: Text(
                          'Mutual',
                          style: FanTypography.tag.copyWith(
                            color: FanColors.primary,
                          ),
                        ),
                      ),
                    ],
                    if (isSameClub && !isSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: FanRadius.pillAll,
                        ),
                        child: Text(
                          'Same Club',
                          style: FanTypography.tag.copyWith(
                            color: FanColors.primary,
                          ),
                        ),
                      ),
                    ],
                    if (isSameCountry && !isSelected && !isSameClub) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: FanColors.primaryDim,
                          borderRadius: FanRadius.pillAll,
                        ),
                        child: Text(
                          'Same Country',
                          style: FanTypography.tag.copyWith(
                            color: FanColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.sports_soccer,
                      size: 10,
                      color: FanColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.club,
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.flag,
                      size: 10,
                      color: FanColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.country,
                      style: FanTypography.caption.copyWith(
                        color: FanColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  '@${user.username}',
                  style: FanTypography.tag.copyWith(
                    color: FanColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleSelection(user),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected ? FanColors.primary : FanColors.surfaceSunken,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? FanColors.primary : FanColors.border,
                  width: 1,
                ),
              ),
              child: Icon(
                isSelected ? Icons.check : Icons.add,
                size: 18,
                color: isSelected
                    ? FanColors.textInverse
                    : FanColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: FanColors.primary,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Finding comrades...',
            style: FanTypography.caption.copyWith(
              color: FanColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: FanColors.surfaceSunken,
              shape: BoxShape.circle,
              border: Border.all(color: FanColors.border),
            ),
            child: Icon(
              Icons.people_outline,
              size: 32,
              color: FanColors.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty
                ? 'No matching users found'
                : 'No comrades available',
            style: FanTypography.title.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Check back later',
            style: FanTypography.caption.copyWith(
              color: FanColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: FanColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _handleSkip, // ✅ Changed from onPressed to onTap
              child: Container(
                height: 48,
                decoration: FanDecorations.ghostButton,
                child: Center(
                  child: Text(
                    'Skip for now',
                    style: FanTypography.button.copyWith(
                      color: FanColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _handleComplete, // ✅ Changed from onPressed to onTap
              child: Container(
                height: 48,
                decoration: FanDecorations.primaryButton,
                child: Center(
                  child: Text(
                    'Add ${_selectedComradeIds.isEmpty ? 'Comrades' : '${_selectedComradeIds.length} Comrades'}',
                    style: FanTypography.button.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: FanColors.textInverse,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
