#!/bin/bash

app=$1;
erp=$2;

[ -z "$erp" ] && erp="gcom"

script_dir_path=$(dirname $(realpath $0))
app_address=$($script_dir_path/app_address.sh  $app $erp)

ssh azdad@$app_address docker logs -f -n 100 $app-$erp