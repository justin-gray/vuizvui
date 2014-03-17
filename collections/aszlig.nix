pkgs:

with pkgs;

{
  haskell = with haskellPackages; [
    bytedump
    cabal2nix
    cabalInstall
    darcs
    diagrams
    ghc
    hjsmin
    hlint
    persistentSqlite
    yesod
    yesodDefault
    yesodStatic
    yesodTest
  ];

  python = with pythonPackages; [
    pep8
    polib
    pkgs.python
    pkgs.python3
  ];

  games = [
    uqm
  ];

  shell = [
    apg
    ascii
    bc
    dash
    dos2unix
    fbida
    figlet
    hexedit
    lftp
    mmv
    mutt
    ncdu
    p7zip
    rlwrap
    screen
    surfraw
    taskwarrior
    unzip
    vbindiff
    w3m
  ];

  multimedia = [
    miro
    mp3info
    mpg321
    mplayer
    pavucontrol
    picard
    pulseaudio
    pvolctrl
    vorbisTools
  ];

  crypto = [
    gnupg1compat
    keychain
    openssh
  ];

  dev = [
    gdb
    gitFull
    gnumake
    gitAndTools.hub
    ltrace
    manpages
    nix-repl
    nixpkgs-lint
    posix_man_pages
    strace
    valgrind
  ];

  dicts = with aspellDicts; [ de en ];

  net = [
    jwhois
    mtr
    netrw
    nmap
    samplicator
    socat
  ];

  x11 = [
    gajim
    i3
    i3lock
    scrot
    xpdf
  ];

  misc = [
    chromiumBetaWrapper
    firefox
    ghostscript
    gimp
    glxinfo
    graphviz
    imagemagick
    lastwatch
    rtorrent
    youtubeDL
  ];
}
