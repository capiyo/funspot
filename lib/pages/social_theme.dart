import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  FanFunzy Design System · v5.0 — "Pitch Light"
//  White-first, green-accented, modern sports-social aesthetic
//  Cards use soft shadows + hairline borders instead of dark chrome
//
//  PRIMARY: #189B48 (Pitch Green)
//  ACCENT:  #C7ECC0 (Mint tint, backgrounds/highlights only)
// ─────────────────────────────────────────────────────────────

class FanColors {
  FanColors._();

  // ── Canvas ────────────────────────────────────────────────
  static const background = Color(0xFFFFFFFF);
  static const backgroundTint = Color(0xFFF5FAF6); // faint green-white wash
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFFFFFFF);
  static const surfaceSunken = Color(0xFFF1F6F2); // inputs, tracks, chips

  static const border = Color(0xFFE4ECE5);
  static const borderActive = Color(0xFFBFE0C6);
  static const borderFocus = Color(0xFF189B48);

  // ── Primary: Pitch Green ──────────────────────────────────
  static const primary = Color(0xFF189B48);
  static const primaryDark = Color(0xFF0E7A37);
  static const primaryMuted = Color(0xFFE3F6E8);
  static const primaryDim = Color(0xFFF0FAF2);
  static const primaryGlow = Color(0x22189B48);

  // ── Secondary: Mint tint (highlights, not text) ───────────
  static const secondary = Color(0xFFC7ECC0);
  static const secondaryDim = Color(0xFFEFFAEE);
  static const secondaryGlow = Color(0x22C7ECC0);

  // ── Amber — draw / neutral vote ───────────────────────────
  static const draw = Color(0xFFE8A100);
  static const drawDim = Color(0xFFFFF6E0);
  static const drawGlow = Color(0x22E8A100);

  // ── Red — away vote / destructive / LIVE only ─────────────
  static const away = Color(0xFFE23744);
  static const awayDim = Color(0xFFFDECED);
  static const awayGlow = Color(0x22E23744);
  static const live = Color(0xFFE23744);

  // ── Text hierarchy ────────────────────────────────────────
  static const textPrimary = Color(0xFF10241A);
  static const textSecondary = Color(0xFF5B7267);
  static const textTertiary = Color(0xFF95A79D);
  static const textInverse = Color(0xFFFFFFFF);

  // ── Score accents ─────────────────────────────────────────
  static const scoreHome = Color(0xFF189B48);
  static const scoreAway =
      Color(0xFF2563EB); // away team identity, not "danger"
  static const scoreDash = Color(0xFFB7C4BC);

  // ── Social reactions ──────────────────────────────────────
  static const reactionLike = Color(0xFFE23744);
  static const reactionPredict = Color(0xFF189B48);
  static const reactionShare = Color(0xFF2563EB);
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TYPOGRAPHY
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanTypography {
  FanTypography._();

  static const scoreHero = TextStyle(
    fontFamily: 'SairaCondensed',
    fontSize: 48,
    fontWeight: FontWeight.w800,
    letterSpacing: -1,
    height: 1.0,
    color: FanColors.textPrimary,
  );

  static const scoreCompact = TextStyle(
    fontFamily: 'SairaCondensed',
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.0,
    color: FanColors.textPrimary,
  );

  static const scoreDash = TextStyle(
    fontFamily: 'SairaCondensed',
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: FanColors.scoreDash,
    height: 1.0,
  );

  static const headline = TextStyle(
    fontFamily: 'SairaCondensed',
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.2,
    color: FanColors.textPrimary,
  );

  static const title = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: FanColors.textPrimary,
  );

  static const body = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: FanColors.textSecondary,
  );

  static const caption = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    color: FanColors.textTertiary,
  );

  static const tag = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 8,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: FanColors.textSecondary,
  );

  static const button = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
    color: FanColors.textInverse,
  );

  static const statValue = TextStyle(
    fontFamily: 'SairaCondensed',
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: FanColors.textPrimary,
    height: 1.0,
  );

  static const statDelta = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 19,
    fontWeight: FontWeight.w300,
    letterSpacing: 0.3,
    height: 1.2,
  );

  static const votePct = TextStyle(
    fontFamily: 'SairaCondensed',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.0,
  );

  static const competition = TextStyle(
    fontFamily: 'DM Sans',
    fontSize: 9,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: FanColors.textTertiary,
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SPACING / RADIUS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanSpacing {
  FanSpacing._();
  static const xs = 2.0;
  static const sm = 4.0;
  static const md = 8.0;
  static const base = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

class FanRadius {
  FanRadius._();
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 14.0;
  static const xl = 18.0;
  static const pill = 999.0;

  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const pillAll = BorderRadius.all(Radius.circular(pill));
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SHADOWS — real elevation now that bg is white
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanShadows {
  FanShadows._();

  static const subtle = [
    BoxShadow(color: Color(0x08102410), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const card = [
    BoxShadow(color: Color(0x0D102410), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const elevated = [
    BoxShadow(color: Color(0x14102410), blurRadius: 24, offset: Offset(0, 8)),
  ];

  static const glow = [
    BoxShadow(color: Color(0x26189B48), blurRadius: 16, spreadRadius: -4),
  ];

  static const cardBase = card;
  static const cardPrimary = elevated;
  static const cardLive = glow;
  static const button = [
    BoxShadow(color: Color(0x33189B48), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DECORATION TOKENS — real cards: white fill, hairline border, soft shadow
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanDecorations {
  FanDecorations._();

  static const double _borderWidth = 1.0;
  static const double _borderWidthActive = 1.4;

  static BoxDecoration card({bool isActive = false, Color? borderColor}) =>
      BoxDecoration(
        color: FanColors.surface,
        borderRadius: FanRadius.lgAll,
        border: Border.all(
          color: borderColor ??
              (isActive ? FanColors.borderActive : FanColors.border),
          width: isActive ? _borderWidthActive : _borderWidth,
        ),
        boxShadow: FanShadows.card,
      );

  static BoxDecoration fixtureCard({bool isLive = false}) => BoxDecoration(
        color: FanColors.surface,
        borderRadius: FanRadius.lgAll,
        border: Border.all(
          color: isLive
              ? FanColors.live.withValues(alpha: 0.35)
              : FanColors.border,
          width: isLive ? _borderWidthActive : _borderWidth,
        ),
        boxShadow: isLive ? FanShadows.glow : FanShadows.card,
      );

  static BoxDecoration elevatedCard({bool isActive = false}) => BoxDecoration(
        color: FanColors.surface,
        borderRadius: FanRadius.xlAll,
        border: Border.all(
          color: isActive ? FanColors.borderActive : FanColors.border,
          width: _borderWidth,
        ),
        boxShadow: FanShadows.elevated,
      );

  static BoxDecoration postCard({bool isActive = false}) => BoxDecoration(
        color: FanColors.surface,
        borderRadius: FanRadius.lgAll,
        border: Border.all(
          color: isActive ? FanColors.borderActive : FanColors.border,
          width: _borderWidth,
        ),
        boxShadow: FanShadows.subtle,
      );

  static BoxDecoration borderlessCard({bool hasUnread = false}) =>
      BoxDecoration(
        color: FanColors.surface,
        borderRadius: FanRadius.mdAll,
        boxShadow: FanShadows.card,
      );

  static BoxDecoration voteBarTrack = BoxDecoration(
    color: FanColors.surfaceSunken,
    borderRadius: FanRadius.pillAll,
  );

  static BoxDecoration primaryButton = BoxDecoration(
    color: FanColors.primary,
    borderRadius: FanRadius.pillAll,
    boxShadow: FanShadows.button,
  );

  static BoxDecoration ghostButton = BoxDecoration(
    color: FanColors.surface,
    borderRadius: FanRadius.pillAll,
    border:
        Border.all(color: FanColors.borderActive, width: _borderWidthActive),
  );

  static BoxDecoration statChip = BoxDecoration(
    color: FanColors.surfaceSunken,
    borderRadius: FanRadius.mdAll,
    border: Border.all(color: FanColors.border, width: _borderWidth),
  );

  static BoxDecoration crestFrame = BoxDecoration(
    color: FanColors.primaryMuted,
    shape: BoxShape.circle,
    border: Border.all(color: FanColors.border, width: _borderWidth),
  );

  static BoxDecoration floatingNav = BoxDecoration(
    color: FanColors.background.withValues(alpha: 0.92),
    borderRadius: FanRadius.pillAll,
    border: Border.all(color: FanColors.border, width: _borderWidth),
    boxShadow: FanShadows.elevated,
  );

  static BoxDecoration competitionBand = BoxDecoration(
    color: FanColors.surface,
    borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(FanRadius.lg),
      topRight: Radius.circular(FanRadius.lg),
    ),
    border: Border(
        bottom: BorderSide(color: FanColors.border, width: _borderWidth)),
  );

  static const appBackground = BoxDecoration(color: FanColors.background);

  static BoxDecoration speechBubble({Color? color}) => BoxDecoration(
        color: color ?? FanColors.surfaceSunken,
        borderRadius: FanRadius.lgAll,
        border: Border.all(color: FanColors.border, width: _borderWidth),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// GRADIENTS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanGradients {
  FanGradients._();

  static const voteHome =
      LinearGradient(colors: [Color(0xFF189B48), Color(0xFF0E7A37)]);
  static const voteDraw =
      LinearGradient(colors: [Color(0xFFE8A100), Color(0xFFC28600)]);
  static const voteAway =
      LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)]);

  static const fire =
      LinearGradient(colors: [Color(0xFFE8A100), Color(0xFFE23744)]);
  static const cta =
      LinearGradient(colors: [Color(0xFF189B48), Color(0xFF0E7A37)]);

  static const imageFade = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCCFFFFFF)],
  );

  static const pitchOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.6, 1.0],
    colors: [Color(0x00FFFFFF), Color(0x80FFFFFF), Color(0xFFFFFFFF)],
  );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MOTION / SIZES (unchanged from v4)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanMotion {
  FanMotion._();
  static const dSnappy = Duration(milliseconds: 120);
  static const dFast = Duration(milliseconds: 200);
  static const dMedium = Duration(milliseconds: 350);
  static const dSlow = Duration(milliseconds: 600);
  static const curveOut = Curves.easeOut;
  static const curveOutCubic = Curves.easeOutCubic;
  static const curveOutBack = Curves.easeOutBack;
  static const curveSpring = Curves.elasticOut;
  static const dPulse = Duration(milliseconds: 1200);
}

class FanSizes {
  FanSizes._();
  static const crestLg = 48.0;
  static const crestMd = 36.0;
  static const crestSm = 24.0;
  static const avatarMd = 32.0;
  static const avatarSm = 24.0;
  static const voteBarHeight = 6.0;
  static const voteBarRadius = 3.0;
  static const liveDot = 6.0;
  static const liveDotOuter = 12.0;
  static const navHeight = 44.0;
  static const navIconSize = 16.0;
  static const navActiveSize = 18.0;
  static const statChipW = 70.0;
  static const statChipH = 56.0;
  static const minTouchTarget = 40.0;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MATCH STATE / VOTE OUTCOME (logic unchanged, colors updated)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enum MatchState { scheduled, live, halftime, fullTime, postponed, cancelled }

extension MatchStateX on MatchState {
  Color get dotColor => switch (this) {
        MatchState.live => FanColors.live,
        MatchState.halftime => FanColors.draw,
        MatchState.fullTime => FanColors.textTertiary,
        MatchState.postponed => FanColors.draw,
        MatchState.cancelled => FanColors.away,
        MatchState.scheduled => FanColors.textTertiary,
      };

  String get label => switch (this) {
        MatchState.live => 'LIVE',
        MatchState.halftime => 'HT',
        MatchState.fullTime => 'FT',
        MatchState.postponed => 'PPD',
        MatchState.cancelled => 'CANCELLED',
        MatchState.scheduled => 'UPCOMING',
      };

  bool get isPulsing => this == MatchState.live;
}

enum VoteOutcome { home, draw, away }

extension VoteOutcomeX on VoteOutcome {
  Color get fill => switch (this) {
        VoteOutcome.home => FanColors.primary,
        VoteOutcome.draw => FanColors.draw,
        VoteOutcome.away => FanColors.away,
      };

  Color get dimBg => switch (this) {
        VoteOutcome.home => FanColors.primaryDim,
        VoteOutcome.draw => FanColors.drawDim,
        VoteOutcome.away => FanColors.awayDim,
      };

  Color get glow => switch (this) {
        VoteOutcome.home => FanColors.primaryGlow,
        VoteOutcome.draw => FanColors.drawGlow,
        VoteOutcome.away => FanColors.awayGlow,
      };

  LinearGradient get gradient => switch (this) {
        VoteOutcome.home => FanGradients.voteHome,
        VoteOutcome.draw => FanGradients.voteDraw,
        VoteOutcome.away => FanGradients.voteAway,
      };
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// THEME — light, uses ColorScheme.light now
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ThemeData fanFunzyTheme() {
  const scheme = ColorScheme.light(
    surface: FanColors.surface,
    primary: FanColors.primary,
    primaryContainer: FanColors.primaryDim,
    secondary: FanColors.secondary,
    secondaryContainer: FanColors.secondaryDim,
    error: FanColors.away,
    errorContainer: FanColors.awayDim,
    onSurface: FanColors.textPrimary,
    onPrimary: FanColors.textInverse,
    onSecondary: FanColors.textPrimary,
    outline: FanColors.border,
    outlineVariant: FanColors.borderActive,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: FanColors.background,
    textTheme: const TextTheme(
      displayLarge: FanTypography.scoreHero,
      displayMedium: FanTypography.scoreCompact,
      headlineLarge: FanTypography.headline,
      titleMedium: FanTypography.title,
      bodyMedium: FanTypography.body,
      bodySmall: FanTypography.caption,
      labelSmall: FanTypography.tag,
      labelMedium: FanTypography.button,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: FanColors.background,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Color(0x14102410),
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: FanColors.textPrimary),
      titleTextStyle: FanTypography.headline,
    ),
    cardTheme: CardThemeData(
      color: FanColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: FanRadius.lgAll,
        side: const BorderSide(color: FanColors.border, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: FanColors.surfaceSunken,
      selectedColor: FanColors.primaryMuted,
      side: const BorderSide(color: FanColors.border),
      labelStyle: FanTypography.caption,
      shape: RoundedRectangleBorder(borderRadius: FanRadius.pillAll),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: FanColors.primary,
        foregroundColor: FanColors.textInverse,
        textStyle: FanTypography.button,
        shape: RoundedRectangleBorder(borderRadius: FanRadius.pillAll),
        padding: const EdgeInsets.symmetric(
            horizontal: FanSpacing.lg, vertical: FanSpacing.md),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: FanColors.textPrimary,
        textStyle: FanTypography.button,
        side: const BorderSide(color: FanColors.borderActive, width: 1),
        shape: RoundedRectangleBorder(borderRadius: FanRadius.pillAll),
        padding: const EdgeInsets.symmetric(
            horizontal: FanSpacing.lg, vertical: FanSpacing.md),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: FanColors.background,
      elevation: 0,
      selectedItemColor: FanColors.primary,
      unselectedItemColor: FanColors.textTertiary,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: const DividerThemeData(
      color: FanColors.border,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: FanColors.textSecondary, size: 16),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FanColors.surfaceSunken,
      hintStyle: FanTypography.body.copyWith(color: FanColors.textTertiary),
      border: OutlineInputBorder(
        borderRadius: FanRadius.lgAll,
        borderSide: const BorderSide(color: FanColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: FanRadius.lgAll,
        borderSide: const BorderSide(color: FanColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: FanRadius.lgAll,
        borderSide: const BorderSide(color: FanColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: FanSpacing.base, vertical: FanSpacing.md),
    ),
  );
}
