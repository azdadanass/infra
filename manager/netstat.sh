#!/bin/bash

app=$1;
erp=$2;

[ -z "$erp" ] && erp="gcom"

script_dir_path=$(dirname $(realpath $0))
host_address=$($script_dir_path/host_address.sh  $app $erp)

ssh azdad@$host_address docker exec $app-$erp netstat -tupn