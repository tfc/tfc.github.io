{
  description = "blog.galowicz.de static page generator";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs =
    { self
    , flake-parts
    , nixpkgs
    , pre-commit-hooks
    }:
    flake-parts.lib.mkFlake { inherit self; } {
      systems = [ "x86_64-linux" ];

      perSystem = { config, system, ... }:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          haskellSrc = pkgs.lib.sourceByRegex ./. [
            "^LICENSE$"
            "^Setup.hs$"
            "^blog.cabal$"
            "^src.*"
          ];
          inherit (pkgs) haskellPackages;
          blog-generator = pkgs.haskellPackages.callCabal2nix "blog" haskellSrc { };

          blogSrc = pkgs.lib.sourceByRegex ./. [
            "^css.*"
            "^images.*"
            "^posts.*"
            "^templates.*"
            "^.*\.md"
          ];

          release = pkgs.stdenv.mkDerivation {
            name = "blog.galowicz.de-content";
            src = blogSrc;
            buildInputs = [ blog-generator ];
            LANG = "en_US.UTF-8";
            LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
            buildPhase = ''
              blog-generator clean
              blog-generator build
            '';
            installPhase = ''
              cp -r _site $out
            '';
          };

        in
        {
          packages = {
            inherit blog-generator release;
            default = release;
          };

          devShells.default = haskellPackages.shellFor {
            packages = _: [ blog-generator ];
            buildInputs = with pkgs; [
              cabal-install
              ghcid
              hlint
              nixpkgs-fmt
              nodePackages.markdownlint-cli
            ];

            # `hoogle server --local`
            withHoogle = true;

            shellHook = ''
              ${config.checks.pre-commit-check.shellHook}
            '';
          };

          checks = {
            pre-commit-check = pre-commit-hooks.lib.${system}.run {
              src = ./.;
              hooks = {
                brittany.enable = true;
                cabal-fmt.enable = true;
                cspell = {
                  enable = true;
                  entry = "${pkgs.nodePackages.cspell}/bin/cspell --words-only";
                  types = [ "markdown" ];
                  excludes = [ "impressum.md" "datenschutz.md" ];
                };
                deadnix.enable = true;
                nixpkgs-fmt.enable = true;
                shellcheck.enable = true;
                shfmt.enable = true;
                statix.enable = true;
              };
            };
          };

        };
    };
}
