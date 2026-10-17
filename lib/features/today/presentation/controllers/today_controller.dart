import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/services/gufi_backend_store.dart';
import '../../../auth/domain/models/user_profile.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../commitments/domain/models/accountability_scope.dart';
import '../../../commitments/domain/models/commitment.dart';
import '../../../commitments/domain/models/commitment_status.dart';
import '../../../commitments/domain/models/daily_result.dart';
import '../../../commitments/domain/models/momentum_result.dart';
import '../../../commitments/domain/models/proof.dart';
import '../../../commitments/domain/models/proof_type.dart';
import '../../../commitments/domain/models/review.dart';
import '../../../commitments/domain/utils/gufi_day_utils.dart';
import '../../../commitments/presentation/providers/commitment_providers.dart';
import '../../domain/models/review_request_item.dart';
import 'today_state.dart';

final todayControllerProvider = NotifierProvider<TodayController, TodayState>(
  TodayController.new,
);

class TodayController extends Notifier<TodayState> {
  @override
  TodayState build() {
    Future.microtask(() => loadToday());
    return const TodayState();
  }

  Future<void> loadToday({bool force = false}) async {
    if (!force && !state.loading && state.currentUser != null) {
      // Don't flash loading if we already have data
    } else {
      state = state.copyWith(loading: true, clearError: true);
    }

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final commitmentRepo = ref.read(commitmentRepositoryProvider);
      final momentumRepo = ref.read(momentumRepositoryProvider);
      final reviewRepo = ref.read(reviewRepositoryProvider);

      UserProfile? user = authRepo.currentUserProfile;
      user ??= await authRepo.fetchCurrentProfile();

      if (user == null) {
        state = state.copyWith(
          loading: false,
          error: 'Please log in to see Today.',
        );
        return;
      }

      final gufiDay = GufiDayUtils.getGufiDayForTimestamp(
        DateTime.now().toUtc(),
      );

      // Fetch core commitments
      List<Commitment> commitments = [];
      try {
        commitments = await commitmentRepo.getUserCommitmentsForDay(
          userId: user.id,
          gufiDay: gufiDay,
        );
      } catch (e) {
        state = state.copyWith(
          loading: false,
          error: 'Failed to load commitments: $e',
        );
        return;
      }

      // Fetch non-core data in parallel without letting non-core failures destroy the page
      MomentumResult? momentum;
      DailyResult? dailyResult;
      List<ReviewRequestItem> reviewRequests = [];
      final Map<String, String> verifierNames = {};

      await Future.wait([
        // Momentum
        () async {
          try {
            momentum = await momentumRepo.getMomentum(
              userId: user!.id,
              currentGufiDay: gufiDay,
            );
          } catch (_) {
            momentum = MomentumResult.neutral();
          }
        }(),

        // Daily Result
        () async {
          try {
            dailyResult = await momentumRepo.getDailyResult(
              userId: user!.id,
              gufiDay: gufiDay,
            );
          } catch (_) {}
        }(),

        // Review requests
        () async {
          try {
            reviewRequests = await _fetchReviewRequests(user!.id);
          } catch (_) {}
        }(),

        // Verifier names for verified commitments
        () async {
          for (final c in commitments) {
            if (c.status == CommitmentStatus.verified) {
              try {
                final reviews = await reviewRepo.getReviewsForCommitment(c.id);
                final approved = reviews
                    .where((r) => r.decision == ReviewDecision.approved)
                    .firstOrNull;
                if (approved != null) {
                  final verifierName = await _fetchUserName(
                    approved.reviewerId,
                  );
                  if (verifierName != null && verifierName.isNotEmpty) {
                    verifierNames[c.id] = verifierName;
                  }
                }
              } catch (_) {}
            }
          }
        }(),
      ]);

      state = state.copyWith(
        currentUser: user,
        gufiDay: gufiDay,
        momentum: momentum,
        commitments: commitments,
        dailyResult: dailyResult,
        reviewRequests: reviewRequests,
        verifierNamesByCommitmentId: verifierNames,
        loading: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> createAndCommit({
    required String title,
    String? circleId,
    AccountabilityScope? accountabilityScope,
    DateTime? dueAt,
  }) async {
    final user = state.currentUser;
    if (user == null) return;

    final gufiDay = state.gufiDay.isNotEmpty
        ? state.gufiDay
        : GufiDayUtils.getGufiDayForTimestamp(DateTime.now().toUtc());

    final fallbackDueAt =
        dueAt ??
        DateTime.now().toUtc().add(
          const Duration(hours: 12),
        ); // Default to end of day window

    final scope =
        accountabilityScope ??
        (circleId != null
            ? AccountabilityScope.circle
            : AccountabilityScope.private);

    final commitmentRepo = ref.read(commitmentRepositoryProvider);
    final draft = await commitmentRepo.createDraft(
      ownerId: user.id,
      circleId: scope.isCircle ? circleId : null,
      accountabilityScope: scope,
      title: title.trim(),
      gufiDay: gufiDay,
      dueAt: fallbackDueAt,
    );

    await commitmentRepo.commit(draft.id);
    await loadToday(force: true);
  }

  Future<void> addTextProof({
    required String commitmentId,
    required String textContent,
  }) async {
    final user = state.currentUser;
    if (user == null) return;

    final proofRepo = ref.read(proofRepositoryProvider);
    await proofRepo.submitProof(
      commitmentId: commitmentId,
      submitterId: user.id,
      proofType: ProofType.text,
      textContent: textContent.trim(),
    );

    await loadToday(force: true);
  }

  Future<void> addPhotoProof({
    required String commitmentId,
    required String mediaUrl,
  }) async {
    final user = state.currentUser;
    if (user == null) return;

    final proofRepo = ref.read(proofRepositoryProvider);
    await proofRepo.submitProof(
      commitmentId: commitmentId,
      submitterId: user.id,
      proofType: ProofType.photo,
      mediaUrl: mediaUrl.trim(),
    );

    await loadToday(force: true);
  }

  Future<void> reviewProof({
    required String proofId,
    required ReviewDecision decision,
    String? reason,
  }) async {
    final user = state.currentUser;
    if (user == null) return;

    final reviewRepo = ref.read(reviewRepositoryProvider);
    await reviewRepo.reviewProof(
      proofId: proofId,
      reviewerId: user.id,
      decision: decision,
      reason: reason,
    );

    await loadToday(force: true);
  }

  // --- Helper loading methods ---

  Future<List<ReviewRequestItem>> _fetchReviewRequests(String userId) async {
    final List<ReviewRequestItem> items = [];

    if (SupabaseConfig.isConfigured) {
      final client = Supabase.instance.client;
      // 1. Get user active circle memberships
      final memberRows = await client
          .from('circle_members')
          .select('circle_id')
          .eq('user_id', userId)
          .eq('status', 'active');

      final circleIds = (memberRows as List)
          .map((r) => r['circle_id'] as String)
          .toList();

      if (circleIds.isEmpty) return items;

      // 2. Query peer commitments awaiting proof review in these circles
      final commitmentRows = await client
          .from('commitments')
          .select()
          .inFilter('circle_id', circleIds)
          .neq('owner_id', userId)
          .eq('status', 'proof_submitted');

      for (final cRow in (commitmentRows as List)) {
        final commitment = Commitment.fromJson(cRow);
        // Find latest submitted proof
        final proofRows = await client
            .from('proofs')
            .select()
            .eq('commitment_id', commitment.id)
            .eq('status', 'submitted')
            .order('created_at', ascending: false)
            .limit(1);

        if ((proofRows as List).isEmpty) continue;
        final proof = Proof.fromJson(proofRows.first);

        // Check if current user has already reviewed this proof
        final existingReview = await client
            .from('reviews')
            .select('id')
            .eq('proof_id', proof.id)
            .eq('reviewer_id', userId);

        if ((existingReview as List).isNotEmpty) continue;

        // Fetch submitter info
        final userRow = await client
            .from('users')
            .select()
            .eq('id', commitment.ownerId)
            .single();

        final submitterProfile = UserProfile.fromJson(userRow);

        final submitterName =
            (submitterProfile.displayName != null &&
                submitterProfile.displayName!.isNotEmpty)
            ? submitterProfile.displayName!
            : submitterProfile.username;

        items.add(
          ReviewRequestItem(
            proof: proof,
            commitment: commitment,
            submitterName: submitterName,
            submitterUsername: submitterProfile.username,
            submitterAvatarUrl: submitterProfile.profilePhotoUrl,
          ),
        );
      }
    } else {
      // Local In-Memory backend store parity
      final store = GufiBackendStore.instance;
      final userCircles = store.getUserCircles(userId);
      final circleIds = userCircles.map((c) => c.id).toSet();

      final allCommitments = store.getAllCommitments();
      for (final c in allCommitments) {
        if (c.circleId != null &&
            circleIds.contains(c.circleId) &&
            c.ownerId != userId &&
            c.status == CommitmentStatus.proofSubmitted) {
          final proofs = store.getProofsForCommitment(c.id);
          final submitted = proofs
              .where((p) => p.status == ProofStatus.submitted)
              .firstOrNull;
          if (submitted == null) continue;

          // Check if already reviewed
          final reviews = store.getReviewsForProof(submitted.id);
          final alreadyReviewed = reviews.any((r) => r.reviewerId == userId);
          if (alreadyReviewed) continue;

          final submitter = store.getUserById(c.ownerId);
          final name =
              submitter != null &&
                  submitter.displayName != null &&
                  submitter.displayName!.isNotEmpty
              ? submitter.displayName!
              : (submitter?.username ?? 'Friend');

          items.add(
            ReviewRequestItem(
              proof: submitted,
              commitment: c,
              submitterName: name,
              submitterUsername: submitter?.username ?? 'friend',
              submitterAvatarUrl: submitter?.profilePhotoUrl,
            ),
          );
        }
      }
    }

    return items;
  }

  Future<String?> _fetchUserName(String userId) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final row = await Supabase.instance.client
            .from('users')
            .select('display_name, username')
            .eq('id', userId)
            .single();
        final displayName = row['display_name'] as String?;
        if (displayName != null && displayName.isNotEmpty) return displayName;
        return row['username'] as String?;
      } catch (_) {
        return null;
      }
    } else {
      final user = GufiBackendStore.instance.getUserById(userId);
      if (user != null) {
        return (user.displayName != null && user.displayName!.isNotEmpty)
            ? user.displayName
            : user.username;
      }
      return null;
    }
  }
}
