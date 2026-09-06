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

You can also append to an existing bookmark. Running `cmdsave build` again will
append the last shell command to the existing `build` entry with `&&`.

## Bookmark storage: central vs legacy

When this repo is deployed at `~/.local/share/cmd_bookmarks` (the standard
gpersonal install), bookmarks are stored centrally per project directory:

```
~/.local/share/cmd_bookmarks/<flattened_cwd>/.local_cmd_bookmarks
~/.local/share/cmd_bookmarks/<flattened_cwd>/.local_cmd_bookmarks_stats
```

where `<flattened_cwd>` is the absolute path of the directory with every `/`
replaced by `_` (e.g. `/tmp/x/proj a` -> `_tmp_x_proj a`). Nothing is written
into the project directory itself.

When the script lives anywhere else, it falls back to legacy behavior: the
`.local_cmd_bookmarks*` files are kept in the current working directory. This
also applies to the nvim plugin (`lua/savecmd-nvim.lua`), which uses the same
detection and layout.

On first use in central mode, existing legacy `.local_cmd_bookmarks` (and
`_stats`, if present) files found in the current directory are automatically
imported into the central store. The import happens only when the central
bookmarks file is missing or empty, so existing central data is never
overwritten. The legacy files are left in place untouched.

Host tests: `zsh test/run_tests.sh` (from the repo root of this project)
exercises central mode, auto-import and legacy mode.

## Dependencies

Commands can declare dependencies on other bookmarks using `+` syntax in
`.local_cmd_bookmarks`:

```
clean|make clean
clean+build|make -j8
build+run|./myapp --serve
```

The last segment after `+` is the bookmark name; earlier segments are
dependencies (other bookmark names). Dependencies resolve recursively, so
running `run` with deps executes: `make clean && make -j8 && ./myapp --serve`.

### zsh

```
cmdrun run        # runs just ./myapp --serve
cmdrun -d run     # resolves deps: make clean && make -j8 && ./myapp --serve
```

### nvim (Telescope picker)

| Key       | Action                                    |
|-----------|-------------------------------------------|
| `Enter`   | Run just the selected command (no deps)   |
| `Ctrl+D`  | Resolve and run dependencies first        |
| `Ctrl+E`  | Edit the bookmarks file at selected line  |

The picker shows a `[+dep1+dep2]` indicator next to entries with dependencies,
and the preview pane displays the full dependency chain.

## Example nvim config (lazy vim plugin)

```lua
return {
  {
    url = "https://github.com/jesusmb1995/savecmd",
    lazy = true,
    cmd = { "LaunchVert", "LaunchHoriz", "LaunchFloat", "LaunchLast" },
    keys = {
      { "<leader><A-v>", "<cmd>LaunchVert<cr>", desc = "Launch command in vertical terminal" },
      { "<leader><A-h>", "<cmd>LaunchHoriz<cr>", desc = "Launch command in horizontal terminal" },
      { "<leader><A-i>", "<cmd>LaunchFloat<cr>", desc = "Launch command in floating terminal" },
      { "<leader>rr", "<cmd>LaunchLast<cr>", desc = "Launch last run command" }
    },
    config = function()
      require('savecmd-nvim').setup()
    end
  }
}
```