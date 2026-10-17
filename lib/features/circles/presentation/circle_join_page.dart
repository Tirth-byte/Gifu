import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/services/gufi_backend_store.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/account_action_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/repositories/supabase_auth_repository.dart';
import '../data/repositories/supabase_circle_repository.dart';
import '../domain/models/circle_invite.dart';

/// Join a Circle — Step 1 & Preview Page
///
/// Production-quality, warm, premium, Gen Z friendly Join Circle flow.
///
/// Interaction Flow:
/// 1. Enter/paste invite code OR scan QR code OR open via deep link.
/// 2. Code format validation (uppercase, trimmed, hyphen-tolerant).
/// 3. Tap "Find Circle" $\rightarrow$ resolve against backend (local spinner, no global block).
/// 4. Valid invite $\rightarrow$ smooth local transition (fade + 10px slide) into Circle preview card.
/// 5. Shows real member avatars/initials, circle name, purpose, member count, and creator attribution.
/// 6. Tap "Join Circle" $\rightarrow$ backend validates invite and creates active membership.
/// 7. Routes to `/today` (clearing onboarding prerequisite stack).
/// 8. Handles: Already Member, Expired Invite, Revoked Invite, and Invalid Code gracefully.
class CircleJoinPage extends StatefulWidget {
  final String? initialCode;

  const CircleJoinPage({super.key, this.initialCode});

  @override
  State<CircleJoinPage> createState() => _CircleJoinPageState();
}

class _CircleJoinPageState extends State<CircleJoinPage>
    with SingleTickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _codeFocusNode = FocusNode();

  bool _isCodeFocused = false;
  bool _isResolving = false;
  bool _isJoining = false;

  String? _errorMessage;
  InviteResolutionResult? _resolvedResult;

  static const Color canvasColor = Color(0xFFFFFFFF);
  static const Color gufiNavy = Color(0xFF1E3365);
  static const Color mutedSlate = Color(0xFF5C6E8C);
  static const Color errorColor = Color(0xFFE5484D);

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_onCodeChanged);
    _codeFocusNode.addListener(() {
      setState(() => _isCodeFocused = _codeFocusNode.hasFocus);
    });

    if (widget.initialCode != null && widget.initialCode!.trim().isNotEmpty) {
      final code = GufiBackendStore.normalizeInviteCode(widget.initialCode!);
      _codeController.text = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveInvite(code);
      });
    }
  }

  @override
  void dispose() {
    _codeController.removeListener(_onCodeChanged);
    _codeController.dispose();
    _codeFocusNode.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    } else {
      setState(() {});
    }
  }

  String get _trimmedCode =>
      GufiBackendStore.normalizeInviteCode(_codeController.text);

  bool get _isInputPlausible => _trimmedCode.length >= 6;

  String? get _currentUserId =>
      SupabaseAuthRepository.instance.currentUserProfile?.id;

  Future<void> _resolveInvite(String codeToResolve) async {
    final cleanCode = GufiBackendStore.normalizeInviteCode(codeToResolve);
    if (cleanCode.isEmpty) return;

    _codeFocusNode.unfocus();
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });

    try {
      final result = await SupabaseCircleRepository.instance.resolveInvite(
        code: cleanCode,
        currentUserId: _currentUserId,
      );

      if (!mounted) return;

      setState(() {
        _isResolving = false;
        if (result is InviteResolvedInvalid) {
          _errorMessage = result.message;
          _resolvedResult = null;
          AppHaptics.warning();
        } else {
          _errorMessage = null;
          _resolvedResult = result;
          AppHaptics.selection();
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResolving = false;
        _errorMessage = 'We couldn’t find that invite.';
        _resolvedResult = null;
      });
    }
  }

  Future<void> _handleJoinCircle(CirclePreview preview) async {
    if (_isJoining) return;

    final userId = _currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to join this Circle.')),
      );
      return;
    }

    AppHaptics.selection();
    setState(() => _isJoining = true);

    try {
      final result = await SupabaseCircleRepository.instance
          .joinCircleWithInvite(code: preview.inviteCode, userId: userId);

      if (!mounted) return;
      setState(() => _isJoining = false);

      if (result is JoinCircleSuccess || result is JoinCircleAlreadyMember) {
        // Circle requirement fulfilled! Navigate to /today and clear entry stack
        context.go('/today');
      } else if (result is JoinCircleFailure) {
        AppHaptics.warning();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message), backgroundColor: errorColor),
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isJoining = false);
      AppHaptics.warning();
    }
  }

  void _handleResetToInput() {
    AppHaptics.selection();
    setState(() {
      _resolvedResult = null;
      _errorMessage = null;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _codeFocusNode.requestFocus();
    });
  }

  Future<void> _openQrScanner() async {
    AppHaptics.selection();
    _codeFocusNode.unfocus();

    final scannedCode = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _QrScannerModalSheet(),
    );

    if (scannedCode != null && scannedCode.isNotEmpty && mounted) {
      final clean = GufiBackendStore.normalizeInviteCode(scannedCode);
      _codeController.text = clean;
      _resolveInvite(clean);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isKeyboardOpen = mediaQuery.viewInsets.bottom > 0;
    final isCompact = mediaQuery.size.height < 750;

    // Tight, cohesive spacing matching Create Circle
    final gapTopBarToHeadline = isCompact ? 20.0 : 28.0;
    final gapHeadlineToSubtitle = isCompact ? 8.0 : 12.0;
    final gapSubtitleToContent = isCompact ? 18.0 : 24.0;

    return Scaffold(
      backgroundColor: canvasColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Bar: Back arrow + "Join a Circle"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.arrow_left,
                      color: gufiNavy,
                      size: 22,
                    ),
                    splashRadius: 24,
                    onPressed: () {
                      AppHaptics.selection();
                      if (_resolvedResult != null) {
                        _handleResetToInput();
                      } else if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/circle-entry');
                      }
                    },
                  ),
                  Text(
                    'Join a Circle',
                    style: TextStyle(
                      fontFamily: AppTypography.gambarinoFontFamily,
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: gufiNavy,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const AccountActionButton(),
                ],
              ),
            ),

            // 2. Interactive Area: Upper-middle grouping with no scroll when keyboard closed
            Expanded(
              child: SingleChildScrollView(
                physics: isKeyboardOpen
                    ? const ClampingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: gapTopBarToHeadline),

                    // Animated Headline + Subtitle + Content switcher
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(
                                0,
                                0.025,
                              ), // 8-12px upward settle
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(
                          (_resolvedResult is InviteResolvedValid ||
                                  _resolvedResult
                                      is InviteResolvedAlreadyMember)
                              ? 'preview_state'
                              : 'entry_state',
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Main Headline in Gambarino
                            Text(
                              (_resolvedResult is InviteResolvedValid)
                                  ? 'This is your Circle.'
                                  : (_resolvedResult
                                        is InviteResolvedAlreadyMember)
                                  ? 'You’re already in this Circle.'
                                  : 'Find your Circle.',
                              style: TextStyle(
                                fontFamily: AppTypography.gambarinoFontFamily,
                                fontSize: isCompact ? 28 : 32,
                                fontWeight: FontWeight.w400,
                                color: gufiNavy,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),

                            SizedBox(height: gapHeadlineToSubtitle),

                            // Supporting Copy in Inter
                            Text(
                              (_resolvedResult is InviteResolvedValid)
                                  ? 'Take a look before you join.'
                                  : (_resolvedResult
                                        is InviteResolvedAlreadyMember)
                                  ? 'Take a look at your Circle.'
                                  : 'Enter the invite code someone shared with you.',
                              style: AppTypography.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w400,
                                color: mutedSlate,
                                height: 1.35,
                              ),
                            ),

                            SizedBox(height: gapSubtitleToContent),

                            _resolvedResult == null
                                ? _buildInputSection(isCompact)
                                : _buildPreviewSection(
                                    _resolvedResult!,
                                    isCompact,
                                  ),
                          ],
                        ),
                      ),
                    ),

                    // Breathing room below
                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // INPUT SECTION (Code field + Find + QR + Microcopy)
  // ==========================================
  Widget _buildInputSection(bool isCompact) {
    return Column(
      key: const ValueKey('input_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'Invite code',
          style: AppTypography.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: gufiNavy,
          ),
        ),

        const SizedBox(height: 8),

        // Single clean text field
        _FormFieldContainer(
          isFocused: _isCodeFocused,
          hasError: _errorMessage != null,
          child: TextField(
            controller: _codeController,
            focusNode: _codeFocusNode,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: [
              _UpperCaseTextFormatter(),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\-]')),
            ],
            onSubmitted: (_) {
              if (_isInputPlausible && !_isResolving) {
                _resolveInvite(_trimmedCode);
              }
            },
            style: AppTypography.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: gufiNavy,
              letterSpacing: 1.8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'GUFI-7K4PX9',
              hintStyle: AppTypography.inter(
                fontSize: 16.5,
                fontWeight: FontWeight.w500,
                color: mutedSlate.withValues(alpha: 0.45),
                letterSpacing: 1.8,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),

        // Inline Error (if invalid code)
        if (_errorMessage != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Row(
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle_fill,
                  size: 13,
                  color: errorColor,
                ),
                const SizedBox(width: 5),
                Text(
                  _errorMessage!,
                  style: AppTypography.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: errorColor,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 14),

        // Primary CTA: Find Circle
        _PrimaryButton(
          title: 'Find Circle',
          loadingTitle: 'Finding…',
          isEnabled: _isInputPlausible,
          isLoading: _isResolving,
          onTap: () => _resolveInvite(_trimmedCode),
        ),

        const SizedBox(height: 10),

        // Secondary Action: Scan QR Code (Full width secondary card)
        _QrSecondaryActionRow(onTap: _openQrScanner),

        const SizedBox(height: 14),

        // Trust microcopy
        Center(
          child: Text(
            'You’ll preview the Circle before joining.',
            style: AppTypography.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
              color: mutedSlate.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PREVIEW SECTION (Social & Trustworthy Card)
  // ==========================================
  Widget _buildPreviewSection(InviteResolutionResult result, bool isCompact) {
    if (result is InviteResolvedValid) {
      return _buildValidPreviewCard(result.preview);
    } else if (result is InviteResolvedAlreadyMember) {
      return _buildAlreadyMemberCard(result.preview);
    } else if (result is InviteResolvedExpired) {
      return _buildNoticeCard(
        title: result.message,
        subtitle: result.supporting,
        icon: CupertinoIcons.clock_fill,
        accentColor: const Color(0xFFE58514),
      );
    } else if (result is InviteResolvedRevoked) {
      return _buildNoticeCard(
        title: result.message,
        subtitle: 'Ask someone in the Circle for a fresh invite link.',
        icon: CupertinoIcons.slash_circle_fill,
        accentColor: errorColor,
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildValidPreviewCard(CirclePreview preview) {
    final attribution =
        (preview.inviterName != null && preview.inviterName!.trim().isNotEmpty)
        ? 'Invited by ${preview.inviterName!.trim()}'
        : (preview.creatorName != null &&
              preview.creatorName!.trim().isNotEmpty)
        ? 'Created by ${preview.creatorName!.trim()}'
        : null;

    return Column(
      key: const ValueKey('valid_preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDFECFB), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3365).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Circle Name
              Text(
                preview.circleName,
                style: TextStyle(
                  fontFamily: AppTypography.gambarinoFontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: gufiNavy,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),

              // 2. Purpose / Description if available
              if (preview.description != null &&
                  preview.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  preview.description!.trim(),
                  style: AppTypography.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: mutedSlate,
                    height: 1.35,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 3. Member visual: Overlapping avatars + count
              Row(
                children: [
                  _MemberAvatarsRow(previewMembers: preview.previewMembers),
                  const SizedBox(width: 12),
                  Text(
                    '${preview.memberCount} ${preview.memberCount == 1 ? 'person' : 'people'}',
                    style: AppTypography.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: gufiNavy,
                    ),
                  ),
                ],
              ),

              // 4. Inviter / Creator attribution if available
              if (attribution != null) ...[
                const SizedBox(height: 14),
                Text(
                  attribution,
                  style: AppTypography.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: mutedSlate,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Confirm Join CTA: Join Circle
        _PrimaryButton(
          title: 'Join Circle',
          loadingTitle: 'Joining…',
          isEnabled: true,
          isLoading: _isJoining,
          onTap: () => _handleJoinCircle(preview),
        ),

        const SizedBox(height: 12),

        // Secondary: Use another code
        Center(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onPressed: _handleResetToInput,
            child: Text(
              'Use another code',
              style: AppTypography.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: mutedSlate,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlreadyMemberCard(CirclePreview preview) {
    final attribution =
        (preview.inviterName != null && preview.inviterName!.trim().isNotEmpty)
        ? 'Invited by ${preview.inviterName!.trim()}'
        : (preview.creatorName != null &&
              preview.creatorName!.trim().isNotEmpty)
        ? 'Created by ${preview.creatorName!.trim()}'
        : null;

    return Column(
      key: const ValueKey('already_member_preview'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDFECFB), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3365).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Circle Name
              Text(
                preview.circleName,
                style: TextStyle(
                  fontFamily: AppTypography.gambarinoFontFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.w400,
                  color: gufiNavy,
                  letterSpacing: -0.4,
                  height: 1.15,
                ),
              ),

              // 2. Purpose / Description if available
              if (preview.description != null &&
                  preview.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  preview.description!.trim(),
                  style: AppTypography.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    color: mutedSlate,
                    height: 1.35,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 3. Member visual: Overlapping avatars + count
              Row(
                children: [
                  _MemberAvatarsRow(previewMembers: preview.previewMembers),
                  const SizedBox(width: 12),
                  Text(
                    '${preview.memberCount} ${preview.memberCount == 1 ? 'person' : 'people'}',
                    style: AppTypography.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: gufiNavy,
                    ),
                  ),
                ],
              ),

              // 4. Inviter / Creator attribution if available
              if (attribution != null) ...[
                const SizedBox(height: 14),
                Text(
                  attribution,
                  style: AppTypography.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: mutedSlate,
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        _PrimaryButton(
          title: 'Go to Today',
          isEnabled: true,
          isLoading: false,
          onTap: () {
            AppHaptics.selection();
            context.go('/today');
          },
        ),

        const SizedBox(height: 12),

        Center(
          child: CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            onPressed: _handleResetToInput,
            child: Text(
              'Use another code',
              style: AppTypography.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: mutedSlate,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Column(
      key: ValueKey('notice_$title'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDFECFB), width: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Center(child: Icon(icon, size: 18, color: accentColor)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: gufiNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: mutedSlate,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        _PrimaryButton(
          title: 'Use another code',
          isEnabled: true,
          isLoading: false,
          onTap: _handleResetToInput,
        ),
      ],
    );
  }
}

/// Overlapping avatars row displaying active member initials / avatars
class _MemberAvatarsRow extends StatelessWidget {
  final List<CirclePreviewMember> previewMembers;

  const _MemberAvatarsRow({required this.previewMembers});

  static const List<Color> _palette = [
    Color(0xFF5880DA),
    Color(0xFF389274),
    Color(0xFFE58514),
    Color(0xFF9854CB),
  ];

  @override
  Widget build(BuildContext context) {
    if (previewMembers.isEmpty) {
      return Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFEEF5FD),
        ),
        child: const Icon(
          CupertinoIcons.person_fill,
          size: 18,
          color: Color(0xFF5880DA),
        ),
      );
    }

    final displayed = previewMembers.take(4).toList();
    final remaining = previewMembers.length - displayed.length;
    final totalCount = displayed.length + (remaining > 0 ? 1 : 0);
    final totalWidth = totalCount == 0 ? 36.0 : (totalCount - 1) * 26.0 + 36.0;

    return SizedBox(
      width: totalWidth,
      height: 36,
      child: Stack(
        children: [
          for (int i = 0; i < displayed.length; i++)
            Positioned(
              left: i * 26.0,
              child: _buildAvatar(displayed[i], _palette[i % _palette.length]),
            ),
          if (remaining > 0)
            Positioned(
              left: displayed.length * 26.0,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFDFECFB),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: AppTypography.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1E3365),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar(CirclePreviewMember member, Color color) {
    final initials = _getInitials(member.displayName);
    return UserAvatar(
      photoUrl: member.profilePhotoUrl,
      fallbackInitial: initials,
      size: 36,
      backgroundColor: color.withValues(alpha: 0.15),
      borderColor: Colors.white,
      borderWidth: 2,
      textStyle: AppTypography.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'M';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, min(2, trimmed.length)).toUpperCase();
  }
}

/// Uppercase text formatter for invite code input
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

/// Form field container with smooth focus and error animation
class _FormFieldContainer extends StatelessWidget {
  final bool isFocused;
  final bool hasError;
  final Widget child;

  const _FormFieldContainer({
    required this.isFocused,
    required this.hasError,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    Color border;
    if (hasError) {
      border = const Color(0xFFE5484D);
    } else if (isFocused) {
      border = const Color(0xFF5880DA);
    } else {
      border = const Color(0xFFE2EAF4);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: isFocused ? 1.5 : 1.0),
      ),
      child: child,
    );
  }
}

/// Primary button with smooth press feedback and local spinner
class _PrimaryButton extends StatefulWidget {
  final String title;
  final String? loadingTitle;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.title,
    this.loadingTitle,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.isEnabled && !widget.isLoading;
    final backgroundColor = enabled
        ? const Color(0xFF5880DA)
        : const Color(0xFF5880DA).withValues(alpha: 0.40);

    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _isPressed = false) : null,
      onTap: enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: const Color(0xFF5880DA).withValues(alpha: 0.20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? (widget.loadingTitle != null
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.0,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.loadingTitle!,
                              style: AppTypography.inter(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ))
                : Text(
                    widget.title,
                    style: AppTypography.inter(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Compact secondary QR action row: [ QR icon ] Scan QR code >
class _QrSecondaryActionRow extends StatefulWidget {
  final VoidCallback onTap;

  const _QrSecondaryActionRow({required this.onTap});

  @override
  State<_QrSecondaryActionRow> createState() => _QrSecondaryActionRowState();
}

class _QrSecondaryActionRowState extends State<_QrSecondaryActionRow> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDFECFB), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E3365).withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFEEF5FD),
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.qrcode,
                    size: 15,
                    color: Color(0xFF1E3365),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Scan QR code',
                style: AppTypography.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E3365),
                ),
              ),
              const Spacer(),
              const Icon(
                CupertinoIcons.chevron_right,
                size: 13,
                color: Color(0xFF8E9EB5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Camera QR Scanner modal sheet
class _QrScannerModalSheet extends StatefulWidget {
  const _QrScannerModalSheet();

  @override
  State<_QrScannerModalSheet> createState() => _QrScannerModalSheetState();
}

class _QrScannerModalSheetState extends State<_QrScannerModalSheet> {
  late final MobileScannerController _controller;
  bool _hasScanned = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final val = barcode.rawValue;
      if (val != null && val.trim().isNotEmpty) {
        _hasScanned = true;
        AppHaptics.selection();
        Navigator.of(context).pop(val.trim());
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD6DFEC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Scan Circle QR',
                  style: TextStyle(
                    fontFamily: AppTypography.gambarinoFontFamily,
                    fontSize: 20,
                    color: const Color(0xFF1E3365),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    CupertinoIcons.xmark_circle_fill,
                    color: Color(0xFF5C6E8C),
                    size: 24,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Scanner Area
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                      errorBuilder: (context, error) {
                        return _buildPermissionDeniedView();
                      },
                    ),
                    // Viewfinder overlay
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.8),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
            child: Text(
              'Align the QR code within the frame to join automatically.',
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                fontSize: 13,
                color: const Color(0xFF5C6E8C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.camera_fill,
              color: Colors.white,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              'Camera access needed',
              style: AppTypography.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please allow camera permission in iOS Settings to scan QR invite codes.',
              textAlign: TextAlign.center,
              style: AppTypography.inter(fontSize: 12.5, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
