import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/services/gufi_backend_store.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/account_action_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/repositories/supabase_auth_repository.dart';
import '../data/repositories/supabase_circle_repository.dart';
import '../domain/models/circle.dart';
import '../domain/models/circle_invite.dart';
import '../domain/models/circle_member.dart';

/// Create Circle — Step 2: "Bring your people in"
///
/// Pure white canvas (#FFFFFF) + purposeful Gufi brand color accents.
///
/// Flow:
/// 1. Creator arrives after circle creation in Step 1.
/// 2. 1 active member: WAITING STATE
///    - Headline: "Bring your people in."
///    - Subtitle: "A Circle becomes real when someone joins you."
///    - Warm 2-person social motif: [YOU] ··· [+]
///    - Coherent grouped invitation block:
///        - "Share invite" primary CTA (native share sheet)
///        - Usable Invite Code container with inline "Copy" / "Copied ✓"
///        - "Show QR code" row -> clean white bottom sheet with QR
///    - Warm waiting status:
///        "Waiting for your first person.
///         As soon as someone joins, your Circle is ready."
/// 3. Realtime stream detects 2+ active members: READY STATE
///    - Smooth local transform (no automatic navigation!)
///    - Headline: "You’re ready."
///    - Subtitle: "Your Circle has its first teammate."
///    - Motif: [YOU avatar] [FRIEND avatar] with real member data
///    - Primary CTA: "Make your first promise" -> routes to /today
class CircleInvitePage extends StatefulWidget {
  final String circleId;

  const CircleInvitePage({super.key, required this.circleId});

  @override
  State<CircleInvitePage> createState() => _CircleInvitePageState();
}

class _CircleInvitePageState extends State<CircleInvitePage> {
  static const Color canvasColor = Color(0xFFFFFFFF);
  static const Color gufiNavy = Color(0xFF1E3365);
  static const Color gufiBlue = Color(0xFF5880DA);
  static const Color surfaceSoft = Color(0xFFFAFBFC);
  static const Color cardBorder = Color(0xFFE2EAF4);
  static const Color mutedSlate = Color(0xFF5C6E8C);

  Circle? _circle;
  CircleInvite? _invite;
  List<CircleMember> _members = [];
  bool _isLoading = true;
  bool _isCopied = false;
  Timer? _copiedTimer;
  Timer? _pollTimer;
  StreamSubscription<void>? _dataSub;
  StreamSubscription<List<CircleMember>>? _membersSub;

  @override
  void initState() {
    super.initState();
    _loadData();
    _dataSub = GufiBackendStore.instance.onDataChanged.listen((_) {
      if (mounted) {
        _loadData(isRefresh: true);
      }
    });
    _membersSub = SupabaseCircleRepository.instance
        .watchCircleMembers(widget.circleId)
        .listen((members) {
          if (mounted) {
            setState(() {
              _members = members;
            });
          }
        });
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && _members.length < 2) {
        _loadData(isRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _pollTimer?.cancel();
    _dataSub?.cancel();
    _membersSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() => _isLoading = true);
    }

    try {
      final circleRepo = SupabaseCircleRepository.instance;
      final circle = await circleRepo.getCircle(widget.circleId);
      final invite = await circleRepo.getActiveInviteForCircle(widget.circleId);
      final members = await circleRepo.getCircleMembers(widget.circleId);

      if (mounted) {
        setState(() {
          _circle = circle;
          _invite = invite;
          _members = members.where((m) => m.isActive).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && !isRefresh) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _isReady => _members.length >= 2;

  String get _inviteUrl {
    final code = _invite?.code ?? '';
    return AppConfig.buildInviteLink(code);
  }

  String get _shareText {
    final circleName = _circle?.name ?? 'Circle';
    final code = _invite?.code ?? '';
    return AppConfig.buildShareText(circleName: circleName, code: code);
  }

  void _handleShare() {
    AppHaptics.selection();
    SharePlus.instance.share(ShareParams(text: _shareText));
  }

  void _handleCopyCode() {
    final code = _invite?.code;
    if (code == null || code.isEmpty) return;

    AppHaptics.selection();
    Clipboard.setData(ClipboardData(text: code));
    _copiedTimer?.cancel();
    setState(() => _isCopied = true);
    _copiedTimer = Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() => _isCopied = false);
      }
    });
  }

  void _showQrBottomSheet() {
    AppHaptics.selection();
    final circleName = _circle?.name ?? 'Circle';
    final inviteCode = _invite?.code ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pill handle
                Container(
                  width: 38,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: cardBorder,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
                const SizedBox(height: 20),

                // Circle Name
                Text(
                  circleName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTypography.gambarinoFontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: gufiNavy,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),

                // Subtitle
                Text(
                  'Scan to join this Circle',
                  style: AppTypography.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: mutedSlate,
                  ),
                ),
                const SizedBox(height: 24),

                // QR Code Container
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cardBorder, width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: gufiNavy.withValues(alpha: 0.05),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: _inviteUrl,
                    version: QrVersions.auto,
                    size: 190.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: gufiNavy,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: gufiNavy,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Invite code pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cardBorder, width: 0.8),
                  ),
                  child: Text(
                    inviteCode,
                    style: AppTypography.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: gufiNavy,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Done CTA
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () {
                      AppHaptics.selection();
                      Navigator.of(bottomSheetContext).pop();
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: surfaceSoft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: cardBorder),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: AppTypography.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: gufiNavy,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleMakePromise() {
    AppHaptics.selection();
    // Creator explicitly confirmed readiness; route to Today
    context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.height < 750;

    // Fluid spacing
    final gapTopToHeadline = isCompact ? 16.0 : 24.0;
    final gapHeadlineToSubtitle = isCompact ? 8.0 : 10.0;
    final gapSubtitleToMotif = isCompact ? 22.0 : 32.0;
    final gapMotifToActions = isCompact ? 22.0 : 32.0;
    final gapBetweenActions = isCompact ? 10.0 : 12.0;
    final gapActionsToFooter = isCompact ? 16.0 : 24.0;

    return Scaffold(
      backgroundColor: canvasColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CupertinoActivityIndicator(radius: 12, color: gufiBlue),
              )
            : Column(
                children: [
                  // 1. Top Navigation Bar
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
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              context.go('/circle-entry');
                            }
                          },
                        ),
                        Text(
                          'Create a Circle',
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

                  // 2. Main Content Group
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: gapTopToHeadline),

                          // Editorial Headline
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isReady
                                  ? 'You’re ready.'
                                  : 'Bring your people in.',
                              key: ValueKey<bool>(_isReady),
                              style: TextStyle(
                                fontFamily: AppTypography.gambarinoFontFamily,
                                fontSize: isCompact ? 28 : 32,
                                fontWeight: FontWeight.w400,
                                color: gufiNavy,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                          ),

                          SizedBox(height: gapHeadlineToSubtitle),

                          // Subtitle
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isReady ? 'Your Circle has its first teammate.' : 'A Circle becomes real\nwhen someone joins you.',
                              key: ValueKey<bool>(_isReady),
                              style: AppTypography.inter(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w400,
                                color: mutedSlate,
                                height: 1.35,
                              ),
                            ),
                          ),

                          SizedBox(height: gapSubtitleToMotif),

                          // Social Motif & Circle Header
                          Center(
                            child: _isReady
                                ? _buildReadyMotif()
                                : _buildWaitingMotif(),
                          ),

                          SizedBox(height: gapMotifToActions),

                          // Actions block
                          if (_isReady)
                            _buildReadyActions()
                          else
                            _buildWaitingActions(
                              gapBetweenActions: gapBetweenActions,
                            ),

                          SizedBox(height: gapActionsToFooter),

                          // Footer notice in Waiting state
                          if (!_isReady)
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Waiting for your first person.',
                                    style: AppTypography.inter(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                      color: gufiNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'As soon as someone joins,\nyour Circle is ready.',
                                    textAlign: TextAlign.center,
                                    style: AppTypography.inter(
                                      fontSize: 13.0,
                                      fontWeight: FontWeight.w400,
                                      color: mutedSlate,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),
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
  // WAITING STATE MOTIF: [YOU] ··· [+]
  // ==========================================
  Widget _buildWaitingMotif() {
    final currentProfile = SupabaseAuthRepository.instance.currentUserProfile;
    final initial = (currentProfile?.displayName?.isNotEmpty ?? false)
        ? currentProfile!.displayName![0].toUpperCase()
        : (currentProfile?.username.isNotEmpty ?? false)
        ? currentProfile!.username[0].toUpperCase()
        : 'Y';

    final circleName = _circle?.name ?? 'Circle';

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // YOU avatar
            Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFEFF5FC),
                    border: Border.all(color: cardBorder, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: AppTypography.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: gufiBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF5FD),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'YOU',
                    style: AppTypography.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: gufiBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),

            // Connecting dots
            Padding(
              padding: const EdgeInsets.only(bottom: 18, left: 16, right: 16),
              child: Row(
                children: List.generate(
                  4,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 4.5,
                    height: 4.5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFCBD8E9),
                    ),
                  ),
                ),
              ),
            ),

            // Empty Buddy [+]
            Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: surfaceSoft,
                    border: Border.all(
                      color: cardBorder,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignCenter,
                    ),
                  ),
                  child: const Center(
                    child: Icon(CupertinoIcons.plus, size: 20, color: gufiBlue),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cardBorder, width: 0.8),
                  ),
                  child: Text(
                    'TEAMMATE',
                    style: AppTypography.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: mutedSlate,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Circle name & member count
        Text(
          circleName,
          style: AppTypography.inter(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: gufiNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '1 member',
          style: AppTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: mutedSlate,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // READY STATE MOTIF: [YOU] [FRIEND]
  // ==========================================
  Widget _buildReadyMotif() {
    final circleName = _circle?.name ?? 'Circle';
    final currentProfile = SupabaseAuthRepository.instance.currentUserProfile;
    final currentUserId = currentProfile?.id;

    // Get real members info from backend store
    final memberUsers = _members.map((m) {
      final user = GufiBackendStore.instance.getUserById(m.userId);
      final isSelf = m.userId == currentUserId;
      final displayName = user?.displayName ?? (isSelf ? 'You' : 'Member');
      final photoUrl = isSelf
          ? currentProfile?.profilePhotoUrl
          : user?.profilePhotoUrl;
      final initial = displayName.isNotEmpty
          ? displayName[0].toUpperCase()
          : 'M';
      return {
        'id': m.userId,
        'displayName': displayName,
        'initial': initial,
        'isSelf': isSelf,
        'photoUrl': photoUrl,
      };
    }).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: memberUsers.map((m) {
            final isSelf = m['isSelf'] as bool;
            final initial = m['initial'] as String;
            final displayName = m['displayName'] as String;
            final photoUrl = m['photoUrl'] as String?;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                children: [
                  UserAvatar(
                    photoUrl: photoUrl,
                    fallbackInitial: initial,
                    size: 54,
                    backgroundColor: isSelf
                        ? const Color(0xFFEFF5FC)
                        : const Color(0xFFEBF7F0),
                    borderColor: isSelf ? gufiBlue : const Color(0xFF50B47B),
                    borderWidth: 1.8,
                    textStyle: AppTypography.inter(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: isSelf ? gufiBlue : const Color(0xFF2E8A54),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    displayName,
                    style: AppTypography.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: gufiNavy,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // Circle name & member count
        Text(
          circleName,
          style: AppTypography.inter(
            fontSize: 16.5,
            fontWeight: FontWeight.w600,
            color: gufiNavy,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${_members.length} members',
          style: AppTypography.inter(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: mutedSlate,
          ),
        ),
      ],
    );
  }

  // ==========================================
  // WAITING STATE ACTIONS
  // ==========================================
  Widget _buildWaitingActions({required double gapBetweenActions}) {
    final inviteCode = _invite?.code ?? '••••••••';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Primary Action: Share invite
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _handleShare,
            style: ElevatedButton.styleFrom(
              backgroundColor: gufiBlue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              shadowColor: Colors.transparent,
            ),
            child: Text(
              'Share invite',
              style: AppTypography.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),

        SizedBox(height: gapBetweenActions),

        // 2. Usable Invite Code container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: surfaceSoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite code',
                style: AppTypography.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: mutedSlate,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    inviteCode,
                    style: AppTypography.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: gufiNavy,
                      letterSpacing: 1.2,
                    ),
                  ),
                  InkWell(
                    onTap: _handleCopyCode,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _isCopied ? 'Copied ✓' : 'Copy',
                          key: ValueKey<bool>(_isCopied),
                          style: AppTypography.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _isCopied
                                ? const Color(0xFF2E8A54)
                                : gufiBlue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        SizedBox(height: gapBetweenActions),

        // 3. Show QR code row
        InkWell(
          onTap: _showQrBottomSheet,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surfaceSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder, width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFEFF5FC),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.qrcode,
                      size: 20,
                      color: gufiBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Show QR code',
                  style: AppTypography.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: gufiNavy,
                  ),
                ),
                const Spacer(),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: mutedSlate,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // READY STATE ACTIONS
  // ==========================================
  Widget _buildReadyActions() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _handleMakePromise,
        style: ElevatedButton.styleFrom(
          backgroundColor: gufiBlue,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          shadowColor: Colors.transparent,
        ),
        child: Text(
          'Make your first promise',
          style: AppTypography.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
