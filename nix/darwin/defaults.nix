# Declarative macOS prefs.
_: {
  system.defaults = {
    dock = {
      autohide = true; # auto-hide the Dock
      tilesize = 68; # Dock icon size
    };
    finder.FXPreferredViewStyle = "Nlsv"; # default Finder view: list
    trackpad.Clicking = true; # tap the trackpad to click
    # trackpad.Clicking sets the per-user trackpad driver; this global mirror
    # is what the login window reads, so tap-to-click works there too.
    NSGlobalDomain."com.apple.mouse.tapBehavior" = 1;
  };
}
