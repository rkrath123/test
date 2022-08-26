#!/bin/sh
#prepare management node
#Pre req- All the NCN should be up and ssh connection should be working from master  node 1

host_name=`hostname | grep pit`
system_platform=`ipmitool fru | grep "Board Mfg" | tail -n 1  | awk '{print $4}'`


# 1. Disable dhcp service
echo "Disable dhcp service"
kubectl scale -n services --replicas=0 deployment cray-dhcp-kea

#2.  Wipe disks on booted nodes

# Full wipe Storage nodes:

NCNS=$(grep -oP "ncn-[s][0-9]{3}" /etc/hosts | sort -u | tr '\n' ' ') ; echo "${NCNS}"

for i in ${NCNS[@]}; do aVar=`ssh $i cephadm ls|jq -r '.[0].fsid'`; ssh $i cephadm rm-cluster --fsid ${aVar} --force; done

NCNS=$(grep -oP "ncn-[s][0-9]{3}" /etc/hosts | sort -u | tr '\n' ',') ; echo "${NCNS}"
pdsh -w $NCNS "ps -ef|grep ceph-osd; ls -1 /dev/sd* /dev/disk/by-label/*; vgremove -f --select 'vg_name=~ceph*'; umount -lv /var/lib/ceph /var/lib/containers /etc/ceph; sgdisk --zap-all /dev/sd*;wipefs --all --force /dev/sd* /dev/disk/by-label/*"
sleep 10m

#Full wipe worker node 

NCNW=$(grep -oP "ncn-[w][0-9]{3}" /etc/hosts | sort -u | tr '\n' ',') ; echo "${NCNW}"

pdsh -w  $NCNW umount -lv /var/lib/containerd /var/lib/kubelet /var/lib/sdu; vgremove -f --select 'vg_name=~metal*'; wipefs --all --force /dev/sd* /dev/disk/by-label/*

#Full wipe Master node 

NCNM=$(grep -oP "ncn-[m][0-9]{3}" /etc/hosts |  grep -v m001 | sort -u  | tr '\n' ',') ; echo "${NCNM}"
pdsh -w $NCNM umount -lv /var/lib/etcd /var/lib/sdu; vgremove -f --select 'vg_name=~metal*'; sgdisk --zap-all /dev/sd*;  wipefs --all --force /dev/sd* /dev/disk/by-label/*

sleep 1m


echo "Do 2nd wipe to confirm"
pdsh -w $NCNS "wipefs --all --force /dev/sd* /dev/disk/by-label/*"
pdsh -w $NCNW "wipefs --all --force /dev/sd* /dev/disk/by-label/*"
pdsh -w $NCNM "wipefs --all --force /dev/sd* /dev/disk/by-label/*"

sleep 1m

#3 Set IPMI credentials
USERNAME=root
IPMI_PASSWORD=initial0
export USERNAME
export IPMI_PASSWORD


#4 Power off booted nodes if system is in PIT 
if [ -z  $host_name ]
then
echo "Shutdown from ncn-m001"
grep ncn /etc/hosts | grep mgmt | grep -v m001 | sort -u | awk '{print $2}' | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power status
grep ncn /etc/hosts | grep mgmt | grep -v m001 | sort -u | awk '{print $2}' | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power off
grep ncn /etc/hosts | grep mgmt | grep -v m001 | sort -u | awk '{print $2}' | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power status
echo "Collect BMC hostnames or IP addresses"
BMCS=$(grep -wEo "ncn-[msw][0-9]{3}-mgmt" /etc/hosts | grep -v "m001" | sort -u | tr '\n' ' ') ; echo $BMCS

else
echo "Shut down from pit node"

conman -q | grep mgmt | grep -v m001 | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power status
conman -q | grep mgmt | grep -v m001 | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power off
conman -q | grep mgmt | grep -v m001 | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power status
echo "Collect BMC hostnames or IP addresses"
BMCS=$(grep mgmt /etc/dnsmasq.d/statics.conf | grep -v m001 | awk -F ',' '{print $2}' |
               grep -Eo "([0-9]{1,3}[.]){3}[0-9]{1,3}" | sort -u  | tr '\n' ' ') ; echo $BMCS
fi

#5. Shut down from ncn-m001
grep ncn /etc/hosts | grep mgmt | grep -v m001 | sort -u | awk '{print $2}' | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power off
grep ncn /etc/hosts | grep mgmt | grep -v m001 | sort -u | awk '{print $2}' | xargs -t -i ipmitool -I lanplus -U $USERNAME -E -H {} power status


#7. Set node BMCs to DHCP

if [[ $system_platform == 'Intel' ]]
then
        LAN=3
else
        LAN=1
fi

echo "Print lan information"
echo $LAN
#8. Set the BMCs to DHCP.
for h in $BMCS ; do
           echo "Setting $h to DHCP"
           ipmitool -U $USERNAME -I lanplus -H $h -E lan set $LAN ipsrc dhcp
       done

#9 Verify that the BMCs have been set to DHCP:

for h in $BMCS ; do
           printf "$h: "
           ipmitool -U $USERNAME -I lanplus -H $h -E lan print $LAN | grep Source
       done
	   

#10 Perform a cold reset of any BMCs which are still reachable

for h in $BMCS ; do
           printf "$h: "
           if ping -c 3 $h >/dev/null 2>&1; then
               printf "Still reachable. Issuing cold reset... "
               ipmitool -U $USERNAME -I lanplus -H $h -E mc reset cold
           else
               echo "Not reachable (DHCP setting appears to be successful)"
           fi
       done
	   





