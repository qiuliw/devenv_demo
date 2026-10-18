{ pkgs, ... }:

{
  android = {
    enable = true;
    flutter.enable = true;
    buildTools.version = [ "36.0.0" "35.0.0" ];
  };
}