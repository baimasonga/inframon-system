import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches and exposes the current user's role from Supabase.
/// Defaults to "Clerk of Works" (safest field role) when role cannot be determined.
class RoleProvider extends ChangeNotifier {
  String _role = 'Clerk of Works';
  bool _loaded = false;

  String get role => _role;
  bool get loaded => _loaded;

  bool get isFieldStaff =>
      _role == 'Clerk of Works' || _role == 'Civil Engineer' || _role == 'M&E Officer';
  bool get isAdmin => _role == 'System Admin';
  bool get isStakeholder => _role == 'Stakeholder';
  bool get isProcurement => _role == 'Procurement Officer';

  Future<void> loadRole() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) { _loaded = true; notifyListeners(); return; }

      // 1. Try metadata first (fastest)
      final metaRole = user.userMetadata?['role'] as String?;
      if (metaRole != null && metaRole.isNotEmpty) {
        _role = metaRole;
        _loaded = true;
        notifyListeners();
        return;
      }

      // 2. Try public.users table by email
      final email = user.email;
      if (email != null) {
        final rows = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('email', email)
            .limit(1);
        if ((rows as List).isNotEmpty && rows.first['role'] != null) {
          _role = rows.first['role'] as String;
          _loaded = true;
          notifyListeners();
          return;
        }
      }

      // 3. Try by auth UID
      final rows2 = await Supabase.instance.client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .limit(1);
      if ((rows2 as List).isNotEmpty && rows2.first['role'] != null) {
        _role = rows2.first['role'] as String;
      }
    } catch (e) {
      debugPrint('[RoleProvider] Could not fetch role: \$e');
    }
    _loaded = true;
    notifyListeners();
  }

  void reset() {
    _role = 'Clerk of Works';
    _loaded = false;
    notifyListeners();
  }
}
