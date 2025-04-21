#!/bin/bash

app=$1
erp=$2;

case $erp in
	gcom)
		case $app in
			rproxy|apps|compta|iadmin|ibuy|iexpense|ifinance|ilogistics|invoice|myhr|myoffice|myreports|mytools|qr|sdm|wtr|public|crm|mypm|ism|utils|biostar)
				echo 192.168.100.70;
				;;
			commons)
				echo NONE;
				;;
		esac
		;;
	web)
		case $app in
			rproxy)
				echo 192.168.100.62;
				;;
			commons)
				echo NONE;
				;;
		esac
		;;
	orange)
		case $app in
			apps|iadmin|ilogistics|qr|sdm|ibuy|public)
				echo 192.168.100.140;
				;;
			commons)
				echo NONE;
				;;
		esac
		;;
	mise)
		case $app in
			apps|iadmin|myhr|ibuy|compta|ifinance|wtr|mytools|myreports|public|iexpense|invoice)
				echo 192.168.100.130;
				;;
			commons)
				echo NONE;
				;;
		esac
		;;
	test)
		case $app in
			apps|compta|iadmin|ibuy|iexpense|ifinance|ilogistics|invoice|myhr|myoffice|myreports|mytools|qr|sdm|wtr|public|crm|mypm|ism)
				echo 192.168.100.110;
				;;
			commons)
				echo NONE;
				;;
		esac
		;;
esac