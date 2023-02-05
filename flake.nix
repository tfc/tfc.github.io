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
    , pre-commit-hooks
    , ...
    }:
    flake-parts.lib.mkFlake { inherit self; } {
      systems = [ "x86_64-linux" ];

      perSystem = { config, pkgs, system, ... }:
        let
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
            "^src.*" # must include haskell src for tailwindcli
            "^tailwind.*"
            "^templates.*"
            "^.*\.hamlet"
            "^.*\.md"
          ];

          tailwindcss =
            let
              twBall = builtins.fetchurl {
                url = "https://github.com/tailwindlabs/tailwindcss/releases/download/v3.2.4/tailwindcss-linux-x64";
                sha256 = "15hj95qdx7z3gdmhb3826h98296rk18j2yi0y0w55l8brdbyflnd";
              };
            in
            pkgs.runCommand "tailwindcss" { } ''
              mkdir -p $out/bin/
              cp ${twBall} $out/bin/tailwindcss
              chmod 755 $out/bin/tailwindcss
            '';

          release = pkgs.stdenv.mkDerivation {
            name = "blog.galowicz.de-content";
            src = blogSrc;
            nativeBuildInputs = [
              blog-generator
              tailwindcss
            ];
            LANG = "en_US.UTF-8";
            LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
            buildPhase = ''
              blog-generator clean

              patchShebangs tailwind.sh
              ./tailwind.sh
              ls -lsa

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
              tailwindcss
              nodejs # only needed for updating tailwind
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
