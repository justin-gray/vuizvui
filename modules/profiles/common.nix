{ config, pkgs, lib, ... }:

with lib;

{
  options.vuizvui = {
    modifyNixPath = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to modify NIX_PATH for vuizvui, so that &lt;nixpkgs&gt; points
        to the path within the Nix channel instead of the
        <literal>nixpkgs</literal> or <literal>nixos</literal> channel from the
        root user.
      '';
    };

    enableGlobalNixpkgsConfig = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enabling this links <literal>nixos-config</literal> to be used by
        <literal>nixpkgs-config</literal>, which essentially means that
        attributes defined in <option>nixpkgs.config</option> are also in effect
        for user environments.
      '';
    };

    channelName = mkOption {
      type = types.str;
      default = "vuizvui";
      description = ''
        The channel name which is used to refer to <literal>vuizvui</literal>.
      '';
    };

    requiresTests = mkOption {
      type = types.listOf types.package;
      default = [];
      description = ''
        A list of derivations which have to succeed in order to trigger a
        channel update for the current configuration/machine.
      '';
    };
  };

  config = let
    nixpkgs = import ../../nixpkgs-path.nix;
    system = config.nixpkgs.system;

  in {
    nixpkgs.config.packageOverrides = pkgs: {
      # XXX: REAAAALLLY UGLY hack to force the Headcounter Hydra to rebuild GHC
      # and all its packages and not use binary substitution.
      haskellPackages = pkgs.haskellPackages.override {
        ghc = pkgs.haskellPackages.ghc.overrideDerivation (const {
          forceRebuild = true;
        });
      };

      inherit (import ../../pkgs {
        # We need to make sure to incorporate other package overrides,
        # otherwise we are unable to override packages in vuizvui.*.
        pkgs = pkgs // config.nixpkgs.config.packageOverrides pkgs;
      }) vuizvui;
    };

    nix.binaryCachePublicKeys = [
      "headcounter.org:/7YANMvnQnyvcVB6rgFTdb8p5LG1OTXaO+21CaOSBzg="
    ];

    environment.variables.NIXPKGS_CONFIG = let
      nixpkgsCfg = toString (pkgs.writeText "nixpkgs-try-config.nix" ''
        if (builtins.tryEval <nixpkgs-config>).success
        then import <nixpkgs-config>
        else {}
      '');
    in mkIf config.vuizvui.enableGlobalNixpkgsConfig (mkForce nixpkgsCfg);

    nix.nixPath = let
      rootChannelsPath = "/nix/var/nix/profiles/per-user/root/channels";
      channelPath = "${rootChannelsPath}/${config.vuizvui.channelName}";
      nixosConfig = "/etc/nixos/configuration.nix";
      nixpkgsConfig = "nixpkgs-config=${pkgs.writeText "nixpkgs-config.nix" ''
        (import ${nixpkgs}/nixos/lib/eval-config.nix {
          modules = [ ${nixosConfig} ];
        }).config.nixpkgs.config
      ''}";
      nixPath = [
        "vuizvui=${channelPath}"
        "nixpkgs=${channelPath}/nixpkgs"
        "nixos-config=${nixosConfig}"
        rootChannelsPath
      ] ++ optional config.vuizvui.enableGlobalNixpkgsConfig nixpkgsConfig;
    in mkIf config.vuizvui.modifyNixPath (mkOverride 90 nixPath);

    _module.args.tests = {
      nixos = let
        upstreamTests = (import "${nixpkgs}/nixos/release.nix" {
          inherit nixpkgs;
        }).tests;
        isTestOrSystems = attr: attr ? test || attr ? ${system};
        cond = attr: !isTestOrSystems attr;
        reduce = attr: if attr ? test then attr else attr.${system};
      in mapAttrsRecursiveCond cond (path: reduce) upstreamTests;

      vuizvui = import ../../tests {
        inherit system;
      };
    };
  };
}
