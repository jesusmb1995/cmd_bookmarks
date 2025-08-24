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
