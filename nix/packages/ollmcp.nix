{
  lib,
  python3Packages,
  fetchPypi,
  fetchFromGitHub,
}:

let
  # mcp 2.x drops streamablehttp_client; every ollmcp release that supports it
  # needs any-llm-sdk, which nixpkgs lacks. Keep the last 1.x SDK local here.
  mcp = python3Packages.mcp.overridePythonAttrs {
    version = "1.29.0";
    src = fetchFromGitHub {
      owner = "modelcontextprotocol";
      repo = "python-sdk";
      tag = "v1.29.0";
      hash = "sha256-lRlj5RT/R5zrYL5XpdQR2l9t99G94WTsubN0gSQekMc=";
    };
    pythonRelaxDeps = [ "pydantic-settings" ];
    dependencies = with python3Packages; [
      anyio
      httpx
      httpx-sse
      jsonschema
      pydantic
      pydantic-settings
      pyjwt
      python-multipart
      sse-starlette
      starlette
      uvicorn
    ];
    # The 2.x test setup does not apply to the 1.x tree.
    doCheck = false;
  };
in
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

  dependencies = [
    mcp
  ]
  ++ (with python3Packages; [
    ollama
    prompt-toolkit
    rich
    typer
  ]);

  # Upstream pins mcp <1.28, rich <14.3 and typer ~=0.21; nixpkgs carries newer
  # minor versions that are API-compatible for this client's usage.
  pythonRelaxDeps = [
    "mcp"
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
