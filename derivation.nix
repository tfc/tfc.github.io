{ mkDerivation, base, blaze-html, containers, hakyll
, hakyll-shakespeare, stdenv, text
}:
mkDerivation {
  pname = "blog";
  version = "0.1.0.0";
  src = ./.;
  isLibrary = false;
  isExecutable = true;
  executableHaskellDepends = [
    base blaze-html containers hakyll hakyll-shakespeare text
  ];
  doHaddock = false;
  license = "unknown";
  hydraPlatforms = stdenv.lib.platforms.none;
}
