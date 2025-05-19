{
  config,
  my_config,
  pkgs,
  username,
  nix-index-database,
  ...
}: let
  stable-packages = with pkgs; [
    bat             # A modern replacement for cat, with syntax highlighting and Git integration.
    bottom          # A graphical process viewer for the terminal.
    coreutils       # Basic file, shell, and text manipulation utilities.
    curl            # A command-line tool for transferring data with URLs.
    du-dust         # A more user-friendly version of du for disk usage analysis.
    fd              # A simple, fast, and user-friendly alternative to find.
    findutils       # A collection of utilities for finding files in a directory hierarchy.
    fx              # A command-line JSON processor.
    git-crypt       # A tool for transparent encryption of files in a Git repository.
    htop            # An interactive process viewer for Unix systems.
    jq              # A lightweight and flexible command-line JSON processor.
    killall         # A command to kill processes by name.
    mosh            # A mobile shell that allows roaming and supports intermittent connectivity.
    procs           # A modern replacement for ps, showing process information.
    ripgrep         # A command-line search tool that recursively searches your current directory for a regex pattern.
    sd              # A simple and fast replacement for sed.
    tmux            # A terminal multiplexer that allows multiple terminal sessions to be accessed simultaneously.
    tree            # A recursive directory listing command that produces a depth-indented listing of files.
    unzip           # A utility for unpacking zip files.
    vim             # A highly configurable text editor.
    wget            # A command-line utility for downloading files from the web.
    zip             # A utility for packaging and compressing files.
    yq-go           # A command-line YAML processor.
    gum             # A tool for creating interactive command-line applications.
    go-task         # A task runner / build tool that aims to be simpler and easier to use than GNU Make.
    devbox          # A tool for managing development environments.
    age             # A simple, modern, and secure file encryption tool.
    ssh-to-age      # A tool for converting SSH keys to age keys.

    gopass          # A password manager for all your secrets.
    gnupg           # The GNU Privacy Guard, a complete and free implementation of the OpenPGP standard.
    pass            # A simple password manager using GnuPG.
    pinentry-curses # A curses-based PIN or pass-phrase entry dialog for GnuPG.

    # key tools
    gh               # GitHub CLI for managing GitHub repositories.
    just             # A handy way to save and run project-specific commands.


    # local dev stuff
    mkcert           # A simple zero-config tool to make locally trusted development certificates.
    httpie           # A user-friendly HTTP client.

    # treesitter
    tree-sitter      # An incremental parsing system for programming tools.

    # language servers (local lsps) for neo-vim or vscode
    nodePackages.vscode-langservers-extracted # Language servers for HTML, CSS, JSON, and ESLint.
    nodePackages.yaml-language-server         # Language server for YAML.
    nil                                       # Language server for Nix.

    # formatters and linters
    alejandra        # A formatter for Nix code.
    deadnix          # A linter for detecting dead code in Nix expressions.
    nodePackages.prettier                      # An opinionated code formatter.
    shellcheck       # A linter for shell scripts.
    shfmt            # A shell script formatter.
    statix           # A linter for Nix code.   
  ];
  nixvimConfig = import ./nixvim.nix;
in {
  imports = [
    nix-index-database.hmModules.nix-index
  ];

  # check stable version at https://github.com/NixOS/nixpkgs/tags 
  home.stateVersion = "24.11";

  home = {
    username = "${username}";
    homeDirectory = "/home/${username}";

    sessionVariables.EDITOR = "nvim";
    # FIXME: set your preferred $SHELL
    sessionVariables.SHELL = "/etc/profiles/per-user/${username}/bin/fish";
  };

  home.packages =
    stable-packages
    ++
    [
      (pkgs.lvim.extend nixvimConfig)
    ];

  programs = {
    home-manager.enable = true;
    nix-index.enable = true;
    nix-index.enableFishIntegration = true;
    nix-index-database.comma.enable = true;


    # FIXME: disable this if you don't want to use the starship prompt
    starship.enable = true;
    starship.settings = {
      aws.disabled = true;
      gcloud.disabled = true;
      kubernetes.disabled = false;
      git_branch.style = "242";
      directory.style = "blue";
      directory.truncate_to_repo = false;
      directory.truncation_length = 8;
      python.disabled = true;
      ruby.disabled = true;
      hostname.ssh_only = false;
      hostname.style = "bold green";
    };

#    gpg = {
#      enable = true;
#      homedir = "${config.home.homeDirectory}/.gnupg";
#    };


    # See usage in https://github.com/junegunn/fzf
    fzf.enable = true;
    fzf.enableFishIntegration = true;
    lsd.enable = true;
    lsd.enableAliases = true;
    zoxide.enable = true;
    zoxide.enableFishIntegration = true;
    zoxide.options = ["--cmd cd"];
    broot.enable = true;
    broot.enableFishIntegration = true;
    direnv.enable = true;
    direnv.nix-direnv.enable = true;

    git = {
      enable = true;
      delta.enable = true;
      delta.options = {
        line-numbers = true;
        side-by-side = true;
        navigate = true;
      };
      userEmail = "${my_config.email}";
      userName = "${my_config.name}";
      extraConfig = {
        # FIXME: comment or uncomment the next lines if you want to be able to clone private https repos
        url = {
#           "https://oauth2:${my_config.github_token}@github.com" = {
#              insteadOf = "https://github.com";};
#           "https://oauth2:${my_config.gitlab_token}@gitlab.com" = {
#              insteadOf = "https://gitlab.com";};         
        };
        push = {
          default = "current";
          autoSetupRemote = true;
        };
        merge = {
          conflictstyle = "diff3";
        };
        diff = {
          colorMoved = "default";
        };
      };
    };

    # Fish config - you can fiddle with it if you want
    fish = {
      enable = true;
      interactiveShellInit = ''

        fish_add_path --append "/mnt/d/nix/LVim/config/winyank"
        ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source

        ${pkgs.lib.strings.fileContents (pkgs.fetchFromGitHub {
            owner = "rebelot";
            repo = "kanagawa.nvim";
            rev = "de7fb5f5de25ab45ec6039e33c80aeecc891dd92";
            sha256 = "sha256-f/CUR0vhMJ1sZgztmVTPvmsAgp0kjFov843Mabdzvqo=";
          }
          + "/extras/kanagawa.fish")}

        set -U fish_greeting
        export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}' --preview-window right:60%"
      '';
      functions = {
        refresh = "source $HOME/.config/fish/config.fish";
        take = ''mkdir -p -- "$1" && cd -- "$1"'';
        ttake = "cd $(mktemp -d)";
        show_path = "echo $PATH | tr ' ' '\n'";
        posix-source = ''
          for i in (cat $argv)
            set arr (echo $i |tr = \n)
            set -gx $arr[1] $arr[2]
          end
        '';
      };
      shellAbbrs =
        {
          gc = "nix-collect-garbage --delete-old";
        }
        # navigation shortcuts
        // {
          ".." = "cd ..";
          "..." = "cd ../../";
          "...." = "cd ../../../";
          "....." = "cd ../../../../";
        }
        # git shortcuts
        // {
          gapa = "git add --patch";
          grpa = "git reset --patch";
          gst = "git status";
          gdh = "git diff HEAD";
          gp = "git push";
          gph = "git push -u origin HEAD";
          gco = "git checkout";
          gcob = "git checkout -b";
          gcm = "git checkout master";
          gcd = "git checkout develop";
          gsp = "git stash push -m";
          gsa = "git stash apply stash^{/";
          gsl = "git stash list";
        };
      shellAliases = {
        jvim = "nvim";
        lvim = "nvim";
        vim = "nvim";
        vi = "nvim";
        l = "lsd -la --tree --depth=2";
        pbcopy = "/mnt/c/Windows/System32/clip.exe";
        pbpaste = "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -command 'Get-Clipboard'";
        explorer = "/mnt/c/Windows/explorer.exe";
        # need for impure to manage external secrets
        nix-rebuild = "sudo nixos-rebuild switch --flake /mnt/d/nix/nixos-wsl-startup#nixos-dev";
        nix-cleanup = "sudo nix-collect-garbage -d; sudo nix-store --gc";

        code = "/mnt/c/Users/${my_config.windows_name}/AppData/Local/Programs/'Microsoft VS Code'/bin/code";
      };
      plugins = [
        {
          inherit (pkgs.fishPlugins.autopair) src;
          name = "autopair";
        }
        {
          inherit (pkgs.fishPlugins.done) src;
          name = "done";
        }
        {
          inherit (pkgs.fishPlugins.sponge) src;
          name = "sponge";
        }
      ];
    };
  };
}
