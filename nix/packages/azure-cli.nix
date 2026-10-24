{
  azure-cli,
  callPackage,
  fetchPypi,
}:

# Azure CLI's Fabric 3.2.3 requires Invoke <3. Keep the compatible release
# inside Azure's private Python scope until nixpkgs fixes that combination.
azure-cli.override {
  # Azure calls this only to create its private Python package set. Extend
  # that result so its existing Azure-specific overrides remain in effect.
  callPackage =
    file: args:
    let
      python = callPackage file args;
    in
    python
    // {
      pkgs = python.pkgs.overrideScope (
        _final: previous: {
          invoke = previous.invoke.overridePythonAttrs {
            version = "2.2.1";
            src = fetchPypi {
              pname = "invoke";
              version = "2.2.1";
              sha256 = "515bf49b4a48932b79b024590348da22f39c4942dff991ad1fb8b8baea1be707";
            };
          };
          # Hydra skips this broken-marked set, so it builds locally, where
          # black's tests fail on an unclosed scandir ResourceWarning.
          black = previous.black.overridePythonAttrs { doCheck = false; };
        }
      );
    };
}
