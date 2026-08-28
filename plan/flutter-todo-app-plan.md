# Plan: Flutter Android TODO App (GitHub Issues–backed)

## 1. Goals

Create a **Flutter Android mobile app** (Material 3, Android 5.0+ / API 21+) that connects to GitHub Issues as its backend, maintaining strict bidirectional compatibility with the existing Python curses TUI:

- **Mobile-first settings**: Enter and securely store a GitHub Personal Access Token (stored in Android Keystore via EncryptedSharedPreferences) and repository (`owner/repo`).
- **Create TODOs on mobile**: Clean touch-friendly form for **Title** and **Description**, saved as a new GitHub issue.
- **List & manage TODOs**: Mobile views for Active / Done / All with pull-to-refresh (`RefreshIndicator`), swipe actions, and status checkboxes.
- **Modify existing TODOs**:
  - Edit title and description.
  - Toggle active ⇄ done (opens/closes GitHub issue).
  - Reorder by priority (drag handle in list).
  - Delete with confirmation dialog (closes issue + sets `deleted: true` metadata).
- **Interoperability**: Strict compatibility with the Python TUI format (`<!-- todo-meta: {"priority":N,"deleted":bool} -->`), so both Android and terminal clients can share the same repo.
- **Efficient Development Methodology**: Fast, pure Dart unit/widget testing for core business logic, API communication, and UI rendering (sub-second feedback via `flutter test` with `FakeClient`), avoiding heavy emulator/Gradle overhead until dedicated verification milestones.

## 2. Android Mobile Specifics & Platform Architecture

| Concern | Android Solution & Configuration |
|---|---|
| **Target Platform** | Android 5.0+ (API 21+) up to Android 14/15 (API 34/35) |
| **Android SDK Configuration** | `compileSdk = 37`, `minSdk = 21`, `targetSdk = 34` in `android/app/build.gradle.kts` |
| **Permissions** | `<uses-permission android:name="android.permission.INTERNET"/>` in `AndroidManifest.xml` |
| **Secure Token Storage** | `flutter_secure_storage` backed by Android KeyStore + `EncryptedSharedPreferences` |
| **Mobile UX Patterns** | Material 3 UI, `RefreshIndicator` (pull-to-refresh), `Dismissible` (swipe actions), `ReorderableListView`, snackbars for error/action feedback, floating action button (FAB) for new TODOs |
| **Touch & Soft Keyboard** | Touch targets >= 48dp, multiline input scrolling with IME/keyboard awareness (`resizeToAvoidBottomInset: true`) |
| **Network & Lifecycle** | Handling Android offline/airplane mode, token expiry, app pause/resume state |

## 3. Current Behavior to Replicate (from Python `todo_manager.py`)

| Python (`todo_manager.py`) | Flutter Android equivalent |
|---|---|
| `TODO_GITHUB_REPO` + `GITHUB_TOKEN` env vars | In-app Settings screen (persisted via `shared_preferences` + `flutter_secure_storage`) |
| `Todo` model: id, header, body, created_date, finished_date, status, priority | Dart `Todo` class with `fromJson`/`toJson` |
| List issues (`GET /repos/{repo}/issues?state=all`, paginated 100/page, PRs filtered out) | Same REST calls via `http` package with bearer auth |
| Create issue (`POST /repos/{repo}/issues`) | Same |
| Edit issue (`PATCH` title/body) | Same |
| Toggle done (`PATCH` issue state open/closed) | Same (swiping row or tapping status checkbox) |
| Delete = close + `{"deleted": true}` metadata, then filtered from lists | Same (swiping row or delete button with confirm dialog) |
| Priority in hidden comment: `<!-- todo-meta: {"priority":N,"deleted":bool} -->` | Identical Dart encoder/decoder |
| Active = open issue, Done = closed issue | Same |

## 4. Architecture

Layered architecture keeping Android UI decoupled from GitHub REST API and storage:

```
┌──────────────────────────────────────────────────┐
│  Android Mobile UI (Material 3)                  │  SettingsScreen, TodoListScreen,
│  - Tabs, Pull-to-refresh, Swipe actions, FAB     │  TodoEditScreen, TodoDetailScreen
├──────────────────────────────────────────────────┤
│  State Management (Provider / ChangeNotifier)    │  TodoListModel, SettingsModel
├──────────────────────────────────────────────────┤
│  TodoRepository                                  │  Business logic: sorting, views,
│                                                  │  add/edit/toggle/reorder/delete
├──────────────────────────────────────────────────┤
│  GitHubApiClient                                 │  REST calls, auth header, pagination,
│                                                  │  HTTP error mapping, rate limits
├──────────────────────────────────────────────────┤
│  Todo model + IssueMetaCodec                     │  Todo entity, JSON mapping,
│                                                  │  todo-meta comment encode/decode
├──────────────────────────────────────────────────┤
│  Android Platform Storage                        │  flutter_secure_storage (KeyStore)
│                                                  │  shared_preferences (repo config)
└──────────────────────────────────────────────────┘
```

## 5. Technology Choices

| Concern | Choice | Rationale |
|---|---|---|
| Framework | Flutter (Dart, Material 3) | Official Android support, declarative mobile UI |
| HTTP client | `http` package | Lean, standard HTTP library, easily mockable with `http.BaseClient` |
| Token storage | `flutter_secure_storage` | Android KeyStore + EncryptedSharedPreferences (never plaintext) |
| Non-secret config | `shared_preferences` | Stores `owner/repo` string on Android |
| State management | `provider` | Standard, minimal boilerplate, great testability |
| Testing | `flutter_test` + `FakeClient` | Fast pure Dart tests (0 build time, no Gradle daemon needed) |
| Android Platform | Android Gradle Plugin (Kotlin DSL) | Modern Android build tooling |

## 6. Data Model & Metadata Codec

```dart
class Todo {
  String? id;            // GitHub issue number (as string) after sync
  String header;         // issue title
  String body;           // issue body without metadata comment
  DateTime? createdDate;
  DateTime? finishedDate;
  String status;         // "active" | "done"
  int priority;
}
```

### Issue body metadata codec (must match Python exactly)

- **Encoding**: `"{body}\n\n<!-- todo-meta: {json} -->"` (or just the comment when body is empty).
- **Decoding**: find the **last** occurrence of `<!-- todo-meta:`, parse JSON up to `-->`; on malformed JSON treat metadata as empty and keep the raw body.
- **Metadata JSON format**: `{"priority":N,"deleted":false}` with compact separators.

## 7. GitHub API Operations

Base URL: `https://api.github.com` — headers: `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`.

| Operation | Call |
|---|---|
| List todos | `GET /repos/{owner}/{repo}/issues?state=all&per_page=100&page=N` (loop until short page; skip items containing `"pull_request"`) |
| Add todo | `POST /repos/{owner}/{repo}/issues` with `{"title", "body": body+meta}` |
| Edit todo | `PATCH /repos/{owner}/{repo}/issues/{number}` with `{"title", "body"}` |
| Toggle done | `PATCH .../issues/{number}` with `{"state": "closed"\|"open"}` |
| Reorder | Swap `priority` of two adjacent todos via two `PATCH` body updates |
| Delete | `PATCH .../issues/{number}` with `{"state": "closed"}` and body meta `{"deleted": true}` |
| Test Connection | `GET /repos/{owner}/{repo}` (validates token & repo existence) |

## 8. Android Mobile UI Design

1. **Settings Screen**:
   - Inputs for `owner/repo` (e.g. `etnt/mytodos`) and GitHub PAT (obscured text field).
   - "Test connection" button calling GitHub API to verify repo access before saving.
   - Saves token to Android KeyStore via `flutter_secure_storage` and repo string to `shared_preferences`.
2. **Todo List Screen** (Main Screen):
   - Top App Bar with repository name, sync status, and Settings action.
   - Tabs / Segmented Buttons for **Active**, **Done**, and **All**.
   - `RefreshIndicator` for Android pull-to-refresh.
   - `ReorderableListView` allowing drag-and-drop priority sorting.
   - List items showing title, creation date, status checkbox (tap to toggle active/done), and swipe-to-delete.
   - Floating Action Button (`+`) to open the Add Todo screen.
3. **Add / Edit Screen**:
   - Single-line title input (`TextField` with autofocus and validation).
   - Multi-line description input (`TextField` with `maxLines: null`, IME action awareness).
   - Save button with loading indicator, gracefully handling network failures without data loss.
4. **Detail Screen**:
   - Full view of header, description, creation/completion timestamps, issue number, and direct buttons for Edit, Toggle Status, and Delete.


## 9. Implementation Milestones

Each phase has checkable action points. **Phases 2–7 are developed and fully verified with fast pure Dart unit/widget tests (`flutter test`) without needing slow Gradle builds or running emulators.**

### Phase 0 — Prerequisites & Baseline

- [x] Flutter SDK installed and verified with `flutter doctor` for Android.
      ✅ Done: Flutter 3.44.0 stable, Android SDK 36/37, Pixel 6a API 34 emulator available.
- [x] Scratch GitHub repo created.
      ✅ Done: `etnt/todo-flutter-scratch` (private).
- [x] Scratch repo verified to work with Python backend.
      ✅ Done: 12/12 checks passed running `todo_manager.py` against scratch repo.
- [ ] Fine-grained GitHub PAT configured on test device / emulator.

### Phase 1 — Android Project Scaffold & Dependencies

- [x] Create Flutter project structure `flutter_todo/` without nested `.git`.
- [x] Add dependencies to `pubspec.yaml`: `http`, `flutter_secure_storage`, `shared_preferences`, `provider`.
- [x] Add Android internet permission in `android/app/src/main/AndroidManifest.xml`.
- [x] Configure Android build settings (`compileSdk = 37`, Java 17) in `android/app/build.gradle.kts`.
- [x] Set up hand-rolled `FakeClient` for fast HTTP unit tests without mockito.
- [x] Add navigation skeleton & route gating (unconfigured → Settings, configured → List).
- [x] Run `flutter test` (all unit/widget tests passing).

### Phase 2 — Todo Model & Metadata Codec (Pure Dart)

- [x] Implement `lib/models/todo.dart` (`id`, `header`, `body`, `createdDate`, `finishedDate`, `status`, `priority`, `markDone`, `markActive`, `copyWith`, `toJson`, `fromJson`, equality).
      ✅ Done: Full Todo entity model matching Python schema.
- [x] Implement `lib/services/issue_meta_codec.dart`:
  - [x] `encode(body, {priority, deleted})` matching Python formatting.
  - [x] `decode(rawBody)` extracting `priority` and `deleted` from the last `<!-- todo-meta: ... -->` block.
  - [x] `fromGitHubIssue(issueJson)` mapping GitHub API JSON into `Todo`, filtering pull requests and soft-deleted items.
      ✅ Done: 100% interoperable codec.
- [x] Add unit tests in `test/issue_meta_codec_test.dart` and `test/todo_model_test.dart`.
      ✅ Done: Comprehensive test suites covering encoding, decoding, corrupted comments, multiple comments, PR filtering, deleted filtering, and model serialization.
- [x] **Gate: `flutter test` passes 100%; metadata codec verified against Python output.**
      ✅ Done: All 24 test assertions passed with zero analyzer issues.


### Phase 3 — GitHub API Client (Pure Dart)

- [x] Implement `lib/services/github_api_client.dart`:
  - [x] Injectable `http.Client` for fast testing.
  - [x] Standard GitHub REST headers (Accept, X-GitHub-Api-Version, Bearer auth).
  - [x] `listIssues(repo, {state=all, perPage=100})` with automatic pagination & PR filtering.
  - [x] `createIssue(repo, {title, body})`.
  - [x] `patchIssue(repo, number, payload)`.
  - [x] `testConnection(repo)`.
      ✅ Done: REST client wrapping GitHub API operations.
- [x] Implement error handling hierarchy (`GitHubApiException`, `GitHubAuthException`, `GitHubNotFoundException`, `GitHubRateLimitException` with reset timestamp, `GitHubValidationException`, `GitHubNetworkException`).
      ✅ Done: Typed exception model for clean UI handling.
- [x] Unit tests in `test/github_api_client_test.dart` using `FakeClient`.
      ✅ Done: Comprehensive tests for headers, auth omission, pagination, CRUD calls, and all HTTP error codes (401, 403 rate limit vs forbidden, 404, 422, network exceptions).
- [x] **Gate: `flutter test` passes with full coverage of API methods and error mappings.**
      ✅ Done: All 36 test assertions passed in sub-second execution with zero analyzer issues.


### Phase 4 — Todo Repository Business Logic (Pure Dart)

- [x] Implement `lib/repositories/todo_repository.dart`:
  - [x] `load()` — retrieves issues, decodes metadata, filters deleted, sorts by priority.
  - [x] `addTodo(header, body)` — calculates next priority (max + 1), creates issue on GitHub, adopts returned attributes.
  - [x] `updateTodo(todo, header, body)` — updates title and body+meta via PATCH.
  - [x] `toggleStatus(todo)` — flips status (open ⇄ closed) on GitHub and updates local finishedDate.
  - [x] `moveUp(todo)` / `moveDown(todo)` — swaps priority metadata of adjacent items via PATCH.
  - [x] `deleteTodo(todo)` — sets `deleted: true`, closes issue on GitHub, removes from local memory.
  - [x] Filter helpers: `getActiveTodos()`, `getDoneTodos()`, `getAllTodos()`.
      ✅ Done: Complete business logic ported from Python `TodoManager`.
- [x] Unit tests in `test/todo_repository_test.dart` with `FakeClient`.
      ✅ Done: Verified issue loading, sorting, query filters, addition, editing, status toggling, moving up/down priority swaps, and deletion.
- [x] **Gate: `flutter test` passes; full business logic verified in sub-second test runs.**
      ✅ Done: 42 test assertions pass with zero analyzer issues.



### Phase 5 — Android Secure Settings & State Management

- [x] Implement `lib/services/settings_store.dart`:
  - [x] GitHub token in `flutter_secure_storage` (Android Keystore).
  - [x] Target repo in `shared_preferences`.
  - [x] Methods: `getToken()`, `saveToken()`, `getRepo()`, `saveRepo()`, `isConfigured()`, `clear()`.
      ✅ Done: Secure and persistent settings storage.
- [x] Implement `lib/state/settings_model.dart` and `lib/state/todo_list_model.dart` with `ChangeNotifier`.
      ✅ Done: State management models handling loading, errors, testing connection, and repository coordination.
- [x] Build `lib/screens/settings_screen.dart`:
  - [x] Text fields for `owner/repo` and PAT (with visibility toggle and validation).
  - [x] "Test Connection" button with real API ping and distinct error banners (invalid token vs repo not found).
  - [x] Save & Continue button that initializes the repository and navigates to the list.
      ✅ Done: Full Material 3 mobile Settings UI.
- [x] Widget tests in `test/settings_screen_test.dart` with mock storage.
      ✅ Done: Verified validation errors, test connection feedback, and saving settings.
- [x] **Gate: Widget tests pass; route gating and token persistence verified.**
      ✅ Done: 46 test assertions pass in sub-second test execution with 0 analyzer issues.


### Phase 6 — Android Todo List Screen (Material 3 Mobile)

- [x] Build `lib/screens/todo_list_screen.dart`:
  - [x] Tabs / Segmented buttons: Active, Done, All.
  - [x] `RefreshIndicator` for Android pull-to-refresh.
  - [x] `ReorderableListView.builder` with drag handles for priority reordering.
  - [x] `Dismissible` swipe actions on list rows (swipe right to toggle, swipe left to delete with confirm).
  - [x] Empty state, loading spinner, and error banner with retry button.
  - [x] Mobile FloatingActionButton (`+`) to navigate to Add Todo.
  - [x] AppBar settings action to edit config.
      ✅ Done: Full Material 3 mobile TODO list interface.
- [x] Build reusable widgets in `lib/widgets/`: `todo_list_tile.dart`, `error_banner.dart`, `empty_state.dart`.
      ✅ Done: Modular and accessible widget components.
- [x] Widget tests in `test/todo_list_screen_test.dart`.
      ✅ Done: Verified list rendering, tab switching between Active/Done/All, empty state rendering, error banner presentation with retry, and checkbox status toggling.
- [x] **Gate: Widget tests pass for list rendering, tab switching, and pull-to-refresh.**
      ✅ Done: 50 test assertions pass in sub-second test execution with 0 analyzer issues.


### Phase 7 — Add/Edit & Detail Screens

- [x] Build `lib/screens/todo_edit_screen.dart`:
  - [x] Single-line Title `TextField` (required validation).
  - [x] Multi-line Description `TextField` (`maxLines: 8`, soft keyboard and IME aware).
  - [x] Mobile-friendly Save and Discard actions with `PopScope` unsaved change prompts.
  - [x] Loading state on save; error presentation preserving entered text if API fails.
      ✅ Done: Add and Edit flows fully implemented.
- [x] Build `lib/screens/todo_detail_screen.dart`:
  - [x] Displays full title, body, status badge, created/closed timestamps, issue number, and priority.
  - [x] Action buttons for Edit, Toggle Status, and Delete with confirmation.
      ✅ Done: Full-featured detail view.
- [x] Widget tests in `test/todo_edit_screen_test.dart` and `test/todo_detail_screen_test.dart`.
      ✅ Done: Verified add mode validation, creation flow, edit mode updates, detail screen rendering, status toggling, and deletion dialog.
- [x] **Gate: Widget tests pass for all user flows.**
      ✅ Done: 56 test assertions pass in sub-second test execution with 0 analyzer issues.


### Phase 8 — Polish, Android UX Hardening & Error Handling

- [ ] Soft keyboard handling (`resizeToAvoidBottomInset: true`, focus management).
- [ ] Offline / network failure handling with retry snackbars.
- [ ] Rate limit warning banners.
- [ ] Semantic labels and accessibility pass for Android TalkBack.
- [ ] Code cleanliness pass (`flutter analyze` with zero warnings/errors).

### Phase 9 — Android Build, Emulator Run & Acceptance

- [ ] Build Android debug APK (`flutter build apk --debug`).
- [ ] Install and run on Android emulator or physical device.
- [ ] Complete full bidirectional interop verification with Python TUI:
  - [ ] Create TODO on Android → verify in Python TUI.
  - [ ] Modify TODO in Python TUI → pull-to-refresh on Android and verify.
  - [ ] Toggle done / reorder on Android → verify issue state & priority in Python TUI.
  - [ ] Delete on Android → verify closed + marked deleted in Python TUI.
- [ ] **Gate: Android app runs smoothly on device/emulator and passes 100% of interop checks.**

## 10. Security & Permissions

- Token is saved in Android Keystore via `flutter_secure_storage` using `EncryptedSharedPreferences`.
- Token is never written to logcat, SharedPreferences, or error dialogs.
- Android permission `android.permission.INTERNET` is the only permission requested.

## 11. Out of Scope (Version 1)

- Offline-only / local `todos.json` mode (app connects to GitHub repository).
- Multi-repository switching / profiles.
- Issue labels, milestones, assignees, or comments.

