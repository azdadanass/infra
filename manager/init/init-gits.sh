#!/bin/bash

# ===== Config =====
git_folder="/home/azdad/git/3gcom"

# Correct array syntax - removed commas and fixed formatting
apps=(
"apps"
"biostar"
"commons"
"generator"
"iadmin"
"ibuy"
"ibuysupplier"
"iexpense"
"iexpenseold"
"ifinance"
"ifinanceold"
"ilogistics"
"invoice"
"myhr"
"myoffice"
"myreports"
"mytools"
"sdm"
"utils"
"wtr"
"sigasfull"
"qr"
"speedtestserver"
"speedtestweb"
"compta"
"excel"
"myproject"
"public"
"crm"
"oncf"
"mydrive"
"anass"
"docker"
"scripts"
"orangeinit"
"infra"
"sdmmobile"
"speedtestandroid"
"seddar"
"spy"
"base"
"basegcom"
"testcascade"
)

# Loop through the array
for item in "${apps[@]}"; do
    # Remove any whitespace from item (especially important for "testcascade ")
    item=$(echo "$item" | xargs)
    
    echo "Creating bare repository: $git_folder/$item"
    mkdir -p "$git_folder/$item"
    if cd "$git_folder/$item" 2>/dev/null; then
        git init --bare
        cd - > /dev/null || exit 1
    else
        echo "Error: Failed to access directory $git_folder/$item" >&2
        exit 1
    fi
done

echo "All bare repositories created successfully."