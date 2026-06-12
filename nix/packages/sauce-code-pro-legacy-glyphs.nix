{
  stdenvNoCC,
  nerd-fonts,
  julia-mono,
  python3,
}:

# SauceCodePro Nerd Font with the Symbols for Legacy Computing block
# (U+1FB00-1FBFF: sextants, wedges) grafted in from JuliaMono. Alacritty's
# font fallback only consults the fixed macOS cascade list, never other
# user-installed fonts, so chafa's finer symbol classes only render if the
# primary font itself carries the glyphs. The donor glyphs are solid blocks
# (weight-irrelevant) with the same 0.6em advance width; name tables are
# untouched so the family/style names match the stock font. Both fonts are
# OFL-licensed and the merge happens locally from pinned nixpkgs sources.
stdenvNoCC.mkDerivation {
  pname = "sauce-code-pro-nerd-font-legacy-glyphs";
  inherit (nerd-fonts.sauce-code-pro) version;

  nativeBuildInputs = [
    (python3.withPackages (pythonPackages: [ pythonPackages.fonttools ]))
  ];

  dontUnpack = true;

  buildCommand = ''
    python3 ${./merge-legacy-glyphs.py} \
      ${nerd-fonts.sauce-code-pro}/share/fonts \
      ${julia-mono}/share/fonts/truetype/JuliaMono-Regular.ttf \
      "$out/share/fonts"
  '';

  meta = {
    inherit (nerd-fonts.sauce-code-pro.meta) description homepage license;
  };
}
