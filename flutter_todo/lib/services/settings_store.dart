import 'package:shared_preferences/shared_preferences.dart';

/// Persists the non-secret app configuration (repository coordinates).
///
/// The GitHub token itself never goes through this store; it lives in
/// flutter_secure_storage once settings are implemented in Phase 5.
class SettingsStore {
  static const repoKey = 'todo_repo';

  Future<bool> isConfigured() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(repoKey) != null;
  }
}
