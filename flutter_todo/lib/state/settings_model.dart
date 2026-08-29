import 'package:flutter/foundation.dart';
import '../services/github_api_client.dart';
import '../services/settings_store.dart';

/// State model managing application settings, multiple configured repositories,
/// active repository selection, and connection validation.
class SettingsModel extends ChangeNotifier {
  SettingsModel({
    required this.settingsStore,
    GitHubApiClient Function(String? token)? clientFactory,
  }) : _clientFactory = clientFactory ?? ((token) => GitHubApiClient(token: token));

  final SettingsStore settingsStore;
  final GitHubApiClient Function(String? token) _clientFactory;

  List<String> _repos = [];
  String _activeRepo = '';
  String _token = '';
  bool _isConfigured = false;
  bool _isLoading = false;
  String? _errorMessage;

  List<String> get repos => List.unmodifiable(_repos);
  String get repo => _activeRepo;
  String get activeRepo => _activeRepo;
  String get token => _token;
  bool get isConfigured => _isConfigured;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Creates a configured [GitHubApiClient] instance using current settings or [clientFactory].
  GitHubApiClient createApiClient([String? tokenOverride]) {
    return _clientFactory(tokenOverride ?? _token);
  }

  /// Loads stored configuration and repository list into memory.
  Future<void> loadSettings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _repos = await settingsStore.getRepos();
      _activeRepo = await settingsStore.getActiveRepo() ?? '';
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

  /// Switches the active repository to [repo].
  Future<void> selectActiveRepo(String repo) async {
    final cleanRepo = repo.trim();
    if (_activeRepo == cleanRepo) return;

    _isLoading = true;
    notifyListeners();

    try {
      await settingsStore.setActiveRepo(cleanRepo);
      _activeRepo = cleanRepo;
      _repos = await settingsStore.getRepos();
      _isConfigured = true;
    } catch (e) {
      _errorMessage = 'Failed to switch repository: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new repository [repo] (optionally activates it) and updates [token].
  Future<void> saveSettings(String repo, String token) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cleanRepo = repo.trim();
      final cleanToken = token.trim();

      await settingsStore.addRepo(cleanRepo, makeActive: true);
      await settingsStore.saveToken(cleanToken);

      _repos = await settingsStore.getRepos();
      _activeRepo = cleanRepo;
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

  /// Removes a repository [repo] from the configured list.
  Future<void> removeRepo(String repo) async {
    _isLoading = true;
    notifyListeners();

    try {
      await settingsStore.removeRepo(repo);
      _repos = await settingsStore.getRepos();
      _activeRepo = await settingsStore.getActiveRepo() ?? '';
      _isConfigured = await settingsStore.isConfigured();
    } catch (e) {
      _errorMessage = 'Failed to remove repository: $e';
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears all stored settings.
  Future<void> clearSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      await settingsStore.clear();
      _repos = [];
      _activeRepo = '';
      _token = '';
      _isConfigured = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
