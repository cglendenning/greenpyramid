/// Deadlines for work that depends on a remote service. Local SQLite work is
/// intentionally not given an artificial deadline; it is the offline-first
/// source of truth for tracking.
const remoteReadTimeout = Duration(seconds: 15);
const remoteWriteTimeout = Duration(seconds: 20);
const providerRequestTimeout = Duration(seconds: 30);

Future<T> withRemoteDeadline<T>(
  Future<T> operation, {
  Duration timeout = remoteReadTimeout,
}) =>
    operation.timeout(timeout);
