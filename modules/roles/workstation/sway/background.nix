{
  config,
  lib,
  pkgs,
  ...
}:
let
  resolution = {
    width = config.services.sway-cheatsheet.width;
    height = config.services.sway-cheatsheet.height;
  };

  # Only text fragments are readable at eval time (path fragments would need
  # import-from-derivation). Our own snippet is excluded: its text embeds the
  # rendered background, so forcing it would be a circular evaluation.
  ownConf = "sway/config.d/10-background.conf";
  fragmentTexts = lib.mapAttrsToList (_: entry: entry.text) (
    lib.filterAttrs (
      name: entry:
      lib.hasPrefix "sway/config.d/" name && name != ownConf && entry.text != null && entry.text != ""
    ) config.environment.etc
  );

  swayConfig = builtins.readFile "${config.environment.etc."sway/config".source}";

  ltrim =
    s:
    if lib.hasPrefix " " s || lib.hasPrefix "\t" s then
      ltrim (builtins.substring 1 (builtins.stringLength s - 1) s)
    else
      s;

  esc = lib.replaceStrings [ "&" "<" ">" ] [ "&amp;" "&lt;" "&gt;" ];

  substitute =
    vars: s:
    builtins.foldl' (s: name: lib.replaceStrings [ "\$${name}" ] [ vars.${name} ] s) s (
      builtins.attrNames vars
    );

  dropWhile =
    pred: list: if list != [ ] && pred (lib.head list) then dropWhile pred (lib.tail list) else list;

  parse =
    lib.foldl'
      (
        acc: rawLine:
        let
          line = ltrim rawLine;
        in
        if line == "" || lib.hasPrefix "##" line then
          acc
        else if lib.hasPrefix "#" line then
          if lib.hasSuffix ":" line then
            acc
            // {
              items = acc.items ++ [
                {
                  type = "section";
                  name = lib.removeSuffix ":" (ltrim (lib.removePrefix "#" line));
                }
              ];
            }
          else
            acc
        else if lib.hasPrefix "set $" line then
          let
            parts = lib.splitString " " line;
            name = lib.removePrefix "$" (lib.elemAt parts 1);
            value = lib.concatStringsSep " " (lib.drop 2 parts);
          in
          acc
          // {
            vars = acc.vars // {
              ${name} = if name == "mod" then "Super" else value;
            };
          }
        else if lib.hasPrefix "mode \"" line then
          acc
          // {
            mode = lib.head (lib.splitString "\"" (lib.removePrefix "mode \"" line));
          }
        else if line == "}" then
          acc // { mode = null; }
        else if lib.hasPrefix "bindsym" line then
          let
            tokens = dropWhile (lib.hasPrefix "--") (lib.splitString " " (lib.removePrefix "bindsym " line));
          in
          acc
          // {
            items = acc.items ++ [
              {
                type = if acc.mode == null then "bind" else "resize";
                keys = substitute acc.vars (lib.head tokens);
                desc = substitute acc.vars (lib.concatStringsSep " " (lib.tail tokens));
              }
            ];
          }
        else
          acc
      )
      {
        vars = { };
        items = [ ];
        mode = null;
      };

  # Drop section headers that ended up with no bindings below them.
  items =
    (lib.foldr
      (
        item: st:
        if item.type == "section" then
          if st.binds > 0 then
            {
              binds = 0;
              out = [ item ] ++ st.out;
            }
          else
            {
              binds = 0;
              inherit (st) out;
            }
        else
          {
            binds = st.binds + 1;
            out = [ item ] ++ st.out;
          }
      )
      {
        binds = 0;
        out = [ ];
      }
      (parse (
        lib.concatLists [
          (lib.splitString "\n" swayConfig)
          [ "# Custom bindings:" ]
          (lib.concatLists (map (lib.splitString "\n") fragmentTexts))
        ]
      )).items
    ).out;

  # Fonts and spacing scale with the declared resolution; everything is laid
  # out relative to the 1080p design, so any resolution renders proportionally.
  s = resolution.height / 1080.0;
  maxKeyLen = builtins.foldl' (m: i: lib.max m (builtins.stringLength (i.keys or ""))) 0 items;
  ncols = lib.max 3 (builtins.floor (resolution.width / (640.0 * s)));
  columnWidth = resolution.width / ncols;
  descX = maxKeyLen * 11.0 * s + 16.0 * s;
  maxChars = lib.max 10 (builtins.floor ((columnWidth - 40.0 * s - descX) / (10.2 * s)));

  chunk = n: list: if list == [ ] then [ ] else [ (lib.take n list) ] ++ chunk n (lib.drop n list);

  wrapLines =
    maxLen: s:
    let
      words = lib.filter (w: w != "") (lib.splitString " " s);
      go =
        rest: cur: acc:
        if rest == [ ] then
          acc ++ (lib.optional (cur != "") cur)
        else
          let
            w = lib.head rest;
            candidate = if cur == "" then w else cur + " " + w;
          in
          if cur == "" || lib.stringLength candidate <= maxLen then
            go (lib.tail rest) candidate acc
          else
            go (lib.tail rest) "" (acc ++ [ cur ]);
    in
    go words "" [ ];

  wrapDesc =
    s:
    let
      lines = wrapLines maxChars s;
    in
    if builtins.length lines <= 3 then lines else lib.take 3 lines ++ [ "…" ];

  renderColumn =
    column:
    (lib.foldl'
      (
        st: item:
        if item.type == "section" then
          {
            y = st.y + 48.0 * s;
            out =
              st.out
              + ''<text x="0" y="${toString (st.y + 18.0 * s)}" font-family="Noto Sans" font-weight="bold" font-size="${toString (21.0 * s)}" fill="#d8a657">${esc item.name}</text>'';
          }
        else
          let
            descLines = wrapDesc item.desc;
            descTexts = lib.concatImapStrings (
              i: l:
              ''<text x="${toString descX}" y="${
                toString (st.y + 15.0 * s + (i - 1) * 20.0 * s)
              }" font-family="Noto Sans" font-size="${toString (18.0 * s)}" fill="#ebdbb2">${esc l}</text>''
            ) descLines;
          in
          {
            y = st.y + 20.0 * s * builtins.length descLines + 6.0 * s;
            out =
              st.out
              + ''<text x="0" y="${toString (st.y + 15.0 * s)}" font-family="DejaVu Sans Mono" font-weight="bold" font-size="${toString (18.0 * s)}" fill="#83a598">${esc item.keys}</text>''
              + descTexts;
          }
      )
      {
        y = 6.0 * s;
        out = "";
      }
      column
    ).out;

  columns = lib.imap1 (
    i: column:
    let
      x = (i - 1) * columnWidth + 40.0 * s;
    in
    ''<g transform="translate(${toString x},${toString (206.0 * s)})">${renderColumn column}</g>''
  ) (chunk ((builtins.length items + ncols - 1) / ncols) items);

  svg = pkgs.writeText "sway-cheatsheet.svg" (
    lib.concatStringsSep "\n" (
      [
        ''<?xml version="1.0" encoding="UTF-8"?>''
        ''<svg xmlns="http://www.w3.org/2000/svg" width="${toString resolution.width}" height="${toString resolution.height}" viewBox="0 0 ${toString resolution.width} ${toString resolution.height}">''
        ''<rect width="${toString resolution.width}" height="${toString resolution.height}" fill="#101010"/>''
        ''<text x="${toString (40.0 * s)}" y="${toString (92.0 * s)}" font-family="Noto Sans" font-weight="bold" font-size="${toString (42.0 * s)}" fill="#fbf1c7">sway cheat sheet</text>''
        ''<text x="${toString (40.0 * s)}" y="${toString (130.0 * s)}" font-family="Noto Sans" font-size="${toString (20.0 * s)}" fill="#928374">Super = Mod4, generated from the sway configuration</text>''
      ]
      ++ columns
      ++ [ "</svg>" ]
    )
  );

  png =
    pkgs.runCommand "sway-cheatsheet.png"
      {
        nativeBuildInputs = [ pkgs.librsvg ];
        FONTCONFIG_FILE = pkgs.makeFontsConf {
          fontDirectories = [
            pkgs.noto-fonts
            pkgs.dejavu_fonts
          ];
        };
      }
      ''
        rsvg-convert -w ${toString resolution.width} -h ${toString resolution.height} -o $out ${svg}
      '';
in
{
  options.services.sway-cheatsheet = {
    width = lib.mkOption {
      type = lib.types.int;
      default = 1920;
      description = "Cheat-sheet render width in pixels.";
    };
    height = lib.mkOption {
      type = lib.types.int;
      default = 1080;
      description = "Cheat-sheet render height in pixels.";
    };
  };

  config = {
    environment.etc."sway/config.d/10-background.conf".text = ''
      output * bg ${png} fill
    '';
  };
}
