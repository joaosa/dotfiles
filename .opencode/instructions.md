# Dotfiles Agent Instructions

Use Serena for codebase symbol search first, then Context7 for library docs.

- Serena starts with the current project already active; no activation call needed.
- For understanding code, prefer Serena's `get_symbols_overview` / `find_symbol` over plain grep.
- When needing external library docs (Nix, Lua, Hammerspoon, tmux, etc.), resolve via Context7's `resolve-library-id`, then `get-library-docs`.
- Keep edits Nix-idiomatic; check flake.nix and nix/ before changes.
