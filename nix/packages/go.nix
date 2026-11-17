{
  go_1_27,
  buildGo127Module,
}:

# The one Go pin for the host and the devcontainer.
{
  package = go_1_27;
  # Builds Go tools that load modules with their own toolchain, so they must
  # not be older than this pin.
  buildGoModule = buildGo127Module;
}
