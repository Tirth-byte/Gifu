import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/account_action_button.dart';

/// Circle Entry Screen: The user's first social moment inside Gufi.
///
/// Prerequisite state for users with zero active Circle memberships.
/// Dreamy, warm, social, playful, premium, Gen Z, dimensional 3D aesthetic.
///
/// KEY ARCHITECTURAL PRINCIPLES:
/// - NO SCROLL: Zero SingleChildScrollView, ListView, or vertical physics.
///   Fits inside SafeArea and available viewport without dragging or bouncing.
/// - MATCH APPROVED TARGET REFERENCE:
///   - Top Bar: Gufi (Gambarino, navy) + "Better together." (handwritten, navy with blue underline)
///   - Headline: Large, editorial Gambarino headline:
///       "Everything feels\neasier with\nyour people." (navy + blue with curved underline)
///   - Hero: High-resolution dimensional 3D illustration with 4 companion spirits
///       (glossy blue, lime-green with sprout, lavender-blue, small white front character)
///       sitting on soft cloud hills with foliage, particles, and orbital arc.
///   - Handwritten Callouts: "Stay\naccountable", "Support\neach other", "Grow together"
///       with loose curved arrows cleanly framing the characters without overlapping faces.
///   - Action Cards: EXACT same outer height (98px), width, and corner radius (26px) for Create & Join.
///   - Create Card: Rich smooth blue surface, translucent circular plus control, chevron right.
///   - Join Card: Elevated soft white card, subtle shadow, QR icon left, circular arrow right.
///   - Privacy Card: Frosted pale-blue card, lock icon, understated appearance.
class CircleEntryPage extends StatefulWidget {
  const CircleEntryPage({super.key});

  @override
  State<CircleEntryPage> createState() => _CircleEntryPageState();
}

class _CircleEntryPageState extends State<CircleEntryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _headlineFade;
  late final Animation<Offset> _headlineSlide;
  late final Animation<double> _heroScale;
  late final Animation<double> _heroFade;
  late final Animation<double> _calloutsFade;

  static const Color canvasColor = Color(0xFFFFFFFF);
  static const Color gufiNavy = Color(0xFF1E3365);
  static const Color gufiBlue = Color(0xFF5880DA);
  static const Color mutedSlate = Color(0xFF5C6E8C);
  static const double actionCardHeight = 98.0;
  static const double actionCardRadius = 26.0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _headlineFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.0, 0.70, curve: Curves.easeOut),
    );
    _headlineSlide =
        Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animController,
            curve: const Interval(0.0, 0.70, curve: Curves.easeOutCubic),
          ),
        );

    _heroFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.10, 0.88, curve: Curves.easeOut),
    );
    _heroScale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.10, 0.88, curve: Curves.easeOutCubic),
      ),
    );

    _calloutsFade = CurvedAnimation(
      parent: _animController,
      curve: const Interval(0.30, 1.0, curve: Curves.easeOut),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  static TextStyle handwrittenStyle({
    double fontSize = 16,
    FontWeight fontWeight = FontWeight.w600,
    Color color = gufiNavy,
    double? height,
  }) {
    try {
      return GoogleFonts.caveat(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        fontStyle: FontStyle.italic,
        height: height,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;

    // Responsive sizing tuned so the continuous composition fits on any iPhone viewport without scrolling
    final isCompact = screenHeight < 750;
    final headlineSize = isCompact
        ? (screenWidth * 0.096).clamp(32.0, 36.0)
        : (screenWidth * 0.106).clamp(38.0, 42.0);
    final gufiWordmarkSize = isCompact ? 34.0 : 38.0;
    final topGap = isCompact ? 4.0 : 8.0;
    final gapAfterTopBar = isCompact ? 8.0 : 12.0;
    final gapAfterHeadline = isCompact ? 10.0 : 14.0;
    final gapAfterHero = isCompact ? 6.0 : 12.0;
    final gapBetweenCards = isCompact ? 8.0 : 10.0;
    final bottomPadding = isCompact ? 6.0 : 10.0;

    return Scaffold(
      backgroundColor: canvasColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: topGap),

              // Top Bar: Gufi brand mark (Gambarino, navy, top-left) and Account Button (top-right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Gufi',
                    style: TextStyle(
                      fontFamily: AppTypography.gambarinoFontFamily,
                      fontSize: gufiWordmarkSize,
                      fontWeight: FontWeight.w400,
                      color: gufiNavy,
                      letterSpacing: -0.8,
                      height: 1.0,
                    ),
                  ),
                  const AccountActionButton(),
                ],
              ),

              SizedBox(height: gapAfterTopBar),

              // Main Editorial Headline: Refined editorial statement without underline
              SlideTransition(
                position: _headlineSlide,
                child: FadeTransition(
                  opacity: _headlineFade,
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontFamily: AppTypography.gambarinoFontFamily,
                        fontSize: headlineSize,
                        height: 1.02,
                        letterSpacing: -0.8,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Everything feels\neasier with\n',
                          style: TextStyle(color: gufiNavy),
                        ),
                        TextSpan(
                          text: 'your people.',
                          style: TextStyle(color: gufiBlue),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: gapAfterHeadline),

              // Hero Social World: High-resolution dimensional 3D centerpiece that bridges headline to action cards
              Expanded(
                child: Center(
                  child: FadeTransition(
                    opacity: _heroFade,
                    child: ScaleTransition(
                      scale: _heroScale,
                      child: _HeroSocialWorld(
                        calloutsOpacity: _calloutsFade,
                        isCompact: isCompact,
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: gapAfterHero),

              // Primary Action: Rich, smooth blue Create Circle card
              _InteractiveActionCard(
                height: actionCardHeight,
                borderRadius: actionCardRadius,
                title: 'Create a Circle',
                subtitle: 'Start something with your people.',
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF5880DA), Color(0xFF476FC9)],
                ),
                titleColor: Colors.white,
                subtitleColor: Colors.white.withValues(alpha: 0.90),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF5880DA).withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
                rightControl: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.add,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: 15,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ],
                ),
                onTap: () {
                  context.push('/circle-create');
                },
              ),

              SizedBox(height: gapBetweenCards),

              // Secondary Action: Elevated soft white Join card (exact matching outer height, width, radius)
              _InteractiveActionCard(
                height: actionCardHeight,
                borderRadius: actionCardRadius,
                title: 'Join a Circle',
                subtitle: 'Already invited? Come in.',
                backgroundColor: Colors.white,
                titleColor: gufiNavy,
                subtitleColor: mutedSlate,
                borderColor: const Color(0xFFE2EAF4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3365).withValues(alpha: 0.06),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
                leadingIcon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: const Color(0xFFEFF5FC),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.qrcode,
                      size: 21,
                      color: gufiBlue,
                    ),
                  ),
                ),
                rightControl: Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEFF5FC),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.arrow_right,
                      size: 18,
                      color: gufiBlue,
                    ),
                  ),
                ),
                onTap: () {
                  context.push('/circle-join');
                },
              ),

              SizedBox(height: gapBetweenCards),

              // Privacy Card: Frosted pale-blue card softly integrated with background
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF5FD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFFDFECFB),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFDFEDFD),
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.lock_fill,
                          size: 13,
                          color: gufiBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Circles are private spaces for you\nand people you trust.',
                        style: AppTypography.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: gufiNavy,
                          height: 1.25,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: bottomPadding),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero Social World composition:
/// - Centered high-resolution 3D character illustration:
///     One large glossy blue character in center, lime-green on left,
///     lavender-blue on right, small white companion in front,
///     cloud hills, leaves, particles, and orbital arc.
/// - Three handwritten annotations with loose curved arrows positioned around them.
class _HeroSocialWorld extends StatelessWidget {
  final Animation<double> calloutsOpacity;
  final bool isCompact;

  const _HeroSocialWorld({
    required this.calloutsOpacity,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final targetHeight = isCompact
            ? availableHeight.clamp(190.0, 230.0)
            : availableHeight.clamp(215.0, 260.0);
        final targetWidth = constraints.maxWidth;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: targetWidth,
            height: targetHeight,
            child: Stack(
              children: [
                // 1. High-resolution 3D character asset filling the entire hero card
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/gufi_circle_hero_3d.jpg',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.high,
                  ),
                ),

                // 2. Handwritten Callout Arrows Painter (curved arrows pointing to group)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HeroCalloutArrowsPainter(
                      isCompact: isCompact,
                      scaleRatio: targetHeight / 240.0,
                    ),
                  ),
                ),

                // 3. Handwritten Annotation 1: Upper-left "Stay\naccountable" (safe internal padding)
                Positioned(
                  left: 20,
                  top: 18,
                  child: FadeTransition(
                    opacity: calloutsOpacity,
                    child: Text(
                      'Stay\naccountable',
                      style: _CircleEntryPageState.handwrittenStyle(
                        fontSize: isCompact ? 14.5 : 15.5,
                        fontWeight: FontWeight.w700,
                        color: _CircleEntryPageState.gufiNavy,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),

                // 4. Handwritten Annotation 2: Upper-right "Support\neach other" (safe internal padding)
                Positioned(
                  right: 20,
                  top: 18,
                  child: FadeTransition(
                    opacity: calloutsOpacity,
                    child: Text(
                      'Support\neach other',
                      textAlign: TextAlign.right,
                      style: _CircleEntryPageState.handwrittenStyle(
                        fontSize: isCompact ? 14.5 : 15.5,
                        fontWeight: FontWeight.w700,
                        color: _CircleEntryPageState.gufiNavy,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),

                // 5. Handwritten Annotation 3: Bottom-right "Grow together" (safe internal padding)
                Positioned(
                  right: 20,
                  bottom: 18,
                  child: FadeTransition(
                    opacity: calloutsOpacity,
                    child: Text(
                      'Grow together',
                      style: _CircleEntryPageState.handwrittenStyle(
                        fontSize: isCompact ? 14.5 : 15.5,
                        fontWeight: FontWeight.w700,
                        color: _CircleEntryPageState.gufiNavy,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Static CustomPainter for the loose, hand-drawn callout arrows pointing toward the characters.
class _HeroCalloutArrowsPainter extends CustomPainter {
  final bool isCompact;
  final double scaleRatio;

  const _HeroCalloutArrowsPainter({
    required this.isCompact,
    required this.scaleRatio,
  });

  static const Color gufiNavy = Color(0xFF1E3365);

  @override
  void paint(Canvas canvas, Size size) {
    final arrowPaint = Paint()
      ..color = gufiNavy.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeCap = StrokeCap.round;

    final sx = size.width / 340.0;
    final sy = size.height / 240.0;

    canvas.save();
    canvas.scale(sx, sy);

    // Arrow 1: Upper-left (from "Stay accountable" curving inward toward lime character)
    final arrow1 = Path()
      ..moveTo(76, 52)
      ..cubicTo(88, 72, 102, 94, 114, 112);
    canvas.drawPath(arrow1, arrowPaint);
    _drawArrowhead(canvas, const Offset(114, 112), 0.58, arrowPaint);

    // Arrow 2: Upper-right (from "Support each other" curving inward toward soft-blue character)
    final arrow2 = Path()
      ..moveTo(254, 52)
      ..cubicTo(246, 72, 238, 92, 230, 108);
    canvas.drawPath(arrow2, arrowPaint);
    _drawArrowhead(canvas, const Offset(230, 108), 2.05, arrowPaint);

    // Arrow 3: Bottom-right (from "Grow together" curving toward group / cloud area)
    final arrow3 = Path()
      ..moveTo(222, 214)
      ..cubicTo(204, 212, 184, 206, 168, 196);
    canvas.drawPath(arrow3, arrowPaint);
    _drawArrowhead(canvas, const Offset(168, 196), 3.65, arrowPaint);

    canvas.restore();
  }

  void _drawArrowhead(Canvas canvas, Offset tip, double angle, Paint paint) {
    const length = 7.0;
    final p1 = Offset(
      tip.dx - length * math.cos(angle - 0.45),
      tip.dy - length * math.sin(angle - 0.45),
    );
    final p2 = Offset(
      tip.dx - length * math.cos(angle + 0.45),
      tip.dy - length * math.sin(angle + 0.45),
    );

    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(tip.dx, tip.dy)
      ..lineTo(p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Action card with fast light scale response (1.0 → 0.98) on tap.
/// Guaranteed identical outer height, width, and corner radius for both Create & Join.
class _InteractiveActionCard extends StatefulWidget {
  final double height;
  final double borderRadius;
  final String title;
  final String subtitle;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Color titleColor;
  final Color subtitleColor;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;
  final Widget? leadingIcon;
  final Widget? rightControl;
  final VoidCallback onTap;

  const _InteractiveActionCard({
    required this.height,
    required this.borderRadius,
    required this.title,
    required this.subtitle,
    this.backgroundColor,
    this.gradient,
    required this.titleColor,
    required this.subtitleColor,
    this.borderColor,
    this.boxShadow,
    this.leadingIcon,
    this.rightControl,
    required this.onTap,
  });

  @override
  State<_InteractiveActionCard> createState() => _InteractiveActionCardState();
}

class _InteractiveActionCardState extends State<_InteractiveActionCard> {
  bool _isPressed = false;

  void _handleTap() async {
    AppHaptics.selection();
    setState(() => _isPressed = true);
    await Future.delayed(const Duration(milliseconds: 90));
    if (mounted) {
      setState(() => _isPressed = false);
      widget.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeInOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          splashColor: widget.titleColor.withValues(alpha: 0.08),
          highlightColor: Colors.transparent,
          child: Ink(
            height: widget.height,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              gradient: widget.gradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: widget.borderColor != null
                  ? Border.all(color: widget.borderColor!, width: 1.0)
                  : null,
              boxShadow:
                  widget.boxShadow ??
                  [
                    BoxShadow(
                      color: const Color(0xFF1E3365).withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.leadingIcon != null) ...[
                  widget.leadingIcon!,
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        style: AppTypography.inter(
                          fontSize: 18.5,
                          fontWeight: FontWeight.w700,
                          color: widget.titleColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        style: AppTypography.inter(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w400,
                          color: widget.subtitleColor,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.rightControl != null) ...[
                  const SizedBox(width: 12),
                  widget.rightControl!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
