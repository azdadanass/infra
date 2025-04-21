#!/bin/bash

app=$1

case $app in
	commons)
		echo NONE;
		;;
	apps)
		echo 8080;
		;;
	iadmin)
		echo 8081;
		;;
	sdm)
		echo 8082;
		;;
	ilogistics)
		echo 8083;
		;;
	public)
		echo 8084;
		;;
	qr)
		echo 8085;
		;;
	ibuy)
		echo 8086;
		;;
	compta)
		echo 8087;
		;;
	iexpense)
		echo 8088;
		;;
	ifinance)
		echo 8089;
		;;
	invoice)
		echo 8090;
		;;
	myhr)
		echo 8091;
		;;
	myoffice)
		echo 8092;
		;;
	myreports)
		echo 8093;
		;;
	mytools)
		echo 8094;
		;;			
	wtr)
		echo 8095;
		;;	
	crm)
		echo 8096;
		;;
	mypm)
		echo 8097;
		;;
	ism)
		echo 8098;
		;;
	utils)
		echo 8099;
		;;
	biostar)
		echo 8100;
		;;
	rproxy)
		echo 80;
		;;
esac