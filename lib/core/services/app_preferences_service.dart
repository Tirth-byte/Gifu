import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for device-level preferences:
/// - hasSeenIntro: whether user has completed the intro onboarding
/// - pendingInviteCode: invite code stored when an unauthenticated user opens an invite deep link
class AppPreferencesService {
  static final AppPreferencesService instance =
      AppPreferencesService._internal();
  AppPreferencesService._internal();

  static const _keyHasSeenIntro = 'gufi_has_seen_intro';
  static const _keyPendingInviteCode = 'gufi_pending_invite_code';

  SharedPreferences? _prefs;
  String? _memoryPendingInviteCode;

  Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      // Clean up legacy flag if previously set on disk so cold launch starts at Screen 1
      if (_prefs != null && _prefs!.containsKey(_keyHasSeenIntro)) {
        await _prefs!.remove(_keyHasSeenIntro);
      }
      if (_prefs != null && _prefs!.containsKey(_keyPendingInviteCode)) {
        _memoryPendingInviteCode = _prefs!.getString(_keyPendingInviteCode);
      }
    } catch (_) {}
  }

  /// Deprecated: public onboarding is not permanently completed by viewing screens.
  /// Cold launches for unauthenticated users always start at Screen 1.
  bool get hasSeenIntro => false;

  bool getHasSeenIntro() => false;

  Future<void> setHasSeenIntro(bool value) async {
    // No-op: unauthenticated cold launches always start at Screen 1.
  }

  String? get pendingInviteCode =>
      _prefs?.getString(_keyPendingInviteCode) ?? _memoryPendingInviteCode;

  String? getPendingInviteCode() => pendingInviteCode;

  Future<void> setPendingInviteCode(String? code) async {
    _memoryPendingInviteCode = code?.trim().toUpperCase();
    try {
      await init();
      if (code == null || code.trim().isEmpty) {
        await _prefs?.remove(_keyPendingInviteCode);
      } else {
        await _prefs?.setString(
          _keyPendingInviteCode,
          code.trim().toUpperCase(),
        );
      }
    } catch (_) {}
  }

  Future<void> clearPendingInviteCode() async {
    _memoryPendingInviteCode = null;
    try {
      await init();
      await _prefs?.remove(_keyPendingInviteCode);
    } catch (_) {}
  }

  void resetForTesting() {
    _memoryPendingInviteCode = null;
    try {
      _prefs?.clear();
    } catch (_) {}
  }
}
