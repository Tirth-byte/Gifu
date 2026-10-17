import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/core/services/gufi_backend_store.dart';
import 'package:gufi/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:gufi/features/auth/domain/models/user_profile.dart';
import 'package:gufi/features/commitments/domain/models/commitment_status.dart';
import 'package:gufi/features/commitments/domain/models/proof_type.dart';
import 'package:gufi/features/commitments/domain/models/review.dart';
import 'package:gufi/features/commitments/domain/utils/gufi_day_utils.dart';
import 'package:gufi/features/today/presentation/components/friend_review_card.dart';
import 'package:gufi/features/today/presentation/components/today_commitment_card.dart';
import 'package:gufi/features/today/presentation/controllers/today_controller.dart';
import 'package:gufi/features/today/presentation/today_page.dart';

void main() {
  final store = GufiBackendStore.instance;
  final authRepo = SupabaseAuthRepository.instance;

  setUp(() {
    store.reset();
    authRepo.setSessionForTesting(null);
  });

  UserProfile setupTestUser({
    String id = 'usr-1',
    String username = 'tirth09',
    String displayName = 'Tirth Patel',
  }) {
    final now = DateTime.utc(2026, 10, 16);
    final profile = UserProfile(
      id: id,
      email: '$username@gufi.app',
      emailNormalized: '$username@gufi.app',
      emailVerified: true,
      username: username,
      usernameNormalized: username,
      displayName: displayName,
      onboardingCompleted: true,
      createdAt: now,
      updatedAt: now,
    );
    authRepo.setSessionForTesting(profile);
    return profile;
  }

  testWidgets('Today screen renders empty day state correctly', (
    WidgetTester tester,
  ) async {
    setupTestUser();

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TodayPage())),
    );
    await tester.pumpAndSettle();

    // Wordmark & Top bar
    expect(find.text('Gufi'), findsOneWidget);

    // Hero content
    expect(find.text('Today'), findsNWidgets(2)); // Hero card + bottom nav tab
    expect(find.text('Your day is open.'), findsOneWidget);
    expect(find.text('Make one promise worth keeping.'), findsOneWidget);

    // Momentum unavailable copy
    expect(
      find.text('Momentum starts\nwith your first promise.'),
      findsOneWidget,
    );

    // CTA
    expect(find.text('Make a promise'), findsOneWidget);

    // Bottom nav tabs
    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Activity'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('Today screen renders real commitments and handles Add Proof', (
    WidgetTester tester,
  ) async {
    final user = setupTestUser();
    final today = GufiDayUtils.getGufiDayForTimestamp(DateTime.now().toUtc());

    // Create 2 commitments: 1 committed (photo), 1 verified
    final draft1 = store.createDraftCommitment(
      ownerId: user.id,
      title: 'Finish DBMS notes before 8',
      proofType: ProofType.photo,
      gufiDay: today,
      dueAt: DateTime.now().toUtc().add(const Duration(hours: 4)),
    );
    store.commitCommitment(draft1.id);

    final draft2 = store.createDraftCommitment(
      ownerId: user.id,
      title: 'Run 3 km',
      proofType: ProofType.text,
      gufiDay: today,
      dueAt: DateTime.now().toUtc().add(const Duration(hours: 6)),
    );
    store.commitCommitment(draft2.id);
    final proof2 = store.submitProof(
      commitmentId: draft2.id,
      submitterId: user.id,
      proofType: ProofType.text,
      textContent: 'Ran 3.2km in 18 minutes',
    );

    final reviewer = UserProfile(
      id: 'reviewer-dhyati',
      email: 'dhyati@gufi.app',
      emailNormalized: 'dhyati@gufi.app',
      emailVerified: true,
      username: 'dhyati',
      usernameNormalized: 'dhyati',
      displayName: 'Dhyati',
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    store.saveUser(reviewer);

    store.reviewProof(
      proofId: proof2.id,
      reviewerId: reviewer.id,
      decision: ReviewDecision.approved,
    );

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: TodayPage())),
    );
    await tester.pumpAndSettle();

    // Verify titles rendered
    expect(find.text('Finish DBMS notes before 8'), findsOneWidget);
    expect(find.text('Run 3 km'), findsOneWidget);

    // Verify secondary state texts
    expect(find.text('In progress'), findsOneWidget);
    expect(find.text('Verified by Dhyati ✓'), findsOneWidget);

    // Verify 'I did it →' action exists for the in-progress commitment
    expect(find.text('I did it →'), findsOneWidget);

    // Headline: "1 of 2 promises still in motion."
    expect(find.text('1 of 2 promises\nstill in motion.'), findsOneWidget);

    // Tap "I did it →" opens CompletionProofSheet
    await tester.tap(find.text('I did it →'));
    await tester.pumpAndSettle();

    expect(find.text('Show that you did it.'), findsOneWidget);
    expect(find.text('A little proof keeps the promise real.'), findsOneWidget);
    expect(find.text('Add a photo'), findsOneWidget);
    expect(find.text('Write a proof'), findsOneWidget);
    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose photo'), findsOneWidget);
  });

  testWidgets(
    'Make a promise creates commitment WITHOUT proof selection, then completes with text proof and supports resubmit',
    (WidgetTester tester) async {
      final user = setupTestUser();
      final circle = store.createCircle(name: 'DSA Group', ownerId: user.id);
      store.addCircleMember(circleId: circle.id, userId: user.id);

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TodayPage())),
      );
      await tester.pumpAndSettle();

      // Tap Make a promise
      await tester.tap(find.text('Make a promise'));
      await tester.pumpAndSettle();

      // Check MakePromiseSheet header & absence of proof options
      expect(find.text('What will you do?'), findsOneWidget);
      expect(
        find.text('Make one promise worth keeping today.'),
        findsOneWidget,
      );
      expect(find.text('Photo proof'), findsNothing);
      expect(find.text('Text proof'), findsNothing);

      // Enter promise title
      final inputFinder = find.byType(TextField);
      expect(inputFinder, findsOneWidget);
      await tester.enterText(inputFinder, 'Read chapter 3 before dinner');
      await tester.pumpAndSettle();

      // Tap Commit button (Section 2: CTA is 'Commit')
      await tester.tap(find.text('Commit'));
      await tester.pumpAndSettle();

      // Commitment row appears in Today UI in committed state
      expect(find.text('Read chapter 3 before dinner'), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('I did it →'), findsOneWidget);

      // Verify no proof record was created
      final commitments = store
          .getAllCommitments()
          .where((c) => c.ownerId == user.id)
          .toList();
      expect(commitments.length, 1);
      final commitment = commitments.first;
      expect(commitment.status, CommitmentStatus.committed);
      expect(store.getProofsForCommitment(commitment.id), isEmpty);

      // Tap 'I did it →' to open CompletionProofSheet
      await tester.tap(find.text('I did it →'));
      await tester.pumpAndSettle();

      expect(find.text('Show that you did it.'), findsOneWidget);

      // Switch to text proof
      await tester.tap(find.text('Write a proof'));
      await tester.pumpAndSettle();

      expect(find.text('What did you complete?'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Finished all 25 pages of chapter 3.',
      );
      await tester.pumpAndSettle();

      // Submit proof
      await tester.tap(find.text('Submit proof'));
      await tester.pumpAndSettle();

      // Row updates to 'Waiting for review'
      expect(find.text('Waiting for review'), findsOneWidget);
      expect(find.text('I did it →'), findsNothing);

      // Reject proof to test rejection and resubmission
      final proofs = store.getProofsForCommitment(commitment.id);
      expect(proofs, isNotEmpty);
      final proof = proofs.last;

      final reviewer = UserProfile(
        id: 'reviewer-peer',
        email: 'peer@gufi.app',
        emailNormalized: 'peer@gufi.app',
        emailVerified: true,
        username: 'peer',
        usernameNormalized: 'peer',
        displayName: 'Peer',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      store.saveUser(reviewer);
      store.addCircleMember(circleId: circle.id, userId: reviewer.id);

      store.reviewProof(
        proofId: proof.id,
        reviewerId: reviewer.id,
        decision: ReviewDecision.rejected,
        reason: 'Too brief, please show more detail.',
      );

      // Peer reviewed on another device -> reload today state
      final element = tester.element(find.byType(TodayPage));
      final container = ProviderScope.containerOf(element);
      await container
          .read(todayControllerProvider.notifier)
          .loadToday(force: true);
      await tester.pumpAndSettle();

      // Row should show 'Proof needs another look' and 'Resubmit →'
      expect(find.text('Proof needs another look'), findsOneWidget);
      expect(find.text('Resubmit →'), findsOneWidget);

      // Tap 'Resubmit →' opens CompletionProofSheet
      await tester.tap(find.text('Resubmit →'));
      await tester.pumpAndSettle();

      expect(find.text('Show that you did it.'), findsOneWidget);
      // Can choose Photo or Text again (not locked!)
      expect(find.text('Add a photo'), findsOneWidget);
      expect(find.text('Write a proof'), findsOneWidget);
    },
  );

  testWidgets(
    'Private promise flow: selectable, shows explanation, transitions directly to Completed without peer review, excluded from verified Momentum',
    (WidgetTester tester) async {
      final user = setupTestUser();

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TodayPage())),
      );
      await tester.pumpAndSettle();

      // Tap Make a promise
      await tester.tap(find.text('Make a promise'));
      await tester.pumpAndSettle();

      // Enter title
      await tester.enterText(
        find.byType(TextField),
        'Read 10 pages before sleep',
      );
      await tester.pumpAndSettle();

      // Open accountability picker
      await tester.tap(find.text('Choose a circle'));
      await tester.pumpAndSettle();

      // Choose "Keep it private"
      expect(find.text('Keep it private'), findsOneWidget);
      await tester.tap(find.text('Keep it private'));
      await tester.pumpAndSettle();

      // Explanatory note is visible
      expect(
        find.text(
          "Private promises aren't peer-verified and don't affect Momentum.",
        ),
        findsOneWidget,
      );

      // Commit
      await tester.tap(find.text('Commit'));
      await tester.pumpAndSettle();

      // Row appears in Today UI with "Private" and action "I did it →"
      expect(find.text('Read 10 pages before sleep'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('I did it →'), findsOneWidget);

      // Tap "I did it →" to open completion sheet
      await tester.tap(find.text('I did it →'));
      await tester.pumpAndSettle();

      // Switch to text and enter proof
      await tester.tap(find.text('Write a proof'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Read chapters 1 and 2.');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Submit proof'));
      await tester.pumpAndSettle();

      // Row transitions directly to "Completed" (NOT "Waiting for review"!)
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Waiting for review'), findsNothing);
      expect(find.text('I did it →'), findsNothing);

      // Private promise does NOT generate peer review requests
      expect(find.byType(FriendReviewCard), findsNothing);

      // Verify that Momentum remains unavailable (0% inflation from private commitments)
      final momentum = store.getMomentum(
        userId: user.id,
        currentGufiDay: GufiDayUtils.getGufiDayForTimestamp(
          DateTime.now().toUtc(),
        ),
      );
      expect(momentum.isAvailable, isFalse);
      expect(momentum.score, isNull);
    },
  );

  testWidgets(
    'Daily limit of 3 commitments disables CTA and shows quiet completed state',
    (WidgetTester tester) async {
      final user = setupTestUser();
      final today = GufiDayUtils.getGufiDayForTimestamp(DateTime.now().toUtc());

      for (var i = 1; i <= 3; i++) {
        final draft = store.createDraftCommitment(
          ownerId: user.id,
          title: 'Promise $i',
          proofType: ProofType.photo,
          gufiDay: today,
          dueAt: DateTime.now().toUtc().add(Duration(hours: i + 1)),
        );
        store.commitCommitment(draft.id);
      }

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TodayPage())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TodayCommitmentCard), findsNWidgets(3));
      expect(find.text('3 promises made today'), findsOneWidget);
      expect(find.text('+ Make a promise'), findsNothing);
    },
  );

  testWidgets(
    'Friend review request renders human card and opens review modal',
    (WidgetTester tester) async {
      final user = setupTestUser();
      final friend = UserProfile(
        id: 'friend-manish',
        email: 'manish@gufi.app',
        emailNormalized: 'manish@gufi.app',
        emailVerified: true,
        username: 'manish',
        usernameNormalized: 'manish',
        displayName: 'Manish',
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );
      store.saveUser(friend);

      // Create shared circle
      final circle = store.createCircle(
        name: 'Morning Study',
        ownerId: friend.id,
      );
      store.addCircleMember(circleId: circle.id, userId: friend.id);
      store.addCircleMember(circleId: circle.id, userId: user.id);

      // Friend commits and submits text proof
      final today = GufiDayUtils.getGufiDayForTimestamp(DateTime.now().toUtc());
      final draft = store.createDraftCommitment(
        ownerId: friend.id,
        circleId: circle.id,
        title: 'Read 20 pages',
        proofType: ProofType.text,
        gufiDay: today,
        dueAt: DateTime.now().toUtc().add(const Duration(hours: 4)),
      );
      store.commitCommitment(draft.id);
      store.submitProof(
        commitmentId: draft.id,
        submitterId: friend.id,
        proofType: ProofType.text,
        textContent: 'Completed chapter 4 on operating systems.',
      );

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TodayPage())),
      );
      await tester.pumpAndSettle();

      // Verify FriendReviewCard rendered
      expect(find.byType(FriendReviewCard), findsOneWidget);
      expect(find.text('Manish needs you.'), findsOneWidget);
      expect(find.text('"Read 20 pages"'), findsOneWidget);
      expect(find.text('Review proof'), findsOneWidget);

      // Tap Review proof
      await tester.tap(find.text('Review proof'));
      await tester.pumpAndSettle();

      // Verify Review Modal opened
      expect(find.text('Looks good'), findsOneWidget);
      expect(find.text('Ask for another proof'), findsOneWidget);
      expect(
        find.text('Completed chapter 4 on operating systems.'),
        findsOneWidget,
      );

      // Tap Looks good to approve
      await tester.tap(find.text('Looks good'));
      await tester.pumpAndSettle();

      // Review card disappears because proof has been reviewed!
      expect(find.byType(FriendReviewCard), findsNothing);
    },
  );

  testWidgets(
    'Bottom navigation switches to Friends, Activity, and Profile placeholders',
    (WidgetTester tester) async {
      setupTestUser(displayName: 'Tirth Patel', username: 'tirth09');

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TodayPage())),
      );
      await tester.pumpAndSettle();

      // Tap Friends tab
      await tester.tap(find.text('Friends'));
      await tester.pumpAndSettle();

      expect(find.text('Friends'), findsNWidgets(2)); // tab item + title
      expect(find.text('Coming next.'), findsOneWidget);

      // Tap Activity tab
      await tester.tap(find.text('Activity'));
      await tester.pumpAndSettle();

      expect(find.text('Activity'), findsNWidgets(2));
      expect(find.text('Coming next.'), findsOneWidget);

      // Tap Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      expect(find.text('Tirth Patel'), findsOneWidget);
      expect(find.text('@tirth09'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);

      // Tap Today tab to return
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      expect(find.text('Your day is open.'), findsOneWidget);
    },
  );
}
