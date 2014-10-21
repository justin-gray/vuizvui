{ config, pkgs, ... }:

with pkgs.lib;

let
  rootUUID = "e33a3dda-a87d-473b-b113-37783aa35667";
  swapUUID = "e9f59283-143c-4c36-978c-c730c6ca27c7";
  storeUUID = "ce1db87b-d717-450d-a212-3685a224f626";
  diskID = "ata-Hitachi_HTS543232A7A384_E2P31243FGB6PJ";
in {
  imports = singleton ../common-workstation.nix;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.kernelModules = [ "fbcon" "usb_storage" ];
    loader.grub.device = "/dev/disk/by-id/${diskID}";
    loader.grub.timeout = 0;
  };

  networking.hostName = "tishtushi";
  networking.wireless.enable = true;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/${rootUUID}";
    fsType = "btrfs";
    options = concatStringsSep "," [
      "space_cache" "compress=zlib" "noatime"
    ];
  };

  fileSystems."/nix/store" = {
    device = "/dev/disk/by-uuid/${storeUUID}";
    fsType = "btrfs";
    options = concatStringsSep "," [
      "ssd" "compress-force=zlib" "noatime"
    ];
  };

  swapDevices = singleton {
    device = "/dev/disk/by-uuid/${swapUUID}";
  };

  powerManagement.powerUpCommands = ''
    ${pkgs.hdparm}/sbin/hdparm -B 254 "/dev/disk/by-id/${diskID}"
  '';

  services.xserver.videoDrivers = [ "intel" ];

  nix.maxJobs = 4;
}