{config, pkgs, ...}:
{
  require = [
    <nixpkgs/nixos/modules/programs/virtualbox.nix>
  ];

  nix = {
    package = pkgs.nixUnstable;
    maxJobs = 8;
    useChroot = true;
    readOnlyStore = true;
    extraOptions = ''
      build-cores = 0
    '';
  };

  boot = {
    cleanTmpDir = true;

    loader.grub = {
      enable = true;
      version = 2;
    };

    kernelParams = [ "zswap.enabled=1" ];
  };

  hardware = {
    cpu.intel.updateMicrocode = true;
    pulseaudio.enable = true;
    pulseaudio.package = pkgs.pulseaudio.override {
      useSystemd = true;
    };
    opengl = {
      driSupport32Bit = true;
      s3tcSupport = true;
    };
  };

  users.defaultUserShell = "/var/run/current-system/sw/bin/zsh";

  networking = {
    wireless.enable = false;
    firewall.enable = false;
  };

  fileSystems = {
    /*
    "/run/nix/remote-stores/mmrnmhrm/nix" = {
      device = "root@mmrnmhrm:/nix";
      fsType = "sshfs";
      noCheck = true;
      options = pkgs.lib.concatStringsSep "," [
        "comment=x-systemd.automount"
        "compression=yes"
        "ssh_command=${pkgs.openssh}/bin/ssh"
        "Ciphers=arcfour"
        "IdentityFile=/root/.ssh/id_buildfarm"
      ];
    };
    */
  };

  fonts = {
    enableCoreFonts = true;
    enableFontDir = true;
    enableGhostscriptFonts = true;
    extraFonts = [
      pkgs.dosemu_fonts
      pkgs.liberation_ttf
    ];
  };

  i18n = {
    consoleKeyMap = "dvorak";
  };

  programs.ssh.startAgent = false;

  services = {
    openssh = {
      enable = true;
      permitRootLogin = "without-password";
    };

    syslogd.tty = "tty13";

    xfs.enable = false;

    gpm = {
      enable = true;
      protocol = "exps2";
    };

    nixosManual.showManual = false;

    printing = {
      enable = true;
      drivers = [ pkgs.foo2zjs pkgs.foomatic_filters ];
    };

    udev.extraRules = ''
      SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", \
        ATTRS{serial}=="0001", OWNER="aszlig", SYMLINK+="axbo"
    '';

    xserver = {
      enable = true;
      layout = "dvorak";

      startGnuPGAgent = true;

      displayManager.sessionCommands = ''
        ${pkgs.redshift}/bin/redshift -l 48.428404:10.866007 &
      '';

      windowManager = {
        default = "i3";

        i3.enable = true;
        i3.configFile = with pkgs.lib; pkgs.substituteAll ({
          name = "i3.conf";
          src = ./cfgfiles/i3.conf;

          inherit (pkgs) conky dmenu xterm pvolctrl;
          inherit (pkgs.xorg) xsetroot;
          leftHead = head config.services.xserver.xrandrHeads;
          rightHead = last config.services.xserver.xrandrHeads;

          primaryNetInterface = "enp0s25";

          conkyrc = pkgs.writeText "conkyrc" ''
            cpu_avg_samples 2
            net_avg_samples 2
            no_buffers yes
            out_to_console yes
            out_to_ncurses no
            out_to_stderr no
            extra_newline no
            update_interval 1.0
            uppercase no
            use_spacer none
            pad_percents 3
            use_spacer left
            TEXT
          '';
        } // (let
          # Workaround for Synergy: we need to have polarizing heads.
          leftHead = head config.services.xserver.xrandrHeads;
          rightHead = last config.services.xserver.xrandrHeads;
        in if config.networking.hostName == "mmrnmhrm"
           then { inherit leftHead rightHead; }
           else { leftHead = rightHead; rightHead = leftHead; }
        ) // (let
          wsConfig = if config.networking.hostName == "mmrnmhrm"
                     then [ "XMPP" null "chromium" null null
                            null   null null       null null ]
                     else [ "chromium" null null null null
                            null       null null null null ];

          mkWsName = num: name: let
            mkPair = nameValuePair "ws${toString num}";
          in if name == null
             then mkPair (toString num)
             else mkPair "${toString num}: ${name}";

        in listToAttrs (imap mkWsName wsConfig)));
      };

      desktopManager.default = "none";
      desktopManager.xterm.enable = false;

      displayManager.lightdm.enable = true;
    };
  };

  /*
  jobs.vlock_all = {
    name = "vlock-all";
    startOn = "keyboard-request";
    path = [ pkgs.vlock ];
    script = "vlock -asn";
    task = true;
    restartIfChanged = false;
  };
  */

  users.extraUsers.aszlig = {
    uid = 1000;
    description = "aszlig";
    group = "users";
    extraGroups = [ "vboxusers" "wheel" "video" ];
    home = "/home/aszlig";
    useDefaultShell = true;
    createHome = true;
    createUser = true;
  };

  environment.systemPackages = with pkgs; [
    binutils
    cacert
    file
    htop
    iotop
    psmisc
    unrar
    unzip
    vim_configurable
    vlock
    wget
    xz
    zsh
  ];

  nixpkgs.config = import ./nixpkgs/config.nix;

  system.fsPackages = with pkgs; [
    sshfsFuse
  ];

  # broken -> chroot build -> FIXME
  #system.copySystemConfiguration = true;

  time.timeZone = "Europe/Berlin";
}
