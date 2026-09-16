import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/haptics/app_haptics.dart';
import '../../../../core/theme/app_typography.dart';

/// Screen 02 of the Gufi Onboarding Flow.
///
/// Palette:
/// - Primary blue: #5880DA
/// - Lime accent: #C9F17E
/// - Soft blue: #BCDBFA
/// - Off-white background: #F7F9F5
/// - Deep text contrast: #1E3365
///
/// Navigation Alignment:
/// - Screen 2 navigation row center Y matches Screen 1 CTA center Y across all devices.
class OnboardingScreen2 extends StatefulWidget {
  const OnboardingScreen2({super.key});

  @override
  State<OnboardingScreen2> createState() => _OnboardingScreen2State();
}

class _OnboardingScreen2State extends State<OnboardingScreen2>
    with TickerProviderStateMixin {
  // Screen palette constants
  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color softBlue = Color(0xFFBCDBFA);
  static const Color screenBg = Color(0xFFF7F9F5);
  static const Color deepContrast = Color(0xFF1E3365);

  // Screen entrance choreography
  late final AnimationController _entranceController;
  late final Animation<double> _heroFade;
  late final Animation<double> _heroScale;
  late final Animation<double> _headlineFade;
  late final Animation<double> _headlineSlide;
  late final Animation<double> _supportFade;
  late final Animation<double> _bottomNavFade;
  late final Animation<double> _bottomNavSlide;

  // Momentum meter counter & gauge animation
  late final AnimationController _momentumController;
  late final Animation<double> _momentumCurve;

  Timer? _startTimer;

  @override
  void initState() {
    super.initState();

    // 1. Screen entrance animation (650ms)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _heroFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
    );

    _heroScale = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic),
      ),
    );

    _headlineFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.20, 0.75, curve: Curves.easeOutCubic),
    );

    _headlineSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.20, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _supportFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOutCubic),
    );

    _bottomNavFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );

    _bottomNavSlide = Tween<double>(begin: 16.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Momentum meter interpolation: 0% -> 87% over 1850ms with easeOutCubic
    _momentumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1850),
    );

    _momentumCurve = CurvedAnimation(
      parent: _momentumController,
      curve: Curves.easeOutCubic,
    );

    _entranceController.forward();

    // Start the momentum growth slightly as the hero enters
    _startTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _momentumController.forward();
      }
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _entranceController.dispose();
    _momentumController.dispose();
    super.dispose();
  }

  void _onBackPressed() {
    AppHaptics.light();
    if (context.canPop()) {
      context.pop();
    }
  }

  bool _isNavigating = false;

  void _onContinuePressed() {
    if (_isNavigating) return;
    _isNavigating = true;
    AppHaptics.medium();
    context.push('/auth').then((_) {
      if (mounted) _isNavigating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: screenBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final usableHeight = constraints.maxHeight;
            final isCompact = usableHeight < 680;

            const horizontalMargin = 26.0;

            // Large, confident gauge: 82–86% of available screen width
            final gaugeRadius = (screenWidth * 0.415).clamp(146.0, 168.0);

            // Responsive headline display font size (48–54px)
            final headlineFontSize = (screenWidth * 0.124).clamp(46.0, 52.0);

            // EXACT Screen 1 Navigation vertical alignment:
            // Screen 1 CTA: size = 66.0, bottom = isCompact ? 56.0 : 110.0
            // Screen 1 center Y = (isCompact ? 56.0 : 110.0) + 33.0
            // Screen 2 Row: height = 62.0 -> bottom = center Y - 31.0 = (isCompact ? 58.0 : 112.0)
            const navRowHeight = 62.0;
            final navBottomOffset = isCompact ? 58.0 : 112.0;

            // Proportional vertical rhythm above navigation
            final topSpacing = isCompact ? 16.0 : 24.0;
            final gaugeToHeadlineGap = isCompact ? 28.0 : 36.0;
            final headlineToSupportGap = isCompact ? 12.0 : 16.0;
            final supportToJourneyGap = isCompact ? 28.0 : 40.0;

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // Subtle atmospheric wash: very pale #BCDBFA (8–12% opacity) behind the meter
                Positioned(
                  top: topSpacing - 12.0,
                  left: (screenWidth - gaugeRadius * 2.2) / 2.0,
                  child: Container(
                    width: gaugeRadius * 2.2,
                    height: gaugeRadius * 1.5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          softBlue.withValues(alpha: 0.11),
                          softBlue.withValues(alpha: 0.0),
                        ],
                        radius: 0.75,
                      ),
                    ),
                  ),
                ),

                // Main Content Flow: Meter -> Headline -> Support Copy -> Enormous Journey
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: horizontalMargin,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: topSpacing),

                        // 1. LARGE CONFIDENT MOMENTUM GAUGE
                        Center(
                          child: FadeTransition(
                            opacity: _heroFade,
                            child: ScaleTransition(
                              scale: _heroScale,
                              child: GufiMomentumMeter(
                                radius: gaugeRadius,
                                animationProgress: _momentumCurve,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: gaugeToHeadlineGap),

                        // 2. HEADLINE: TWO LINES ONLY IN GAMBARINO
                        FadeTransition(
                          opacity: _headlineFade,
                          child: AnimatedBuilder(
                            animation: _entranceController,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(0, _headlineSlide.value),
                              child: child,
                            ),
                            child: Text(
                              'Small steps.\nReal momentum.',
                              maxLines: 2,
                              softWrap: false,
                              style: TextStyle(
                                fontFamily: AppTypography.gambarinoFontFamily,
                                fontSize: headlineFontSize,
                                fontWeight: FontWeight.w400,
                                height: 0.98,
                                letterSpacing: -0.8,
                                color: deepContrast,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: headlineToSupportGap),

                        // 3. SUPPORTING TEXT: DELIBERATE TWO-LINE LAYOUT WITHOUT HYPHENATION
                        FadeTransition(
                          opacity: _supportFade,
                          child: Text(
                            'Turn daily intentions into\nconsistent follow-through.',
                            style: GoogleFonts.inter(
                              fontSize: isCompact ? 14.5 : 16.0,
                              fontWeight: FontWeight.w400,
                              height: 1.36,
                              letterSpacing: -0.15,
                              color: deepContrast.withValues(alpha: 0.65),
                            ),
                          ),
                        ),

                        SizedBox(height: supportToJourneyGap),

                        // 4. ENLARGED MOMENTUM PIPELINE TRACKER (Show up / Repeat / Grow)
                        FadeTransition(
                          opacity: _supportFade,
                          child: _MomentumPipelineTracker(
                            animationProgress: _momentumCurve,
                            screenWidth: screenWidth,
                          ),
                        ),

                        // Flexible breathing space above bottom navigation
                        const Spacer(),
                      ],
                    ),
                  ),
                ),

                // 5. LOCKED BOTTOM NAVIGATION ROW (Matching Screen 1 CTA vertical center)
                Positioned(
                  left: horizontalMargin,
                  right: horizontalMargin,
                  bottom: navBottomOffset,
                  child: AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _bottomNavFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _bottomNavSlide.value),
                          child: child,
                        ),
                      );
                    },
                    child: SizedBox(
                      height: navRowHeight,
                      child: Row(
                        children: [
                          // Left: Refined Back button matching new palette
                          Semantics(
                            label: 'Back',
                            button: true,
                            child: InkWell(
                              onTap: _onBackPressed,
                              borderRadius: BorderRadius.circular(20.0),
                              child: Container(
                                width: navRowHeight,
                                height: navRowHeight,
                                decoration: BoxDecoration(
                                  color: screenBg,
                                  borderRadius: BorderRadius.circular(20.0),
                                  border: Border.all(
                                    color: softBlue.withValues(alpha: 0.85),
                                    width: 1.6,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryBlue.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 23.0,
                                  color: primaryBlue,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 14.0),

                          // Right: Refined Continue button
                          Expanded(
                            child: _RefinedContinueButton(
                              onTap: _onContinuePressed,
                              height: navRowHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The Gufi Momentum Meter widget with refreshed Screen 2 palette.
class GufiMomentumMeter extends StatelessWidget {
  final double radius;
  final Animation<double> animationProgress;

  const GufiMomentumMeter({
    super.key,
    required this.radius,
    required this.animationProgress,
  });

  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color deepContrast = Color(0xFF1E3365);

  @override
  Widget build(BuildContext context) {
    final rOut = radius;
    final rIn = radius * 0.69;
    final gaugeWidth = rOut * 2 + 16.0;
    final gaugeHeight = rOut + 10.0;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animationProgress,
        builder: (context, _) {
          final t = animationProgress.value;
          final currentPercent = (t * 87.0).round().clamp(0, 87);

          return SizedBox(
            width: gaugeWidth,
            height: gaugeHeight,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                // 1. Semicircular Segmented Gauge
                CustomPaint(
                  size: Size(gaugeWidth, gaugeHeight),
                  painter: _MomentumGaugePainter(
                    progress: t,
                    rOut: rOut,
                    rIn: rIn,
                  ),
                ),

                // 2. Clean Center Content: ONLY 87% + Momentum
                Positioned(
                  top: (rOut - rIn) + (rIn * 0.28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$currentPercent%',
                        style: GoogleFonts.inter(
                          fontSize: (rOut * 0.34).clamp(50.0, 56.0),
                          fontWeight: FontWeight.w600,
                          color: deepContrast,
                          letterSpacing: -1.6,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6.0),
                      Text(
                        'Momentum',
                        style: GoogleFonts.inter(
                          fontSize: 15.0,
                          fontWeight: FontWeight.w400,
                          color: primaryBlue.withValues(alpha: 0.75),
                          letterSpacing: -0.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Custom painter for the 13 rounded radial segments with the refreshed Screen 2 palette:
/// #5880DA -> tinted #5880DA -> #BCDBFA -> #C9F17E on the final segment.
class _MomentumGaugePainter extends CustomPainter {
  final double progress; // 0.0 to 1.0 (0% -> 87%)
  final double rOut;
  final double rIn;

  _MomentumGaugePainter({
    required this.progress,
    required this.rOut,
    required this.rIn,
  });

  // Reusable Paint objects to eliminate thousands of per-frame allocations at 120Hz
  static final Paint _fillPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;
  static final Paint _shadowPaint = Paint()
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

  // Static cache for computed segment paths
  static final Map<String, List<Path>> _cachedPaths = {};

  // Refreshed Screen 2 palette progression across active segments
  static const List<Color> _activePalette = [
    Color(0xFF5880DA), // 0: Primary blue
    Color(0xFF5E85DC), // 1
    Color(0xFF658BDF), // 2
    Color(0xFF6E92E3), // 3
    Color(0xFF7B9EE7), // 4: Middle active
    Color(0xFF8BAAEB), // 5
    Color(0xFF9BB7EF), // 6: Apex
    Color(0xFFABC4F4), // 7
    Color(0xFFBCDBFA), // 8: Soft blue
    Color(0xFFC2E4DC), // 9: Tint toward Lime
    Color(0xFFC9F17E), // 10: Final highlighted segment in LIME!
  ];

  // Inactive segments: #BCDBFA at low opacity
  static const Color _unfilledColor = Color(0x38BCDBFA);

  static const int _totalSegments = 13;
  static const double _gapDegrees = 3.6;
  static const double _totalSpanDegrees = 180.0;
  static const double _segmentDegrees =
      (_totalSpanDegrees - (_totalSegments - 1) * _gapDegrees) / _totalSegments;

  List<Path> _getPaths(Offset center, double rIn, double rOut) {
    final key =
        '${center.dx.toStringAsFixed(1)}_${center.dy.toStringAsFixed(1)}_${rIn.toStringAsFixed(1)}_${rOut.toStringAsFixed(1)}';
    return _cachedPaths.putIfAbsent(key, () {
      const cornerRadius = 4.6;
      final paths = <Path>[];
      for (int i = 0; i < _totalSegments; i++) {
        final startDeg = 180.0 + i * (_segmentDegrees + _gapDegrees);
        final endDeg = startDeg + _segmentDegrees;
        final startAngle = startDeg * (math.pi / 180.0);
        final endAngle = endDeg * (math.pi / 180.0);
        paths.add(
          _buildRoundedSegmentPath(
            center: center,
            rIn: rIn,
            rOut: rOut,
            startAngle: startAngle,
            endAngle: endAngle,
            cornerRadius: cornerRadius,
          ),
        );
      }
      return paths;
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, rOut + 6.0);
    final segmentPaths = _getPaths(center, rIn, rOut);

    for (int i = 0; i < _totalSegments; i++) {
      final segmentPath = segmentPaths[i];
      Color segmentColor;
      double activeIntensity = 0.0;

      if (i < 11) {
        // Sequential illumination left to right
        final startWindow = (i / 11.0) * 0.76;
        final endWindow = (startWindow + 0.24).clamp(0.0, 1.0);

        final rawT = ((progress - startWindow) / (endWindow - startWindow))
            .clamp(0.0, 1.0);
        activeIntensity = Curves.easeOutCubic.transform(rawT);

        segmentColor =
            Color.lerp(_unfilledColor, _activePalette[i], activeIntensity) ??
            _unfilledColor;
      } else {
        segmentColor = _unfilledColor;
      }

      // Restrained soft ambient shadow on active segments
      if (activeIntensity > 0.08) {
        _shadowPaint.color = _activePalette[i].withValues(
          alpha: 0.16 * activeIntensity,
        );
        canvas.drawPath(segmentPath, _shadowPaint);
      }

      // Fill segment
      _fillPaint.color = segmentColor;
      canvas.drawPath(segmentPath, _fillPaint);
    }
  }

  Path _buildRoundedSegmentPath({
    required Offset center,
    required double rIn,
    required double rOut,
    required double startAngle,
    required double endAngle,
    required double cornerRadius,
  }) {
    final daOut = cornerRadius / rOut;
    final daIn = cornerRadius / rIn;

    final path = Path();

    final pRadInStart = Offset(
      center.dx + (rIn + cornerRadius) * math.cos(startAngle),
      center.dy + (rIn + cornerRadius) * math.sin(startAngle),
    );
    final pRadOutStart = Offset(
      center.dx + (rOut - cornerRadius) * math.cos(startAngle),
      center.dy + (rOut - cornerRadius) * math.sin(startAngle),
    );
    final cOutStart = Offset(
      center.dx + rOut * math.cos(startAngle),
      center.dy + rOut * math.sin(startAngle),
    );
    final pArcOutStart = Offset(
      center.dx + rOut * math.cos(startAngle + daOut),
      center.dy + rOut * math.sin(startAngle + daOut),
    );

    final cOutEnd = Offset(
      center.dx + rOut * math.cos(endAngle),
      center.dy + rOut * math.sin(endAngle),
    );
    final pRadOutEnd = Offset(
      center.dx + (rOut - cornerRadius) * math.cos(endAngle),
      center.dy + (rOut - cornerRadius) * math.sin(endAngle),
    );
    final pRadInEnd = Offset(
      center.dx + (rIn + cornerRadius) * math.cos(endAngle),
      center.dy + (rIn + cornerRadius) * math.sin(endAngle),
    );
    final cInEnd = Offset(
      center.dx + rIn * math.cos(endAngle),
      center.dy + rIn * math.sin(endAngle),
    );
    final cInStart = Offset(
      center.dx + rIn * math.cos(startAngle),
      center.dy + rIn * math.sin(startAngle),
    );

    path.moveTo(pRadInStart.dx, pRadInStart.dy);
    path.lineTo(pRadOutStart.dx, pRadOutStart.dy);
    path.quadraticBezierTo(
      cOutStart.dx,
      cOutStart.dy,
      pArcOutStart.dx,
      pArcOutStart.dy,
    );

    final outerRect = Rect.fromCircle(center: center, radius: rOut);
    path.arcTo(
      outerRect,
      startAngle + daOut,
      (endAngle - daOut) - (startAngle + daOut),
      false,
    );

    path.quadraticBezierTo(
      cOutEnd.dx,
      cOutEnd.dy,
      pRadOutEnd.dx,
      pRadOutEnd.dy,
    );
    path.lineTo(pRadInEnd.dx, pRadInEnd.dy);

    final pArcInEnd = Offset(
      center.dx + rIn * math.cos(endAngle - daIn),
      center.dy + rIn * math.sin(endAngle - daIn),
    );
    path.quadraticBezierTo(cInEnd.dx, cInEnd.dy, pArcInEnd.dx, pArcInEnd.dy);

    final innerRect = Rect.fromCircle(center: center, radius: rIn);
    path.arcTo(
      innerRect,
      endAngle - daIn,
      -((endAngle - daIn) - (startAngle + daIn)),
      false,
    );

    path.quadraticBezierTo(
      cInStart.dx,
      cInStart.dy,
      pRadInStart.dx,
      pRadInStart.dy,
    );

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _MomentumGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.rOut != rOut ||
        oldDelegate.rIn != rIn;
  }
}

/// Enormous, expressive habit momentum pipeline tracker:
/// Show up (✓) ──── Repeat (✓) ──── Grow (↑, LIME)
///
/// Nodes: 54–60px, labels: 17.5px, width: 84–88% of screen.
class _MomentumPipelineTracker extends StatelessWidget {
  final Animation<double> animationProgress;
  final double screenWidth;

  const _MomentumPipelineTracker({
    required this.animationProgress,
    required this.screenWidth,
  });

  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color repeatBlue = Color(0xFF6C91E5);
  static const Color limeAccent = Color(0xFFC9F17E);
  static const Color softBlue = Color(0xFFBCDBFA);
  static const Color deepText = Color(0xFF1E3365);
  static const Color inactiveNodeBg = Color(0x33BCDBFA);
  static const Color inactiveIcon = Color(0x805880DA);

  @override
  Widget build(BuildContext context) {
    final maxJourneyWidth = (screenWidth * 0.86).clamp(310.0, 360.0);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animationProgress,
        builder: (context, _) {
          final t = animationProgress.value;

          // Choreography:
          // 0–30%: SHOW UP node fills #5880DA
          final s1 = (t / 0.30).clamp(0.0, 1.0);
          // 30–60%: first connector animates
          final c1 = ((t - 0.30) / 0.30).clamp(0.0, 1.0);
          // 60–80%: REPEAT fills
          final s2 = ((t - 0.60) / 0.20).clamp(0.0, 1.0);
          // 80–87%: final connector grows toward GROW
          final c2 = ((t - 0.75) / 0.12).clamp(0.0, 1.0);
          // 87%: GROW fills in #C9F17E and scale-pulses
          final s3 = ((t - 0.82) / 0.15).clamp(0.0, 1.0);
          final growScale = (t >= 0.87)
              ? (1.0 +
                    0.06 *
                        math.sin(((t - 0.87) / 0.13).clamp(0.0, 1.0) * math.pi))
              : 1.0;

          return Center(
            child: SizedBox(
              width: maxJourneyWidth,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  // Connecting line between circle centers (Y = 28.0)
                  Positioned(
                    top: 27.0,
                    left: 32.0,
                    right: 32.0,
                    child: SizedBox(
                      height: 2.5,
                      child: Row(
                        children: [
                          // Segment 1 (Show up -> Repeat)
                          Expanded(
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1.5),
                                color: softBlue.withValues(alpha: 0.32),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: c1,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(1.5),
                                      gradient: LinearGradient(
                                        colors: [primaryBlue, repeatBlue],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Segment 2 (Repeat -> Grow)
                          Expanded(
                            child: Container(
                              height: 2.5,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(1.5),
                                color: softBlue.withValues(alpha: 0.32),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: c2,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(1.5),
                                      gradient: LinearGradient(
                                        colors: [repeatBlue, limeAccent],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3 Prominent Step Nodes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // 1. Show up (54px)
                      _buildStepNode(
                        icon: Icons.check_rounded,
                        label: 'Show up',
                        nodeSize: 54.0,
                        iconSize: 25.0,
                        activeBg: primaryBlue,
                        activeIconColor: Colors.white,
                        reveal: s1,
                      ),

                      // 2. Repeat (54px)
                      _buildStepNode(
                        icon: Icons.check_rounded,
                        label: 'Repeat',
                        nodeSize: 54.0,
                        iconSize: 25.0,
                        activeBg: repeatBlue,
                        activeIconColor: Colors.white,
                        reveal: s2,
                      ),

                      // 3. Grow (60px in LIME!)
                      Transform.scale(
                        scale: growScale,
                        child: _buildStepNode(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Grow',
                          nodeSize: 60.0,
                          iconSize: 27.0,
                          activeBg: limeAccent,
                          activeIconColor: deepText,
                          reveal: s3,
                          isLimeGlow: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStepNode({
    required IconData icon,
    required String label,
    required double nodeSize,
    required double iconSize,
    required Color activeBg,
    required Color activeIconColor,
    required double reveal,
    bool isLimeGlow = false,
  }) {
    final currentBg = Color.lerp(inactiveNodeBg, activeBg, reveal)!;
    final currentIconColor = Color.lerp(inactiveIcon, activeIconColor, reveal)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: nodeSize,
          height: nodeSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: currentBg,
            border: Border.all(
              color: Color.lerp(
                softBlue.withValues(alpha: 0.45),
                activeBg,
                reveal,
              )!,
              width: 1.5,
            ),
            boxShadow: [
              if (isLimeGlow && reveal > 0.4)
                BoxShadow(
                  color: limeAccent.withValues(alpha: 0.50 * reveal),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                )
              else if (reveal > 0.2)
                BoxShadow(
                  color: activeBg.withValues(alpha: 0.20 * reveal),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: currentIconColor),
        ),
        const SizedBox(height: 14.0),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 17.5,
            fontWeight: isLimeGlow ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: -0.2,
            color: deepText.withValues(alpha: 0.55 + 0.45 * reveal),
          ),
        ),
      ],
    );
  }
}

/// Refined Continue button with 26px rounded corners, 18px Inter typography,
/// subtle horizontal tonal gradient, 44x44 circular arrow interaction zone,
/// and smooth press micro-interaction (scale + arrow translate).
class _RefinedContinueButton extends StatefulWidget {
  final VoidCallback onTap;
  final double height;

  const _RefinedContinueButton({required this.onTap, required this.height});

  @override
  State<_RefinedContinueButton> createState() => _RefinedContinueButtonState();
}

class _RefinedContinueButtonState extends State<_RefinedContinueButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _arrowSlideAnimation;
  late final Animation<double> _limeGlowAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.985,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.985,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 55,
      ),
    ]).animate(_pressController);

    _arrowSlideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 4.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 4.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
    ]).animate(_pressController);

    _limeGlowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_pressController);
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTap() {
    AppHaptics.medium();
    _pressController.forward(from: 0.0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF5880DA);
    const primaryBlueDeep = Color(0xFF4F75CC);
    const screenBg = Color(0xFFF7F9F5);
    const limeAccent = Color(0xFFC9F17E);

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: Semantics(
        label: 'Continue',
        button: true,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(26.0),
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [primaryBlue, primaryBlueDeep],
              ),
              borderRadius: BorderRadius.circular(26.0),
              boxShadow: [
                BoxShadow(
                  color: primaryBlue.withValues(alpha: 0.28),
                  blurRadius: 22,
                  spreadRadius: -1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 28.0, right: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 18.0,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.2,
                      color: screenBg,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _pressController,
                    builder: (context, _) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // 44x44 subtle interaction zone with momentary lime press glow
                          Container(
                            width: 44.0,
                            height: 44.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFF7F9F5)
                                  .withValues(alpha: 0.08),
                              boxShadow: _limeGlowAnimation.value > 0.01
                                  ? [
                                      BoxShadow(
                                        color: limeAccent.withValues(
                                          alpha:
                                              0.35 * _limeGlowAnimation.value,
                                        ),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                          // Arrow with micro translateX(0 -> 4px) on press
                          Transform.translate(
                            offset: Offset(_arrowSlideAnimation.value, 0.0),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 24.0,
                              color: screenBg,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
