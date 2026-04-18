# TODO Application

A terminal-based full-screen todo application with priority management.

## Features

- ✅ Add todo notes with header and body text
- ✅ Display active, done, or all todos
- ✅ Mark todos as done/undone
- ✅ Creation and completion timestamps
- ✅ Priority ordering (reorder todos)
- ✅ Persistent storage in JSON format
- ✅ Optional GitHub Issues-backed storage
- ✅ Full-screen terminal interface

## Installation

No installation required. Python 3.6+ with curses support (standard on Linux/macOS).

## Usage

Run the application:
```bash
./todo.py
```

Or:
```bash
python3 todo.py
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `a` | Add new todo |
| `d` | Mark selected todo as done/undone (toggle) |
| `Tab` | Switch between Active/Done/All views |
| `↑/↓` | Navigate todo list |
| `Ctrl+↑/↓` | Change priority (move up/down) |
| `Enter` | View todo details |
| `Delete` | Remove todo permanently |
| `q` | Quit application |

## Data Storage

Todos are stored in `todos.json` in the current directory. Each todo contains:
- Unique ID
- Header (title)
- Body (description)
- Creation date
- Finished date (if completed)
- Status (active/done)
- Priority (for ordering)

### GitHub Issues storage (optional)

You can store todos as issues in a GitHub repository instead of `todos.json`.

Set these environment variables before running the app:

```bash
export TODO_GITHUB_REPO="owner/repo"
export GITHUB_TOKEN="ghp_your_token_here"
./todo.py
```

Behavior in GitHub-backed mode:
- Each todo is stored as an issue
- Active todos are open issues, done todos are closed issues
- Priority and internal metadata are saved in a hidden metadata block in the issue body
- Deleting a todo marks it as deleted and closes its issue

## Project Structure

```
todo/
├── todo.py           # Main entry point
├── models.py         # Todo data model
├── todo_manager.py   # Business logic & persistence
├── ui.py             # Curses-based UI
└── todos.json        # Data storage (auto-created)
```
