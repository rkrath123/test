#!/bin/sh

#Create a working area for this procedure:
mkdir usb
cd usb

#Set up the initial typescript.

#SCRIPT_FILE=$(pwd)/csm-install-usb.$(date +%Y-%m-%d).txt
#script -af ${SCRIPT_FILE}
export PS1='\u@\H \D{%Y-%m-%d} \t \w # '

#Set and export helper variables. command line argument to do 
export CSM_RELEASE=csm-1.2.0
export SYSTEM_NAME=drax
export PITDATA=/mnt/pitdata


#Download and expand the CSM software release.
echo "nameserver 172.30.84.40" >>/etc/resolv.conf
wget https://artifactory.algol60.net/artifactory/csm-releases/csm/1.2/csm-1.2.0.tar.gz
tar -zxvf ${CSM_RELEASE}.tar.gz
ls -l ${CSM_RELEASE}
export CSM_PATH=$(pwd)/${CSM_RELEASE}
echo "CSM tarball placed in this path" $CSM_PATH

#Install the latest version of CSI tool.
rpm -Uvh --force $(find ${CSM_PATH}/rpm/cray/csm/ -name "cray-site-init-*.x86_64.rpm" | sort -V | tail -1)

#Download and upgrade the latest documentation RPM
echo "Download and upgrade the latest documentation RPM"
rpm -Uvh --force https://artifactory.algol60.net/artifactory/csm-rpms/hpe/stable/sle-15sp2/docs-csm/1.2/noarch/docs-csm-latest.noarch.rpm


#csi version
csi version

#Configure zypper with the embedded repository from the CSM release.

zypper ar -fG "${CSM_PATH}/rpm/embedded" "${CSM_RELEASE}-embedded"

#Install Podman or Docker to support container tools required to generate sealed secrets.
 zypper in --repo ${CSM_RELEASE}-embedded -y podman podman-cni-config
 
#Install lsscsi package:
 zypper in --repo ${CSM_RELEASE}-embedded -y lsscsi
 
#Remove CNI configuration from prior install
rm -rf /etc/cni/net.d/00-multus.conf /etc/cni/net.d/10-*.conflist /etc/cni/net.d/multus.d
ls /etc/cni/net.d


# Create the bootable media

lsscsi
USB=/dev/sdd


#Format the USB device.

csi pit format ${USB} ${CSM_PATH}/cray-pre-install-toolkit-*.iso 50000

#Mount the configuration and persistent data partitions.
mkdir -pv /mnt/cow ${PITDATA} &&
       mount -vL cow /mnt/cow &&
       mount -vL PITDATA ${PITDATA} &&
       mkdir -pv ${PITDATA}/configs ${PITDATA}/prep/{admin,logs} ${PITDATA}/data/{ceph,k8s}
	   
#Copy and extract the tarball into the USB.
cp -v ${CSM_PATH}.tar.gz ${PITDATA} &&
       tar -zxvf ${CSM_PATH}.tar.gz -C ${PITDATA}/
	   

echo "copy the seed file manually from vsahata then proceed with configuration payload step"	   
exit
