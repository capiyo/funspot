import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  FanFunzy Design System · v6.0 — "Pitch Light / Pitch Night"
//  Same token names as v5.0 (FanColors.primary, FanColors.surface, …)
//  but every token now resolves to a LIGHT or DARK value depending
//  on FanColors.isDark. Nothing that references FanColors.xxx or
//  FanTypography.xxx or FanDecorations.xxx anywhere else in the app
//  needs to change — only the values behind them changed.
//
//  IMPORTANT: because the values now depend on a runtime flag, the
//  tokens below are `static Color get` (or plain static getters),
//  not `static const`. If you had `const FanTypography.body` /
//  `const BoxDecoration(color: FanColors.x)` anywhere in your own
//  pages, drop the `const` keyword at that call site — the rest of
//  the API (the names, how you call them) is unchanged.
//
//  Toggle theme anywhere with:
//      FanTheme.controller.setDark(true / false);
//  or:
//      FanTheme.controller.toggle();
//  Wrap MaterialApp in a ListenableBuilder on FanTheme.controller
//  (see bottom of file) so the UI rebuilds when it changes.
//
//  DARK MODE UPDATE: dark mode is now flat — there is only ONE
//  background color (the old card bg, 0xFF121A30). background,
//  backgroundTint, surface, surfaceElevated, and surfaceSunken all
//  resolve to that same value in dark mode, so canvas and cards no
//  longer sit at different depths. Light mode is unchanged.
// ─────────────────────────────────────────────────────────────

/// Global light/dark switch. Flip this (via FanTheme.controller) and
/// every FanColors / FanTypography / FanDecorations / FanGradients /
/// FanShadows getter below immediately reflects the new theme.
import 'package:flutter/material.dart';

/// Global light/dark switch. Now fully OS-driven — there is no manual
/// override. FanColors.isDark (and everything derived from it) updates
/// automatically whenever the device's system appearance changes,
/// including live while the app is in the foreground.
class FanTheme {
  FanTheme._();
  static final controller = FanThemeController();
}

class FanThemeController extends ChangeNotifier with WidgetsBindingObserver {
  FanThemeController() {
    WidgetsBinding.instance.addObserver(this);
    _isDark = _systemIsDark;
    FanColors.isDark = _isDark;
  }

  bool _isDark = false;
  bool get isDark => _isDark;

  bool get _systemIsDark =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;

  // Fires automatically whenever the OS-level appearance changes,
  // even while the app is already running in the foreground.
  @override
  void didChangePlatformBrightness() {
    final nowDark = _systemIsDark;
    if (_isDark == nowDark) return;
    _isDark = nowDark;
    FanColors.isDark = nowDark;
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// COLORS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanColors {
  FanColors._();

  /// Flip via FanTheme.controller.setDark(...) — don't set directly
  /// unless you also call FanTheme.controller.setDark to keep the
  /// two in sync.
  static bool isDark = false;

  // ── Canvas ────────────────────────────────────────────────
  // Dark mode: ONE flat background color everywhere (the old card
  // bg, 0xFF121A30). No more tiered background/surface/sunken
  // layering — everything in dark mode shares this single value.
  static const Color _darkFlatBg = Color(0xFF121A30);

  static Color get background =>
      isDark ? _darkFlatBg : const Color(0xFFFFFFFF);
  static Color get backgroundTint =>
      isDark ? _darkFlatBg : const Color(0xFFF5FAF6);
  static Color get surface =>
      isDark ? _darkFlatBg : const Color(0xFFFFFFFF);
  static Color get surfaceElevated =>
      isDark ? _darkFlatBg : const Color(0xFFFFFFFF);
  static Color get surfaceSunken =>
      isDark ? _darkFlatBg : const Color(0xFFF1F6F2);

  // ── Input surfaces ───────────────────────────────────────
  // Dark mode is flat (background == surface == card bg), so a text
  // input drawn with `surface` disappears into the card behind it.
  // This token lifts it one notch lighter so inputs stay visually
  // distinct without reintroducing the old tiered backgrounds.
  // Light mode is unaffected — inputs there already contrast via
  // the white surface + border.
  static Color get inputSurface => isDark
      ? Color.alphaBlend(Colors.white.withValues(alpha: 0.04), _darkFlatBg)
      : const Color(0xFFFFFFFF);
  static Color get inputSurfaceDisabled => isDark
      ? Color.alphaBlend(Colors.white.withValues(alpha: 0.015), _darkFlatBg)
      : const Color(0xFFFAFAFA);

  static Color get border =>
      isDark ? const Color(0xFF232C52) : const Color(0xFFE4ECE5);
  static Color get borderActive =>
      isDark ? const Color(0xFF34407A) : const Color(0xFFBFE0C6);
  static Color get borderFocus =>
      isDark ? const Color(0xFF22C46B) : const Color(0xFF189B48);

  // ── Primary: Pitch Green (brightened for dark navy canvas) ─
  static Color get primary =>
      isDark ? const Color(0xFF22C46B) : const Color(0xFF189B48);
  static Color get primaryDark =>
      isDark ? const Color(0xFF189B48) : const Color(0xFF0E7A37);
  static Color get primaryMuted =>
      isDark ? const Color(0xFF13301F) : const Color(0xFFE3F6E8);
  static Color get primaryDim =>
      isDark ? const Color(0xFF0F2418) : const Color(0xFFF0FAF2);
  static Color get primaryGlow =>
      isDark ? const Color(0x4022C46B) : const Color(0x22189B48);

  // ── Secondary: mint tint → glass cyan-mint highlight in dark ─
  static Color get secondary =>
      isDark ? const Color(0xFF2FE3B0) : const Color(0xFFC7ECC0);
  static Color get secondaryDim =>
      isDark ? const Color(0xFF13291F) : const Color(0xFFEFFAEE);
  static Color get secondaryGlow =>
      isDark ? const Color(0x332FE3B0) : const Color(0x22C7ECC0);

  // ── Amber — draw / neutral vote ───────────────────────────
  static Color get draw =>
      isDark ? const Color(0xFFFFC53D) : const Color(0xFFE8A100);
  static Color get drawDim =>
      isDark ? const Color(0xFF352A0C) : const Color(0xFFFFF6E0);
  static Color get drawGlow =>
      isDark ? const Color(0x40FFC53D) : const Color(0x22E8A100);

  // ── Red — away vote / destructive / LIVE only ─────────────
  static Color get away =>
      isDark ? const Color(0xFFFF5C6C) : const Color(0xFFE23744);
  static Color get awayDim =>
      isDark ? const Color(0xFF391721) : const Color(0xFFFDECED);
  static Color get awayGlow =>
      isDark ? const Color(0x40FF5C6C) : const Color(0x22E23744);
  static Color get live => away;

  // ── Text hierarchy ────────────────────────────────────────
  static Color get textPrimary =>
      isDark ? const Color(0xFFF3F6FC) : const Color(0xFF10241A);
  static Color get textSecondary =>
      isDark ? const Color(0xFFA6B1D1) : const Color(0xFF5B7267);
  static Color get textTertiary =>
      isDark ? const Color(0xFF6C79A3) : const Color(0xFF95A79D);
  static Color get textInverse =>
      const Color(0xFFFFFFFF); // always sits on a colored fill

  // ── Score accents ─────────────────────────────────────────
  static Color get scoreHome => primary;
  static Color get scoreAway =>
      isDark ? const Color(0xFF5FA8FF) : const Color(0xFF2563EB);
  static Color get scoreDash =>
      isDark ? const Color(0xFF3B4570) : const Color(0xFFB7C4BC);

  // ── Social reactions ──────────────────────────────────────
  static Color get reactionLike => away;
  static Color get reactionPredict => primary;
  static Color get reactionShare => scoreAway;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// TYPOGRAPHY — same style names, colors now theme-aware
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanTypography {
  FanTypography._();

  static TextStyle get scoreHero => TextStyle(
        fontFamily: 'SairaCondensed',
        fontSize: 48,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.0,
        color: FanColors.textPrimary,
      );

  static TextStyle get scoreCompact => TextStyle(
        fontFamily: 'SairaCondensed',
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        height: 1.0,
        color: FanColors.textPrimary,
      );

  static TextStyle get scoreDash => TextStyle(
        fontFamily: 'SairaCondensed',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: FanColors.scoreDash,
        height: 1.0,
      );

  static TextStyle get headline => TextStyle(
        fontFamily: 'SairaCondensed',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
        color: FanColors.textPrimary,
      );

  static TextStyle get title => TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
        color: FanColors.textPrimary,
      );

  static TextStyle get body => TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.55,
        color: FanColors.textSecondary,
      );

  static TextStyle get caption => TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
        color: FanColors.textTertiary,
      );

  static TextStyle get tag => TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 8,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: FanColors.textSecondary,
      );

  static TextStyle get button => TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: FanColors.textInverse,
      );

  static TextStyle get statValue => TextStyle(
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

  static TextStyle get competition => TextStyle(
        fontFamily: 'DM Sans',
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: FanColors.textTertiary,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SPACING / RADIUS — no color dependency, unchanged
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
// SHADOWS — light uses soft black shadows; dark uses glow shadows
// (a black shadow is invisible on a near-black background)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanShadows {
  FanShadows._();

  static List<BoxShadow> get subtle => FanColors.isDark
      ? const [
          BoxShadow(
              color: Color(0x33000000), blurRadius: 10, offset: Offset(0, 3)),
        ]
      : const [
          BoxShadow(
              color: Color(0x08102410), blurRadius: 8, offset: Offset(0, 2)),
        ];

  static List<BoxShadow> get card => FanColors.isDark
      ? const [
          BoxShadow(
              color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
        ]
      : const [
          BoxShadow(
              color: Color(0x0D102410), blurRadius: 16, offset: Offset(0, 4)),
        ];

  static List<BoxShadow> get elevated => FanColors.isDark
      ? const [
          BoxShadow(
              color: Color(0x59000000), blurRadius: 28, offset: Offset(0, 10)),
        ]
      : const [
          BoxShadow(
              color: Color(0x14102410), blurRadius: 24, offset: Offset(0, 8)),
        ];

  static List<BoxShadow> get glow => [
        BoxShadow(
            color: FanColors.isDark
                ? const Color(0x5522C46B)
                : const Color(0x26189B48),
            blurRadius: FanColors.isDark ? 22 : 16,
            spreadRadius: -4),
      ];

  static List<BoxShadow> get cardBase => card;
  static List<BoxShadow> get cardPrimary => elevated;
  static List<BoxShadow> get cardLive => glow;
  static List<BoxShadow> get button => [
        BoxShadow(
            color: FanColors.isDark
                ? const Color(0x5522C46B)
                : const Color(0x33189B48),
            blurRadius: 12,
            offset: const Offset(0, 4)),
      ];
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// DECORATION TOKENS — same method names, theme-aware bodies
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
        color: FanColors.surfaceElevated,
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

  static BoxDecoration get voteBarTrack => BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: FanRadius.pillAll,
      );

  static BoxDecoration get primaryButton => BoxDecoration(
        color: FanColors.primary,
        borderRadius: FanRadius.pillAll,
        boxShadow: FanShadows.button,
      );

  static BoxDecoration get ghostButton => BoxDecoration(
        color: FanColors.surface,
        borderRadius: FanRadius.pillAll,
        border: Border.all(
            color: FanColors.borderActive, width: _borderWidthActive),
      );

  static BoxDecoration get statChip => BoxDecoration(
        color: FanColors.surfaceSunken,
        borderRadius: FanRadius.mdAll,
        border: Border.all(color: FanColors.border, width: _borderWidth),
      );

  static BoxDecoration get crestFrame => BoxDecoration(
        color: FanColors.primaryMuted,
        shape: BoxShape.circle,
        border: Border.all(color: FanColors.border, width: _borderWidth),
      );

  static BoxDecoration get floatingNav => BoxDecoration(
        color: FanColors.background.withValues(alpha: 0.92),
        borderRadius: FanRadius.pillAll,
        border: Border.all(color: FanColors.border, width: _borderWidth),
        boxShadow: FanShadows.elevated,
      );

  static BoxDecoration get competitionBand => BoxDecoration(
        color: FanColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(FanRadius.lg),
          topRight: Radius.circular(FanRadius.lg),
        ),
        border: Border(
            bottom: BorderSide(color: FanColors.border, width: _borderWidth)),
      );

  static BoxDecoration get appBackground =>
      BoxDecoration(color: FanColors.background);

  static BoxDecoration speechBubble({Color? color}) => BoxDecoration(
        color: color ?? FanColors.surfaceSunken,
        borderRadius: FanRadius.lgAll,
        border: Border.all(color: FanColors.border, width: _borderWidth),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// GRADIENTS — same names, theme-aware stops
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class FanGradients {
  FanGradients._();

  static LinearGradient get voteHome =>
      LinearGradient(colors: [FanColors.primary, FanColors.primaryDark]);

  static LinearGradient get voteDraw => LinearGradient(colors: [
        FanColors.draw,
        FanColors.isDark ? const Color(0xFFC98A00) : const Color(0xFFC28600),
      ]);

  static LinearGradient get voteAway => LinearGradient(colors: [
        FanColors.scoreAway,
        FanColors.isDark ? const Color(0xFF2E6FE0) : const Color(0xFF1D4ED8),
      ]);

  static LinearGradient get fire =>
      LinearGradient(colors: [FanColors.draw, FanColors.away]);

  // The blue→cyan "glow" gradient from the reference — use for hero
  // CTAs / bestseller-style badges in dark mode, same green CTA in light.
  static LinearGradient get cta => FanColors.isDark
      ? const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF22D3EE)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        )
      : LinearGradient(colors: [FanColors.primary, FanColors.primaryDark]);

  static LinearGradient get imageFade => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          FanColors.isDark ? const Color(0xCC121A30) : const Color(0xCCFFFFFF),
        ],
      );

  static LinearGradient get pitchOverlay => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.6, 1.0],
        colors: FanColors.isDark
            ? const [
                Color(0x00121A30),
                Color(0x80121A30),
                Color(0xFF121A30),
              ]
            : const [
                Color(0x00FFFFFF),
                Color(0x80FFFFFF),
                Color(0xFFFFFFFF),
              ],
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// MOTION / SIZES — unchanged
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
// MATCH STATE / VOTE OUTCOME — logic unchanged, colors flow through
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
// THEME — one function, reads FanColors.isDark at call time.
// Call it again after FanTheme.controller changes to get a fresh
// ThemeData (see MaterialApp wiring below).
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ThemeData fanFunzyTheme() {
  final scheme = FanColors.isDark
      ? ColorScheme.dark(
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
        )
      : ColorScheme.light(
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
    brightness: FanColors.isDark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: FanColors.background,
    textTheme: TextTheme(
      displayLarge: FanTypography.scoreHero,
      displayMedium: FanTypography.scoreCompact,
      headlineLarge: FanTypography.headline,
      titleMedium: FanTypography.title,
      bodyMedium: FanTypography.body,
      bodySmall: FanTypography.caption,
      labelSmall: FanTypography.tag,
      labelMedium: FanTypography.button,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: FanColors.background,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor:
          FanColors.isDark ? const Color(0x40000000) : const Color(0x14102410),
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: FanColors.textPrimary),
      titleTextStyle: FanTypography.headline,
    ),
    cardTheme: CardThemeData(
      color: FanColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: FanRadius.lgAll,
        side: BorderSide(color: FanColors.border, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: FanColors.surfaceSunken,
      selectedColor: FanColors.primaryMuted,
      side: BorderSide(color: FanColors.border),
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
        side: BorderSide(color: FanColors.borderActive, width: 1),
        shape: RoundedRectangleBorder(borderRadius: FanRadius.pillAll),
        padding: const EdgeInsets.symmetric(
            horizontal: FanSpacing.lg, vertical: FanSpacing.md),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: FanColors.background,
      elevation: 0,
      selectedItemColor: FanColors.primary,
      unselectedItemColor: FanColors.textTertiary,
      showSelectedLabels: false,
      showUnselectedLabels: false,
      type: BottomNavigationBarType.fixed,
    ),
    dividerTheme: DividerThemeData(
      color: FanColors.border,
      thickness: 1,
      space: 1,
    ),
    iconTheme: IconThemeData(color: FanColors.textSecondary, size: 16),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: FanColors.surfaceSunken,
      hintStyle: FanTypography.body.copyWith(color: FanColors.textTertiary),
      border: OutlineInputBorder(
        borderRadius: FanRadius.lgAll,
        borderSide: BorderSide(color: FanColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: FanRadius.lgAll,
        borderSide: BorderSide(color: FanColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: FanRadius.lgAll,
        borderSide: BorderSide(color: FanColors.primary, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: FanSpacing.base, vertical: FanSpacing.md),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// Wiring it up in main.dart — the ONLY new code you add:
//
//   ListenableBuilder(
//     listenable: FanTheme.controller,
//     builder: (context, _) => MaterialApp(
//       theme: fanFunzyTheme(),   // rebuilt fresh, reads current isDark
//       home: const MyHomePage(),
//     ),
//   );
//
// Toggle from anywhere, e.g. a settings switch:
//   FanTheme.controller.toggle();
//   FanTheme.controller.setDark(true);
// ─────────────────────────────────────────────────────────────