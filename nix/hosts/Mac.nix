# Host-specific configuration for "Mac".
#
# The shared base (../darwin, ../home) is parameterized by the host entry in
# flake.nix (username/hostname/system via specialArgs), so anything common
# lives there. This file holds only what is specific to *this* machine —
# e.g. host-only Homebrew casks, networking, or one-off overrides. It is the
# seam that keeps a second host cheap to add without touching the shared base.
{ ... }:
{
}
