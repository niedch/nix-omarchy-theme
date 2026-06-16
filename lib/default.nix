{lib}: let
  colors = import ./colors.nix {inherit lib;};
  render = import ./render.nix {
    inherit lib;
    colorUtils = colors;
  };
in {
  inherit colors render;
}
