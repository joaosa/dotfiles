# NAV mode: Vimium-style navigation outside text fields

Date: 2026-10-12

## Goal

Outside a text field with text in it, the frontmost app is in a NAV mode in
which Vimium's navigation keys drive it (scroll, back/forward, tabs, hints).
NAV is entered on app activation and toggled by a caps_lock tap. Inside a text
field with text, the tap enters VimMode.spoon's NORMAL mode. Firefox Developer
Edition already runs Vimium, so NAV mirrors Vimium's defaults and is disabled
there, along with the other apps that have native vim bindings.

No rule is app-specific: every app gets the same gate, the same keys and the
same exits.

## Non-goals

- Patching VimMode.spoon. It stays the pinned, unmodified derivation.
- Driving page content inside Firefox. Vimium owns that.
- Text editing. NORMAL mode and the spoon own that.
- Per-app key tables or focus tricks.

## Modules

- `lib/ax.lua` owns the two accessibility questions both modes ask:
  `editing()` (is the focused element a text field holding non-blank text?)
  and `wake(app)` (switch on an Electron app's accessibility tree).
- `modules/vim.lua` keeps the spoon setup, the caps dispatch, the app watcher
  and every mode exit. It is the only module that knows both modes exist.
- `modules/nav.lua` absorbs `element-hints.lua` and adds the NAV modal and its
  badge. It exports `enter`, `exit`, `toggle`, `isActive` and `showHints`;
  `vim.lua` never reaches into its internals. `init.lua` lists `nav` in place
  of `element-hints`.

## The editing predicate (lib/ax.lua)

`editing()` is true when the system-wide focused element has one of the
spoon's text roles (AXTextField, AXTextArea, AXComboBox) and holds at least
one non-whitespace character. An empty field is nothing to edit, and some apps
keep an empty composer focused while you read, so an empty field counts as
"outside a text field". Whitespace-only is empty because an empty Electron
composer reports a lone newline. The character count is read before the value
so a large document is not copied over IPC on every decision.

## Electron accessibility (lib/ax.lua)

Electron apps expose no accessibility tree until a client sets
`AXManualAccessibility` on the application element, and the tree takes
seconds to come up. The spoon sets it only after entering NORMAL, which is
after the gate has already asked. So `vim.lua` calls `wake(app)` on every
`launched` and `activated` event and once at reload for the frontmost app.
The set is idempotent, fails fast on native apps, and fails on an app still
launching, which the next activation retries.

## Caps dispatch (vim.lua)

Karabiner is unchanged: a lone caps tap sends f17 then escape. The key-down
event tap consumes f17 and decides, in order:

1. Spoon disabled for the frontmost app (`vim.enabled` false): let escape
   through. NAV is never entered here, so the disabled-app list is honoured
   without a second copy.
2. Spoon in NORMAL or VISUAL: let escape through (the spoon's modal handles
   it). No NAV change.
3. `editing()`: exit NAV if active, enter NORMAL, swallow the escape (Slack
   closes a thread on escape).
4. Otherwise: toggle NAV. Entering swallows the escape, because the modal's
   own escape binding would exit again at once; leaving lets it through so a
   tap still dismisses popovers.

Entering NORMAL always exits NAV first, and entering NAV is only possible
when the spoon is in insert mode, so the two modes are mutually exclusive.

## App switch (vim.lua)

On activation the watcher exits both modes (the spoon only leaves NORMAL on a
focus change inside the app, and that observer fails in Electron apps), wakes
the app, then after `TIMING.WINDOW_FOCUS_DELAY` decides as a caps tap would:
if the spoon is enabled, in insert, and `editing()` is false, enter NAV. One
timer is re-armed per activation so only the latest switch decides. The cost
is that an empty field focused after a switch needs `i` (or a click) before
typing, like vim.

## NAV modal (nav.lua)

Built on `hs.hotkey.modal`, which intercepts only bound keys; everything else
reaches the app. Scrolling uses scroll-wheel events, which reach the view
under the pointer regardless of keyboard focus, so NAV scrolls even in apps
that keep a field focused. If the pointer is outside the focused window it is
moved to the window centre first. Other actions synthesize the macOS
keystroke. Default table, Vimium names:

| Key | Action | Sent |
| --- | --- | --- |
| `j` / `k` | scroll down / up | wheel, 60 px |
| `h` / `l` | scroll left / right | wheel, 60 px |
| `d` / `u` | half page down / up | wheel, half the window height |
| `gg` / `G` | top / bottom | wheel, farther than any view |
| `H` / `L` | back / forward | cmd+[ / cmd+] |
| `J` / `K` | previous / next tab | ctrl+shift+tab / ctrl+tab |
| `r` | reload | cmd+r |
| `x` | close tab | cmd+w |
| `t` | new tab | cmd+t |
| `/` | find | exit NAV, then cmd+f (focus moves to a field) |
| `f` | hints | exit NAV, then `showHints` |
| `i` | exit NAV | nothing |
| `escape` | exit NAV | escape, re-posted so the app sees it too |

`gg` uses a pending-g flag cleared by a 500 ms timer or any other key; the
modal cannot bind sequences. `j`/`k`/`h`/`l`/`d`/`u` repeat while held.

Before executing any action other than `i` and `escape` the modal re-checks
`editing()`. If a field with text has focus (typed into, or focus moved there,
the case the spoon's observer misses in Electron apps), NAV exits and the key
is re-posted so the app receives it. The exit is deferred one tick: exiting a
modal synchronously inside a repeat-bound callback leaks the key-repeat timer.

## Hints

`element-hints.lua` moves into `nav.lua` unchanged in behaviour: labels every
clickable element in the focused window, typing a label presses it, escape or
a click cancels. `f` in NAV and the existing `altCmd+.` both call `showHints`.
Hints and NAV are never live at the same time: `f` exits NAV before showing
labels, and hints keep their own consuming event tap while labels are up.
Hints are the app-agnostic way to move to an item such as a sidebar channel.

## Exits

NAV must never be left on by accident, so every path below clears it:

- `i`, `escape`, or a caps tap while NAV is active (rule 4 toggles).
- App activation: the watcher in `vim.lua` exits both modes before deciding
  the new app's mode.
- Left mouse click: a `leftMouseDown` event tap owned by `nav.lua`, started
  on enter and stopped on exit, so it costs nothing while NAV is off.
- A field with text taking focus, caught by the pre-action self-check and by
  rule 3 of the dispatch.

## Badge

`nav.lua` draws its own `hs.canvas` badge reading `NAV`, centred at the bottom
of the main screen in the spoon's indicator style (same size, font and
corner radius; a distinct colour). Module-scope references keep the canvas,
modal, timers and taps alive; every exit path hides the badge.

## Files

- `config/hammerspoon/lib/ax.lua` (new; `editing`, `wake`)
- `config/hammerspoon/modules/nav.lua` (new; absorbs `element-hints.lua`)
- `config/hammerspoon/modules/element-hints.lua` (removed)
- `config/hammerspoon/modules/vim.lua` (dispatch rules 1 to 4, app switch)
- `config/hammerspoon/init.lua` (module list)
- `config/karabiner/karabiner.json` unchanged

## Verification

Manual, after `hs -c "hs.reload()"` shows a clean load:

1. Cmd-tab into Slack with an empty composer: `NAV` appears by itself; `j`/`k`
   scroll the pane under the pointer; `f` labels the sidebar channels; `H`
   goes back; `i` returns to insert; a click clears the badge.
2. Slack composer with text: caps shows `NORMAL`, the thread stays open;
   `h`/`l` move the caret; `i` returns to insert.
3. Finder: `NAV` appears on switch; `j`/`k` scroll, `gg`/`G` jump, `f` shows
   hints.
4. Firefox Developer Edition and Alacritty: no badge on switch, caps is a
   plain escape.
5. Quit and relaunch Slack: a caps tap in the composer with text still shows
   `NORMAL` (the tree was woken on launch).
