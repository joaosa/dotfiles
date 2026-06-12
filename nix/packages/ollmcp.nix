{
  lib,
  python3Packages,
  fetchPypi,
}:

python3Packages.buildPythonApplication rec {
  pname = "mcp-client-for-ollama";
  version = "0.29.1";
  pyproject = true;

  src = fetchPypi {
    pname = "mcp_client_for_ollama";
    inherit version;
    hash = "sha256-KeCaq+WkWL3Wvk4V4Vcu4UtOnaHhVED/sD7Ic006t8o=";
  };

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    mcp
    ollama
    prompt-toolkit
    rich
    typer
  ];

  # Upstream pins rich <14.3 and typer ~=0.21; nixpkgs carries newer minor
  # versions that are API-compatible for this client's usage.
  pythonRelaxDeps = [
    "rich"
    "typer"
  ];

  nativeCheckInputs = [ python3Packages.pytestCheckHook ];

  # The config manager creates ~/.config at import time; the sandbox has no
  # writable HOME.
  preCheck = ''
    export HOME=$TMPDIR
  '';

  meta = {
    description = "TUI client connecting local Ollama models to MCP servers";
    homepage = "https://github.com/jonigl/mcp-client-for-ollama";
    changelog = "https://github.com/jonigl/mcp-client-for-ollama/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "ollmcp";
  };
}
