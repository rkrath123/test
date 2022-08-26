#!/bin/sh



echo "Wait for the deployment to finish."
echo "Deployment is done with enable  the password less for NCNs "
echo "script will continue from step 16/Apply the kdump workaround."
#rsync -av ncn-m002:.ssh/ /root/.ssh/

echo "Apply the kdump workaround "
/usr/share/doc/csm/scripts/workarounds/kdump/run.sh

echo "Check LVM on Kubernetes NCNs."
RESULT=`/usr/share/doc/csm/install/scripts/check_lvm.sh`
RESULT1=$(grep "failed" RESULT)

if [[ -z $RESULT1 ]]
then
echo "Install CSM service completed successfully"
else
echo "EXIT in install csm service due to error"
exit
fi



FM=$(cat /var/www/ephemeral/configs/data.json | jq -r '."Global"."meta-data"."first-master-hostname"')
echo $FM

mkdir -v ~/.kube
scp ${FM}.nmn:/etc/kubernetes/admin.conf ~/.kube/config
kubectl get nodes -o wide


pushd /var/www/ephemeral && ${CSM_RELEASE}/lib/install-goss-tests.sh && popd

for i in $(grep -oP 'ncn-\w\d+' /etc/dnsmasq.d/statics.conf | sort -u | grep -v ncn-m001); do 
       ssh $i "TOKEN=token /srv/cray/scripts/common/chrony/csm_ntp.py"; done

sleep 10m

csi pit validate --ceph | tee csi-pit-validate-ceph.log

 grep "Total Test" csi-pit-validate-ceph.log  --> check is there any failed number in out put 


 csi pit validate --k8s | tee csi-pit-validate-k8s.log

grep "Total Test" csi-pit-validate-k8s.log  --> check is there any failed number in out put

kubectl get pods -o wide -n kube-system | grep -Ev '(Running|Completed)'


