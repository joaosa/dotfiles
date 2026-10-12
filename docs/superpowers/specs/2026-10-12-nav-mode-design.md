# NAV mode: Vimium-style navigation outside text fields

Date: 2026-10-12

## Goal

Tapping caps_lock outside a text field enters a NAV mode in which Vimium's
navigation keys drive the frontmost app (scroll, back/forward, tabs, hints).
Inside a text field the tap keeps entering VimMode.spoon's NORMAL mode. Firefox
Developer Edition already runs Vimium, so NAV mirrors Vimium's defaults and is
disabled there, along with the other apps that have native vim bindings.

## Non-goals

- Patching VimMode.spoon. It stays the pinned, unmodified derivation.
- Driving page content inside Firefox. Vimium owns that.
- Text editing. NORMAL mode and the spoon own that.

## Modules

Two Hammerspoon modules replace today's three (`vim`, `element-hints`):

- `modules/vim.lua` keeps the spoon setup, the caps dispatch and every mode
  exit. It is the only module that knows both modes exist.
- `modules/nav.lua` absorbs `element-hints.lua` and adds the NAV modal and its
  badge. It exports `enter`, `exit`, `isActive` and `showHints`; `vim.lua`
  never reaches into its internals. `init.lua` lists `nav` in place of
  `element-hints`.

## Caps dispatch (vim.lua)

Karabiner is unchanged: a lone caps tap sends f17 then escape. The existing
key-down event tap handles f17 and decides, in order:

1. Spoon disabled for the frontmost app (`vim.enabled` false): consume f17,
   let escape through. NAV is never entered here, so the disabled-app list is
   honoured without a second copy.
2. Spoon in NORMAL or VISUAL: let escape through (the spoon's modal handles
   it). No NAV change.
3. A text field has focus (same AX roles as today): exit NAV if active, enter
   NORMAL, swallow the escape. Unchanged from today.
4. Otherwise: toggle NAV. The escape passes through so a single tap still
   dismisses popovers; swallowing is reserved for NORMAL entry.

Entering NORMAL always exits NAV first, and entering NAV is only possible
when the spoon is in insert mode, so the two modes are mutually exclusive.

## NAV modal (nav.lua)

Built on `hs.hotkey.modal`, which intercepts only bound keys; everything else
reaches the app. Actions synthesize macOS-conventional keystrokes to the
focused window, so scroll keys double as list navigation in Finder, Mail and
the Slack sidebar. Default table, Vimium names:

| Key | Action | Sent |
| --- | --- | --- |
| `j` / `k` | scroll down / up | down / up |
| `h` / `l` | scroll left / right | left / right |
| `d` / `u` | half page down / up | pagedown / pageup |
| `gg` / `G` | top / bottom | cmd+up / cmd+down |
| `H` / `L` | back / forward | cmd+[ / cmd+] |
| `J` / `K` | previous / next tab | ctrl+shift+tab / ctrl+tab |
| `r` | reload | cmd+r |
| `x` | close tab | cmd+w |
| `t` | new tab | cmd+t |
| `/` | find | cmd+f, then exit NAV (focus moves to a field) |
| `f` | hints | exit NAV, then `showHints` |
| `i`, `escape` | exit NAV | nothing |

`gg` uses a pending-g flag cleared by a 500 ms timer or any other key; the
modal cannot bind sequences. `j`/`k`/`h`/`l`/`d`/`u` repeat while held.

Before executing any action the modal re-checks `focusedTextField()`. If a
field has quietly taken focus (the case the spoon's observer misses in Electron
apps), NAV exits and the key is re-posted so the app receives it.

## Hints

`element-hints.lua` moves into `nav.lua` unchanged in behaviour: labels every
clickable element in the focused window, typing a label presses it, escape or
a click cancels. `f` in NAV and the existing `altCmd+.` both call `showHints`.
Hints and NAV are never live at the same time: `f` exits NAV before showing
labels, and hints keep their own consuming event tap while labels are up.

## Exits

NAV must never be left on by accident, so every path below clears it:

- `i`, `escape`, or a caps tap while NAV is active (rule 4 toggles).
- App activation: the application watcher in `vim.lua` already calls the
  spoon's exit; it now also calls `nav.exit()`.
- Left mouse click: a `leftMouseDown` event tap owned by `nav.lua`, started
  on enter and stopped on exit, so it costs nothing while NAV is off.
- A text field taking focus, caught by the pre-action self-check above and by
  rule 3 of the dispatch.

## Badge

`nav.lua` draws its own `hs.canvas` badge reading `NAV`, centred at the bottom
of the main screen in the spoon's indicator style (same size, font and
corner radius; a distinct colour). Module-scope references keep the canvas,
modal, timers and taps alive; every exit path hides the badge.

## Files

- `config/hammerspoon/modules/nav.lua` (new; absorbs `element-hints.lua`)
- `config/hammerspoon/modules/element-hints.lua` (removed)
- `config/hammerspoon/modules/vim.lua` (dispatch rules 1 to 4, exits)
- `config/hammerspoon/init.lua` (module list)
- `config/karabiner/karabiner.json` unchanged

## Verification

Manual, after `hs -c "hs.reload()"` shows a clean load:

1. Slack channel view: caps shows `NAV`; `j`/`k` move the message list;
   `H` goes back; click anywhere clears the badge.
2. Slack composer: caps shows `NORMAL`, thread stays open; `i` returns to
   insert; caps again now toggles nothing because focus is in a field.
3. Finder: caps, `j`/`k` move the selection, `gg`/`G` jump, `f` shows hints.
4. Firefox Developer Edition and Alacritty: caps is a plain escape, no badge.
5. Cmd-tab away from an app in NAV: badge clears.
