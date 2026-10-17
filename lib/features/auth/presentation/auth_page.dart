import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../core/haptics/app_haptics.dart';
import '../../../core/services/app_preferences_service.dart';
import '../../../core/services/disposable_email_service.dart';
import '../../../core/theme/app_typography.dart';
import '../domain/models/user_profile.dart';
import '../domain/repositories/auth_repository.dart';
import '../data/repositories/supabase_auth_repository.dart';
import '../../circles/data/repositories/supabase_circle_repository.dart';
import '../../circles/domain/models/circle.dart';
import 'screens/email_verification_screen.dart';

const bg = Color(0xFFFFFFFF);
const navy = Color(0xFF1E3365);
const blue = Color(0xFF5880DA);
const muted = Color(0xFF77839A);
const border = Color(0xFFBCDBFA);
const success = Color(0xFF3D7A62);
const errorRed = Color(0xFFB54848);

enum AuthProvider { apple, google }

abstract class AuthGateway {
  UserProfile? get currentUserProfile;
  Stream<UserProfile?> get authStateChanges;
  Future<bool> emailExists(String email);
  Future<bool> usernameAvailable(String username);
  Future<bool> continueWithProvider(AuthProvider provider);
  Future<void> signUp(String email, String password);
  Future<void> resendVerification(String email);
  Future<bool> checkEmailVerified();
  Future<VerificationCheckResult> checkEmailVerificationStatus();
  Future<UserProfile> createAccount(
    String email,
    String password,
    String username,
    String? photoPath,
  );
  Future<UserProfile?> logIn(String email, String password);
  Future<void> sendPasswordReset(String email);
  Future<UserProfile?> restoreSession();
}

/// Production implementation connecting to Supabase Auth Repository.
class RepositoryAuthGateway implements AuthGateway {
  final AuthRepository repository;
  const RepositoryAuthGateway(this.repository);

  @override
  UserProfile? get currentUserProfile => repository.currentUserProfile;

  @override
  Stream<UserProfile?> get authStateChanges => repository.authStateChanges;

  @override
  Future<bool> emailExists(String email) => repository.emailExists(email);

  @override
  Future<bool> usernameAvailable(String username) =>
      repository.isUsernameAvailable(username);

  @override
  Future<bool> continueWithProvider(AuthProvider provider) async {
    final profile = provider == AuthProvider.apple
        ? await repository.signInWithApple()
        : await repository.signInWithGoogle();
    return !profile.onboardingCompleted;
  }

  @override
  Future<void> signUp(String email, String password) =>
      repository.signUpWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> resendVerification(String email) =>
      repository.resendEmailVerification(email);

  @override
  Future<bool> checkEmailVerified() => repository.checkEmailVerified();

  @override
  Future<VerificationCheckResult> checkEmailVerificationStatus() =>
      repository.checkEmailVerificationStatus();

  @override
  Future<UserProfile> createAccount(
    String email,
    String password,
    String username,
    String? photoPath,
  ) => repository.completeUserProfile(
    username: username,
    photoFilePath: photoPath,
  );

  @override
  Future<UserProfile?> logIn(String email, String password) =>
      repository.logIn(email: email, password: password);

  @override
  Future<void> sendPasswordReset(String email) =>
      repository.sendPasswordReset(email);

  @override
  Future<UserProfile?> restoreSession() => repository.restoreSession();
}

class _AuthNavigatorObserver extends NavigatorObserver {
  final VoidCallback onStateChanged;
  _AuthNavigatorObserver(this.onStateChanged);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onStateChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onStateChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onStateChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    onStateChanged();
  }
}

class AuthPage extends StatefulWidget {
  final AuthGateway? gateway;
  final VoidCallback? onAuthenticated;
  final VoidCallback? onBack;
  const AuthPage({super.key, this.gateway, this.onAuthenticated, this.onBack});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final nav = GlobalKey<NavigatorState>();
  final draft = AuthDraft();
  final _navCanPop = ValueNotifier<bool>(false);
  StreamSubscription<UserProfile?>? _authSub;
  // Use the singleton repository so profile state set here (on login/signup)
  // is visible to the same instance watched by ComingSoonPage and the router.
  late final AuthGateway _gateway =
      widget.gateway ?? RepositoryAuthGateway(SupabaseAuthRepository.instance);
  late final _observer = _AuthNavigatorObserver(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final canPop = nav.currentState?.canPop() ?? false;
        if (_navCanPop.value != canPop) {
          _navCanPop.value = canPop;
        }
      }
    });
  });

  @override
  void dispose() {
    _authSub?.cancel();
    _navCanPop.dispose();
    draft.dispose();
    super.dispose();
  }

  bool _canContextPop() {
    bool goRouterCan = false;
    bool navCan = false;
    try {
      goRouterCan = context.canPop();
    } catch (_) {}
    try {
      navCan = Navigator.of(context).canPop();
    } catch (_) {}
    return goRouterCan || navCan;
  }

  void _backToOnboarding() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    // Pop via GoRouter — this correctly unwinds the pushed stack:
    //   / (Onboarding1) → /screen-2 (Onboarding2) → /auth (AuthPage)
    // Popping /auth returns to /screen-2, popping /screen-2 returns to /.
    // Never use context.go() here — it destroys the navigation history.
    try {
      if (context.canPop()) {
        context.pop();
        return;
      }
    } catch (_) {}
    // Last resort: if GoRouter stack is somehow at root (no pushes above),
    // go to onboarding root. This should not normally occur.
    try {
      context.go('/');
    } catch (_) {}
  }

  void _handleBack() {
    if (nav.currentState?.canPop() ?? false) {
      nav.currentState!.pop();
    } else {
      _backToOnboarding();
    }
  }

  void push(Widget child) {
    AppHaptics.selection();
    nav.currentState?.push<void>(_Route(child));
  }

  @override
  void initState() {
    super.initState();
    _authSub = _gateway.authStateChanges.listen((authProfile) {
      if (!mounted) return;
      if (authProfile != null) {
        if (!authProfile.onboardingCompleted) {
          if (authProfile.username.isEmpty) {
            push(username());
          } else {
            push(profile());
          }
        } else {
          done(authProfile);
        }
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
    });
  }

  Future<void> _checkSession() async {
    final restoredProfile = await _gateway.restoreSession();
    if (restoredProfile != null && mounted) {
      if (restoredProfile.onboardingCompleted) {
        done(restoredProfile);
      } else if (restoredProfile.username.isEmpty) {
        push(username());
      } else {
        push(profile());
      }
    }
  }

  Future<void> done([UserProfile? userProfile]) async {
    widget.onAuthenticated?.call();
    if (widget.onAuthenticated == null) {
      try {
        final resolvedProfile =
            userProfile ??
            _gateway.currentUserProfile ??
            await _gateway.restoreSession();
        if (resolvedProfile?.isAdmin == true) {
          if (mounted) context.go('/admin');
          return;
        }

        // Check for pending invite from deep link first
        final pendingInvite = AppPreferencesService.instance
            .getPendingInviteCode();
        if (pendingInvite != null && pendingInvite.isNotEmpty) {
          await AppPreferencesService.instance.clearPendingInviteCode();
          if (mounted) {
            context.go('/circle-join?code=$pendingInvite');
            return;
          }
        }

        if (resolvedProfile != null) {
          if (!resolvedProfile.onboardingCompleted) {
            if (resolvedProfile.username.isEmpty) {
              push(username());
            } else {
              push(profile());
            }
            return;
          }

          final circles = await SupabaseCircleRepository.instance
              .getUserCircles(resolvedProfile.id);
          if (mounted) {
            if (circles.isEmpty) {
              context.go('/circle-entry');
            } else {
              Circle? pendingCircle;
              bool hasReady = false;
              for (final c in circles) {
                final members = await SupabaseCircleRepository.instance
                    .getCircleMembers(c.id);
                if (!mounted) return;
                if (members.where((m) => m.isActive).length >= 2) {
                  hasReady = true;
                  break;
                }
                pendingCircle ??= c;
              }

              if (hasReady) {
                context.go('/today');
              } else if (pendingCircle != null) {
                context.go('/circle-invite/${pendingCircle.id}');
              } else {
                context.go('/circle-entry');
              }
            }
          }
        } else {
          if (mounted) context.go('/circle-entry');
        }
      } catch (_) {
        if (mounted) {
          message(context, 'Authentication flow complete.');
        }
      }
    }
  }

  Widget emailVerification() => EmailVerificationScreen(
    email: draft.email.text.trim(),
    onResend: () => _gateway.resendVerification(draft.email.text.trim()),
    onCheckVerification: () => _gateway.checkEmailVerificationStatus(),
    onSessionConfirmed: (sessionProfile) async {
      final resolvedProfile = sessionProfile ?? await _gateway.restoreSession();
      if (resolvedProfile == null || !resolvedProfile.onboardingCompleted) {
        if (resolvedProfile == null || resolvedProfile.username.isEmpty) {
          push(username());
        } else {
          push(profile());
        }
      } else {
        done(resolvedProfile);
      }
    },
    onNeedsSignIn: () => push(loginPassword()),
    onChangeEmail: () => nav.currentState?.pop(),
  );

  Widget profile() => ProfileScreen(
    draft: draft,
    gateway: _gateway,
    onDone: (UserProfile? updatedProfile) async {
      final restored = updatedProfile ?? await _gateway.restoreSession();
      done(restored);
    },
  );
  Widget username() => UsernameScreen(
    draft: draft,
    gateway: _gateway,
    onNext: () => push(profile()),
  );
  Widget loginPassword() => LoginPasswordScreen(
    draft: draft,
    gateway: _gateway,
    onDone: (userProfile) {
      if (userProfile != null && !userProfile.onboardingCompleted) {
        if (userProfile.username.isEmpty) {
          push(username());
        } else {
          push(profile());
        }
      } else {
        done(userProfile);
      }
    },
    onForgot: () => push(ResetScreen(draft: draft, gateway: _gateway)),
  );
  Widget confirm() => ConfirmScreen(
    draft: draft,
    gateway: _gateway,
    onNext: () async {
      final result = await _gateway.checkEmailVerificationStatus();
      if (result.status == VerificationCheckStatus.confirmedWithSession) {
        if (result.profile == null || !result.profile!.onboardingCompleted) {
          push(username());
        } else {
          done(result.profile);
        }
      } else {
        push(emailVerification());
      }
    },
  );
  Widget password() =>
      PasswordScreen(draft: draft, onNext: () => push(confirm()));

  @override
  Widget build(BuildContext context) {
    final canDirectPop = _canContextPop();
    return ValueListenableBuilder<bool>(
      valueListenable: _navCanPop,
      builder: (context, canPop, staticBody) {
        return PopScope(
          canPop: !canPop && canDirectPop,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBack();
          },
          child: staticBody!,
        );
      },
      child: Scaffold(
        backgroundColor: bg,
        resizeToAvoidBottomInset: false,
        body: Navigator(
          key: nav,
          observers: [_observer],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => WelcomeScreen(
              onBack: _handleBack,
              onCreate: () => push(
                SignupEmailScreen(
                  draft: draft,
                  gateway: _gateway,
                  onNext: () => push(password()),
                  onLogin: () => push(loginPassword()),
                ),
              ),
              onLogin: () => push(
                LoginEmailScreen(
                  draft: draft,
                  onNext: () => push(loginPassword()),
                ),
              ),
              onProvider: (provider) async {
                final needsProfile = await _gateway.continueWithProvider(
                  provider,
                );
                if (!mounted) return;
                if (needsProfile) {
                  push(username());
                } else {
                  final restored = await _gateway.restoreSession();
                  done(restored);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class AuthDraft {
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  final username = TextEditingController();
  XFile? photo;
  void dispose() {
    email.dispose();
    password.dispose();
    confirmation.dispose();
    username.dispose();
  }
}

class _Route extends PageRouteBuilder<void> {
  _Route(Widget child)
    : super(
        transitionDuration: const Duration(milliseconds: 170),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => child,
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          child: SlideTransition(
            position: Tween(begin: const Offset(0.02, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                    reverseCurve: Curves.easeInCubic,
                  ),
                ),
            child: child,
          ),
        ),
      );
}

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onCreate;
  final VoidCallback onLogin;
  final Future<void> Function(AuthProvider) onProvider;
  final VoidCallback onBack;
  const WelcomeScreen({
    super.key,
    required this.onCreate,
    required this.onLogin,
    required this.onProvider,
    required this.onBack,
  });
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  AuthProvider? loading;
  late final AnimationController _entranceController;
  late final Animation<double> _symbolOpacity;
  late final Animation<double> _symbolTranslate;
  late final Animation<double> _textOpacity;
  late final Animation<double> _textTranslate;
  late final Animation<double> _actionOpacity;
  late final Animation<double> _actionTranslate;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    const ease = Curves.easeOutCubic;

    _symbolOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
    );
    _symbolTranslate = Tween<double>(begin: 6.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.75, curve: ease),
      ),
    );

    _textOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.12, 0.88, curve: Curves.easeOut),
    );
    _textTranslate = Tween<double>(begin: 6.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.12, 0.88, curve: ease),
      ),
    );

    _actionOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.24, 1.0, curve: Curves.easeOut),
    );
    _actionTranslate = Tween<double>(begin: 4.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.24, 1.0, curve: ease),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    if (!_entranceController.isCompleted) {
      _entranceController.value = 1.0;
    }
    widget.onCreate();
  }

  void _handleLogin() {
    if (!_entranceController.isCompleted) {
      _entranceController.value = 1.0;
    }
    widget.onLogin();
  }

  Future<void> provider(AuthProvider value) async {
    if (loading != null) return;
    setState(() => loading = value);
    try {
      await widget.onProvider(value);
    } catch (_) {
      if (mounted) message(context, 'Authentication failed. Try again.');
    } finally {
      if (mounted) setState(() => loading = null);
    }
  }

  Widget _wrapAnimated({
    required Animation<double> opacity,
    required Animation<double> translate,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, staticChild) {
        if (_entranceController.isCompleted) {
          return staticChild!;
        }
        return Transform.translate(
          offset: Offset(0, translate.value),
          child: Opacity(
            opacity: opacity.value.clamp(0.0, 1.0),
            child: staticChild,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) => MediaQuery.removeViewInsets(
    removeBottom: true,
    context: context,
    child: Canvas(
      resizeToAvoidBottomInset: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(
            builder: (_, box) {
              final screenH = MediaQuery.sizeOf(context).height;
              final compact = screenH < 750;
              final veryCompact = screenH < 620;
              final topHeroSpace = veryCompact ? 16.0 : (compact ? 36.0 : 64.0);
              final symbolSize = veryCompact ? 96.0 : (compact ? 112.0 : 124.0);
              final headlineSize = compact ? 44.0 : 48.0;
              final symbolToHeadGap = veryCompact
                  ? 20.0
                  : (compact ? 28.0 : 38.0);

              return SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: box.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Breathing space from top SafeArea / back button level
                        SizedBox(height: topHeroSpace),

                        // 1. COMPOSED HERO REGION
                        _wrapAnimated(
                          opacity: _symbolOpacity,
                          translate: _symbolTranslate,
                          child: Center(
                            child: Image.asset(
                              'assets/images/gufi_hero_eye.png',
                              width: symbolSize,
                              height: symbolSize,
                              cacheWidth: 372,
                              cacheHeight: 372,
                            ),
                          ),
                        ),
                        SizedBox(height: symbolToHeadGap),
                        _wrapAnimated(
                          opacity: _textOpacity,
                          translate: _textTranslate,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Welcome to Gufi',
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily:
                                        AppTypography.gambarinoFontFamily,
                                    fontSize: headlineSize,
                                    height: 1.05,
                                    letterSpacing: -0.7,
                                    color: navy,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Show up. Follow through. Together.',
                                textAlign: TextAlign.center,
                                style: ui(
                                  16.5,
                                  color: const Color(0xFF5A6A85),
                                  height: 1.35,
                                  spacing: -0.15,
                                  weight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 2. FLEXIBLE BREATHING SPACE BETWEEN HERO AND ACTIONS
                        const Spacer(),
                        SizedBox(height: veryCompact ? 16.0 : 28.0),

                        // 3. ACTION GROUP
                        _wrapAnimated(
                          opacity: _actionOpacity,
                          translate: _actionTranslate,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              PrimaryButton(
                                label: 'Create an account',
                                onPressed: _handleCreate,
                              ),
                              const SizedBox(height: 13),
                              SecondaryButton(
                                label: 'Log in',
                                onPressed: _handleLogin,
                              ),
                              SizedBox(height: veryCompact ? 18.0 : 28.0),
                              const DividerLabel(),
                              SizedBox(height: veryCompact ? 16.0 : 22.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: ProviderButton(
                                      label: 'Apple',
                                      loading: loading == AuthProvider.apple,
                                      icon: const Icon(
                                        Icons.apple,
                                        size: 24,
                                        color: navy,
                                      ),
                                      onPressed: () =>
                                          provider(AuthProvider.apple),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: ProviderButton(
                                      label: 'Google',
                                      loading: loading == AuthProvider.google,
                                      icon: Text(
                                        'G',
                                        style: ui(
                                          21,
                                          color: const Color(0xFF4285F4),
                                          weight: FontWeight.w700,
                                        ),
                                      ),
                                      onPressed: () =>
                                          provider(AuthProvider.google),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // 4. LEGAL TEXT
                        SizedBox(height: veryCompact ? 18.0 : 30.0),
                        const _LegalText(),
                        SizedBox(height: veryCompact ? 4.0 : 10.0),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.topLeft,
            child: BackControl(onPressed: widget.onBack),
          ),
        ],
      ),
    ),
  );
}

class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) => Text.rich(
    const TextSpan(
      text: "By continuing, you agree to Gufi's\n",
      children: [
        TextSpan(
          text: 'Terms of Use',
          style: TextStyle(color: blue),
        ),
        TextSpan(text: ' and '),
        TextSpan(
          text: 'Privacy Policy',
          style: TextStyle(color: blue),
        ),
        TextSpan(text: '.'),
      ],
    ),
    textAlign: TextAlign.center,
    style: ui(13, color: muted, height: 1.45),
  );
}

class SignupEmailScreen extends StatefulWidget {
  final AuthDraft draft;
  final AuthGateway gateway;
  final VoidCallback onNext;
  final VoidCallback onLogin;
  const SignupEmailScreen({
    super.key,
    required this.draft,
    required this.gateway,
    required this.onNext,
    required this.onLogin,
  });
  @override
  State<SignupEmailScreen> createState() => _SignupEmailScreenState();
}

class _SignupEmailScreenState extends State<SignupEmailScreen> {
  bool loading = false, exists = false;
  String? error;
  Future<void> submit() async {
    final emailText = widget.draft.email.text.trim();
    if (!validEmail(emailText) || loading) return;

    if (DisposableEmailService.isDisposable(emailText)) {
      setState(() {
        error = 'Please use a permanent email address.';
        exists = false;
      });
      return;
    }

    setState(() {
      loading = true;
      exists = false;
      error = null;
    });
    try {
      final found = await widget.gateway.emailExists(emailText);
      if (!mounted) return;
      if (found) {
        setState(() => exists = true);
      } else {
        widget.onNext();
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Network unavailable. Try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormScreen(
    title: "What's your email?",
    support: "We'll use this to create your Gufi account.",
    fields: [
      Input(
        key: const ValueKey('signup-email'),
        controller: widget.draft.email,
        autofocus: true,
        hint: 'Email address',
        keyboardType: TextInputType.emailAddress,
        action: TextInputAction.done,
        error:
            error ?? (exists ? 'This email already has a Gufi account.' : null),
        onChanged: (_) {
          if (exists || error != null) {
            setState(() {
              exists = false;
              error = null;
            });
          }
        },
        onSubmitted: (_) => submit(),
      ),
      if (exists) ...[
        const SizedBox(height: 12),
        TextAction(label: 'Log in instead', onPressed: widget.onLogin),
      ],
    ],
    actions: Listen(
      widget.draft.email,
      (value) => PrimaryButton(
        label: 'Continue',
        loading: loading,
        onPressed: validEmail(value) && !loading ? submit : null,
      ),
    ),
  );
}

class PasswordScreen extends StatefulWidget {
  final AuthDraft draft;
  final VoidCallback onNext;
  const PasswordScreen({super.key, required this.draft, required this.onNext});
  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final ValueNotifier<bool> obscureNotifier = ValueNotifier<bool>(true);

  @override
  void dispose() {
    obscureNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FormScreen(
    title: 'Create a password',
    support: "Make it something you'll remember.",
    fields: [
      ValueListenableBuilder<bool>(
        valueListenable: obscureNotifier,
        builder: (context, obscure, _) => Input(
          key: const ValueKey('signup-password'),
          controller: widget.draft.password,
          autofocus: true,
          hint: 'Password',
          obscure: obscure,
          action: TextInputAction.done,
          suffix: VisibilityControl(
            obscure: obscure,
            onPressed: () => obscureNotifier.value = !obscureNotifier.value,
          ),
          onSubmitted: (_) {
            if (validPassword(widget.draft.password.text)) widget.onNext();
          },
        ),
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 17, color: muted),
          const SizedBox(width: 8),
          Text('6+ characters', style: ui(13, color: muted)),
        ],
      ),
    ],
    actions: Listen(
      widget.draft.password,
      (value) => PrimaryButton(
        label: 'Continue',
        onPressed: validPassword(value) ? widget.onNext : null,
      ),
    ),
  );
}

class ConfirmScreen extends StatefulWidget {
  final AuthDraft draft;
  final AuthGateway gateway;
  final Future<void> Function() onNext;
  const ConfirmScreen({
    super.key,
    required this.draft,
    required this.gateway,
    required this.onNext,
  });
  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  final ValueNotifier<bool> obscureNotifier = ValueNotifier<bool>(true);
  bool loading = false;
  String? error;

  @override
  void dispose() {
    obscureNotifier.dispose();
    super.dispose();
  }

  bool get matches =>
      widget.draft.confirmation.text.isNotEmpty &&
      widget.draft.confirmation.text == widget.draft.password.text;

  Future<void> submit() async {
    if (!matches || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.gateway.signUp(
        widget.draft.email.text.trim(),
        widget.draft.password.text,
      );
      if (mounted) await widget.onNext();
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Sign up failed. Try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormScreen(
    title: 'Confirm your\npassword',
    fields: [
      ValueListenableBuilder<bool>(
        valueListenable: obscureNotifier,
        builder: (context, obscure, _) => ListenableBuilder(
          listenable: Listenable.merge([
            widget.draft.confirmation,
            widget.draft.password,
          ]),
          builder: (context, _) {
            final text = widget.draft.confirmation.text;
            final isMismatch =
                text.isNotEmpty && text != widget.draft.password.text;
            return Input(
              key: const ValueKey('confirm-password'),
              controller: widget.draft.confirmation,
              autofocus: true,
              hint: 'Confirm password',
              obscure: obscure,
              action: TextInputAction.done,
              error: error ?? (isMismatch ? "Passwords don't match." : null),
              suffix: VisibilityControl(
                obscure: obscure,
                onPressed: () => obscureNotifier.value = !obscureNotifier.value,
              ),
              onSubmitted: (_) {
                if (matches) submit();
              },
            );
          },
        ),
      ),
    ],
    actions: ListenableBuilder(
      listenable: Listenable.merge([
        widget.draft.confirmation,
        widget.draft.password,
      ]),
      builder: (context, _) => PrimaryButton(
        label: 'Continue',
        loading: loading,
        onPressed: matches && !loading ? submit : null,
      ),
    ),
  );
}

class UsernameScreen extends StatefulWidget {
  final AuthDraft draft;
  final AuthGateway gateway;
  final VoidCallback onNext;
  const UsernameScreen({
    super.key,
    required this.draft,
    required this.gateway,
    required this.onNext,
  });
  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  Timer? debounce;
  int _checkToken = 0;
  final ValueNotifier<({bool checking, bool? available})> statusNotifier =
      ValueNotifier((checking: false, available: null));

  @override
  void dispose() {
    debounce?.cancel();
    statusNotifier.dispose();
    super.dispose();
  }

  void changed(String raw) {
    debounce?.cancel();
    final name = raw.trim().replaceFirst('@', '');
    if (!validUsername(name)) {
      statusNotifier.value = (checking: false, available: null);
      return;
    }
    statusNotifier.value = (checking: true, available: null);
    final currentToken = ++_checkToken;
    debounce = Timer(const Duration(milliseconds: 350), () async {
      final value = await widget.gateway.usernameAvailable(name);
      if (mounted &&
          currentToken == _checkToken &&
          widget.draft.username.text.trim().replaceFirst('@', '') == name) {
        statusNotifier.value = (checking: false, available: value);
      }
    });
  }

  @override
  Widget build(BuildContext context) => FormScreen(
    title: 'What should we\ncall you?',
    support: 'Choose your Gufi username.',
    fields: [
      ValueListenableBuilder<({bool checking, bool? available})>(
        valueListenable: statusNotifier,
        builder: (context, status, _) {
          final note = status.checking
              ? 'Checking availability…'
              : status.available == true
              ? '✓ Username available'
              : status.available == false
              ? 'Username is already taken.'
              : null;
          return Input(
            key: const ValueKey('username'),
            controller: widget.draft.username,
            autofocus: true,
            hint: 'username',
            prefix: '@',
            action: TextInputAction.done,
            error: status.available == false ? note : null,
            supporting: status.available != false ? note : null,
            supportColor: status.available == true ? success : muted,
            onChanged: changed,
            onSubmitted: (_) {
              if (status.available == true) widget.onNext();
            },
          );
        },
      ),
    ],
    actions: ValueListenableBuilder<({bool checking, bool? available})>(
      valueListenable: statusNotifier,
      builder: (context, status, _) => PrimaryButton(
        label: 'Continue',
        onPressed: status.available == true ? widget.onNext : null,
      ),
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  final AuthDraft draft;
  final AuthGateway gateway;
  final void Function(UserProfile? profile) onDone;
  const ProfileScreen({
    super.key,
    required this.draft,
    required this.gateway,
    required this.onDone,
  });
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = false;
  String? error;
  Future<void> choose() async {
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 600,
        maxHeight: 600,
      );
      if (photo != null && mounted) setState(() => widget.draft.photo = photo);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Photo library unavailable. You can skip for now.',
        );
      }
    }
  }

  Future<void> finish() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final updatedProfile = await widget.gateway.createAccount(
        widget.draft.email.text.trim(),
        widget.draft.password.text,
        widget.draft.username.text.trim().replaceFirst('@', ''),
        widget.draft.photo?.path,
      );
      if (mounted) widget.onDone(updatedProfile);
    } on AvatarUploadException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on ProfileUpdateException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => error = "Couldn't finish your profile. Try again.");
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.draft.photo;
    return FormScreen(
      title: 'Make it yours.',
      support: 'Add a profile picture so your friends can recognize you.',
      fields: [
        const SizedBox(height: 10),
        Center(
          child: Container(
            width: 136,
            height: 136,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE8EEF5),
              border: Border.all(color: border),
            ),
            child: photo == null
                ? const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedUser,
                      size: 50,
                      color: navy,
                    ),
                  )
                : Image.file(
                    File(photo.path),
                    width: 136,
                    height: 136,
                    cacheWidth: 272,
                    cacheHeight: 272,
                    fit: BoxFit.cover,
                  ),
          ),
        ),
        const SizedBox(height: 14),
        TextAction(
          label: photo == null ? 'Choose photo' : 'Change photo',
          onPressed: choose,
        ),
        if (error != null)
          Text(
            error!,
            textAlign: TextAlign.center,
            style: ui(13, color: errorRed),
          ),
      ],
      actions: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PrimaryButton(
            label: photo == null ? 'Skip for now' : 'Finish',
            loading: loading,
            onPressed: loading ? null : finish,
          ),
          if (photo != null) ...[
            const SizedBox(height: 8),
            TextAction(
              label: 'Remove photo',
              onPressed: () => setState(() => widget.draft.photo = null),
            ),
          ],
        ],
      ),
    );
  }
}

class LoginEmailScreen extends StatelessWidget {
  final AuthDraft draft;
  final VoidCallback onNext;
  const LoginEmailScreen({
    super.key,
    required this.draft,
    required this.onNext,
  });
  @override
  Widget build(BuildContext context) => FormScreen(
    title: 'Welcome back.',
    support: 'Enter the email connected to your Gufi account.',
    fields: [
      Input(
        key: const ValueKey('login-email'),
        controller: draft.email,
        autofocus: true,
        hint: 'Email address',
        keyboardType: TextInputType.emailAddress,
        action: TextInputAction.done,
        onSubmitted: (_) {
          if (validEmail(draft.email.text)) onNext();
        },
      ),
    ],
    actions: Listen(
      draft.email,
      (value) => PrimaryButton(
        label: 'Continue',
        onPressed: validEmail(value) ? onNext : null,
      ),
    ),
  );
}

class LoginPasswordScreen extends StatefulWidget {
  final AuthDraft draft;
  final AuthGateway gateway;
  final void Function(UserProfile? profile) onDone;
  final VoidCallback onForgot;
  const LoginPasswordScreen({
    super.key,
    required this.draft,
    required this.gateway,
    required this.onDone,
    required this.onForgot,
  });
  @override
  State<LoginPasswordScreen> createState() => _LoginPasswordScreenState();
}

class _LoginPasswordScreenState extends State<LoginPasswordScreen> {
  final ValueNotifier<bool> obscureNotifier = ValueNotifier<bool>(true);
  bool loading = false;
  String? error;

  @override
  void dispose() {
    obscureNotifier.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (widget.draft.password.text.isEmpty || loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final profile = await widget.gateway.logIn(
        widget.draft.email.text.trim(),
        widget.draft.password.text,
      );
      if (mounted) widget.onDone(profile);
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on AuthException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (_) {
      if (mounted) setState(() => error = 'Authentication failed. Try again.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FormScreen(
    title: 'Enter your\npassword',
    support: widget.draft.email.text.trim(),
    fields: [
      ValueListenableBuilder<bool>(
        valueListenable: obscureNotifier,
        builder: (context, obscure, _) => Input(
          key: const ValueKey('login-password'),
          controller: widget.draft.password,
          autofocus: true,
          hint: 'Password',
          obscure: obscure,
          action: TextInputAction.done,
          error: error,
          suffix: VisibilityControl(
            obscure: obscure,
            onPressed: () => obscureNotifier.value = !obscureNotifier.value,
          ),
          onChanged: (_) {
            if (error != null) setState(() => error = null);
          },
          onSubmitted: (_) => login(),
        ),
      ),
    ],
    actions: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Listen(
          widget.draft.password,
          (value) => PrimaryButton(
            label: 'Log in',
            loading: loading,
            onPressed: value.isNotEmpty && !loading ? login : null,
          ),
        ),
        const SizedBox(height: 12),
        TextAction(label: 'Forgot password?', onPressed: widget.onForgot),
      ],
    ),
  );
}

class ResetScreen extends StatefulWidget {
  final AuthDraft draft;
  final AuthGateway gateway;
  const ResetScreen({super.key, required this.draft, required this.gateway});
  @override
  State<ResetScreen> createState() => _ResetScreenState();
}

class _ResetScreenState extends State<ResetScreen> {
  bool loading = false, sent = false;
  String? error;
  Future<void> send() async {
    if (loading) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await widget.gateway.sendPasswordReset(widget.draft.email.text.trim());
      if (mounted) setState(() => sent = true);
    } on AuthFlowException catch (e) {
      if (mounted) setState(() => error = e.message);
    } on AuthException catch (e) {
      if (mounted) {
        if (e.code == 'over_email_send_rate_limit' ||
            e.statusCode == '429' ||
            e.message.toLowerCase().contains('rate limit') ||
            e.message.toLowerCase().contains('over_email_send_rate_limit')) {
          setState(
            () => error =
                'Too many emails were sent recently. Please try again later.',
          );
        } else {
          setState(() => error = e.message);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not send the reset link. Try again.');
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => sent
      ? FormScreen(
          title: 'Check your email.',
          support:
              'We sent password reset instructions to:\n${widget.draft.email.text.trim()}',
          fields: const [],
          actions: PrimaryButton(
            label: 'Back to log in',
            onPressed: () => Navigator.of(context).pop(),
          ),
        )
      : FormScreen(
          title: 'Reset your\npassword',
          support:
              "We'll send password reset instructions to\n${widget.draft.email.text.trim()}",
          fields: [
            if (error != null) Text(error!, style: ui(13, color: errorRed)),
          ],
          actions: PrimaryButton(
            label: 'Send reset link',
            loading: loading,
            onPressed: loading ? null : send,
          ),
        );
}

class Canvas extends StatelessWidget {
  final Widget child;
  final bool back;
  final bool resizeToAvoidBottomInset;
  const Canvas({
    super.key,
    required this.child,
    this.back = false,
    this.resizeToAvoidBottomInset = false,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: bg,
    resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (back) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: BackControl(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: 30),
            ],
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}

class FormScreen extends StatelessWidget {
  final String title;
  final String? support;
  final List<Widget> fields;
  final Widget actions;
  const FormScreen({
    super.key,
    required this.title,
    this.support,
    required this.fields,
    required this.actions,
  });
  @override
  Widget build(BuildContext context) => Canvas(
    back: true,
    resizeToAvoidBottomInset: true,
    child: LayoutBuilder(
      builder: (_, box) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Heading(title),
                  if (support != null) ...[
                    const SizedBox(height: 12),
                    Support(support!),
                  ],
                  const SizedBox(height: 30),
                  ...fields,
                  const Spacer(),
                  const SizedBox(height: 24),
                  actions,
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class Heading extends StatelessWidget {
  final String text;
  final bool centered;
  const Heading(this.text, {super.key, this.centered = false});
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: centered ? TextAlign.center : TextAlign.left,
    style: const TextStyle(
      fontFamily: AppTypography.gambarinoFontFamily,
      fontSize: 43,
      height: 1.04,
      letterSpacing: -.7,
      color: navy,
    ),
  );
}

class Support extends StatelessWidget {
  final String text;
  final bool centered;
  const Support(this.text, {super.key, this.centered = false});
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: centered ? TextAlign.center : TextAlign.left,
    style: ui(15, color: muted, height: 1.45),
  );
}

class Input extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefix;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? action;
  final Widget? suffix;
  final String? error;
  final String? supporting;
  final Color supportColor;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  const Input({
    super.key,
    required this.controller,
    required this.hint,
    this.prefix,
    this.obscure = false,
    this.keyboardType,
    this.action,
    this.suffix,
    this.error,
    this.supporting,
    this.supportColor = muted,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });
  @override
  State<Input> createState() => _InputState();
}

class _InputState extends State<Input> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    focus.addListener(refresh);
  }

  @override
  void dispose() {
    focus.removeListener(refresh);
    focus.dispose();
    super.dispose();
  }

  void refresh() => setState(() {});
  @override
  Widget build(BuildContext context) {
    final bad = widget.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: bad
                  ? errorRed
                  : focus.hasFocus
                  ? blue
                  : border,
              width: bad || focus.hasFocus ? 2 : 1,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: focus,
            autofocus: widget.autofocus,
            obscureText: widget.obscure,
            keyboardType: widget.keyboardType,
            textInputAction: widget.action,
            autocorrect: false,
            enableSuggestions: !widget.obscure,
            cursorColor: blue,
            style: ui(17),
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixText: widget.prefix,
              prefixStyle: ui(17),
              hintStyle: ui(17, color: muted),
              suffixIcon: widget.suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
            ),
          ),
        ),
        if (widget.error != null || widget.supporting != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.error ?? widget.supporting!,
            style: ui(13, color: bad ? errorRed : widget.supportColor),
          ),
        ],
      ],
    );
  }
}

class Listen extends StatelessWidget {
  final TextEditingController controller;
  final Widget Function(String) builder;
  const Listen(this.controller, this.builder, {super.key});
  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, _) => builder(value.text),
      );
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
  @override
  Widget build(BuildContext context) => ButtonSurface(
    filled: true,
    enabled: onPressed != null && !loading,
    onPressed: loading ? null : onPressed,
    child: SizedBox(
      height: 24,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: ui(17, color: Colors.white, weight: FontWeight.w600),
              ),
      ),
    ),
  );
}

class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => ButtonSurface(
    filled: false,
    enabled: true,
    onPressed: onPressed,
    child: Text(label, style: ui(17, weight: FontWeight.w600)),
  );
}

class ProviderButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final bool loading;
  final VoidCallback onPressed;
  const ProviderButton({
    super.key,
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => ButtonSurface(
    filled: false,
    enabled: !loading,
    onPressed: onPressed,
    child: SizedBox(
      height: 24,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: blue),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: ui(15, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
      ),
    ),
  );
}

class ButtonSurface extends StatefulWidget {
  final Widget child;
  final bool filled;
  final bool enabled;
  final VoidCallback? onPressed;
  const ButtonSurface({
    super.key,
    required this.child,
    required this.filled,
    required this.enabled,
    required this.onPressed,
  });
  @override
  State<ButtonSurface> createState() => _ButtonSurfaceState();
}

class _ButtonSurfaceState extends State<ButtonSurface> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.enabled
        ? (_) {
            AppHaptics.selection();
            setState(() => pressed = true);
          }
        : null,
    onTapCancel: () {
      if (pressed) setState(() => pressed = false);
    },
    onTapUp: (_) {
      if (pressed) setState(() => pressed = false);
    },
    onTap: widget.enabled ? widget.onPressed : null,
    child: AnimatedScale(
      scale: pressed ? 0.985 : 1.0,
      duration: Duration(milliseconds: pressed ? 80 : 100),
      curve: pressed ? Curves.easeOut : Curves.easeOutCubic,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.filled
              ? (widget.enabled ? blue : blue.withValues(alpha: .35))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: widget.filled ? null : Border.all(color: border),
        ),
        child: widget.child,
      ),
    ),
  );
}

class BackControl extends StatefulWidget {
  final VoidCallback onPressed;
  final double size;
  const BackControl({super.key, required this.onPressed, this.size = 50.0});

  @override
  State<BackControl> createState() => _BackControlState();
}

class _BackControlState extends State<BackControl> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Back',
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        AppHaptics.light();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: Duration(milliseconds: _pressed ? 80 : 110),
        curve: _pressed ? Curves.easeOut : Curves.easeOutCubic,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.transparent,
            border: Border.all(color: border, width: 1.2),
          ),
          child: const Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              size: 24,
              color: navy,
              strokeWidth: 1.8,
            ),
          ),
        ),
      ),
    ),
  );
}

class VisibilityControl extends StatelessWidget {
  final bool obscure;
  final VoidCallback onPressed;
  const VisibilityControl({
    super.key,
    required this.obscure,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: obscure ? 'Show password' : 'Hide password',
    button: true,
    child: IconButton(
      onPressed: () {
        AppHaptics.selection();
        onPressed();
      },
      splashRadius: 24,
      icon: HugeIcon(
        icon: obscure
            ? HugeIcons.strokeRoundedView
            : HugeIcons.strokeRoundedViewOff,
        size: 22,
        color: navy,
        strokeWidth: 1.7,
      ),
    ),
  );
}

class TextAction extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  const TextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.light();
        onPressed();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: ui(15, color: color ?? blue, weight: FontWeight.w600),
            ),
          ),
        ),
      ),
    ),
  );
}

class DividerLabel extends StatelessWidget {
  const DividerLabel({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          'OR',
          style: ui(11, color: muted, weight: FontWeight.w600, spacing: 1.5),
        ),
      ),
      const Expanded(child: Divider(color: border)),
    ],
  );
}

bool validEmail(String value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
bool validPassword(String value) => value.length >= 6;
bool validUsername(String value) =>
    RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(value);
TextStyle ui(
  double size, {
  Color color = navy,
  FontWeight weight = FontWeight.w400,
  double? height,
  double? spacing,
}) => GoogleFonts.inter(
  fontSize: size,
  color: color,
  fontWeight: weight,
  height: height,
  letterSpacing: spacing,
);
void message(BuildContext context, String value) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
