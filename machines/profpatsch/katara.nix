{ config, pkgs, lib, ... }:
let

  offlineimapGPG = pkgs.offlineimap.overrideDerivation (old: {
    propagatedBuildInputs = old.propagatedBuildInputs
                         ++ lib.singleton pkgs.pythonPackages.pygpgme;
  });

  mytexlive = with pkgs.texlive; combine { inherit scheme-medium minted units collection-bibtexextra; };

  mylyx = with pkgs; stdenv.mkDerivation rec {
    name = "mylyx";
    src = pkgs.lyx;
    buildInputs = [ makeWrapper ];
    installPhase = ''
      mkdir -p $out/bin
      cd $out/bin
      ln -s ${src}/bin/lyx
      wrapProgram $out/bin/lyx \
        --set TEXMFDIST ${mytexlive}/texmf-dist
    '';
  };

in {

  config = rec {

    #########
    # Kernel

    boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "firewire_ohci" ];
    boot.kernelModules = [ "kvm-intel" ];
    boot.loader.grub.enable = true;
    boot.loader.grub.version = 2;
    boot.loader.grub.device = "/dev/sda";
    boot.initrd.luks.devices = [ { device = "/dev/sda2"; name = "cryptroot"; } ];


    ###########
    # Hardware

    # Use this if you want the T400 wifi to work …
    hardware.enableAllFirmware = true;

    hardware.trackpoint = {
      enable = true;
      emulateWheel = true;
      speed = 250;
      sensitivity = 140;
    };

    fileSystems."/" = {
      device = "/dev/dm-0";
      fsType = "btrfs";
    };

    fileSystems."/boot" = {
      device = "/dev/sda1";
      fsType = "ext3";
    };

    hardware.pulseaudio.enable = true;


    ######
    # Nix

    nix.maxJobs = 2;
    nix.binaryCaches = [ "https://hydra.nixos.org/" ];

    ##########
    # Network

    networking.hostName = "katara";
    networking.networkmanager.enable = true;

    networking.extraHosts = ''
      192.168.1.10 nyx.pnetz
    '';

    networking.firewall = {
      enable = true;
      # Programmer’s dilemma
      allowedTCPPortRanges = [
        { from = 8000; to = 8005; }
        { from = 8080; to = 8085; }
      ];
    };

    i18n = {
      consoleFont = "lat9w-16";
      consoleKeyMap = "us";
      defaultLocale = "en_US.UTF-8";
    };


    ###########
    # Packages

    environment.systemPackages = with pkgs;
    let
      systemPkgs = [
        ack
        atool
        curl
        file
        fish
        git
        gnupg
        htop
        imagemagick
        mkpasswd
        mosh
        nix-repl
        nmap
        stow
        tmux
        vim
        wget
        zsh
      ];
      xPkgs = [
        dmenu
        dunst
        i3lock
        libnotify
        lxappearance
        xbindkeys
        haskellPackages.xmobar
      ];
      guiPkgs = [
        gnome3.adwaita-icon-theme
        # TODO: get themes to work. See notes.org.
        gnome3.gnome_themes_standard
        # kde4.oxygen-icons TODO
      ];
      userPrograms = [
        audacity
        (chromium.override { enablePepperFlash = true; })
        dropbox-cli
        emacs
        feh
        filezilla
        gajim
        gmpc
        kde4.kdiff3
        keepassx
        libreoffice
        lilyterm
        # (lyx.overrideDerivation (old: { buildInputs = old.buildInputs ++ /*packages*/ lib.singleton mytexlive; }))
        lyx mytexlive #mylyx mytexlive
        mpv
        audacity lame
        gmpc
        zathura
      ];
      mailPkgs = [
        offlineimapKeyring
        mutt-with-sidebar # TODO mutt-kz
        msmtp
        notmuch
      ];
      haskellPkgs = with pkgs.haskellngPackages; [
        cabal2nix
      ];
      nixPkgs = [
        nix-prefetch-scripts
      ];
    in systemPkgs ++ xPkgs ++ guiPkgs ++ userPrograms ++ mailPkgs ++ haskellPkgs ++ nixPkgs;

    system.extraDependencies = lib.singleton (
       pkgs.haskellPackages.ghcWithHoogle (hpkgs: with hpkgs;
         [
           # frp
           frpnow
           gloss
           gtk
           frpnow-gtk
           frpnow-gloss
         ]));


    ###########
    # Services

    # Enable the OpenSSH daemon.
    services.openssh.enable = true;

    # Enable CUPS to print documents.
    services.printing = {
      enable = true;
      drivers = [ pkgs.gutenprint ];
    };

    time.timeZone = "Europe/Berlin";

    # redshift TODO as user
    services.redshift = {
      latitude = "48";
      longitude = "10";
      temperature.day = 6300;
    };

    # locate
    services.locate = {
      enable = true;
    };

    # Automount
    services.udisks2.enable = true;

    # Music as a Service TODO
    services.mpd.enable = false;
    services.mpd.musicDirectory = pkgs.runCommand "mpd-link" {} ''
      ln -s ${users.extraUsers.philip.home}/Downloads/music $out
    '';


    ###################
    # Graphical System

    services.xserver = {
      enable = true;
      layout = "de";
      xkbVariant = "neo";
      xkbOptions = "altwin:swap_alt_win";
      serverFlagsSection = ''
        Option "StandbyTime" "10"
        Option "SuspendTime" "20"
        Option "OffTime" "30"
      '';
      synaptics.enable = true;
      synaptics.minSpeed = "0.5";
      synaptics.accelFactor = "0.01";
      videoDrivers = [ "intel" ];

      # otherwise xterm is enabled, creating an xterm that spawns the window manager.
      desktopManager.xterm.enable = false;
      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
      };
      displayManager.sessionCommands =
        ''
        #TODO add as nixpkg
        export PATH+=":$HOME/scripts" #add utility scripts
        xset r rate 250 35
        set-background &
        xbindkeys
        nice -n19 dropbox start &
        '';

      startGnuPGAgent = true;
    };

    fonts.fontconfig = {
      defaultFonts = {
        monospace = [ "Source Code Pro" "DejaVu Sans Mono" ]; # TODO does not work
        sansSerif = [ "Liberation Sans" ];
      };
      # use overkill infinality settings from old Arch installation
      ultimate = {
        rendering = {
          INFINALITY_FT_FILTER_PARAMS = "08 24 36 24 08";
          INFINALITY_FT_FRINGE_FILTER_STRENGTH = "25";
          INFINALITY_FT_USE_VARIOUS_TWEAKS = "true";
          INFINALITY_FT_WINDOWS_STYLE_SHARPENING_STRENGTH = "25";
          INFINALITY_FT_STEM_ALIGNMENT_STRENGTH = "15";
          INFINALITY_FT_STEM_FITTING_STRENGTH = "15";
        };
      };
    };
    fonts.enableFontDir = true;
    fonts.fonts = with pkgs; [
      corefonts
      source-han-sans-japanese
      source-han-sans-korean
      source-han-sans-simplified-chinese
      source-code-pro
      dejavu_fonts
      ubuntu_font_family
    ];



    ########
    # Users

    # Nobody wants mutable state. :)
    users.mutableUsers = false;
    users.extraUsers = 
      let authKeys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDJhthfk38lzDvoI7lPqRneI0yBpZEhLDGRBpcXzpPSu+V0YlgrDix5fHhBl+EKfw4aeQNvQNuAky3pDtX+BDK1b7idbz9ZMCExy2a1kBKDVJz/onLSQxiiZMuHlAljVj9iU4uoTOxX3vB85Ok9aZtMP1rByRIWR9e81/km4HdfZTCjFVRLWfvo0s29H7l0fnbG9bb2E6kydlvjnXJnZFXX+KUM16X11lK53ilPdPJdm87VtxeSKZ7GOiBz6q7FHzEd2Zc3CnzgupQiXGSblXrlN22IY3IWfm5S/8RTeQbMLVoH0TncgCeenXH7FU/sXD79ypqQV/WaVVDYMOirsnh/ philip@nyx"];
      in {
        philip = rec {
  	name = "philip";
  	group = "users";
          extraGroups = [ "wheel" "networkmanager" ];
  	uid = 1000;
  	createHome = true;
  	home = "/home/philip";
          passwordFile = "${home}/.config/passwd";
          # password = "test"; # in case of emergency, break glass
  	shell = "/run/current-system/sw/bin/bash";
          openssh.authorizedKeys.keys = authKeys;
      };
    };

    ###########
    # Programs

    programs.ssh = {
      startAgent = false; # see services.xserver.startGnuPGAgent
      agentTimeout = "1h";
    };

    #######
    # Misc

    # TODO seems to work only sometimes in chromium
    security.pki.certificateFiles = [ "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt" ];

    ########
    # Fixes

    # fix for emacs
    programs.bash.promptInit = "PS1=\"# \"";

  };
}
