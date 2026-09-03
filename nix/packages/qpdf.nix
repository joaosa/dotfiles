{
  bashInteractive,
  fetchFromGitHub,
  qpdf,
  zsh,
}:

qpdf.overrideAttrs (
  finalAttrs: previousAttrs: {
    version = "12.4.1";
    src = fetchFromGitHub {
      owner = "qpdf";
      repo = "qpdf";
      tag = "v${finalAttrs.version}";
      hash = "sha256-OGFSr/fdfOz6nCLbYfNNTgd5vuehADyFUh4o28Q3j3U=";
    };
    nativeCheckInputs = (previousAttrs.nativeCheckInputs or [ ]) ++ [
      bashInteractive
      zsh
    ];
    cmakeFlags = (previousAttrs.cmakeFlags or [ ]) ++ [ "-DREQUIRE_SHELLS=ON" ];
  }
)
