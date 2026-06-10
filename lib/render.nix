{ lib, colorUtils }:
rec {
  buildReplacements = colors:
    lib.foldlAttrs (acc: k: v:
      if lib.hasPrefix "#" v then
        {
          searches = acc.searches ++ [ "{{ ${k} }}" "{{ ${k}_strip }}" "{{ ${k}_rgb }}" ];
          replaces = acc.replaces ++ [ v (lib.removePrefix "#" v) (colorUtils.hexToRgb v) ];
        }
      else
        {
          searches = acc.searches ++ [ "{{ ${k} }}" ];
          replaces = acc.replaces ++ [ v ];
        }
    ) { searches = [ ]; replaces = [ ]; } colors;

  renderTemplate = colors: template:
    let r = buildReplacements colors;
    in builtins.replaceStrings r.searches r.replaces template;
}
