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
        status = f" View: {self.current_view.upper()} | a:Add Enter:View/Edit d:Done Tab:Switch ↑↓:Nav p/n:Priority Del:Delete q:Quit "
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
        body_lines = todo.body.split('\n')
        for body_line in body_lines[:height - y - 5]:
            if len(body_line) > width - 6:
                wrapped = textwrap.wrap(body_line, width=width - 6)
                for wrapped_line in wrapped:
                    if y >= height - 5:
                        break
                    self.stdscr.addstr(y, 4, wrapped_line)
                    y += 1
            else:
                if y >= height - 5:
                    break
                self.stdscr.addstr(y, 4, body_line)
                y += 1
        
        y = height - 5
        self.stdscr.addstr(y, 2, f"Status: {todo.status}", curses.color_pair(2 if todo.status == "done" else 3))
        y += 1
        self.stdscr.addstr(y, 2, f"Created: {datetime.fromisoformat(todo.created_date).strftime('%Y-%m-%d %H:%M')}")
        if todo.finished_date:
            y += 1
            self.stdscr.addstr(y, 2, f"Finished: {datetime.fromisoformat(todo.finished_date).strftime('%Y-%m-%d %H:%M')}")
        
        self.stdscr.attron(curses.color_pair(1))
        self.stdscr.addstr(height - 1, 0, " e:Edit | Press any key to return ".ljust(width - 1))
        self.stdscr.attroff(curses.color_pair(1))
        
        self.stdscr.refresh()
        key = self.stdscr.getch()
        
        if key == ord('e'):
            self.edit_todo_form(todo)

    def edit_single_line(self, win, y: int, x: int, initial_text: str, max_len: int) -> Optional[str]:
        """Single-line text editor supporting cursor navigation, backspace, delete, home, end."""
        text = list(initial_text)
        cursor_pos = len(text)
        win.keypad(True)
        curses.curs_set(1)
        curses.noecho()
        
        while True:
            display_str = "".join(text)
            win.addstr(y, x, " " * max_len)
            
            if cursor_pos < max_len:
                view_start = 0
            else:
                view_start = cursor_pos - max_len + 1
            
            visible_text = display_str[view_start:view_start + max_len]
            win.addstr(y, x, visible_text)
            win.move(y, x + (cursor_pos - view_start))
            win.refresh()
            
            ch = win.getch()
            
            if ch in (curses.KEY_ENTER, 10, 13):
                return "".join(text).strip()
            elif ch == 27:  # Esc
                return None
            elif ch in (curses.KEY_LEFT,):
                if cursor_pos > 0:
                    cursor_pos -= 1
            elif ch in (curses.KEY_RIGHT,):
                if cursor_pos < len(text):
                    cursor_pos += 1
            elif ch in (curses.KEY_HOME, 1):  # KEY_HOME or Ctrl+A
                cursor_pos = 0
            elif ch in (curses.KEY_END, 5):   # KEY_END or Ctrl+E
                cursor_pos = len(text)
            elif ch in (curses.KEY_BACKSPACE, 127, 8):
                if cursor_pos > 0:
                    text.pop(cursor_pos - 1)
                    cursor_pos -= 1
            elif ch in (curses.KEY_DC, 330, 4):  # KEY_DC or Ctrl+D
                if cursor_pos < len(text):
                    text.pop(cursor_pos)
            elif ch == 21:  # Ctrl+U
                text = text[cursor_pos:]
                cursor_pos = 0
            elif ch == 11:  # Ctrl+K
                text = text[:cursor_pos]
            elif 32 <= ch <= 126 or (ch >= 160 and ch <= 0x10ffff):
                char = chr(ch)
                text.insert(cursor_pos, char)
                cursor_pos += 1

    def edit_multiline(self, win, initial_text: str, max_y: int, max_x: int) -> Optional[str]:
        """Multi-line text editor supporting 2D cursor navigation, line split/merge, deletion, scrolling."""
        lines = initial_text.split("\n") if initial_text else [""]
        if not lines:
            lines = [""]
        
        row = 0
        col = 0
        scroll_y = 0
        scroll_x = 0
        win.keypad(True)
        curses.curs_set(1)
        curses.noecho()
        
        while True:
            row = max(0, min(row, len(lines) - 1))
            col = max(0, min(col, len(lines[row])))
            
            if row < scroll_y:
                scroll_y = row
            elif row >= scroll_y + max_y:
                scroll_y = row - max_y + 1
                
            if col < scroll_x:
                scroll_x = col
            elif col >= scroll_x + max_x:
                scroll_x = col - max_x + 1
            
            win.clear()
            for i in range(max_y):
                line_idx = scroll_y + i
                if line_idx < len(lines):
                    line_content = lines[line_idx]
                    if scroll_x < len(line_content):
                        visible_chunk = line_content[scroll_x:scroll_x + max_x]
                        win.addstr(i, 0, visible_chunk)
            
            win.move(row - scroll_y, col - scroll_x)
            win.refresh()
            
            ch = win.getch()
            
            if ch == 7:  # Ctrl+G to finish
                return "\n".join(lines)
            elif ch == 27:  # Esc to cancel
                return None
            elif ch == curses.KEY_UP:
                if row > 0:
                    row -= 1
                    col = min(col, len(lines[row]))
            elif ch == curses.KEY_DOWN:
                if row < len(lines) - 1:
                    row += 1
                    col = min(col, len(lines[row]))
            elif ch == curses.KEY_LEFT:
                if col > 0:
                    col -= 1
                elif row > 0:
                    row -= 1
                    col = len(lines[row])
            elif ch == curses.KEY_RIGHT:
                if col < len(lines[row]):
                    col += 1
                elif row < len(lines) - 1:
                    row += 1
                    col = 0
            elif ch in (curses.KEY_HOME, 1):  # KEY_HOME or Ctrl+A
                col = 0
            elif ch in (curses.KEY_END, 5):   # KEY_END or Ctrl+E
                col = len(lines[row])
            elif ch in (curses.KEY_ENTER, 10, 13):
                current_line = lines[row]
                lines[row] = current_line[:col]
                lines.insert(row + 1, current_line[col:])
                row += 1
                col = 0
            elif ch in (curses.KEY_BACKSPACE, 127, 8):
                if col > 0:
                    current_line = lines[row]
                    lines[row] = current_line[:col - 1] + current_line[col:]
                    col -= 1
                elif row > 0:
                    prev_line_len = len(lines[row - 1])
                    lines[row - 1] += lines[row]
                    lines.pop(row)
                    row -= 1
                    col = prev_line_len
            elif ch in (curses.KEY_DC, 330, 4):  # KEY_DC or Ctrl+D
                if col < len(lines[row]):
                    current_line = lines[row]
                    lines[row] = current_line[:col] + current_line[col + 1:]
                elif row < len(lines) - 1:
                    lines[row] += lines[row + 1]
                    lines.pop(row + 1)
            elif ch == 21:  # Ctrl+U
                lines[row] = lines[row][col:]
                col = 0
            elif ch == 11:  # Ctrl+K
                lines[row] = lines[row][:col]
            elif ch == 9:  # Tab
                lines[row] = lines[row][:col] + "  " + lines[row][col:]
                col += 2
            elif 32 <= ch <= 126 or (ch >= 160 and ch <= 0x10ffff):
                char = chr(ch)
                lines[row] = lines[row][:col] + char + lines[row][col:]
                col += 1

    def edit_todo_form(self, todo: Todo):
        height, width = self.stdscr.getmaxyx()
        self.stdscr.clear()
        
        self.stdscr.addstr(0, 0, "Edit TODO".ljust(width - 1), curses.A_BOLD)
        self.stdscr.addstr(1, 0, "─" * (width - 1))
        
        self.stdscr.addstr(3, 2, "Header (one line):")
        self.stdscr.addstr(4, 2, ">")
        
        self.stdscr.addstr(7, 2, "Body (multi-line, Ctrl+G to finish):")
        self.stdscr.addstr(8, 2, ">")
        
        self.stdscr.attron(curses.color_pair(1))
        self.stdscr.addstr(height - 1, 0, " Edit header & body. Arrows/Home/End navigate, Ctrl+G saves, Esc cancels ".ljust(width - 1))
        self.stdscr.attroff(curses.color_pair(1))
        
        header = self.edit_single_line(self.stdscr, 4, 4, todo.header, width - 6)
        if header is None or not header:
            curses.curs_set(0)
            return
        
        body_win = curses.newwin(height - 12, width - 6, 8, 4)
        body = self.edit_multiline(body_win, todo.body or "", height - 12, width - 6)
        if body is None:
            curses.curs_set(0)
            return
        
        curses.curs_set(0)
        self.manager.update_todo(todo, header, body)

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
        self.stdscr.addstr(height - 1, 0, " Enter header & body. Arrows/Home/End navigate, Ctrl+G saves, Esc cancels ".ljust(width - 1))
        self.stdscr.attroff(curses.color_pair(1))
        
        header = self.edit_single_line(self.stdscr, 4, 4, "", width - 6)
        if header is None or not header:
            curses.curs_set(0)
            return
        
        body_win = curses.newwin(height - 12, width - 6, 8, 4)
        body = self.edit_multiline(body_win, "", height - 12, width - 6)
        if body is None:
            curses.curs_set(0)
            return
        
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
            elif key == ord('p') and todos:  # p = move up in priority
                self.manager.move_up(todos[self.selected_idx], todos)
                self.selected_idx = max(0, self.selected_idx - 1)
            elif key == ord('n') and todos:  # n = move down in priority (next)
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
