_: {
  perSystem = { pkgs, ... }: {
    devshells.floorplan = {
      packages = with pkgs; [
        # Floorplan GIS
        qgis

        # Supporting tools for data prep
        gdal
        libtiff
        libjpeg
        proj

        # Vector/raster editing
        inkscape

        # Web export/viewing
        python3
        python3Packages.pip

        # Glue tools
        just
        gnumake
        jq
        git
      ];

      enterShell = ''
        echo "Floorplan devshell ready!"
        echo "Available tools:"
        echo "  - QGIS (primary floorplan GIS/editor)"
        echo "  - GDAL (data conversion)"
        echo "  - Inkscape (vector editing)"
        echo "  - Python for web export scripting"
        echo ""
        echo "To start QGIS, run 'qgis'"
        echo "For web viewing, export to GeoJSON/WMS and use QGIS Web Client or Leaflet"
      '';
    };
  };
}
