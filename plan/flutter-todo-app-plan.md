# Plan: Flutter TODO App (GitHub Issues–backed)

## 1. Goals

Create a simple Flutter app that replaces the current Python curses-based TUI while
keeping the same backend behavior:

- Configure a GitHub token and target repository (`owner/repo`) from within the app.
- Create a TODO by entering a **Title** and **Description**; it is stored as a GitHub
  issue in the configured repository.
- List existing TODOs (views: Active / Done / All).
- Modify existing TODOs:
  - Edit title and description.
  - Toggle active ⇄ done (open ⇄ closed issue).
  - Reorder by priority.
  - Delete (close issue + mark as deleted in metadata).

The app must remain **interoperable** with the existing Python TUI: both apps read and
write the same GitHub issues, including the hidden metadata block, so either client can
be used against the same repository.

## 2. Current behavior to replicate (from the Python app)

| Python (`todo_manager.py`) | Flutter equivalent |
|---|---|
| `TODO_GITHUB_REPO` + `GITHUB_TOKEN` env vars | In-app Settings screen persisted on device |
| `Todo` model: id, header, body, created_date, finished_date, status, priority | Dart `Todo` class with `fromJson`/`toJson` |
| List issues (`GET /repos/{repo}/issues?state=all`, paginated 100/page, PRs filtered out) | Same REST calls via `http` package |
| Create issue (`POST /repos/{repo}/issues`) | Same |
| Edit issue (`PATCH` title/body) | Same |
| Toggle done (`PATCH` issue state open/closed) | Same |
| Delete = close + `{"deleted": true}` metadata, then filtered from lists | Same |
| Priority stored in hidden `<!-- todo-meta: {"priority":N,"deleted":bool} -->` comment in issue body | Same codec implemented in Dart |
| Active = open issue, Done = closed issue | Same |

## 3. Architecture

Layered architecture, mirroring the separation in the Python app (`models.py` /
`todo_manager.py` / `ui.py`):

```
┌─────────────────────────────────────────┐
│  UI (Screens & Widgets)                 │  SettingsScreen, TodoListScreen,
│                                         │  TodoEditScreen, TodoDetailScreen
├─────────────────────────────────────────┤
│  State management (Provider)            │  TodoListModel, SettingsModel
├─────────────────────────────────────────┤
│  TodoRepository                         │  Business logic: sorting, views,
│                                         │  add/edit/toggle/reorder/delete
├─────────────────────────────────────────┤
│  GitHubApiClient                        │  REST calls, auth header, pagination
├─────────────────────────────────────────┤
│  Todo model + IssueMetaCodec            │  Mapping Todo ⇄ GitHub issue JSON,
│                                         │  todo-meta comment encode/decode
└─────────────────────────────────────────┘
```

## 4. Technology choices

| Concern | Choice | Rationale |
|---|---|---|
| Framework | Flutter (stable, Dart) | Cross-platform, single codebase |
| HTTP client | `http` package | Simple, official, sufficient for the REST calls used |
| Token storage | `flutter_secure_storage` | Token must not be stored in plaintext |
| Repo config | `shared_preferences` | `owner/repo` string is not a secret |
| State management | `provider` | Simple, official, adequate for this app size |
| Dates | Built-in `DateTime` + ISO-8601 strings | Matches Python's ISO format handling |
| Tests | `flutter_test` + a fake `http.Client` | Unit-test codec and repository logic without network |

## 5. Data model

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

- Encoding: `"{body}\n\n<!-- todo-meta: {json} -->"` (or just the comment when body is empty).
- Decoding: find the **last** occurrence of `<!-- todo-meta:`, parse JSON up to `-->`;
  on malformed JSON treat metadata as empty and keep the raw body.
- Metadata JSON uses compact separators: `{"priority":N,"deleted":false}`.

This is the most error-prone part — implement it as a standalone class and unit-test it
against the same cases the Python `_parse_issue_body`/`_build_issue_body` handle.

## 6. GitHub API operations

Base URL: `https://api.github.com` — headers: `Authorization: Bearer <token>`,
`Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`.

| Operation | Call |
|---|---|
| List todos | `GET /repos/{owner}/{repo}/issues?state=all&per_page=100&page=N` (loop until short page; skip items containing `"pull_request"`) |
| Add todo | `POST /repos/{owner}/{repo}/issues` with `{"title", "body": body+meta}` |
| Edit todo | `PATCH /repos/{owner}/{repo}/issues/{number}` with `{"title", "body"}` |
| Toggle done | `PATCH .../issues/{number}` with `{"state": "closed"\|"open"}` |
| Reorder | Swap `priority` of two adjacent todos via two `PATCH` body updates |
| Delete | `PATCH .../issues/{number}` with `{"state": "closed"}` and body meta `{"deleted": true}` |

## 7. UI design

1. **Settings screen** — inputs for `owner/repo` and GitHub token, Save button,
   connection test (`GET` on the repo endpoint), validation errors shown inline.
   Shown automatically on first launch if not configured.
2. **Todo list screen** — the main screen:
   - Tabs / segmented control: Active / Done / All.
   - Each row: status icon (○/✓), title, creation date; done rows visually dimmed.
   - Swipe actions or per-row menu: edit, toggle done, delete (with confirmation).
   - Reorder: long-press drag handles.
   - Pull-to-refresh; loading spinner; error banner with Retry; empty state ("No todos").
   - FAB "+" to add a new todo.
3. **Add / Edit screen** — Title (single-line `TextField`) and Description
   (multi-line `TextField`), Save (Cancel button too). Save shows a progress indicator
   while the API call runs; failures keep the form open with an error message.
4. **Detail screen** — full title, description, dates, status; buttons to edit / toggle / delete.


## 8. Project structure

```
flutter_todo/
├── pubspec.yaml
├── lib/
│   ├── main.dart
│   ├── models/
│   │   └── todo.dart               # Todo + TodoStatus
│   ├── services/
│   │   ├── github_api_client.dart  # raw REST calls, auth, pagination
│   │   ├── issue_meta_codec.dart   # todo-meta comment encode/decode
│   │   └── settings_store.dart     # secure token + repo persistence
│   ├── repositories/
│   │   └── todo_repository.dart    # port of TodoManager logic
│   ├── state/
│   │   ├── todo_list_model.dart    # ChangeNotifier: todos, views, loading, errors
│   │   └── settings_model.dart
│   ├── screens/
│   │   ├── settings_screen.dart
│   │   ├── todo_list_screen.dart
│   │   ├── todo_edit_screen.dart
│   │   └── todo_detail_screen.dart
│   └── widgets/                    # todo_row, error_banner, etc.
└── test/
    ├── issue_meta_codec_test.dart
    ├── todo_repository_test.dart   # with fake http.Client
    └── todo_model_test.dart
```

## 9. Implementation milestones

Each phase ends with a checkable "done" gate. Phases 2–4 are pure Dart logic and can be
developed and verified with `flutter test` before any UI exists.

### Phase 0 — Prerequisites

- [ ] Flutter SDK installed and `flutter doctor` passes for at least one target platform (iOS/Android/desktop).
- [ ] A scratch GitHub repository created for testing (e.g. `owner/todo-scratch`).
- [ ] A fine-grained GitHub personal access token created with *Issues: read & write* on the scratch repo only.
- [ ] Scratch repo verified to work with the existing Python TUI (baseline interop check).

### Phase 1 — Scaffold & dependencies

- [ ] Run `flutter create flutter_todo` and confirm the default app builds and runs (`flutter run`).
- [ ] Add dependencies to `pubspec.yaml`: `http`, `flutter_secure_storage`, `shared_preferences`, `provider`.
- [ ] Add dev/test setup: `flutter_test` (default) and a `mockito`-free fake `http.Client` helper (hand-rolled `FakeClient extends http.BaseClient`).
- [ ] Create the folder skeleton under `lib/`: `models/`, `services/`, `repositories/`, `state/`, `screens/`, `widgets/`.
- [ ] Set up navigation skeleton: placeholder `SettingsScreen` and `TodoListScreen` with routes (`/settings`, `/list`); app starts on Settings if unconfigured, List otherwise.
- [ ] Run `flutter analyze` and `flutter test` — both clean.
- [ ] **Gate: app runs on device/simulator showing a placeholder list screen; navigation to settings works.**

### Phase 2 — Todo model & issue metadata codec (no UI)

- [ ] Implement `lib/models/todo.dart`: `Todo` class with `id`, `header`, `body`, `createdDate`, `finishedDate`, `status` (`active`/`done`), `priority`.
- [ ] Add `copyWith` and equality helpers to `Todo`.
- [ ] Implement `lib/services/issue_meta_codec.dart`:
  - [ ] `encode(body, {priority, deleted})` → `"{body}\n\n<!-- todo-meta: {compact-json} -->"`; comment-only body when body is empty; no trailing whitespace mismatch vs. Python.
  - [ ] `decode(rawBody)` → `(body, {priority, deleted})` using the **last** `<!-- todo-meta:` occurrence; malformed JSON → empty metadata, raw body preserved.
- [ ] Implement issue JSON ⇄ `Todo` mapping: number→id, title→header, state→status, created_at/closed_at→ISO timestamps, PRs flagged.
- [ ] Unit tests `test/issue_meta_codec_test.dart`:
  - [ ] Encode/decode round-trip (body with and without text, empty body).
  - [ ] Body containing a literal `<!--` elsewhere still parses (last-marker rule).
  - [ ] Malformed metadata JSON tolerated; body returned intact.
  - [ ] Priority default fallback when metadata missing.
- [ ] Unit tests `test/todo_model_test.dart`: JSON mapping, status mapping, timestamp parsing incl. `Z` suffix.
- [ ] **Gate: `flutter test` green for codec + model; codec output byte-compared against Python `_build_issue_body` for at least one fixture.**

### Phase 3 — GitHub API client (no UI)

- [ ] Implement `lib/services/github_api_client.dart`:
  - [ ] Constructor takes base URL (default `https://api.github.com`), token, and an injectable `http.Client`.
  - [ ] Standard headers on every request: `Authorization: Bearer`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`, `Content-Type: application/json`.
  - [ ] `listIssues(repo, {state=all, perPage=100})` with page loop until a short page; skip items containing `pull_request`.
  - [ ] `createIssue(repo, {title, body})`, `patchIssue(repo, number, payload)`.
- [ ] Define a `GitHubApiException` hierarchy: auth error (401/403), not found (404), validation (422), rate-limited (403 + `X-RateLimit-Remaining: 0`), network error.
- [ ] Unit tests with fake client:
  - [ ] Headers present and correct.
  - [ ] Pagination: 2 pages (full + partial) aggregated; PR entries filtered out.
  - [ ] Each HTTP error class mapped to the right exception type.
  - [ ] Request bodies for create/patch are correct JSON.
- [ ] **Gate: `flutter test` green; client contains no UI or storage code.**

### Phase 4 — Todo repository (business logic, no UI)

- [ ] Implement `lib/repositories/todo_repository.dart` as a port of `TodoManager`:
  - [ ] `load()` — list issues, decode metadata, skip `deleted:true`, sort by priority (fallback: creation index).
  - [ ] `addTodo(header, body)` — next priority = max+1, create issue, adopt returned number/timestamps/state.
  - [ ] `updateTodo(todo, header, body)` — PATCH title + body-with-meta.
  - [ ] `toggleStatus(todo)` — PATCH state open/closed; update finishedDate locally.
  - [ ] `moveUp/moveDown(todo)` — swap priorities and PATCH both issues' bodies.
  - [ ] `deleteTodo(todo)` — PATCH close + `deleted:true` metadata; remove from local list.
  - [ ] View helpers: `getActive()`, `getDone()`, `getAll()` sorted by priority.
- [ ] Define repository-level exceptions reusing the client's exception types.
- [ ] Unit tests with fake client:
  - [ ] Load: open→active, closed→done, deleted filtered, priority ordering.
  - [ ] Add: correct POST body; returned number becomes id.
  - [ ] Update/toggle/delete: correct PATCH payloads (verify with captured requests).
  - [ ] Reorder: both issues patched with swapped priorities.
  - [ ] Client errors surface as repository exceptions.
- [ ] **Gate: `flutter test` green — full backend behavior is verified without network or UI.**

### Phase 5 — Settings screen & persistence

- [ ] Implement `lib/services/settings_store.dart`:
  - [ ] `shared_preferences` for `owner/repo`; `flutter_secure_storage` for the token.
  - [ ] Load/save/clear methods; no token ever written to `shared_preferences` or logs.
- [ ] Implement `lib/state/settings_model.dart` (ChangeNotifier): repo, hasToken, configured flag.
- [ ] Build `SettingsScreen`:
  - [ ] Text fields for `owner/repo` (format validation `owner/repo`) and token (obscured).
  - [ ] "Test connection" button → `GET /repos/{owner}/{repo}`; success/failure message (maps 401 vs 404 distinctly).
  - [ ] Save button persists config and navigates to the list screen.
- [ ] First-launch gating: app opens Settings when unconfigured; list screen unreachable until configured.
- [ ] Widget tests: validation errors shown; config round-trips through the store (fake secure storage).
- [ ] **Gate: on a clean install the app demands configuration; with valid token+repo it proceeds to the (still placeholder) list screen.**

### Phase 6 — Todo list screen

- [ ] Implement `lib/state/todo_list_model.dart` (ChangeNotifier): todos, current view, loading/error flags; wraps `TodoRepository`.
- [ ] Build `TodoListScreen`:
  - [ ] Segmented control / tabs: Active / Done / All (default Active).
  - [ ] Rows: status icon (○/✓), header, created date; done rows dimmed/strikethrough.
  - [ ] Pull-to-refresh triggers `load()`.
  - [ ] Toggle done via swipe action or row menu, with optimistic update + error rollback.
  - [ ] Edit entry point per row; delete with confirmation dialog.
  - [ ] Reorder via long-press drag (`ReorderableListView`); on drop, swap priorities through the repository.
  - [ ] States: loading spinner, error banner with Retry, empty state per tab ("No todos").
  - [ ] FAB "+" navigates to Add screen; tapping a row navigates to Detail.
- [ ] Settings entry point in the app bar (allows changing repo/token later).
- [ ] Widget tests: tab filtering renders correct subset; toggle calls repository; delete asks for confirmation.
- [ ] **Gate: real end-to-end run against the scratch repo — todos added via GitHub UI/Python TUI appear after pull-to-refresh.**

### Phase 7 — Add/Edit + Detail screens

- [ ] Build `TodoEditScreen` (used for both add and edit):
  - [ ] Single-line Title field (required, non-empty validation) and multi-line Description field.
  - [ ] Save: shows progress; calls `addTodo` or `updateTodo`; on failure keeps the form and shows the error; on success pops back to list.
  - [ ] Cancel button and back navigation (with discard-changes confirmation when fields are dirty).
- [ ] Build `TodoDetailScreen`: full title, description, created/finished dates, status; buttons for edit, toggle done, delete.
- [ ] Wire navigation: list → detail → edit; list → add.
- [ ] Widget tests: empty title blocks save; save success pops navigation; API failure shows inline error and keeps data.
- [ ] **Gate: full create-edit-toggle-delete cycle performed from the UI against the scratch repo.**

### Phase 8 — Polish & UX hardening

- [ ] Friendly error messages for all `GitHubApiException` types (bad token, repo not found, rate limited, offline).
- [ ] Global "unconfigured/invalid token" handling: any 401/404 during use offers to open Settings.
- [ ] Confirm-token-mismatch check: warning if the configured repo contains non-todo issues (they will be shown) — document the limitation.
- [ ] Theming: dark/light support; consistent status colors (green=done, default=active).
- [ ] Accessibility pass: semantics labels on icons/buttons, sufficient contrast, dynamic text scaling.
- [ ] Performance: only one full list load per refresh; no per-frame API calls; images/fonts checked.
- [ ] `flutter analyze` clean; remove debug prints; verify no token appears in logs or error text.
- [ ] **Gate: error paths demoed by revoking the token / renaming the repo / going offline — each shows a clear message, no crash.**

### Phase 9 — Integration & acceptance testing

- [ ] Run full `flutter test` + `flutter analyze` suites; all green.
- [ ] Manual interop checklist against the scratch repo shared with the Python TUI:
  - [ ] Add in Flutter → visible in Python TUI after restart, and vice versa.
  - [ ] Edit title/description in one app → change visible in the other.
  - [ ] Toggle done in one app → open/closed state correct in the other.
  - [ ] Reorder in Flutter → priority order respected by the Python TUI.
  - [ ] Delete in Flutter → issue closed, hidden from both apps; also delete via Python → hidden in Flutter.
  - [ ] Non-todo issue and an open PR in the repo → both ignored by the list.
- [ ] Manual UI pass on the primary target platform (and a second platform if claimed): all screens, states, and flows.
- [ ] Token security review: confirm token only in secure storage; grep code/logs for accidental exposure.
- [ ] Update the root `README.md` with a Flutter app section (build/run instructions, token scope guidance).
- [ ] **Gate: acceptance checklist signed off; app usable as the daily TODO client.**

## 10. Testing & security notes

- Unit-test the metadata codec and repository logic with a fake `http.Client` — no real
  network in tests.
- The token is stored only via `flutter_secure_storage` (Keychain/Keystore); never logged,
  never in `shared_preferences`, never committed.
- Request the minimum scope: a fine-grained token limited to the single repository with
  *Issues: read & write* (or `public_repo` on a classic token for public repos).
- Handle rate limiting gracefully (HTTP 403 + `X-RateLimit-Remaining: 0` → friendly message).
- All destructive actions (delete) require confirmation.

## 11. Out of scope (for the first version)

- Local/offline mode (`todos.json` equivalent) — GitHub-only, matching the configured repo.
- Assignees, labels, milestones, comments on issues.
- Multiple repository profiles.

