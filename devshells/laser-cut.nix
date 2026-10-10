_: {
  perSystem = { pkgs, ... }: {
    devshells.laserCut = {
      packages = with pkgs; [
        # Laser Cutting
        inkscape
        openscad

        # Python DXF libraries
        python3
        python3Packages.pip

        # Box generation
        boxes

        # Glue tools
        just
        gnumake
        jq
        git
      ];

      enterShell = ''
        echo "Laser cutting devshell ready!"
        echo "Available tools:"
        echo "  - Inkscape (vector editing, SVG/DXF)"
        echo "  - OpenSCAD (parametric modeling)"
        echo "  - boxes (box generator)"
        echo ""
        echo "Note: For ezdxf, use 'nix develop --command pip install ezdxf'"
      '';
    };
  };
}
