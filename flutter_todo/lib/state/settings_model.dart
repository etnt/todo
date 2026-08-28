import 'package:flutter/foundation.dart';
import '../services/github_api_client.dart';
import '../services/settings_store.dart';

/// State model managing application settings, configuration state, and connection validation.
class SettingsModel extends ChangeNotifier {
  SettingsModel({
    required this.settingsStore,
    GitHubApiClient Function(String? token)? clientFactory,
  }) : _clientFactory = clientFactory ?? ((token) => GitHubApiClient(token: token));

  final SettingsStore settingsStore;
  final GitHubApiClient Function(String? token) _clientFactory;

  String _repo = '';
  String _token = '';
  bool _isConfigured = false;
  bool _isLoading = false;
  String? _errorMessage;

  String get repo => _repo;
  String get token => _token;
  bool get isConfigured => _isConfigured;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Loads stored configuration into memory.
  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _repo = await settingsStore.getRepo() ?? '';
      _token = await settingsStore.getToken() ?? '';
      _isConfigured = await settingsStore.isConfigured();
    } catch (e) {
      _errorMessage = 'Failed to load settings: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tests GitHub API connection for the given [repo] and [token].
  ///
  /// Returns a success message if valid, or throws [GitHubApiException].
  Future<String> testConnection(String repo, String token) async {
    final client = _clientFactory(token.trim());
    final cleanRepo = repo.trim();

    if (!RegExp(r'^[^/\s]+/[^/\s]+$').hasMatch(cleanRepo)) {
      throw const GitHubValidationException('Repository must be formatted as "owner/repo"');
    }

    final repoData = await client.testConnection(cleanRepo);
    final fullName = repoData['full_name'] as String? ?? cleanRepo;
    return 'Successfully connected to $fullName';
  }

  /// Saves [repo] and [token] to persistent storage, then updates state.
  Future<void> saveSettings(String repo, String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanRepo = repo.trim();
      final cleanToken = token.trim();

      await settingsStore.saveRepo(cleanRepo);
      await settingsStore.saveToken(cleanToken);

      _repo = cleanRepo;
      _token = cleanToken;
      _isConfigured = true;
    } catch (e) {
      _errorMessage = 'Failed to save settings: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears stored settings.
  Future<void> clearSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      await settingsStore.clear();
      _repo = '';
      _token = '';
      _isConfigured = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
