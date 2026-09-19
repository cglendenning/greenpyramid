import 'auth_service.dart';
import 'setup_rebuild_intent.dart';
import 'sync_service.dart';

/// D-177: begins a confirmed "Set up again".
///
/// The order matters and is the whole point of this class. The cloud pyramid
/// is erased *first*, and this throws if that fails, so the caller's local
/// wipe is never reached. The reverse order, or ignoring a failed erase,
/// leaves the account half wiped — an empty device and an intact cloud copy —
/// which is exactly the state that made "Set up again" restore the pyramid it
/// had just erased.
///
/// A signed-out or anonymous account has no cloud pyramid to erase, so the
/// local wipe is all there is and proceeds unconditionally.
class SetupRebuildService {
  SetupRebuildService({
    SyncService? sync,
    AuthService? auth,
    SetupRebuildIntent? intent,
  })  : _sync = sync ?? SyncService.instance,
        _auth = auth ?? AuthService(),
        _intent = intent ?? SetupRebuildIntent.instance;

  static final SetupRebuildService instance = SetupRebuildService();

  final SyncService _sync;
  final AuthService _auth;
  final SetupRebuildIntent _intent;

  /// Throws [SetupRebuildFailed] if the cloud pyramid could not be erased. The
  /// caller must surface that and leave the existing pyramid alone: a user who
  /// is offline has lost nothing, and can try again when they reconnect.
  Future<void> prepareRebuild() async {
    final uid = _auth.currentUid;
    if (uid != null && !_auth.isAnonymous) {
      try {
        await _sync.eraseCloudPyramid(uid);
      } catch (e, st) {
        throw SetupRebuildFailed(e, st);
      }
    }
    await _intent.record();
  }
}

class SetupRebuildFailed implements Exception {
  SetupRebuildFailed(this.cause, this.stackTrace);
  final Object cause;
  final StackTrace stackTrace;

  @override
  String toString() => 'SetupRebuildFailed: $cause';
}
