import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/presentation/providers/auth_providers.dart';

const Color _bg = Color(0xFFF7F9F5);
const Color _navy = Color(0xFF1E3365);
const Color _muted = Color(0xFF77839A);
const Color _lime = Color(0xFFC9F17E);
const Color _skeletonBase = Color(0xFFDDE3EC);
const double _kPad = 30.0;

// ---------------------------------------------------------------------------
// State model
// ---------------------------------------------------------------------------

enum _ScreenState {
  loading, // Profile fetch in flight — show skeleton
  complete, // Username resolved — show identity hero
  incomplete, // Auth'd but no username — re-route to setup
  error, // Backend fetch failed — show retry
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

/// "This Is Yours" — Coming Soon / Holding Screen.
///
/// Explicitly handles all four states:
///   loading   → animated skeleton (no blank screen ever)
///   complete  → @username hero with optional reveal animation
///   incomplete → redirect back to username setup
///   error     → inline retry with "Couldn't load your account."
class ComingSoonPage extends ConsumerStatefulWidget {
  const ComingSoonPage({super.key});

  @override
  ConsumerState<ComingSoonPage> createState() => _ComingSoonPageState();
}

class _ComingSoonPageState extends ConsumerState<ComingSoonPage>
    with TickerProviderStateMixin {
  // Skeleton pulse
  late final AnimationController _skeletonCtrl;
  late final Animation<double> _skeletonOpacity;

  // Reveal (first-signup only)
  bool _revealDone = false;
  bool _showDot = false;
  bool _playReveal = false;
  bool _revealResolved = false; // have we looked up SharedPrefs yet?
  int _revealedCount = 0;

  // Dot scale-in
  late final AnimationController _dotCtrl;
  late final Animation<double> _dotScale;

  bool _loggingOut = false;
  bool _retrying = false;

  @override
  void initState() {
    super.initState();

    _skeletonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _skeletonOpacity = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _skeletonCtrl, curve: Curves.easeInOut));

    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _dotScale = CurvedAnimation(parent: _dotCtrl, curve: Curves.easeOutBack);
  }

  @override
  void dispose() {
    _skeletonCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Reveal logic
  // -------------------------------------------------------------------------

  Future<void> _resolveReveal(String username) async {
    if (_revealResolved) return;
    _revealResolved = true;

    final prefs = await SharedPreferences.getInstance();
    final key = 'reveal_shown_$username';
    final alreadyShown = prefs.getBool(key) ?? false;

    if (!mounted) return;

    if (alreadyShown) {
      setState(() {
        _revealDone = true;
        _showDot = true;
        _playReveal = false;
        _skeletonCtrl.stop();
      });
    } else {
      await prefs.setBool(key, true);
      if (!mounted) return;
      setState(() {
        _playReveal = true;
        _skeletonCtrl.stop();
      });
      await _startReveal(username);
    }
  }

  Future<void> _startReveal(String username) async {
    final full = '@$username';
    final totalChars = full.length;
    if (totalChars == 0) {
      _finishReveal();
      return;
    }

    const totalMs = 480;
    for (int i = 1; i <= totalChars; i++) {
      if (!mounted) return;
      setState(() => _revealedCount = i);
      final progress = i / totalChars;
      final delay = (totalMs * (1.0 - progress * 0.6) / totalChars)
          .round()
          .clamp(10, 80);
      await Future<void>.delayed(Duration(milliseconds: delay));
    }

    if (!mounted) return;
    _finishReveal();
  }

  void _finishReveal() {
    setState(() => _revealDone = true);
    AppHaptics.light();
    Future<void>.delayed(const Duration(milliseconds: 60), () {
      if (!mounted) return;
      setState(() => _showDot = true);
      _dotCtrl.forward();
    });
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  Future<void> _handleRetry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    // Invalidate the async provider to force a re-fetch.
    ref.invalidate(currentUserProfileAsyncProvider);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (mounted) setState(() => _retrying = false);
  }

  Future<void> _handleLogout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    AppHaptics.light();
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) context.go('/auth');
    } catch (_) {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  double _computeFontSize(String username) {
    final charCount = '@$username'.length;
    if (charCount <= 7) return 78.0;
    if (charCount <= 11) return 64.0;
    if (charCount <= 15) return 52.0;
    return 42.0;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final asyncProfile = ref.watch(currentUserProfileAsyncProvider);

    // Determine state
    _ScreenState screenState;
    String username = '';

    if (asyncProfile.isLoading) {
      screenState = _ScreenState.loading;
    } else if (asyncProfile.hasError) {
      screenState = _ScreenState.error;
    } else {
      final profile = asyncProfile.value;
      if (profile == null) {
        // No profile returned and no exception:
        // - Supabase not configured + no cached session (app restart in preview).
        // - OR: authenticated but profile record genuinely missing.
        // Either way, route back to auth so user can re-authenticate / complete setup.
        // Do NOT show "Couldn't load your account" — that is for real backend errors.
        screenState = _ScreenState.incomplete; // uses the redirect path
      } else {
        // Resolve username
        final raw = profile.username.trim();
        username = raw.isNotEmpty ? raw.replaceFirst('@', '') : '';
        if (username.isEmpty) {
          // Email-part fallback only if username field is completely empty
          username = profile.email.split('@').first;
        }

        // If onboarding not completed and no username, redirect to setup.
        if (!profile.onboardingCompleted && profile.username.trim().isEmpty) {
          screenState = _ScreenState.incomplete;
        } else {
          screenState = _ScreenState.complete;
        }
      }
    }

    if (screenState == _ScreenState.loading) {
      if (!_skeletonCtrl.isAnimating) {
        _skeletonCtrl.repeat(reverse: true);
      }
    } else {
      if (_skeletonCtrl.isAnimating) {
        _skeletonCtrl.stop();
      }
    }

    // Trigger reveal lookup once profile is available
    if (screenState == _ScreenState.complete &&
        username.isNotEmpty &&
        !_revealResolved) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveReveal(username);
      });
    }

    // Handle incomplete redirect (post-frame to avoid routing during build)
    if (screenState == _ScreenState.incomplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/auth');
      });
    }

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final h = constraints.maxHeight;

            return Stack(
              children: [
                // TOP-LEFT: Brand signature — always visible
                const Positioned(top: 18, left: _kPad, child: _GufiSignature()),

                // HERO ZONE — state-dependent
                Positioned(
                  left: _kPad,
                  right: _kPad,
                  top: h * 0.32,
                  child: _buildHero(screenState, username),
                ),

                // BOTTOM-LEFT: Log out — always visible
                Positioned(
                  left: _kPad,
                  right: _kPad,
                  bottom: 24,
                  child: _buildLogout(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHero(_ScreenState state, String username) {
    switch (state) {
      case _ScreenState.loading:
        return _buildLoadingSkeleton();
      case _ScreenState.complete:
        return _buildIdentityHero(username);
      case _ScreenState.incomplete:
        // Redirect happening — show skeleton while it resolves
        return _buildLoadingSkeleton();
      case _ScreenState.error:
        return _buildErrorState();
    }
  }

  // -------------------------------------------------------------------------
  // State: Loading
  // -------------------------------------------------------------------------

  Widget _buildLoadingSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Username placeholder bar
        FadeTransition(
          opacity: _skeletonOpacity,
          child: Container(
            width: 220,
            height: 62,
            decoration: BoxDecoration(
              color: _skeletonBase,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 22),
        // "This is yours." placeholder
        FadeTransition(
          opacity: _skeletonOpacity,
          child: Container(
            width: 130,
            height: 16,
            decoration: BoxDecoration(
              color: _skeletonBase,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Subtitle placeholder
        FadeTransition(
          opacity: _skeletonOpacity,
          child: Container(
            width: 200,
            height: 14,
            decoration: BoxDecoration(
              color: _skeletonBase.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // State: Complete
  // -------------------------------------------------------------------------

  Widget _buildIdentityHero(String username) {
    // Determine what text to show in the hero
    final String heroText;
    if (_playReveal && !_revealDone) {
      final full = '@$username';
      heroText = full.substring(0, _revealedCount.clamp(0, full.length));
    } else {
      heroText = '@$username';
    }

    // Message visible once reveal completes (or immediately for returning users)
    final msgVisible = _revealDone || (!_playReveal && _revealResolved);
    final fontSize = _computeFontSize(username);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Username + lime dot row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                heroText,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: AppTypography.inter(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                  letterSpacing: -1.2,
                  height: 1.0,
                ),
              ),
            ),
            if (_showDot) ...[
              const SizedBox(width: 10),
              ScaleTransition(
                scale: _dotScale,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: _lime,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ],
        ),

        // Message block — fades in once reveal is done
        AnimatedOpacity(
          opacity: msgVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 280),
          child: AnimatedSlide(
            offset: msgVisible ? Offset.zero : const Offset(0, 0.04),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'This is yours.',
                    style: AppTypography.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _navy,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "We're getting the rest ready.",
                    style: AppTypography.inter(
                      fontSize: 15.5,
                      color: _muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // State: Error
  // -------------------------------------------------------------------------

  Widget _buildErrorState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Couldn\'t load your account.',
          style: AppTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: _navy,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _retrying ? null : _handleRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _retrying
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Retry',
                    style: AppTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Log out
  // -------------------------------------------------------------------------

  Widget _buildLogout() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _loggingOut ? null : _handleLogout,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        alignment: Alignment.centerLeft,
        child: _loggingOut
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_navy),
                ),
              )
            : Text(
                'Log out',
                style: AppTypography.inter(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: _muted,
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _GufiSignature extends StatelessWidget {
  const _GufiSignature();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Gufi',
      style: TextStyle(
        fontFamily: AppTypography.gambarinoFontFamily,
        fontSize: 28,
        color: _navy,
        letterSpacing: -0.3,
      ),
    );
  }
}
