import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cases/case_record.dart';
import '../core/cases/cases_db.dart';

final casesDatabaseProvider = Provider<CasesDatabase>((ref) {
  final db = CasesDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Typed as [CaseStore] so pages depend on the journal's behaviour rather
/// than on the database class.
final caseRepositoryProvider = Provider<CaseStore>(
    (ref) => CaseRepository(ref.watch(casesDatabaseProvider)));

/// Live journal, newest first.
final caseListProvider = StreamProvider<List<CaseRecord>>(
    (ref) => ref.watch(caseRepositoryProvider).watchAll());

/// How many saved cases are ready to have their outcome filled in — drives
/// the badge on the 案例库 entry point.
final dueCaseCountProvider = Provider<int>((ref) {
  final cases = ref.watch(caseListProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return cases
      .where((c) =>
          c.status(now) == CaseStatus.awaitingReview ||
          c.status(now) == CaseStatus.partiallyReviewed)
      .length;
});
