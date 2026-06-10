{ lib }:
let
  hexMap = {
    "0" = 0; "1" = 1; "2" = 2; "3" = 3; "4" = 4;
    "5" = 5; "6" = 6; "7" = 7; "8" = 8; "9" = 9;
    "a" = 10; "b" = 11; "c" = 12; "d" = 13; "e" = 14; "f" = 15;
  };
  hexToDec = hex:
    let
      h = lib.toLower hex;
      c0 = hexMap.${builtins.substring 0 1 h};
      c1 = hexMap.${builtins.substring 1 1 h};
    in
    c0 * 16 + c1;
in {
  hexToRgb = hex:
    let
      h = lib.removePrefix "#" hex;
    in
    "${toString (hexToDec (builtins.substring 0 2 h))},${toString (hexToDec (builtins.substring 2 2 h))},${toString (hexToDec (builtins.substring 4 2 h))}";
}
