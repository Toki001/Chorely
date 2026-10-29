import '../../chores/domain/chore_repository.dart';

/// Progress counts occurrences, never taps, individual parts or cancelled slots.
class ChoreProgress {
  ChoreProgress(Iterable<ChoreOccurrence> rows) {
    for (final row in rows) {
      if (['cancelled', 'skipped'].contains(row.status)) continue;
      total++;
      if (['completed', 'approved'].contains(row.status)) done++;
      if (row.status == 'pending_review') waiting++;
    }
  }
  int total = 0;
  int done = 0;
  int waiting = 0;
  double get fraction => total == 0 ? 0 : done / total;
}
