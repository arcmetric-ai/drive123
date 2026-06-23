import 'package:shared_preferences/shared_preferences.dart';

/// Simple wrapper around [SharedPreferences] for app-launch level flags.
class LaunchPreferences {
  static const _introSeenKey = 'drive_t_intro_seen_v1';

  /// Returns `true` when the app should show the intro walkthrough.
  static Future<bool> shouldShowIntro() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_introSeenKey) ?? false);
  }

  /// Marks the intro walkthrough as complete.
  static Future<void> markIntroSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_introSeenKey, true);
  }

  /// Helper to reset the intro flag (occasionally useful in QA).
  static Future<void> resetIntroFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_introSeenKey);
  }
}
