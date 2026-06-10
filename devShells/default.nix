{ pkgs }:
{
  default = pkgs.mkShell {
    packages = with pkgs; [
      alejandra
      statix
    ];
  };
}
