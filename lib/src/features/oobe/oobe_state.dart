import 'package:oronbox/src/core/services/shared_prefs_service.dart';

/// Legal documents the user has accepted. Bump [currentLegalVersion] when the
/// terms or privacy notice change in a way that requires re-consent.
const currentLegalVersion = 1;

const _legalVersionKey = 'legal.agreementsAcceptedVersion';
const _oobeCompletedKey = 'oobe.completed';

/// Process-local latch. Once the wizard is completed in this running process,
/// route redirects must never fall back to the OOBE again. On iOS (especially
/// sideloaded / enterprise-signed builds) the shared_preferences write and the
/// immediately-following synchronous read can race, which made `context.go`
/// bounce between the home page and the last OOBE step ("flicker" loop).
/// This latch makes completion monotonic within a session; on the next cold
/// start the persisted value is authoritative again.
bool _completedInMemory = false;

bool isLegalAccepted([SharedPrefsService? prefs]) {
  final store = prefs ?? SharedPrefsService.instance;
  return (store.getInt(_legalVersionKey) ?? 0) >= currentLegalVersion;
}

bool isOobeCompleted([SharedPrefsService? prefs]) {
  if (_completedInMemory) return true;
  final store = prefs ?? SharedPrefsService.instance;
  return isLegalAccepted(store) && (store.getBool(_oobeCompletedKey) ?? false);
}

Future<void> markLegalAccepted([SharedPrefsService? prefs]) async {
  final store = prefs ?? SharedPrefsService.instance;
  await store.setInt(_legalVersionKey, currentLegalVersion);
}

Future<void> markOobeCompleted([SharedPrefsService? prefs]) async {
  final store = prefs ?? SharedPrefsService.instance;
  // Ensure both flags are persisted: the redirect guard requires BOTH the
  // legal version and the completion flag. Historically _finish only wrote
  // the completion flag, relying on an earlier step for the legal version;
  // writing both here removes that ordering dependency entirely.
  await store.setInt(_legalVersionKey, currentLegalVersion);
  await store.setBool(_oobeCompletedKey, true);
  // Latch in-process so the redirect triggered by the following context.go
  // cannot observe a stale shared_preferences value and bounce back to OOBE.
  _completedInMemory = true;
}

/// Test/debug helper to reset the in-process latch.
void resetOobeCompletionLatch() => _completedInMemory = false;
