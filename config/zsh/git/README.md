# Vendored prezto git module

`alias.zsh` and `functions/` are vendored unmodified from
[sorin-ionescu/prezto](https://github.com/sorin-ionescu/prezto) `modules/git`
(MIT license), taken from the nixpkgs `zsh-prezto-0-unstable-2025-07-30`
package. Only this module is used; the prezto framework itself is not loaded —
`nix/home/common.nix` adds `functions/` to `fpath`, autoloads the helpers, and
sources `alias.zsh` directly.
