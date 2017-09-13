{ config, callPackage, ... }:

{
  buildGame = callPackage ./build-game.nix {
    withPulseAudio = config.pulseaudio or true;
  };
  buildUnity = callPackage ./build-unity.nix {};
}