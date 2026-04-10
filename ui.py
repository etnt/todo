import curses
import textwrap
from datetime import datetime
from typing import List, Optional
from models import Todo
from todo_manager import TodoManager


class TodoUI:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.manager = TodoManager()
        self.current_view = "active"
        self.selected_idx = 0
        self.scroll_offset = 0
        
        curses.curs_set(0)
        curses.init_pair(1, curses.COLOR_BLACK, curses.COLOR_WHITE)
        curses.init_pair(2, curses.COLOR_GREEN, curses.COLOR_BLACK)
        curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)
        curses.init_pair(4, curses.COLOR_CYAN, curses.COLOR_BLACK)

    def get_current_todos(self) -> List[Todo]:
        if self.current_view == "active":
            return self.manager.get_active_todos()
        elif self.current_view == "done":
            return self.manager.get_done_todos()
        else:
            return self.manager.get_all_todos()

    def draw_status_bar(self):
        height, width = self.stdscr.getmaxyx()
        status = f" View: {self.current_view.upper()} | a:Add d:Done Tab:Switch ↑↓:Nav Ctrl+↑↓:Priority Del:Delete q:Quit "
        self.stdscr.attron(curses.color_pair(1))
        self.stdscr.addstr(height - 1, 0, status[:width - 1].ljust(width - 1))
        self.stdscr.attroff(curses.color_pair(1))

    def draw_todos(self):
        height, width = self.stdscr.getmaxyx()
        todos = self.get_current_todos()
        
        self.stdscr.addstr(0, 0, f"TODO List - {self.current_view.upper()}".ljust(width - 1), curses.A_BOLD)
        self.stdscr.addstr(1, 0, "─" * (width - 1))

        visible_height = height - 4
        
        if not todos:
            self.stdscr.addstr(3, 2, "No todos to display. Press 'a' to add one.")
            return

        if self.selected_idx >= len(todos):
            self.selected_idx = max(0, len(todos) - 1)

        if self.selected_idx < self.scroll_offset:
            self.scroll_offset = self.selected_idx
        elif self.selected_idx >= self.scroll_offset + visible_height:
            self.scroll_offset = self.selected_idx - visible_height + 1

        for i, todo in enumerate(todos[self.scroll_offset:self.scroll_offset + visible_height]):
            actual_idx = i + self.scroll_offset
            y = i + 2
            
            status_icon = "✓" if todo.status == "done" else "○"
            created = datetime.fromisoformat(todo.created_date).strftime("%Y-%m-%d")
            
            header_text = f"{status_icon} {todo.header}"
            max_header_len = width - 15
            if len(header_text) > max_header_len:
                header_text = header_text[:max_header_len - 3] + "..."
            
            line = f"{header_text.ljust(max_header_len)} {created}"
            
            if actual_idx == self.selected_idx:
                self.stdscr.attron(curses.color_pair(1))
                self.stdscr.addstr(y, 0, line[:width - 1].ljust(width - 1))
                self.stdscr.attroff(curses.color_pair(1))
            else:
                color = curses.color_pair(2) if todo.status == "done" else curses.color_pair(0)
                self.stdscr.addstr(y, 0, line[:width - 1], color)

    def draw_detail_view(self, todo: Todo):
        height, width = self.stdscr.getmaxyx()
        self.stdscr.clear()
        
        self.stdscr.addstr(0, 0, "TODO Details".ljust(width - 1), curses.A_BOLD)
        self.stdscr.addstr(1, 0, "─" * (width - 1))
        
        y = 3
        self.stdscr.addstr(y, 2, "Header:", curses.A_BOLD)
        y += 1
        self.stdscr.addstr(y, 4, todo.header[:width - 6])
        y += 2
        
        self.stdscr.addstr(y, 2, "Body:", curses.A_BOLD)
        y += 1
        wrapped_body = textwrap.wrap(todo.body, width=width - 6)
        for line in wrapped_body[:height - y - 5]:
            self.stdscr.addstr(y, 4, line)
            y += 1
        
        y = height - 5
        self.stdscr.addstr(y, 2, f"Status: {todo.status}", curses.color_pair(2 if todo.status == "done" else 3))
        y += 1
        self.stdscr.addstr(y, 2, f"Created: {datetime.fromisoformat(todo.created_date).strftime('%Y-%m-%d %H:%M')}")
        if todo.finished_date:
            y += 1
            self.stdscr.addstr(y, 2, f"Finished: {datetime.fromisoformat(todo.finished_date).strftime('%Y-%m-%d %H:%M')}")
        
        self.stdscr.attron(curses.color_pair(1))
        self.stdscr.addstr(height - 1, 0, " Press any key to return ".ljust(width - 1))
        self.stdscr.attroff(curses.color_pair(1))
        
        self.stdscr.refresh()
        self.stdscr.getch()

    def add_todo_form(self):
        height, width = self.stdscr.getmaxyx()
        self.stdscr.clear()
        
        self.stdscr.addstr(0, 0, "Add New TODO".ljust(width - 1), curses.A_BOLD)
        self.stdscr.addstr(1, 0, "─" * (width - 1))
        
        self.stdscr.addstr(3, 2, "Header (one line):")
        self.stdscr.addstr(4, 2, ">")
        
        self.stdscr.addstr(7, 2, "Body (multi-line, Ctrl+G to finish):")
        self.stdscr.addstr(8, 2, ">")
        
        self.stdscr.attron(curses.color_pair(1))
        self.stdscr.addstr(height - 1, 0, " Enter header, then body. Ctrl+G to save, Esc to cancel ".ljust(width - 1))
        self.stdscr.attroff(curses.color_pair(1))
        
        curses.curs_set(1)
        curses.echo()
        
        self.stdscr.move(4, 4)
        self.stdscr.refresh()
        header = self.stdscr.getstr(4, 4, width - 6).decode('utf-8')
        
        if not header:
            curses.noecho()
            curses.curs_set(0)
            return
        
        body_win = curses.newwin(height - 12, width - 6, 8, 4)
        body_win.keypad(True)
        
        body_lines = []
        current_line = ""
        
        while True:
            body_win.clear()
            for i, line in enumerate(body_lines):
                if i < height - 13:
                    body_win.addstr(i, 0, line[:width - 7])
            if len(body_lines) < height - 13:
                body_win.addstr(len(body_lines), 0, current_line[:width - 7])
            body_win.refresh()
            
            ch = body_win.getch()
            
            if ch == 7:  # Ctrl+G
                if current_line:
                    body_lines.append(current_line)
                break
            elif ch == 27:  # Esc
                curses.noecho()
                curses.curs_set(0)
                return
            elif ch in (curses.KEY_ENTER, 10, 13):
                body_lines.append(current_line)
                current_line = ""
            elif ch in (curses.KEY_BACKSPACE, 127, 8):
                if current_line:
                    current_line = current_line[:-1]
                elif body_lines:
                    current_line = body_lines.pop()
            elif 32 <= ch <= 126:
                current_line += chr(ch)
        
        body = "\n".join(body_lines)
        
        curses.noecho()
        curses.curs_set(0)
        
        self.manager.add_todo(header, body)

    def run(self):
        while True:
            self.stdscr.clear()
            self.draw_todos()
            self.draw_status_bar()
            self.stdscr.refresh()
            
            key = self.stdscr.getch()
            todos = self.get_current_todos()
            
            if key == ord('q'):
                break
            elif key == ord('a'):
                self.add_todo_form()
            elif key == ord('\t'):
                if self.current_view == "active":
                    self.current_view = "done"
                elif self.current_view == "done":
                    self.current_view = "all"
                else:
                    self.current_view = "active"
                self.selected_idx = 0
                self.scroll_offset = 0
            elif key == curses.KEY_UP and todos:
                self.selected_idx = max(0, self.selected_idx - 1)
            elif key == curses.KEY_DOWN and todos:
                self.selected_idx = min(len(todos) - 1, self.selected_idx + 1)
            elif key == 566 and todos:  # Ctrl+Up
                self.manager.move_up(todos[self.selected_idx], todos)
                self.selected_idx = max(0, self.selected_idx - 1)
            elif key == 525 and todos:  # Ctrl+Down
                self.manager.move_down(todos[self.selected_idx], todos)
                self.selected_idx = min(len(todos) - 1, self.selected_idx + 1)
            elif key == ord('d') and todos:
                self.manager.toggle_status(todos[self.selected_idx])
            elif key in (curses.KEY_ENTER, 10, 13) and todos:
                self.draw_detail_view(todos[self.selected_idx])
            elif key in (curses.KEY_DC, 330) and todos:
                self.manager.delete_todo(todos[self.selected_idx])
                if self.selected_idx >= len(self.get_current_todos()):
                    self.selected_idx = max(0, len(self.get_current_todos()) - 1)


def main(stdscr):
    ui = TodoUI(stdscr)
    ui.run()
