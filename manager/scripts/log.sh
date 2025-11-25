#!/bin/bash

app=$1;
erp=$2;

[ -z "$erp" ] && erp="gcom"


ip_port_file="/home/azdad/docker/ip_port.csv"
found_entry=$(grep -w "^${erp},${app}" "$ip_port_file")

app_ip=$(echo "$found_entry" | awk -F',' '{print $3}')
app_port=$(echo "$found_entry" | awk -F',' '{print $4}')


ssh azdad@$app_ip docker logs -f -n 100 $app-$erp