#!/bin/sh


export CSM_RELEASE=csm-1.2.0
export SYSTEM_NAME=drax
export PITDATA=/var/www/ephemeral


#Mount the data partition.
 mount -vL PITDATA
 
#Set and export new environment variables.

echo "Set and export new environment variables."
export PITDATA=$(lsblk -o MOUNTPOINT -nr /dev/disk/by-label/PITDATA)
export CSM_PATH=${PITDATA}/${CSM_RELEASE}
echo "
PITDATA=${PITDATA}
CSM_PATH=${CSM_PATH}" | tee -a /etc/environment

#Verify that expected environment variables are set in the new login shell.
echo -e "CSM_PATH=${CSM_PATH}\nCSM_RELEASE=${CSM_RELEASE}\nPITDATA=${PITDATA}\nSYSTEM_NAME=${SYSTEM_NAME}"


#Check the hostname.
hostnamectl

#Check for latest documentation

rpm -Uvh --force https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp2/docs-csm/1.2/noarch/docs-csm-latest.noarch.rpm

#Print information about the booted PIT image.

echo "Print information about the booted PIT image."

/root/bin/metalid.sh

#Configure the running LiveCD

echo "Configure the running LiveCD"

IPMI_PASSWORD=initial0
USERNAME=root
export IPMI_PASSWORD USERNAME

#Initialize the PIT.
echo "Initialize the PIT."
/root/bin/pit-init.sh

#Start and configure NTP on the LiveCD for a fallback/recovery server.

echo "Start and configure NTP on the LiveCD for a fallback/recovery server."
/root/bin/configure-ntp.sh

#Install Goss Tests and Server

echo "Install Goss Tests and Server"

rpm -Uvh --force $(find ${CSM_PATH}/rpm/ -name "goss-servers*.rpm" | sort -V | tail -1) \
                      $(find ${CSM_PATH}/rpm/ -name "csm-testing*.rpm" | sort -V | tail -1)
					  
					  


