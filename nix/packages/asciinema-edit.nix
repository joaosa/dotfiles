{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:

buildGoModule {
  pname = "asciinema-edit";
  version = "0-unstable-2019-01-30";

  src = fetchFromGitHub {
    owner = "cirocosta";
    repo = "asciinema-edit";
    rev = "1c0971ae232aef9637035f7a5ce3a98fadc7c181";
    hash = "sha256-7wKSYaBsxZbmySnwgTKUDW2zRxtkgLHjXw0jALiNhC4=";
  };

  postPatch = ''
        cat > go.mod <<EOF
    module github.com/cirocosta/asciinema-edit

    go 1.13

    require (
      github.com/pkg/errors v0.9.1
      gopkg.in/urfave/cli.v1 v1.20.0
    )
    EOF
  '';

  vendorHash = null;
}
