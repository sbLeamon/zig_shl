# Requirenments

- Shell should implement REPL(Read-Eval-Print Loop)
    1. **Read**: display a prompt and wait for user input
    2. **Eval**: parse and execute the command
    3. **Print**: display output or return error message
    4. **Loop**: Go to step 1 and wait for command

- Shell should display initial prompt: `$`

- Shell should implement simple commands: `ls`, `cd`, `pwd`, `mkdir`, `rm`, `cp`, `mv`, `cat`, `echo`, `exit`, `help`, `clear`

- Shell should handle invalid commands: return message in format `command_entered: command not found`
- Shell should implement "plugin-like" architecture for commands

## Commands

- Shell should handle `ls` command:
  - When user enters `ls`, **shl** displays list of files and folders in current folder
  - `ls` displays table with columns: Type, Last time modified, Size, Name
  - `ls` formating rules:
    - columns width should be adjusted to content
    - gap between columns should be 4 spaces
  - `ls` formating:
Type    Last modified      Size         Name
d       Mar 4 0:34:24      100020000    .git
f       Feb 19 17:40:58    10002        .gitignore
d       Mar 4 0:34:24      10002        .zig-cache
f       Feb 20 12:05:48    10002        build.zig
f       Feb 19 15:14:53    10002        build.zig.zon
f       Feb 19 18:14:35    10002        README.md
f       Mar 2 9:55:10      10002        spec.md
d       Mar 4 0:34:24      10002        src
f       Mar 2 9:58:46      10002        TODO_TASKS.md
d       Mar 4 0:34:24      10002        zig-out
