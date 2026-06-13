{
  lib,
  python3Packages,
  fetchFromGitHub,
}:

let
  # nixpkgs' pywebview declares pyobjc-framework-uniformtypeidentifiers on
  # darwin, which nixpkgs does not package, failing the runtime-deps check.
  # Serena only needs `import webview` to succeed; its GUI log window is
  # unsupported on macOS, so the missing framework is never reached.
  pywebview = python3Packages.pywebview.overridePythonAttrs {
    dontCheckRuntimeDeps = true;
  };
in
python3Packages.buildPythonApplication rec {
  pname = "serena-agent";
  version = "1.5.3";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "oraios";
    repo = "serena";
    tag = "v${version}";
    hash = "sha256-8RHjJG8loqC742LoFK7O3MK7JDEhb1qw8VMBhzj04MM=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = [
    pywebview
  ]
  ++ (with python3Packages; [
    anthropic
    beautifulsoup4
    cryptography
    docstring-parser
    filelock
    flask
    jinja2
    joblib
    lsprotocol
    mcp
    overrides
    pathspec
    psutil
    pydantic
    pygls
    pystray
    python-dotenv
    python-multipart
    pyyaml
    regex
    requests
    ruamel-yaml
    sensai-utils
    starlette
    tiktoken
    tqdm
    types-pyyaml
    urllib3
    werkzeug
  ]);

  # Upstream pins every dependency to an exact version because uvx installs
  # from git without a lock file; the nixpkgs set carries compatible newer
  # versions.
  pythonRelaxDeps = true;

  # "dotenv" is a deprecated alias of python-dotenv with no nixpkgs attribute.
  pythonRemoveDeps = [ "dotenv" ];

  # The test suite drives per-language LSP servers that serena downloads at
  # runtime, which the sandbox cannot do.
  doCheck = false;

  pythonImportsCheck = [
    "serena"
    "solidlsp"
    "interprompt"
  ];

  meta = {
    description = "MCP toolkit providing semantic code retrieval and editing tools";
    homepage = "https://github.com/oraios/serena";
    changelog = "https://github.com/oraios/serena/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "serena";
  };
}
