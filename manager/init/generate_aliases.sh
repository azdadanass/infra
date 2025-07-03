#!/bin/bash

# Define the content to be added to .bash_aliases
CONTENT='
# Deploy alias with autocompletion
alias deploy='"'"'~/docker/deploy.sh'"'"'

_deploy_completion() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # List of available applications
    opts="commons rproxy apps iadmin sdm ilogistics public qr ibuy compta iexpense iexpenseold ifinance invoice myhr myoffice myreports mytools wtr crm mypmnew ism utils biostar mydrive totpvalidator mysqlradius"  # Update this list as needed

    if [[ ${prev} == "deploy" ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
}

complete -F _deploy_completion deploy
'

# Backup existing .bash_aliases if it exists
if [ -f ~/.bash_aliases ]; then
    cp ~/.bash_aliases ~/.bash_aliases.bak
    echo "Created backup of .bash_aliases at ~/.bash_aliases.bak"
fi

# Remove existing deploy-related configurations if they exist
if [ -f ~/.bash_aliases ]; then
    sed -i '/^# Deploy alias with autocompletion/,/^complete -F _deploy_completion deploy/d' ~/.bash_aliases
fi

# Append the new content
echo "$CONTENT" >> ~/.bash_aliases

# Source the file to make changes take effect immediately
source ~/.bash_aliases

echo "Deploy alias and autocompletion have been set up successfully."