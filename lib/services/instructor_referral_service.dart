import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

class InstructorReferralService {
  static const String _pendingCodeKey = 'pending_instructor_referral_code';

  static Future<void> savePendingCode(String code) async {
    final normalized = _normalize(code);
    if (normalized == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCodeKey, normalized);
  }

  static Future<String?> pendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalize(prefs.getString(_pendingCodeKey));
  }

  static Future<void> clearPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingCodeKey);
  }

  static Future<bool> claimPendingCodeIfAvailable() async {
    final code = await pendingCode();
    if (code == null) return false;
    await SupabaseService.claimInstructorReferralCode(code);
    await clearPendingCode();
    return true;
  }

  static String? _normalize(String? code) {
    final cleaned =
        (code ?? '').trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length != 8) return null;
    return '${cleaned.substring(0, 2)}-${cleaned.substring(2)}';
  }
}
