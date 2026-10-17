import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/haptics/app_haptics.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/data/repositories/supabase_auth_repository.dart';
import '../../auth/domain/models/user_profile.dart';
import '../../commitments/domain/models/commitment.dart';
import 'components/completion_proof_sheet.dart';
import 'components/friend_review_card.dart';
import 'components/make_promise_sheet.dart';
import 'components/review_proof_sheet.dart';
import 'components/today_bottom_nav.dart';
import 'components/today_commitment_card.dart';
import 'components/today_hero_card.dart';
import 'components/today_top_bar.dart';
import 'controllers/today_controller.dart';
import 'controllers/today_state.dart';

/// The canonical Gufi Today Screen.
/// Replaces the old /coming-soon holding screen.
class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({super.key});

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage> {
  int _currentTabIndex = 0;

  static const Color canvasBg = Color(0xFFFFFFFF);
  static const Color primaryBlue = Color(0xFF5880DA);
  static const Color gufiNavy = Color(0xFF1E3365);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(todayControllerProvider);

    return Scaffold(
      backgroundColor: canvasBg,
      body: SafeArea(
        bottom: false,
        child: _currentTabIndex == 0
            ? _buildTodayTab(state)
            : _buildPlaceholderTab(_currentTabIndex, state.currentUser),
      ),
      bottomNavigationBar: TodayBottomNav(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
      ),
    );
  }

  Widget _buildTodayTab(TodayState state) {
    if (state.loading &&
        state.commitments.isEmpty &&
        state.currentUser == null) {
      return _buildSkeletonView();
    }

    if (state.error != null && state.commitments.isEmpty) {
      return _buildErrorView(state.error!);
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(todayControllerProvider.notifier).loadToday(force: true),
      color: primaryBlue,
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A. Top Bar
            TodayTopBar(
              user: state.currentUser,
              onAvatarTap: () => setState(() => _currentTabIndex = 3),
            ),

            const SizedBox(height: 8),

            // B. Hero Today Card
            TodayHeroCard(state: state),

            const SizedBox(height: 24),

            // C. Today Commitments (Max 3)
            if (state.commitments.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Promises',
                      style: AppTypography.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: gufiNavy.withValues(alpha: 0.6),
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      '${state.commitments.length} of 3',
                      style: AppTypography.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: gufiNavy.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              ...state.commitments.map((commitment) {
                final verifier =
                    state.verifierNamesByCommitmentId[commitment.id];
                return TodayCommitmentCard(
                  commitment: commitment,
                  verifierName: verifier,
                  onComplete: () => _openCompletionProofSheet(commitment),
                );
              }),
            ],

            // D. Friend Review Request (if peer proof needs review)
            if (state.reviewRequests.isNotEmpty) ...[
              const SizedBox(height: 16),
              FriendReviewCard(
                item: state.reviewRequests.first,
                totalWaitingCount: state.reviewRequests.length,
                onReviewTap: () => _openReviewSheet(state.reviewRequests.first),
              ),
            ],

            const SizedBox(height: 24),

            // E. Make a Promise CTA
            _buildMakePromiseCta(state),
          ],
        ),
      ),
    );
  }

  Widget _buildMakePromiseCta(TodayState state) {
    if (!state.canCreateCommitment) {
      // 3 promises already made today: show quiet completed badge (Section 19)
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.symmetric(vertical: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: gufiNavy.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: gufiNavy.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
        child: Center(
          child: Text(
            '3 promises made today',
            style: AppTypography.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: gufiNavy.withValues(alpha: 0.7),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: _openMakePromiseSheet,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                'Make a promise',
                style: AppTypography.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Modals ---

  void _openMakePromiseSheet() {
    AppHaptics.light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MakePromiseSheet(
        onCommit:
            ({required title, circleId, required accountabilityScope, dueAt}) {
              return ref
                  .read(todayControllerProvider.notifier)
                  .createAndCommit(
                    title: title,
                    circleId: circleId,
                    accountabilityScope: accountabilityScope,
                    dueAt: dueAt,
                  );
            },
      ),
    );
  }

  void _openCompletionProofSheet(Commitment commitment) {
    AppHaptics.light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CompletionProofSheet(
        commitment: commitment,
        onSubmitText: (text) {
          return ref
              .read(todayControllerProvider.notifier)
              .addTextProof(commitmentId: commitment.id, textContent: text);
        },
        onSubmitPhoto: (url) {
          return ref
              .read(todayControllerProvider.notifier)
              .addPhotoProof(commitmentId: commitment.id, mediaUrl: url);
        },
      ),
    );
  }

  void _openReviewSheet(dynamic requestItem) {
    AppHaptics.light();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewProofSheet(
        item: requestItem,
        onReview: ({required decision, reason}) {
          return ref
              .read(todayControllerProvider.notifier)
              .reviewProof(
                proofId: requestItem.proof.id,
                decision: decision,
                reason: reason,
              );
        },
      ),
    );
  }

  // --- Skeleton loading state ---

  Widget _buildSkeletonView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gufi',
                  style: TextStyle(
                    fontFamily: AppTypography.gambarinoFontFamily,
                    fontSize: 30,
                    color: gufiNavy,
                  ),
                ),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: gufiNavy.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Hero skeleton
          Container(
            height: 220,
            margin: const EdgeInsets.symmetric(horizontal: 22),
            decoration: BoxDecoration(
              color: primaryBlue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(30),
            ),
          ),

          const SizedBox(height: 24),

          // Commitment row skeletons
          ...List.generate(
            2,
            (_) => Container(
              height: 74,
              margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: gufiNavy.withValues(alpha: 0.06)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: primaryBlue),
            const SizedBox(height: 16),
            Text(
              "Couldn't load Today",
              style: TextStyle(
                fontFamily: AppTypography.gambarinoFontFamily,
                fontSize: 22,
                color: gufiNavy,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: AppTypography.inter(
                fontSize: 14,
                color: gufiNavy.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref
                  .read(todayControllerProvider.notifier)
                  .loadToday(force: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Route-safe unbuilt tab placeholders (Section 22) ---

  Widget _buildPlaceholderTab(int index, UserProfile? user) {
    final title = index == 1
        ? 'Friends'
        : index == 2
        ? 'Activity'
        : 'Profile';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (index == 3) ...[
              // Profile info with Logout capability
              UserAvatar(
                photoUrl: user?.profilePhotoUrl,
                fallbackInitial:
                    (user?.displayName != null && user!.displayName!.isNotEmpty)
                    ? user.displayName![0].toUpperCase()
                    : (user?.username.isNotEmpty == true
                          ? user!.username[0].toUpperCase()
                          : 'G'),
                size: 72,
                backgroundColor: const Color(0xFFBCDBFA),
                borderColor: const Color(0xFF1E3365).withValues(alpha: 0.12),
                borderWidth: 2,
                textStyle: TextStyle(
                  fontFamily: AppTypography.gambarinoFontFamily,
                  fontSize: 32,
                  color: gufiNavy,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                (user?.displayName != null && user!.displayName!.isNotEmpty)
                    ? user.displayName!
                    : (user?.username ?? 'Gufi User'),
                style: TextStyle(
                  fontFamily: AppTypography.gambarinoFontFamily,
                  fontSize: 26,
                  color: gufiNavy,
                ),
              ),
              if (user != null && user.username.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  '@${user.username}',
                  style: AppTypography.inter(
                    fontSize: 15,
                    color: gufiNavy.withValues(alpha: 0.6),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () async {
                  AppHaptics.light();
                  await SupabaseAuthRepository.instance.signOut();
                  if (mounted) {
                    context.go('/auth');
                  }
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: gufiNavy.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  'Log out',
                  style: AppTypography.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: gufiNavy,
                  ),
                ),
              ),
            ] else ...[
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTypography.gambarinoFontFamily,
                  fontSize: 28,
                  color: gufiNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coming next.',
                style: AppTypography.inter(
                  fontSize: 15,
                  color: gufiNavy.withValues(alpha: 0.55),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
