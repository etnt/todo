# TODO Application

This project includes a full-screen todo app for the terminal and an Android app.
Both apps can use GitHub issues to store todos.

You can use the apps with several GitHub repositories. A private repository also
works for personal lists, such as a shopping list.

## Features

- Add todos with a title and description.
- Show active todos, completed todos, or all todos.
- Mark todos as complete or active.
- See when you created or completed a todo.
- Change the order of todos by priority.
- Store todos in a local JSON file or in GitHub issues.
- Manage several GitHub repositories in the terminal app.
- Use the full-screen terminal interface.

## Install and start the terminal app

The terminal app needs Python 3.6 or later and `curses`.
Linux and macOS include `curses` with Python.

Run the app from the project directory:

```bash
./todo.py
```

You can also run it with Python:

```bash
python3 todo.py
```

## Keyboard shortcuts

| Key | Action |
|-----|--------|
| `a` | Add a todo |
| `d` | Mark the selected todo as complete or active |
| `Tab` | Show active todos, completed todos, or all todos |
| `↑/↓` | Move through the todo list |
| `p/n` | Move the selected todo up or down in priority |
| `Enter` | View todo details. Press `e` there to edit the todo. |
| `r` | Open the repository list |
| `Delete` | Delete the selected todo |
| `q` | Quit the app |

### Keys in the todo editor

| Key | Action |
|-----|--------|
| Arrow keys | Move the cursor |
| `Home` / `Ctrl+A` | Move to the start of the line |
| `End` / `Ctrl+E` | Move to the end of the line |
| `Backspace` | Delete the character before the cursor. At the start of a line, join it with the previous line. |
| `Delete` / `Ctrl+D` | Delete the character under the cursor. At the end of a line, join it with the next line. |
| `Ctrl+U` | Delete from the cursor to the start of the line |
| `Ctrl+K` | Delete from the cursor to the end of the line |
| `Enter` | Move from the title to the description, or add a line to the description |
| `Tab` | Add two spaces |
| `Ctrl+G` | Save and finish editing |
| `Esc` | Exit without saving |

### Manage GitHub repositories

A backend is a place where the app stores todos. Press `r` to open the repository list.
The selected backend appears in the app header and status bar.

| Key | Action |
|-----|--------|
| `↑/↓` | Move through the backend list |
| `Enter` | Select a backend and load its todos |
| `a` | Add a backend with a name, a GitHub repository, and an optional token |
| `Delete` | Remove a backend. Keep at least one backend. |
| `q` / `Esc` | Return to the todo list |

The app saves the selected backend and the backend list in `repos.json`.

## Store todos

By default, the app stores todos in `todos.json` in the current directory.
Each todo has:

- An ID that identifies the todo.
- A title and description.
- The date it was created.
- The date it was completed, if complete.
- A status: active or complete.
- A priority that sets its place in the list.

### Use GitHub repositories

You can store todos as issues in one or more GitHub repositories. An issue is
a GitHub item with a title and description. The app calls each storage choice
a backend.

The app stores the backend list and the selected backend in `repos.json`.
For example:

```json
{
  "active": "mytodos",
  "repos": [
    { "name": "local", "repo": null, "token": "" },
    { "name": "mytodos", "repo": "etnt/mytodos", "token": "" },
    { "name": "my-football", "repo": "etnt/my-football", "token": "" }
  ]
}
```

Each entry is either a GitHub repository or the local backend. The local backend
stores todos in `todos.json`. Write GitHub repository names as `owner/name`.

The `active` value names the backend that the app uses when it starts.
When you select another backend with `r`, the app loads its todos and
saves your selection.

A GitHub token is a secret key that lets the app access a repository.
You can save a token for each backend in `repos.json`. If that field is empty,
the app uses the `GITHUB_TOKEN` environment variable. The app needs a token
before it can use a GitHub backend.

If `repos.json` does not exist, the app creates it the first time it runs.
If `TODO_GITHUB_REPO` is set, the app adds a local backend and a GitHub backend
for that repository. Otherwise, it adds only the local backend.

To use the older environment variable setup, create a private `env.sh` file:

```bash
export TODO_GITHUB_REPO="owner/repo"
export GITHUB_TOKEN="ghp_your_token_here"
```

Load the variables, then start the app:

```bash
. ./env.sh
./todo.py
```

After the app creates `repos.json`, it no longer needs `TODO_GITHUB_REPO`.
It still uses `GITHUB_TOKEN` when a GitHub backend has no token of its own.

`repos.json` can contain GitHub tokens. Do not share this file. Keep it out of
version control if you save tokens in it. The repository `.gitignore` already
lists `repos.json`.

When you use a GitHub backend:

- Each todo is a GitHub issue.
- Active todos are open issues. Completed todos are closed issues.
- The app saves priority and other internal data in a hidden block in each issue description.
- Deleting a todo marks its issue as deleted and closes the issue.

## Android app

The Flutter app is in `flutter_todo/`. It uses the same GitHub issues as
the terminal app. Flutter is the software used to build this mobile app.

The Android app supports several repositories. It stores GitHub tokens in
Android's secure storage. It can also refresh the todo list, mark todos
complete or active, delete todos, and change their priority by dragging them.

From the project directory, run these commands:

```bash
cd flutter_todo
flutter test
flutter build apk --debug
flutter run
```

## Project files

```text
todo/
├── todo.py            # Starts the terminal app
├── models.py          # Defines a todo
├── todo_manager.py    # Loads and saves todos
├── repo_config.py     # Loads and saves the backend list
├── repos.json         # Backend list, created when the app starts
├── ui.py              # Draws the terminal screens
├── test_multi_repo.py # Tests backend setup
└── todos.json         # Local todo data, created when needed
```
