{ pkgs }:

let
  repo = "Qwen/Qwen3-ASR-0.6B";
  revision = "5eb144179a02acc5e5ba31e748d22b0cf3e303b0";

  fetchModelFile =
    name: hash:
    pkgs.fetchurl {
      url = "https://huggingface.co/${repo}/resolve/${revision}/${name}";
      inherit hash;
    };
in
pkgs.linkFarm "qwen3-asr-0.6b" (
  builtins.mapAttrs fetchModelFile {
    ".gitattributes" = "sha256-Ea1++iSXXuSww8OjjtGHN/Blil91oKlnh7V2p4oCM2E=";
    "README.md" = "sha256-UFhBaJG8R6IFFVd2WZfoxC+Ot4oOM8Pndb0X1LC6TVA=";
    "chat_template.json" = "sha256-dajPyiTwDecteW+/7WhY/JYU7z2r2GlmhMw7wDqcWP8=";
    "config.json" = "sha256-dtOuRgHOk5gwslF/SmytuGzFExbDkAr2sCCwUcIaR4w=";
    "generation_config.json" = "sha256-HaUngk2B4HEY+s/0N+A/LiSiMxHjvesjaJc/535fJ1w=";
    "merges.txt" = "sha256-iDHk8aBERxNA98CoPXvXEwaluGfpX9hw900MUwipBNU=";
    "model.safetensors" = "sha256-edbL1MmMe7/+nbLtrAf1bNZjfQ1ZRLJ/bCuDU4QDI+o=";
    "preprocessor_config.json" = "sha256-ReEgpO2iwgxdfy6pNU5jU2vzXieqVz+3zfeAF7N4dw0=";
    "tokenizer_config.json" = "sha256-SULQBWBCZoCTCcq8n06cuJzoVdWbFGgf3A4cxi6ibEw=";
    "vocab.json" = "sha256-yhDX6fs+0YV13R4neiV5wW0QjjLydDloSvoOELFECRA=";
  }
)
