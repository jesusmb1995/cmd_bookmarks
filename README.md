A command bookeeping script with autocompletion for zsh.
Useful to remember compilation procedure/commands of specific project folders.

For example:
```
cmake -B build -S . -DGPU=ON && cmake build --build build
cmdsave build
```

Then any other time, type `cmdrun b` and hit `<tab>` to autocomplete:
```
cmdrun build
```

## Example nvim config (lazy vim plugin)

```
_return {
  {
    url = "https://github.com/jesusmb1995/savecmd",
    lazy = true,
    cmd = { "LaunchVert", "LaunchHoriz", "LaunchFloat" },
    keys = {
      { "<leader><A-v>", "<cmd>LaunchVert<cr>", desc = "Launch command in vertical terminal" },
      { "<leader><A-h>", "<cmd>LaunchHoriz<cr>", desc = "Launch command in horizontal terminal" },
      { "<leader><A-i>", "<cmd>LaunchFloat<cr>", desc = "Launch command in horizontal terminal" },
      { "<leader>rr", "<cmd>LaunchLast<cr>", desc = "Launch last run command" }
    },
    config = function()
      require('savecmd-nvim').setup()
    end
  }
}
```