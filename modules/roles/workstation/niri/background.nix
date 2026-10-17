{
  config,
  lib,
  pkgs,
  ...
}:
let
  # This module renders the cheat-sheet wallpaper: it extracts the key
  # bindings from the composed niri configuration, lays them out as an SVG,
  # rasterizes the SVG to a PNG, and drops in a config fragment that makes
  # niri draw the PNG with swaybg.

  resolution = {
    width = config.services.niri-cheatsheet.width;
    height = config.services.niri-cheatsheet.height;
  };

  # Only text fragments are readable at eval time (path fragments would need
  # import-from-derivation). Our own fragment is excluded: its text embeds
  # the rendered background, so forcing it would be a circular evaluation.
  ownFragment = "niri/config.d/10-background.kdl";
  fragmentLines = lib.flatten (
    lib.mapAttrsToList (_: entry: lib.splitString "\n" entry.text) (
      lib.filterAttrs (
        name: entry:
        lib.hasPrefix "niri/config.d/" name && name != ownFragment && entry.text != null && entry.text != ""
      ) config.environment.etc
    )
  );

  # The system config first, then a marker for user-provided fragments, then
  # the fragments themselves.
  configLines =
    lib.splitString "\n" config.environment.etc."niri/config.kdl".text
    ++ [ "// Custom bindings:" ]
    ++ fragmentLines;

  # Strip leading spaces and tabs.
  ltrim =
    s:
    if lib.hasPrefix " " s || lib.hasPrefix "\t" s then
      ltrim (builtins.substring 1 (builtins.stringLength s - 1) s)
    else
      s;

  esc = lib.replaceStrings [ "&" "<" ">" ] [ "&amp;" "&lt;" "&gt;" ];

  # Parse one line from a `binds` block. Bindings are written single-line, so
  # a bind is one `Keys [attrs] { action; } [// description]` line, and a
  # section header is a `//` comment ending in a colon. Blank lines and other
  # comments are ignored. Bindings carry a description comment, falling back
  # to the action itself; `Mod` is displayed as `Super`.
  parseLine =
    raw:
    let
      line = ltrim raw;
      # Split at the closing brace: the binding node on the left, the
      # optional trailing comment on the right.
      parts = lib.splitString "}" line;
      node = lib.concatStringsSep "}" (lib.init parts);
      comment = ltrim (lib.last parts);
      # The node is `Keys [attrs] { action;`: the keys are its first word
      # (dropping attributes like `repeat=false`), the action the rest.
      keys = lib.head (lib.splitString " " (lib.head (lib.splitString "{" node)));
      action = ltrim (lib.concatStringsSep "{" (lib.tail (lib.splitString "{" node)));
      desc =
        if lib.hasPrefix "//" comment then
          ltrim (lib.removePrefix "//" comment)
        else
          lib.removeSuffix ";" action;
    in
    if line == "" then
      null
    else if lib.hasPrefix "//" line then
      if lib.hasSuffix ":" line then
        {
          type = "section";
          name = ltrim (lib.removeSuffix ":" (lib.removePrefix "//" line));
        }
      else
        null
    else if lib.length parts < 2 then
      null
    else
      {
        type = "bind";
        keys = lib.replaceStrings [ "Mod+" "Mod" ] [ "Super+" "Super" ] keys;
        inherit desc;
      };

  # Collect the items from every `binds { ... }` block (the system config has
  # one; a fragment may add more). A block starts at a line that is exactly
  # `binds {` and ends at the next `}`.
  parsedItems =
    (lib.foldl'
      (
        acc: rawLine:
        let
          line = ltrim rawLine;
          item = parseLine line;
        in
        if !acc.inBinds then
          acc // { inBinds = line == "binds {"; }
        else if line == "}" then
          acc // { inBinds = false; }
        else if item != null then
          acc // { items = acc.items ++ [ item ]; }
        else
          acc
      )
      {
        inBinds = false;
        items = [ ];
      }
      configLines
    ).items;

  # A section header with no binding under it would render as an empty
  # heading; keep a header only when a bind follows it before the next one.
  bindsBeforeNextHeader =
    rest:
    if rest == [ ] || (lib.head rest).type == "section" then
      [ ]
    else
      [ (lib.head rest) ] ++ bindsBeforeNextHeader (lib.tail rest);

  dropEmptySections =
    list:
    if list == [ ] then
      [ ]
    else
      let
        item = lib.head list;
        rest = lib.tail list;
        keepHeader = item.type != "section" || lib.any (it: it.type == "bind") (bindsBeforeNextHeader rest);
      in
      lib.optional keepHeader item ++ dropEmptySections rest;

  items = dropEmptySections parsedItems;

  # Fonts and spacing scale with the declared resolution; everything is laid
  # out relative to the 1080p design, so any resolution renders proportionally.
  s = resolution.height / 1080.0;
  maxKeyLen = builtins.foldl' (m: i: lib.max m (builtins.stringLength (i.keys or ""))) 0 items;
  ncols = lib.max 3 (builtins.floor (resolution.width / (640.0 * s)));
  columnWidth = resolution.width / ncols;
  descX = maxKeyLen * 11.0 * s + 16.0 * s;
  maxChars = lib.max 10 (builtins.floor ((columnWidth - 40.0 * s - descX) / (10.2 * s)));

  chunk = n: list: if list == [ ] then [ ] else [ (lib.take n list) ] ++ chunk n (lib.drop n list);

  # Wrap a description at `maxLen` characters, breaking on spaces.
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

  # Descriptions get at most three lines; longer ones end in an ellipsis.
  wrapDesc =
    s:
    let
      lines = wrapLines maxChars s;
    in
    if builtins.length lines <= 3 then lines else lib.take 3 lines ++ [ "…" ];

  # Render one column of items, stacking them vertically. Section headers
  # are amber, key names monospace blue, descriptions cream.
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
              i: line:
              ''<text x="${toString descX}" y="${
                toString (st.y + 15.0 * s + (i - 1) * 20.0 * s)
              }" font-family="Noto Sans" font-size="${toString (18.0 * s)}" fill="#ebdbb2">${esc line}</text>''
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

  svg = pkgs.writeText "niri-cheatsheet.svg" (
    lib.concatStringsSep "\n" (
      [
        ''<?xml version="1.0" encoding="UTF-8"?>''
        ''<svg xmlns="http://www.w3.org/2000/svg" width="${toString resolution.width}" height="${toString resolution.height}" viewBox="0 0 ${toString resolution.width} ${toString resolution.height}">''
        ''<rect width="${toString resolution.width}" height="${toString resolution.height}" fill="#101010"/>''
        ''<text x="${toString (40.0 * s)}" y="${toString (92.0 * s)}" font-family="Noto Sans" font-weight="bold" font-size="${toString (42.0 * s)}" fill="#fbf1c7">niri cheat sheet</text>''
        ''<text x="${toString (40.0 * s)}" y="${toString (130.0 * s)}" font-family="Noto Sans" font-size="${toString (20.0 * s)}" fill="#928374">Mod = Super, generated from the niri configuration</text>''
      ]
      ++ columns
      ++ [ "</svg>" ]
    )
  );

  png =
    pkgs.runCommand "niri-cheatsheet.png"
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
  options.services.niri-cheatsheet = {
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
    environment.etc."niri/config.d/10-background.kdl".text = ''
      spawn-at-startup "swaybg" "-i" "${png}" "-m" "fill"
    '';
  };
}
