import 'package:shared_preferences/shared_preferences.dart';

/// D-177: records that the user deliberately chose "Set up again".
///
/// Without this, a rebuild is indistinguishable from a reinstall. Both
/// arrive at setup with no local pyramid while signed in, so
/// `startOrResumeSetup` restored the cloud copy and reported the pyramid
/// already built — which is right for a reinstall and wrong for a rebuild,
/// where the user has just confirmed erasing everything.
///
/// Stored outside the SQLite database on purpose: `wipeLocalPyramid()`
/// clears and re-seeds those tables, so a flag kept there could not survive
/// the very wipe it has to outlive. Persisting it also means an app kill
/// between the wipe and the first setup screen does not strand the account
/// with an empty local pyramid that then silently re-restores.
///
/// Single use: [consume] returns the flag and clears it in the same step, so
/// one confirmation grants exactly one rebuild. If the user abandons setup
/// afterwards, the next visit behaves like an ordinary reinstall again and
/// their cloud pyramid is restored — the safe outcome.
class SetupRebuildIntent {
  SetupRebuildIntent._();

  static final SetupRebuildIntent instance = SetupRebuildIntent._();

  static const storageKey = 'setup_rebuild_requested_v1';

  Future<void> record() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(storageKey, true);
  }

  Future<bool> consume() async {
    final prefs = await SharedPreferences.getInstance();
    final requested = prefs.getBool(storageKey) ?? false;
    if (requested) await prefs.remove(storageKey);
    return requested;
  }

  /// Used when a rebuild is abandoned before setup reads the flag.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
