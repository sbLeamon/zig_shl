# Requirenments
- Shell should implement REPL(Read-Eval-Print Loop)
    1. **Read**: display a prompt and wait for user input 
    2. **Eval**: parse and execute the command
    3. **Print**: display output or return error message
    4. **Loop**: Go to step 1 and wait for command 
- Shell should display initial prompt: `$`
- Shell should implement simple commands: `ls`, `cd`, `pwd`, `mkdir`, `rm`, `cp`, `mv`, `cat`, `echo`, `exit`, `help`, `clear`
- Shell should handle invalid commands: return message in format `command_entered: command not found`