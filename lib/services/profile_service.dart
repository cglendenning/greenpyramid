import 'ai_guard.dart';
import 'council_client.dart';
import 'db.dart';

/// D-114: the profile screen's two AI features — regenerating the vision
/// statement and generating a 30-day progress analysis — migrated onto
/// Claude. Both were, until now, the one AI surface D-069/D-083's
/// retirement of the legacy AI screens missed: still calling OpenAI
/// directly through a now-defunct account (confirmed dead from live Cloud
/// Run logs — "429 You have no credits remaining" — not guessed).
///
/// Neither call is free (D-016) — profile.dart checks entitlement and
/// routes to the paywall before calling either method here, the same
/// pattern `CouncilCategoryPicker` already establishes; this class assumes
/// it's being called by an entitled caller and lets the backend's own
/// D-016 check be the authoritative backstop if that assumption is ever
/// wrong (a stale local cache).
class ProfileService {
  ProfileService({DatabaseHelper? db, CouncilClient? client})
      : _db = db ?? DatabaseHelper.instance,
        _client = client ?? CouncilClient.instance;

  static final ProfileService instance = ProfileService();

  final DatabaseHelper _db;
  final CouncilClient _client;

  Future<String?> loadVisionStatement() => _db.getLatestVisionStatement();

  Future<void> saveVisionStatement(String text) => _db.insertVisionStatement(text);

  /// Regenerates the vision statement from the pyramid's current essences
  /// — not a live conversation (there isn't one at this point), so
  /// [sessionId]/transcript are omitted entirely (D-114's amendment to
  /// buildVisionStatementPrompt frames an absent transcript explicitly,
  /// rather than rendering an empty conversation section).
  Future<String> regenerateVisionStatement() async {
    final summary = await _db.queryPyramidSummary();
    final essences = summary
        .where((c) => c['essence'] != null)
        .map((c) => {
              'categoryName': c['name'] as String,
              'essence': c['essence'] as String,
            })
        .toList();
    await AiGuard.instance.acquire();
    return _client.deriveVisionStatement(essences: essences, isSetup: false);
  }

  /// A short Claude-written reflection on the last 30 days of habit
  /// check-offs. Bounded to [AiGuard.maxTaskLogRows], the same cap D-075's
  /// Firestore sync already uses for task_log — the most recent rows, not
  /// an arbitrary or unbounded slice.
  Future<String> generateProgressAnalysis() async {
    final logs = await _db.queryTaskLogs(30);
    final bounded = logs.length > AiGuard.maxTaskLogRows
        ? logs.sublist(logs.length - AiGuard.maxTaskLogRows)
        : logs;
    final taskLogs = bounded
        .map((row) => {
              'date': AiGuard.sanitizeField(
                  row[DatabaseHelper.columnTLTaskDate] as String? ?? '',
                  maxChars: 10),
              'category': AiGuard.sanitizeField(
                  row[DatabaseHelper.columnTLCategory] as String? ?? '',
                  maxChars: 60),
              'taskDescription': AiGuard.sanitizeField(
                  row[DatabaseHelper.columnTLTaskDescription] as String? ?? '',
                  maxChars: 120),
              'checked': row[DatabaseHelper.columnTLChecked] as String? ?? 'false',
            })
        .toList();
    await AiGuard.instance.acquire();
    final account = await _db.getAccountState();
    final firstName = account[DatabaseHelper.columnFirstName] as String?;
    return _client.deriveProgressAnalysis(taskLogs: taskLogs, firstName: firstName);
  }
}
