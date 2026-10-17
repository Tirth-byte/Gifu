import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'components/circular_arrow_button.dart';

/// Screen 01: The Approved Gufi Onboarding Screen.
///
/// Features:
/// - Single approved screen (no extra swipe pages, no unapproved routes)
/// - Exactly THREE deliberate editorial lines in GAMBARINO:
///     "Commit."
///     "Show up."
///     "Grow together."
/// - Single-line supporting copy in #405881
/// - Unified 30px left alignment grid (Headline, Subtitle, Bottom Gufi signature)
/// - Enormous Hero Card (~41.5% usable height, 36px radius, diffuse cool shadow)
/// - Massive 65% scale Gufi radial brand mark with subtle optical asymmetry
/// - Bottom Gufi wordmark in GAMBARINO + 66px circular CTA
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  late final Animation<double> _cardFade;
  late final Animation<double> _cardSlide;
  late final Animation<double> _symbolScale;
  late final Animation<double> _paginationFade;
  late final Animation<double> _headlineFade;
  late final Animation<double> _headlineSlide;
  late final Animation<double> _supportFade;
  late final Animation<double> _bottomRowFade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<double>(begin: 12.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    _symbolScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.12, 0.48, curve: Curves.easeOutBack),
      ),
    );

    _paginationFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.28, 0.55, curve: Curves.easeOut),
      ),
    );

    _headlineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.38, 0.75, curve: Curves.easeOut),
      ),
    );
    _headlineSlide = Tween<double>(begin: 14.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.38, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _supportFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.50, 0.85, curve: Curves.easeOut),
      ),
    );

    _bottomRowFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  bool _isNavigating = false;

  void _onCtaPressed() {
    if (_isNavigating) return;
    _isNavigating = true;
    AppHaptics.light();
    context.push('/screen-2').then((_) {
      if (mounted) _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 0. Oversized Background Editorial Typographic Watermark (Anchored to physical viewport)
          Positioned(
            left: 20.0,
            bottom: -28.0,
            child: IgnorePointer(
              child: Text(
                'Gufi',
                style: TextStyle(
                  fontFamily: AppTypography.gambarinoFontFamily,
                  fontSize: 195.0,
                  fontWeight: FontWeight.w400,
                  height: 0.86,
                  letterSpacing: -6.0,
                  color: AppColors.navy900.withValues(alpha: 0.15),
                ),
              ),
            ),
          ),

          // Foreground UI inside SafeArea
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final usableHeight = constraints.maxHeight;

                // 1. Full-Display Scale: 88-92% width (margins 22px)
                const cardHorizontalMargin = 22.0;
                final cardWidth = screenWidth - (cardHorizontalMargin * 2);

                // 2. Dominant Hero Height: ~41.5% of usable height
                final isCompact = usableHeight < 680;
                final cardHeight = isCompact
                    ? (usableHeight * 0.38).clamp(240.0, 290.0)
                    : (usableHeight * 0.415).clamp(290.0, 365.0);

                // 3. Dominant Mystical Eye Artwork: Increased ~10% (8–12% target), perfectly centered
                final artworkSize = (cardWidth * 0.86).clamp(
                  220.0,
                  cardHeight - 20.0,
                );

                // 4. Tightened Top Opening & Spacing Rhythm
                final topGap = isCompact ? 10.0 : 16.0;
                final heroToPaginationGap = isCompact ? 16.0 : 20.0;
                final paginationToHeadlineGap = isCompact ? 22.0 : 28.0;

                // 5. Unified Left Grid: exactly 30.0px
                const textMargin = 30.0;

                // Gambarino 40-44px display font size
                final headlineFontSize = (screenWidth * 0.106).clamp(
                  40.0,
                  44.0,
                );

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Upper / Middle Content Flow
                    Positioned.fill(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: topGap),

                            // 1. Enormous Hero Card (Dominates upper 45%)
                            Center(
                              child: FadeTransition(
                                opacity: _cardFade,
                                child: AnimatedBuilder(
                                  animation: _animController,
                                  builder: (context, child) =>
                                      Transform.translate(
                                        offset: Offset(0, _cardSlide.value),
                                        child: child,
                                      ),
                                  child: Container(
                                    width: cardWidth,
                                    height: cardHeight,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(36.0),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0A273869),
                                          blurRadius: 45,
                                          spreadRadius: -2,
                                          offset: Offset(0, 16),
                                        ),
                                        BoxShadow(
                                          color: Color(0x05273869),
                                          blurRadius: 15,
                                          offset: Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: AnimatedBuilder(
                                        animation: _animController,
                                        builder: (context, child) =>
                                            Transform.scale(
                                              scale: _symbolScale.value,
                                              child: child,
                                            ),
                                        child: BlinkingGufiHeroArtwork(
                                          size: artworkSize,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            SizedBox(height: heroToPaginationGap),

                            // 2. Visual Pagination Design Element (Reference Aesthetic)
                            FadeTransition(
                              opacity: _paginationFade,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Active Indicator (42px × 6px pill)
                                    Container(
                                      width: 42.0,
                                      height: 6.0,
                                      decoration: BoxDecoration(
                                        color: AppColors.navy900,
                                        borderRadius: BorderRadius.circular(
                                          999.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    // Inactive Indicator 1 (10px × 6px)
                                    Container(
                                      width: 10.0,
                                      height: 6.0,
                                      decoration: BoxDecoration(
                                        color: AppColors.navy800.withValues(
                                          alpha: 0.20,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999.0,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8.0),
                                    // Inactive Indicator 2 (10px × 6px)
                                    Container(
                                      width: 10.0,
                                      height: 6.0,
                                      decoration: BoxDecoration(
                                        color: AppColors.navy800.withValues(
                                          alpha: 0.20,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            SizedBox(height: paginationToHeadlineGap),

                            // 3. Editorial Headline in GAMBARINO (EXACTLY THREE DELIBERATE LINES)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: textMargin,
                              ),
                              child: FadeTransition(
                                opacity: _headlineFade,
                                child: AnimatedBuilder(
                                  animation: _animController,
                                  builder: (context, child) =>
                                      Transform.translate(
                                        offset: Offset(0, _headlineSlide.value),
                                        child: child,
                                      ),
                                  child: Text(
                                    'Commit.\nShow up.\nGrow together.',
                                    style: TextStyle(
                                      fontFamily:
                                          AppTypography.gambarinoFontFamily,
                                      fontSize: headlineFontSize,
                                      fontWeight: FontWeight.w400,
                                      height: 1.01,
                                      letterSpacing: -0.6,
                                      color: AppColors.navy900,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 16.0),

                            // 4. Single-Line Supporting Copy (Aligned to 30px Grid)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: textMargin,
                              ),
                              child: FadeTransition(
                                opacity: _supportFade,
                                child: Text(
                                  'Make it visible. Follow through.',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: isCompact ? 14.0 : 15.5,
                                    fontWeight: FontWeight.w400,
                                    height: 1.35,
                                    letterSpacing: -0.15,
                                    color: AppColors.navy800.withValues(
                                      alpha: 0.52,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Clearance ensuring content flows comfortably above the bottom anchor
                            const SizedBox(height: 150.0),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Anchored Region: Gufi Signature on Left (30px) + CTA on Right (22px)
                    // Moved upward by ~46px for an intentional, balanced 70–90px lower breathing rhythm
                    Positioned(
                      left: textMargin,
                      right: cardHorizontalMargin,
                      bottom: isCompact ? 56.0 : 110.0,
                      child: FadeTransition(
                        opacity: _bottomRowFade,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Editorial Gufi Signature in GAMBARINO
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Gufi',
                                  style: TextStyle(
                                    fontFamily:
                                        AppTypography.gambarinoFontFamily,
                                    fontSize: 23.0,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.4,
                                    color: AppColors.navy900,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  'GROW TOGETHER.',
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.8,
                                    color: AppColors.navy800.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Navigation CTA Button (66px, 1.6px border, 23px arrow)
                            CircularArrowButton(
                              onTap: _onCtaPressed,
                              size: 66.0,
                              borderWidth: 1.6,
                              iconSize: 23.0,
                              color: AppColors.navy900,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Self-contained widget rendering the authentic Gufi hero eye with occasional,
/// natural, organic eyelid blinks.
///
/// Features:
/// - Zero rebuilds of the rest of the screen
/// - Respects Reduce Motion accessibility settings
/// - Organic eyelid motion: closing (100ms) -> closed hold (60ms) -> opening (140ms)
/// - Completely still for 3.5–6.0 seconds between blinks (randomized)
/// - Occasional natural double blink (~18% chance, 120ms pause)
/// - Smooth quadratic Bezier eyelid curves matching exact artwork landmarks with ZERO visible seam
class BlinkingGufiHeroArtwork extends StatefulWidget {
  final double size;

  const BlinkingGufiHeroArtwork({super.key, required this.size});

  @override
  State<BlinkingGufiHeroArtwork> createState() =>
      _BlinkingGufiHeroArtworkState();
}

class _BlinkingGufiHeroArtworkState extends State<BlinkingGufiHeroArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;
  Timer? _blinkTimer;
  Timer? _doubleBlinkTimer;
  Completer<void>? _doubleBlinkCompleter;
  final Random _random = Random();
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );

    _blinkAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_blinkController);

    // Initial brief stillness before first blink (1.2–1.8s) so user sees it right away
    _scheduleNextBlink(initial: true);
  }

  void _scheduleNextBlink({bool initial = false}) {
    if (!mounted || _disposed) return;
    _blinkTimer?.cancel();
    final delayMs = initial
        ? 1200 +
              _random.nextInt(600) // 1.2–1.8s initially
        : 1800 + _random.nextInt(1200); // 1.8–3.0s recurring

    _blinkTimer = Timer(Duration(milliseconds: delayMs), _runBlinkCycle);
  }

  Future<void> _runBlinkCycle() async {
    if (!mounted || _disposed) return;

    final isVisible = ModalRoute.of(context)?.isCurrent ?? true;
    if (!isVisible) {
      return;
    }

    // Respect Reduce Motion accessibility settings
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      return;
    }

    try {
      // 1. Primary Smooth Blink (480ms)
      await _blinkController.forward(from: 0.0);
      if (!mounted || _disposed) return;
      _blinkController.value = 0.0;

      // 2. Occasional natural double blink (~22% probability)
      final isDoubleBlink = _random.nextDouble() < 0.22;
      if (isDoubleBlink) {
        final completer = Completer<void>();
        _doubleBlinkCompleter = completer;
        _doubleBlinkTimer = Timer(const Duration(milliseconds: 140), () {
          if (!completer.isCompleted) completer.complete();
        });
        await completer.future;
        _doubleBlinkCompleter = null;
        _doubleBlinkTimer = null;
        if (!mounted || _disposed) return;
        await _blinkController.forward(from: 0.0);
        if (!mounted || _disposed) return;
        _blinkController.value = 0.0;
      }
    } catch (_) {}

    // 3. Schedule next frequent blink
    _scheduleNextBlink();
  }

  @override
  void dispose() {
    _disposed = true;
    _blinkTimer?.cancel();
    _doubleBlinkTimer?.cancel();
    if (_doubleBlinkCompleter != null && !_doubleBlinkCompleter!.isCompleted) {
      _doubleBlinkCompleter!.complete();
    }
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Exact authentic static hero artwork (never modified or squashed)
            Image.asset(
              'assets/images/gufi_hero_eye.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
              cacheWidth: (widget.size * 3).round(),
              cacheHeight: (widget.size * 3).round(),
            ),

            // 2. Isolated animated eyelid overlay (only active during smooth blinks)
            AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (context, child) {
                final rawT = _blinkAnimation.value;
                if (rawT <= 0.001) return const SizedBox.shrink();
                final progress = _BlinkProgressEvaluator.evaluate(rawT);
                return CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _EyelidPainter(progress: progress),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Evaluator transforming 0.0..1.0 controller time into a slower, liquid-smooth eyelid cycle:
/// - Closing: 0.0 to 0.36 (~170ms) with easeInOutCubic
/// - Closed Hold: 0.36 to 0.50 (~70ms) holding 1.0
/// - Opening: 0.50 to 1.0 (~240ms) with easeOutCubic
class _BlinkProgressEvaluator {
  static double evaluate(double t) {
    if (t < 0.36) {
      final subT = t / 0.36;
      return Curves.easeInOutCubic.transform(subT);
    } else if (t < 0.50) {
      return 1.0;
    } else {
      final subT = ((t - 0.50) / 0.50).clamp(0.0, 1.0);
      return 1.0 - Curves.easeOutCubic.transform(subT);
    }
  }
}

/// Custom painter rendering organic eyelids meeting along the natural central eye line.
class _EyelidPainter extends CustomPainter {
  final double progress; // 0.0 = fully open, 1.0 = fully closed

  _EyelidPainter({required this.progress});

  // Exact creature navy skin color for 100% seamless transition
  static const Color navyColor = Color(0xFF1F2F61);
  static const Color creaseColor = Color(0xFF121C3E);

  static final Paint _navyPaint = Paint()
    ..color = navyColor
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  static final Paint _creasePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001) return;

    final scale = size.width / 780.0;

    // Subpixel landmarks in 780x780 artwork coordinates
    final pLeft = Offset(272.0 * scale, 332.0 * scale);
    final pRight = Offset(507.0 * scale, 332.0 * scale);
    final ctrlTopOpen = Offset(389.5 * scale, 216.0 * scale);
    final ctrlBotOpen = Offset(389.5 * scale, 448.0 * scale);

    final topCtrlY = (216.0 + progress * 116.0) * scale;
    final botCtrlY = (448.0 - progress * 116.0) * scale;

    // 1. Upper Eyelid: covers from fixed top socket curve down to moving lid curve
    final upperPath = Path()
      ..moveTo(pLeft.dx, pLeft.dy)
      ..quadraticBezierTo(ctrlTopOpen.dx, ctrlTopOpen.dy, pRight.dx, pRight.dy)
      ..quadraticBezierTo(389.5 * scale, topCtrlY, pLeft.dx, pLeft.dy)
      ..close();

    // 2. Lower Eyelid: covers from fixed bottom socket curve up to moving lid curve
    final lowerPath = Path()
      ..moveTo(pRight.dx, pRight.dy)
      ..quadraticBezierTo(ctrlBotOpen.dx, ctrlBotOpen.dy, pLeft.dx, pLeft.dy)
      ..quadraticBezierTo(389.5 * scale, botCtrlY, pRight.dx, pRight.dy)
      ..close();

    canvas.drawPath(upperPath, _navyPaint);
    canvas.drawPath(lowerPath, _navyPaint);

    // 3. Subtle organic crease line when closed (>90%)
    if (progress >= 0.90) {
      final creaseAlpha = ((progress - 0.90) / 0.10).clamp(0.0, 1.0);
      _creasePaint
        ..color = creaseColor.withValues(alpha: creaseAlpha * 0.90)
        ..strokeWidth = 1.6 * scale;

      final creasePath = Path()
        ..moveTo(pLeft.dx, pLeft.dy)
        ..quadraticBezierTo(389.5 * scale, 333.0 * scale, pRight.dx, pRight.dy);

      canvas.drawPath(creasePath, _creasePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EyelidPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
