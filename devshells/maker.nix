_: {
  perSystem = { pkgs, ... }: {
    devshells.maker = {
      packages = with pkgs; [
        # PCB Design
        kicad

        # CAD Modeling
        freecad
        openscad
        solvespace

        # Python for scripting
        python3
        python3Packages.numpy
        python3Packages.pip

        # 3D Printing
        prusa-slicer
        orca-slicer

        # Laser Cutting
        inkscape

        # Glue tools
        just
        gnumake
        jq
        git
      ];

      enterShell = ''
        echo "Maker devshell ready!"
        echo "Available tools:"
        echo "  - KiCad (PCB design, includes kicad-cli)"
        echo "  - FreeCAD, OpenSCAD, SolveSpace (CAD)"
        echo "  - Python with numpy for scripting"
        echo "  - PrusaSlicer, OrcaSlicer (3D printing)"
        echo "  - Inkscape (Laser cutting)"
        echo ""
        echo "Note: For CadQuery/build123d, use 'nix shell' or 'nix develop --command pip install'"
      '';
    };
  };
}
