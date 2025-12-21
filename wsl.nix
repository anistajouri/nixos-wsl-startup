{
  username,
  hostname,
  pkgs,
  inputs,
  minimalBuild ? false,
  ...
}: {
  # FIXME: change to your tz! look it up with "timedatectl list-timezones"
  time.timeZone = "Africa/Tunis";
  # time.timeZone = "Europe/Paris";


  networking.hostName = "${hostname}";

  # Disable documentation for minimal CI builds to speed up and avoid build failures
  documentation = {
    enable = !minimalBuild;
    man.enable = !minimalBuild;
    info.enable = !minimalBuild;
    doc.enable = !minimalBuild;
    nixos.enable = !minimalBuild;
  };

  # FIXME: change your shell here if you don't want fish
  programs.fish.enable = true;
  environment.pathsToLink = ["/share/fish"];
 
  # Keep both fish and bash as valid login shells
  # Bash acts as a fallback during system updates and recovery
  environment.shells = [ pkgs.fish pkgs.bashInteractive ];

  # Provide essential compatibility paths (incl. VS Code)
  # Keep only minimal symlinks - other tools added via activationScripts
  # Also ensure XDG_RUNTIME_DIR exists for the user (needed for systemd user bus)
  systemd.tmpfiles.rules = [
    "L+ /usr/bin/env  - - - - /run/current-system/sw/bin/env"
    "L+ /bin/bash     - - - - /run/current-system/sw/bin/bash"
    "L+ /bin/sh       - - - - /run/current-system/sw/bin/sh"
    "d /run/user/1000 0700 ${username} users -"
  ];

  # Create persistent compatibility symlinks during system activation
  # These exist on the filesystem before WSL starts systemd
  system.activationScripts.wslUsrBinCompat = ''
    mkdir -p /usr/bin /bin
    ln -sfn /run/current-system/sw/bin/systemctl  /usr/bin/systemctl
    ln -sfn /run/current-system/sw/bin/loginctl   /usr/bin/loginctl
    ln -sfn /run/current-system/sw/bin/journalctl /usr/bin/journalctl
    # Redundant links for tools that expect them
    ln -sfn /run/current-system/sw/bin/bash /bin/bash
    ln -sfn /run/current-system/sw/bin/sh   /bin/sh
  '';

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      zlib
      openssl
    ];
  };

#  programs.gnupg.agent = {
#    enable = true;
#    pinentryPackage = pkgs.pinentry-curses;
#  };

  environment.enableAllTerminfo = true;

  security.sudo.wheelNeedsPassword = false;

  # FIXME: uncomment the next line to enable SSH
  # services.openssh.enable = true;

  users.users.${username} = {
    isNormalUser = true;
    # FIXME: change your shell here if you don't want fish
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "docker"
    ];
    # Keep systemd user session alive even without TTY
    # Prevents X11 autolaunch and session termination issues
    linger = true;
    # FIXME: add your own hashed password
    # hashedPassword = "";
    # FIXME: add your own ssh public key
    # openssh.authorizedKeys.keys = [
    #   "ssh-rsa ..."
    # ];
  };

  home-manager.users.${username} = {
    imports = [
      ./home.nix
    ];
  };

  system.stateVersion = "25.11";

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    wslConf.interop.appendWindowsPath = false;
    wslConf.network.generateHosts = false;
    defaultUser = username;
    startMenuLaunchers = true;
    docker-desktop.enable = false;
    # Suppress the "Failed to start systemd user session" warning
    # The user session starts via PAM/login, this just hides the initial check
    wslConf.user.default = username;
  };

  # Ensure systemd user session starts properly on login
  # This creates the user bus socket that WSL checks for
  security.pam.loginLimits = [
    { domain = "@wheel"; item = "nofile"; type = "soft"; value = "65536"; }
  ];

  # Force systemd user session to start for the default user
  systemd.services."user@" = {
    overrideStrategy = "asDropin";
    serviceConfig = {
      # Ensure user slice is properly initialized
      Delegate = "yes";
    };
  };

  # Start user session early during boot (before WSL checks for it)
  systemd.services."ensure-user-session-${username}" = {
    description = "Ensure systemd user session for ${username}";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-logind.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.systemd}/bin/loginctl enable-linger ${username}";
    };
  };


  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune.enable = true;
    daemon.settings = {
      "registry-mirrors" = [ "https://mirror.gcr.io" ];
    };
  };

  # Workaround to make vscode running in Windows "just work" with NixOS on WSL
  # solution adapted from: https://github.com/K900/vscode-remote-workaround
  # more information: https://github.com/nix-community/NixOS-WSL/issues/238 and https://github.com/nix-community/NixOS-WSL/issues/294
  systemd.user = if minimalBuild then { } else {
    # Fix systemd user session startup issues in WSL
    # Forces a valid PATH for all user units (fixes WSLg and other services)
    extraConfig = ''
      DefaultEnvironment=PATH=/run/current-system/sw/bin:/etc/profiles/per-user/%u/bin:/usr/bin:/bin
      DefaultEnvironment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/%U/bus
    '';

    paths.vscode-remote-workaround = {
      wantedBy = ["default.target"];
      pathConfig.PathChanged = "%h/.vscode-server/bin";
    };
    services.vscode-remote-workaround.script = ''
      for i in ~/.vscode-server/bin/*; do
        if [ -e "$i/node" ]; then
          echo "Fixing vscode-server node in $i (wrapping with UV_USE_IO_URING=0)..."
          cat > "$i/node" <<'EOF'
#!/usr/bin/env bash
export UV_USE_IO_URING=0
exec ${pkgs.nodejs_22}/bin/node "$@"
EOF
           chmod +x "$i/node"
        fi
#        if [ -e $i/node ]; then
#          echo "Fixing vscode-server in $i..."
#          ln -sf ${pkgs.nodejs_22}/bin/node $i/node
#        fi
      done
    '';
  };

  nix = {
    settings = {
      trusted-users = [username];
      # TODO: use your access tokens from secrets.json here to be able to clone private repos on GitHub and GitLab
      #access-tokens = [
      #  "github.com=${secrets.github_token}"
      #  "gitlab.com=OAuth2:${secrets.gitlab_token}"
      #];

      accept-flake-config = true;
      auto-optimise-store = true;
    };

    registry = {
      nixpkgs = {
        flake = inputs.nixpkgs;
      };
    };

    nixPath = [
      "nixpkgs=${inputs.nixpkgs.outPath}"
      "nixos-config=/etc/nixos/configuration.nix"
      "/nix/var/nix/profiles/per-user/root/channels"
    ];

    package = pkgs.nixVersions.stable;
    extraOptions = ''experimental-features = nix-command flakes'';

    gc = {
      automatic = true;
      options = "--delete-older-than 7d";
    };
  };
}
