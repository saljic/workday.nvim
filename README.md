# 📋 workday.nvim

A powerful task management plugin for Neovim that transforms your editor into a productivity workspace.

## 💡 Why workday.nvim?

During work, I constantly run into situations where:
- Someone asks me to investigate something
- I discover bugs that need fixing later
- I want to explore interesting code patterns
- Ideas pop up that I don't want to forget

The problem? I didn't want to pollute the sprint board with personal tasks that only matter to me. Using Notepad or browser tabs was clunky and took me away from my coding flow.

**workday.nvim** was born from this need - a lightweight, integrated task manager that lives right in your editor, keeping your personal todos organized without disrupting your development workflow.

## ✨ Features

- **Three-Pane Interface**: Todo, Backlog, and Archive in a clean split layout
- **Checkbox Management**: Automatic `- [ ]` and `- [x]` prefix handling
- **Task Movement**: Seamlessly move tasks between different sections
- **Visual Selection Support**: Batch operations on multiple tasks
- **Undo/Redo System**: Full command history with undo/redo support
- **Auto-Save**: Persistent storage with automatic saving
- **Syntax Highlighting**: Color-coded headers and task states

## 📸 Demo

TODO: Add gif demo

## 📦 Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/workday.nvim",
  config = function()
    require("workday").setup({
      -- Optional configuration
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/workday.nvim",
  config = function()
    require("workday").setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'your-username/workday.nvim'
```

Then in your `init.lua`:

```lua
require("workday").setup()
```

## 🚀 Quick Start

1. Open workday interface: `<leader>ow` (or `:Workday`)
2. Add your first todo in the Todo pane
3. Toggle completion: `<leader>tt`
4. Move tasks around: `<leader>tb` (to backlog), `<leader>td` (to todo)
5. Archive completed tasks: `<leader>ta`

## ⌨️ Default Keybindings

| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ow` | Open Workday | Launch the workday interface |
| `<leader>tt` | Toggle Todo | Toggle task completion (works in visual mode) |
| `<leader>tb` | Move to Backlog | Move task(s) from todo to top of backlog |
| `<leader>td` | Move to Todo | Move task(s) from backlog/archive to bottom of todo |
| `<leader>ta` | Archive Completed | Archive all completed tasks to archive pane |
| `<leader>tu` | Undo | Undo last workday command |
| `<leader>tr` | Redo | Redo last undone workday command |
| `<leader>th` | Show History | Display command history |
| `q` | Quit | Close workday interface |

## ⚙️ Configuration

### Default Configuration

```lua
require("workday").setup({
  keymap = {
    toggle_todo = "<leader>tt",
    move_to_backlog_top = "<leader>tb",
    archive_completed_tasks = "<leader>ta",
    move_to_todo_bottom = "<leader>td",
    quit = "q",
    start = "<leader>ow",
    undo = "<leader>tu",
    redo = "<leader>tr",
    show_history = "<leader>th",
  },
  persistence = {
    enabled = true,
    todo_file_path = vim.fn.stdpath('data') .. "/workday_todo.txt",
    backlog_file_path = vim.fn.stdpath('data') .. "/workday_backlog.txt",
    archive_file_path = vim.fn.stdpath('data') .. "/workday_archive.txt",
  }
})
```

### Custom Configuration Example

```lua
require("workday").setup({
  keymap = {
    toggle_todo = "<C-t>",
    move_to_backlog_top = "<C-b>",
    start = "<leader>tw",
  },
  persistence = {
    enabled = true,
    todo_file_path = "~/Documents/workday_todo.txt",
    backlog_file_path = "~/Documents/workday_backlog.txt",
    archive_file_path = "~/Documents/workday_archive.txt",
  }
})
```

## 🎯 Usage Guide

### Task Management Workflow

1. **Add Tasks**: Type directly in any pane, tasks auto-format with appropriate prefixes
2. **Complete Tasks**: Use `<leader>tt` to toggle completion status
3. **Organize Tasks**:
   - Move active tasks to backlog when not immediately actionable
   - Move backlog items to todo when ready to work on them
   - Archive completed tasks to keep todo list clean

### Visual Mode Operations

Select multiple tasks and use the same keybindings to perform batch operations:

- `<leader>tt` - Toggle multiple tasks
- `<leader>tb` - Move multiple tasks to backlog
- `<leader>td` - Move multiple tasks to todo

### Undo/Redo System

- `<leader>tu` - Undo last workday command
- `<leader>tr` - Redo last undone command
- `<leader>th` - View command history

## 🏗️ Architecture

### Three-Pane Layout

- **Todo**: Active tasks with `- [ ]` and `- [x]` checkboxes
- **Backlog**: Unstructured task storage without checkboxes
- **Archive**: Completed tasks with `- [x]` checkboxes preserved

### Smart Prefix Management

- Todo pane: Automatically adds `- [ ]` prefix to new lines
- Archive pane: Automatically adds `- [x]` prefix to new lines
- Backlog pane: Plain text without prefixes

### Command Pattern

Built with a robust command pattern that enables:

- Full undo/redo functionality
- Command history tracking
- Atomic operations

## 🎨 Customization

### Highlight Groups

You can customize the appearance by overriding these highlight groups:

```lua
vim.api.nvim_set_hl(0, "WorkdayTodoHeader", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "WorkdayBacklogHeader", { fg = "#bb9af7", bold = true })
vim.api.nvim_set_hl(0, "WorkdayArchiveHeader", { fg = "#9ece6a", bold = true })
vim.api.nvim_set_hl(0, "WorkdayCompleted", { fg = "#565f89", strikethrough = true })
vim.api.nvim_set_hl(0, "WorkdayUncompleted", { fg = "#c0caf5" })
```

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with the awesome Neovim API
- Thanks to the Neovim community for their excellent plugins and documentation

---

⭐ If you like this plugin, please consider giving it a star on GitHub!

