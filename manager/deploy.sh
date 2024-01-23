#!/bin/bash

BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

app=$1;

erp=$2;
[ -z "$erp" ] && erp="gcom"

script_dir_path=$(dirname $(realpath $0))
registry_address=192.168.100.160:5000
app_port=$($script_dir_path/app_port.sh  $app)
app_address=$($script_dir_path/app_address.sh  $app $erp)



[ -z "$app" ] && echo -e "${RED}app empty !${NC}" && exit
[ -z "$app_address" ] && echo -e "${RED}app_address empty !${NC}" && exit
[ -z "$app_port" ] && echo -e "${RED}app_port empty !${NC}" && exit

echo -e "${GREEN}"
echo -e "#############################################"
echo -e "---> registry_address $registry_address"
echo -e "---> app_address $app_address"
echo -e "---> erp $erp"
echo -e "---> app_port $app_port"
echo -e "#############################################"
echo -e "${NC}"

echo -e "${BLUE}cd to ~/git/docker/docker-files/$app ${NC}"
cd ~/git/docker/$1

echo -e "${BLUE}build image $app ${NC}"
~/git/docker/$app/build.sh $app $erp $registry_address

echo -e "${BLUE}delete untagged images ${NC}"
docker rmi $(docker images -qa -f 'dangling=true')

echo -e "${BLUE}push image to $registry_address ${NC}"
docker push $registry_address/$app-$erp:latest

if [ $erp = "orange" ]
then
    echo -e "${BLUE}push image to cloud ${NC}"
    docker image rm azdadanass/$app-$erp:latest
    docker tag $registry_address/$app-$erp azdadanass/$app-$erp
    docker push azdadanass/$app-$erp:latest
fi



if [ $app_port = "NONE" ] || [ $app_port = "NONE" ]
then
    exit 
fi

echo -e "${BLUE}ssh-copy-id azdad@$app_address ${NC}"
ssh-copy-id azdad@$app_address
echo -e "${BLUE}remove existing container & images ${NC}"
ssh azdad@$app_address docker stop $app-$erp
ssh azdad@$app_address docker rm $app-$erp
ssh azdad@$app_address docker image rm $registry_address/$app-$erp:latest 

echo -e "${BLUE}pull image in host ${NC}"
ssh azdad@$app_address docker pull $registry_address/$app-$erp:latest

echo -e "${BLUE}run app ${NC}"
~/git/docker/$app/run.sh $app $erp $app_address $app_port $registry_address


if [ $erp = "gcom" ]
then
    echo "Wait 5min"
    sleep 300
    echo -e "${BLUE}ssh-copy-id azdad@192.168.1.80 ${NC}"
    ssh-copy-id azdad@192.168.1.80
    echo -e "${BLUE}remove existing container & images ${NC}"
    ssh azdad@192.168.1.80 docker stop $app-$erp
    ssh azdad@192.168.1.80 docker rm $app-$erp
    ssh azdad@192.168.1.80 docker image rm $registry_address/$app-$erp:latest 

    echo -e "${BLUE}pull image in host ${NC}"
    ssh azdad@192.168.1.80 docker pull $registry_address/$app-$erp:latest

    echo -e "${BLUE}run app ${NC}"
    ~/git/docker/$app/run.sh $app $erp 192.168.1.80 $app_port $registry_address
fi
