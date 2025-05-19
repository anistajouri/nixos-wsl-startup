#!/bin/sh

# Help function
show_help() {
    echo "Usage: ./git_secret.sh [OPTION]"
    echo "Configure git secrets for github and optionally GitHub."
    echo
    echo "Options:"
    echo "  --help     Display this help message"
    echo "  --github   Include GitHub token configuration"
    echo
    echo "Examples:"
    echo "  ./git_secret.sh         # Configure github only"
    echo "  ./git_secret.sh --github # Configure both github and GitHub"
}


echo "Configuring git secrets for github and optionally GitHub..."
# Check for help argument
if [ "$1" = "--help" ]; then
    show_help
    exit 0
fi


# Prompt for github token with visible asterisks
echo -n "Enter github token: "
github_TOKEN=""
while IFS= read -r -s -n1 char; do
    if [ "$char" = $'\0' ]; then
        break
    elif [ "$char" = $'\177' ] || [ "$char" = $'\010' ]; then
        if [ ${#github_TOKEN} -gt 0 ]; then
            github_TOKEN=${github_TOKEN%?}
            echo -n $'\b \b'
        fi
    else
        github_TOKEN+="$char"
        echo -n "*"
    fi
done
echo



# Prompt for GitHub token if needed
if [ "$1" = "--github" ]; then
    echo -n "Enter GitHub token: "
    read -s GITHUB_TOKEN
    echo
fi


# add github token to git config ./my_config.json where entry is "github_token"
if [ -n "$github_TOKEN" ]; then
    echo "Adding github token to git config..."
    jq --arg token "$github_TOKEN" '.github_token = $token' my_config.json > my_config.json.tmp && mv my_config.json.tmp my_config.json
fi


# Uncomment github configuration in home.nix
sed -i \
    -e 's/^#           "https:\/\/oauth2:${my_config.github_token}@github.com" = {/           "https:\/\/oauth2:${my_config.github_token}@github.com" = {/' \
    -e 's/^#              insteadOf = "https:\/\/github.com";};/              insteadOf = "https:\/\/github.com";};/' \
    home.nix

# rebuild with new git configuration
sudo nixos-rebuild switch --flake /mnt/d/nix/nixos-wsl-startup#nixos-dev
