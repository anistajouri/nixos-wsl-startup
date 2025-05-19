# nixos-wsl-startup

This repository is a startup for NixOS development environment on WSL.

Nix enables declarative configuration-as-code, providing a modern development environment comparable to those used by advanced developers or DevOps teams, offering significant advantages over shell-script-based system configuration.


# Checklist

```
NixOS:
✅ Auto-Install NixOS on WSL/Powershell/Windows 10
✅ Fish shell/starship prompt

Backend/Microservices:
✅ Java flake.nix/spring boot profile on vscode/Github copilot/Github Actions
✅ Java flake.nix/Github Actions Simplified with Nix
✅ Java devcontainer/Github copilot
✅ Python flake.nix/Neovim/Github copilot
❌ Go App flake.nix/golang profile on vscode/Github copilot
❌ Java Microservices flake.nix/testcontainer/docker compose/Grafana/Promotheus/spring boot profile on vscode/Github copilot

Web:
✅ Node.JS flake.nix/Angular profile on vscode/Github copilot/playwright e2e testing/jest



Data/IA:
❌ Jupyter/Python flake.nix/data profile on vscode/Github copilot
❌ SQL flake.nix/Bigquery/BigqueryML/data profile on vscode/Github copilot

Ops:
✅ Minikube flake.nix/minikube/Neovim/Github copilot
✅ Crossplane flake.nix/kind/Helm/Neovim/Github copilot
✅ Terraform flake.nix/Google Cloud Platform/Neovim/Github copilot
```

# steps to install

We suppose that you have already:
- you are under windows 10 or 11
- installed WSL2
- git config is correctly set
- optinal: installed vscode (latest version)

then you will install nix under D:\nix or C:\nix


## Quickstart

1. Open powershell and make sure that the wsl working with version 2:

```bash
> wsl --version
Version WSL : 2....
```

2. Under powershell, create a directory where to store the nixos wsl installation and start installation:

```bash
d:  # can be installed on other driver
cd\
mkdir nix 
cd nix
git clone https://github.com/anistajouri/nixos-wsl-startup
cd nixos-wsl-startup
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser 
.\install_nixos.ps1 
```


3. Start using your new NixOS-Dev WSL

```bash
wsl -d NixOS-Dev
```


4. To shutdown the WSL2 VM

```bash
exit
wsl --shutdown
```

## Configuration

1. the setup is declarative, you update it under `/mnt/d/nix/nixos-wsl-startup` and make changes wherever you want.

2. To apply any change in the configuration :

```bash
nix-rebuild
exit
wsl --shutdown
wsl -d NixOS-Dev
```

3. To clean up the system sometimes

```bash
nix-cleanup
```


## Github secret

1. You can add later your github secrets using this script

```bash
./git_secret.sh
``` 


## To add secrets

1. configure gpg agent

```bash
echo "pinentry-program /etc/profiles/per-user/atajouri/bin/pinentry-curses" > ~/.gnupg/gpg-agent.conf
chmod 700 ~/.gnupg
chmod 600 ~/.gnupg/gpg-agent.conf        
gpgconf --kill all
gpg-agent --daemon
```
2. Generate a new GPG key and initialize pass:

```bash
gpg --gen-key
pass init <public key>
``` 

3. Create a new secret:

```bash
pass insert api/openai/key
```


4. Export it under .envrc file:


```bash
echo "export OPENAI_KEY=$(pass api/openai/key)" >> .envrc
```

5. Check pass tree:

```bash
❯ pass ls
Password Store
└── api
    └── openai
        └── key
```

## Environment best Practices

### Maintenance
- Track package versions
- Perform regular security updates
- Monitor dependency changes
- Keep documentation current


### When getting Started
1. Begin with minimal changes
2. Test each modification
3. Document all customizations
4. Keep backup configurations

### Recommended Workflow
- Make incremental changes
- Test thoroughly
- Version control configs
- Maintain change logs

### Safety Measures
- Backup before major updates
- Create restore points
- Test in isolation
- Document rollback procedures


## Core Features

### Shell Environment
- **Default Shell**: `fish` with enhanced configuration (see features https://fishshell.com/)
  - Customized via [home.nix](home.nix)
  - Includes Git aliases and WSL-specific optimizations
  - Features [Starship](https://starship.rs/) prompt for better visual feedback


### CLI Enhancements
- **Modern CLI Tools** (configurable in [home.nix](home.nix)):
  - [`fzf`](https://Github.com/junegunn/fzf) - Fuzzy finder
  - [`lsd`](https://Github.com/lsd-rs/lsd) - Enhanced `ls` command
  - [`zoxide`](https://Github.com/ajeetdsouza/zoxide) - Smarter directory navigation
  - [`broot`](https://Github.com/Canop/broot) - Directory tree explorer
  - All tools can be disabled by setting `enable = false` or removing entries

### Development Tools
- **Environment Management**:
  - [`direnv`](https://Github.com/direnv/direnv) - Load and unload environment variables depending on the current directory.


### Git Configuration
- **Automated Setup**:
  - Configuration generated via [home.nix](home.nix)
  - Support for private HTTPS clones with token authentication
  - Custom aliases for improved workflow


## Project Layout

In order to keep the template as approachable as possible for new NixOS users,
this project uses a flat layout without any nesting or modularization.

```plaintext
.
├── flake.lock            # Lock file for Nix flakes
├── flake.nix             # Dependencies and system configuration
├── home.nix              # User environment configuration
├── nixvim.nix            # nixvim configuration
├── README.md             # Project README with installation and usage instructions
├── my_config.json        # JSON file for storing user informtions
├── statix.toml           # Configuration for statix linter
└── wsl.nix               # WSL-specific system settings
```

- `flake.nix` is where dependencies are specified
  - `nixpkgs` is the current stable release of NixOS
  - `home-manager` is used to manage everything related to your home
    directory (dotfiles etc.)
  - `nixos-wsl` exposes important WSL-specific configuration options
  - `nix-index-database` tells you how to install a package when you run a
    command which requires a binary not in the `$PATH`
- `wsl.nix` is where the VM is configured
  - The hostname is set here
  - The default shell is set here
  - User groups are set here
  - WSL configuration options are set here
  - NixOS options are set here
- `home.nix` is where packages, dotfiles, terminal tools, environment variables
  and aliases are configured
