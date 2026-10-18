{
  self,
  ...
}:
{
  perSystem =
    { pkgs, ... }:
    {
      # Linting with statix
      checks.lint = pkgs.stdenv.mkDerivation {
        name = "lint";
        src = self;
        buildInputs = [ pkgs.statix ];
        buildPhase = ''
          statix check .
        '';
        installPhase = "touch $out";
      };
    };
}
