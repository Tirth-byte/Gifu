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
  bool _memoryHasSeenIntro = false;
  String? _memoryPendingInviteCode;

  Future<void> init() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      if (_prefs != null && _prefs!.containsKey(_keyHasSeenIntro)) {
        _memoryHasSeenIntro = _prefs!.getBool(_keyHasSeenIntro) ?? false;
      }
      if (_prefs != null && _prefs!.containsKey(_keyPendingInviteCode)) {
        _memoryPendingInviteCode = _prefs!.getString(_keyPendingInviteCode);
      }
    } catch (_) {}
  }

  bool get hasSeenIntro =>
      _prefs?.getBool(_keyHasSeenIntro) ?? _memoryHasSeenIntro;

  bool getHasSeenIntro() => hasSeenIntro;

  Future<void> setHasSeenIntro(bool value) async {
    _memoryHasSeenIntro = value;
    try {
      await init();
      await _prefs?.setBool(_keyHasSeenIntro, value);
    } catch (_) {}
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
    _memoryHasSeenIntro = false;
    _memoryPendingInviteCode = null;
    try {
      _prefs?.clear();
    } catch (_) {}
  }
}
