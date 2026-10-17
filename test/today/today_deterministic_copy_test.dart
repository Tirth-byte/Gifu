import 'package:flutter_test/flutter_test.dart';
import 'package:gufi/features/commitments/domain/models/commitment.dart';
import 'package:gufi/features/commitments/domain/models/commitment_status.dart';
import 'package:gufi/features/commitments/domain/models/proof_type.dart';
import 'package:gufi/features/today/presentation/controllers/today_state.dart';

void main() {
  Commitment makeCommitment(String id, CommitmentStatus status) {
    return Commitment(
      id: id,
      ownerId: 'user-1',
      title: 'Promise $id',
      proofType: ProofType.photo,
      status: status,
      gufiDay: '2026-10-16',
      dueAt: DateTime.utc(2026, 10, 16, 20, 0),
      createdAt: DateTime.utc(2026, 10, 16, 8, 0),
      updatedAt: DateTime.utc(2026, 10, 16, 8, 0),
    );
  }

  group('Today Deterministic Copy Mapper', () {
    test('0 commitments -> "Your day is open." with subtitle', () {
      const state = TodayState(commitments: []);
      expect(state.heroHeadline, 'Your day is open.');
      expect(state.heroSubtitle, 'Make one promise worth keeping.');
    });

    test('1 commitment active -> "One promise.\nMake it count."', () {
      final state = TodayState(
        commitments: [makeCommitment('1', CommitmentStatus.committed)],
      );
      expect(state.heroHeadline, 'One promise.\nMake it count.');
      expect(state.heroSubtitle, isNull);
    });

    test('1 commitment verified -> "You showed up\nfor today."', () {
      final state = TodayState(
        commitments: [makeCommitment('1', CommitmentStatus.verified)],
      );
      expect(state.heroHeadline, 'You showed up\nfor today.');
    });

    test('2 of 3 promises still in motion', () {
      final state = TodayState(
        commitments: [
          makeCommitment('1', CommitmentStatus.verified),
          makeCommitment('2', CommitmentStatus.committed),
          makeCommitment('3', CommitmentStatus.proofSubmitted),
        ],
      );
      expect(state.heroHeadline, '2 of 3 promises\nstill in motion.');
    });

    test('3 promises all in motion', () {
      final state = TodayState(
        commitments: [
          makeCommitment('1', CommitmentStatus.committed),
          makeCommitment('2', CommitmentStatus.proofSubmitted),
          makeCommitment('3', CommitmentStatus.committed),
        ],
      );
      expect(state.heroHeadline, '3 promises\nin motion.');
    });

    test('All verified (3 promises) -> "You showed up\nfor all 3."', () {
      final state = TodayState(
        commitments: [
          makeCommitment('1', CommitmentStatus.verified),
          makeCommitment('2', CommitmentStatus.verified),
          makeCommitment('3', CommitmentStatus.verified),
        ],
      );
      expect(state.heroHeadline, 'You showed up\nfor all 3.');
      expect(state.allVerified, isTrue);
    });

    test('All resolved but mixed -> "Today is written."', () {
      final state = TodayState(
        commitments: [
          makeCommitment('1', CommitmentStatus.verified),
          makeCommitment('2', CommitmentStatus.missed),
        ],
      );
      expect(state.heroHeadline, 'Today is written.');
      expect(state.allVerified, isFalse);
    });
  });
}
