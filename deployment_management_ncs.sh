#!/bin/sh


system_platform=`ipmitool fru | grep "Board Mfg" | tail -n 1  | awk '{print $4}'`
#echo "set enviornment variable"
#/bin/bash config.sh

export CSM_RELEASE=csm-1.2.0
export SYSTEM_NAME=drax
export IPMI_PASSWORD=initial0 
export PITDATA=/var/www/ephemeral

mtoken='ncn-m(?!001)\w+-mgmt' ; stoken='ncn-s\w+-mgmt' ; wtoken='ncn-w\w+-mgmt' ; export USERNAME=root

echo " Check power status of the nodes" 
grep -oP "($mtoken|$stoken|$wtoken)" /etc/dnsmasq.d/statics.conf | sort -u |
        xargs -t -i ipmitool -I lanplus -U $USERNAME   -E -H {} power status


grep -oP "($mtoken|$stoken|$wtoken)" /etc/dnsmasq.d/statics.conf | sort -u |
        xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power off


echo "Change NCN Image Root Password and SSH Keys on PIT Node"
NCN_MOD_SCRIPT=$(rpm -ql docs-csm | grep ncn-image-modification[.]sh)

PW1=initial0
PW2=initial0

#read -s -p "Enter root password for NCN images: " PW1; echo ; if [[ -z ${PW1} ]]; then
         #echo "ERROR: Password cannot be blank"
    # else
        # read -r -s -p "Enter again: " PW2
        # echo
        #if [[ ${PW1} != ${PW2} ]]; then
         #   echo "ERROR: Passwords do not match"
         #else
             export SQUASHFS_ROOT_PW_HASH=$(echo -n "${PW1}" | openssl passwd -6 -salt $(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c4) --stdin)
             [[ -n ${SQUASHFS_ROOT_PW_HASH} ]] && echo "Password hash set and exported" || echo "ERROR: Problem generating hash"
         #fi
    # fi ; unset PW1 PW2  

#It needs inititial0 as password


$NCN_MOD_SCRIPT -p \
                     -t rsa \
                     -N "" \
                     -k "${PITDATA}"/data/k8s/kubernetes-*.squashfs \
                     -s "${PITDATA}"/data/ceph/storage-ceph-*.squashfs


cd "${PITDATA}"/data && rm -rvf ceph/old k8s/old

sed -i -E 's:rd.luks=0 /:rd.luks=0 module_blacklist=rpcrdma \/:g' /root/bin/set-sqfs-links.sh
 /root/bin/set-sqfs-links.sh
 
 if [[ $SYSTEM_NAME == 'drax' ]]
then
        for bs in /var/www/ncn-m*/script.ipxe; do sed -i 's/set hsn_did0 .*/set hsn_did0 0000/' $bs ; done
		for bs in /var/www/ncn-s*/script.ipxe; do sed -i 's/set hsn_did0 .*/set hsn_did0 0000/' $bs ; done

fi

/root/bin/bios-baseline.sh


echo "Set each node to always UEFI Network Boot, and ensure they are powered off"
grep -oP "($mtoken|$stoken|$wtoken)" /etc/dnsmasq.d/statics.conf | sort -u | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} chassis bootdev pxe options=persistent
grep -oP "($mtoken|$stoken|$wtoken)" /etc/dnsmasq.d/statics.conf | sort -u | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} chassis bootdev pxe options=efiboot
grep -oP "($mtoken|$stoken|$wtoken)" /etc/dnsmasq.d/statics.conf | sort -u | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power off

export SW_ADMIN_PASSWORD=!nitial0
echo "Run the LiveCD preflight checks."
csi pit validate --livecd-preflight

conman -q

grep -oP $stoken /etc/dnsmasq.d/statics.conf | grep -v "ncn-s001-" | sort -u |
        xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power on; \
     sleep 60; ipmitool -I lanplus -U $USERNAME -E -H ncn-s001-mgmt power on
	 
	 
echo "if there is no issue with CSI PIT validate command  start the deployment for NCN"
echo "we have rebooted storage node login to each node and check the boot message using conman"
exit

