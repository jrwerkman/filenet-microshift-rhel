# Installing the OS and microshift   
I have used RHEL 9.4 and installed microshift using this guide   
[Getting ready to install microshift](https://docs.redhat.com/en/documentation/red_hat_build_of_microshift/4.18/html/getting_ready_to_install_microshift/microshift-greenboot)   
[Installing with an rpm package](https://docs.redhat.com/en/documentation/red_hat_build_of_microshift/4.18/html/installing_with_an_rpm_package/microshift-install-rpm)   

## note
In this manual i used Password1 for all passwords, change if needed.   
I created this manual with developers in mind, so we have access to a lightweight environment for developing with filenet in container.   
I use Amsterdam for my timezone in de deployment files, change if needed.   

# Download the pull secret   
Get the pull secret here: [pull-secret](https://console.redhat.com/openshift/install/pull-secret)   

## install the pull secret on rhel
```bash
sudo cp openshift-pull-secret /etc/crio/openshift-pull-secret
sudo chown root:root /etc/crio/openshift-pull-secret
sudo chmod 600 /etc/crio/openshift-pull-secret
```

# Prepare install   
Copy the content of the repository in the your home folder   
- install (folder)
- nfs (folder)
- keytool (folder, only if you want to config your key yourself)

# Disable firewall and SELinux (only for dev)
Add SELINUX=disabled to /etc/selinux/config   
```bash
sudo nano /etc/selinux/config
```

## stop the firewall   
```bash
sudo systemctl stop firewalld
sudo systemctl disable firewalld
```

# Prepare OS  
Enable crio (if not enabled already)   
```bash
sudo systemctl enable crio
```
Change hostname
```bash
sudo hostnamectl set-hostname <hostname>
```
You can choose another hostname, but than you have to change values in the yaml files...   
finally reboot the vmware/machine   

# Installing   
## information: used images in this example
see [ecm container releases](https://github.com/ibm-ecm/container-samples/releases)
|Component 		|Image Repository 									|Image Tag 					|Build Version  |
|---------------|---------------------------------------------------|---------------------------|---------------|
|CPE 			|cp.icr.io/cp/cp4a/fncm/cpe 						|ga-570-p8cpe 				|5.7.0-0-952    |
|CPE-SSO 		|cp.icr.io/cp/cp4a/fncm/cpe-sso 					|ga-570-p8cpe 				|5.7.0-0-952    |
|CSS 			|cp.icr.io/cp/cp4a/fncm/css 						|ga-570-p8css 				|5.7.0-0-28     |
|GraphQL 		|cp.icr.io/cp/cp4a/fncm/graphql				 		|ga-570-p8cgql				|5.7.0-877      |
|External Share |cp.icr.io/cp/cp4a/fncm/extshare 					|ga-320-es 					|5.7.0-0-125    |
|CMIS 			|cp.icr.io/cp/cp4a/fncm/cmis					 	|ga-307-cmis-if010		 	|307.010.0187   |
|TaskManager 	|cp.icr.io/cp/cp4a/fncm/taskmgr 					|ga-320-tm		 			|320.000.102    |
|Navigator 		|cp.icr.io/cp/cp4a/ban/navigator					|ga-320-icn				 	|320.000.0339   |
|Navigator-SSO 	|cp.icr.io/cp/cp4a/ban/navigator-sso 				|ga-320-icn		 			|320.000.0339   |
|IER 			|cp.icr.io/cp/cp4a/ier/ier 							|ga-5218-if008-ier-2500 	|570.005.774    |
|ICCSAP 		|cp.icr.io/cp/cp4a/iccsap/iccsap 					|ga-iccsap-4004-if019-2500 	|4.0.0.4        |
|Keytool-Init 	|cp.icr.io/cp/cp4a/common/dba-keytool-initcontainer |25.0.0 					|25.0.0         |
|Operator 		|icr.io/cpopen/icp4a-content-operator 				|5.7.0 						|5.7.0          |


## Create namespaces   
```bash
oc create namespace infra
oc create namespace filenet
```

## apply configmaps
### general configmap
```bash
oc apply -f ~/install/configmap.yaml -n filenet
```

### ssl configmap
Create the `ssl-configmap.yaml`, see [KEYTOOL.md](./KEYTOOL.md)
```bash
oc apply -f ~/install/ssl-configmap.yaml -n filenet
```
## Logins
First get you entitlement key, see link below   
[https://myibm.ibm.com/products-services/containerlibrary](https://myibm.ibm.com/products-services/containerlibrary)   
### Login to podman
Note you have to have a redhat account   
When you restart the machine you have to login again if you want to pull images    
```bash
podman login registry.redhat.io
podman login cp.icr.io --username cp --password <entitlement-key>
```
### create ibm-entitlement-key secrets for namespaces
We do this for both infra and filenet namespace, so we can pull IBM Verify Directory Server and filenet images
```bash
oc create secret docker-registry ibm-entitlement-key \
  --docker-server=cp.icr.io \
  --docker-username=cp \
  --docker-password=<entitlement-key> \
  --namespace=infra

oc create secret docker-registry ibm-entitlement-key \
  --docker-server=cp.icr.io \
  --docker-username=cp \
  --docker-password=<entitlement-key> \
  -n filenet
```

## Install storageclass
We are using the nfs storageclass, this is handy, because we dont need anything extra, besides the storageclasses   
LVM storage is also an option, but needs much more configuration and is more string in binding to a PVC   
### prepare nfs-server   
Install nfs-utils first   
```bash
sudo dnf install nfs-utils
sudo systemctl enable --now rpcbind nfs-server

sudo mkdir -p /mnt/nfs_share
sudo chown admin:admin /mnt/nfs_share
sudo chmod 777 /mnt/nfs_share
```
Add you share to /etc/exports, but adding following line   
`/mnt/nfs_share *(rw,sync,no_root_squash,no_subtree_check)`   
Initialize the nfs-server
```bash
sudo exportfs -arv
sudo systemctl restart nfs-server
```
Now we create the nfs storageclasses, pods and rbac for easy option, use nfs folder in this project (skip next chapter)   
### Configure nfs stuff yourself
Download yaml files   
```bash
mkdir ~/nfs
cd ~/nfs

wget https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/rbac.yaml
wget https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/deployment.yaml
wget https://raw.githubusercontent.com/kubernetes-sigs/nfs-subdir-external-provisioner/master/deploy/class.yaml
```
Update the deployment.yaml   
change /ifs/kubernetes to /mnt/nfs_share   
change ip to 10.42.0.2 (in my case, using "hostname -I")   
also replace namespace for 3 downloaded file to: infra    
### deploy nfs stuff
install NFS subdir external provisioner
```bash
oc apply -f ~/nfs/class.yaml -n infra
oc apply -f ~/nfs/rbac.yaml -n infra
oc apply -f ~/nfs/deployment.yaml -n infra

# Set the enforcement level to privileged (allows all pod security violations)
oc label namespace infra pod-security.kubernetes.io/enforce=privileged
# Set the audit level to privileged (logs violations but doesn't block them)
oc label namespace infra pod-security.kubernetes.io/audit=privileged
# Set the warning level to privileged (shows warnings but doesn't block)
oc label namespace infra pod-security.kubernetes.io/warn=privileged
# Add the nfs-client-provisioner service account to the privileged SCC users list
oc patch scc privileged --type='json' -p='[{"op": "add", "path": "/users/-", "value": "system:serviceaccount:infra:nfs-client-provisioner"}]'
```

## (Optional) Create a Samba share
Install samba-tools   
```bash
sudo dnf install samba samba-common-tools
```
Edit /etc/samba/smb.conf, see example below   
```
[global]
        workgroup = SAMBA
        security = user
        passdb backend = tdbsam

[homes]
        comment = Home Directories
        valid users = %S
        browseable = yes
        writable = yes
        inherit acls = yes

[share]
        comment = Shared Directory
        path = /mnt/nfs_share
        browseable = yes
        writable = yes
        guest ok = no
        valid users = @samba-users
        inherit acls = yes
```
Create a samba group and user   
```
sudo groupadd samba-users
sudo usermod -a -G samba-users admin
sudo smbpasswd -a admin

# extra permission in pvc's
sudo usermod -a -G root admin
```
Lastly enable samba   
```
sudo setsebool -P samba_enable_home_dirs on
sudo systemctl enable --now smb
sudo systemctl status smb
```

## Install IBM Verify Directory Server
Note you can use openLdap instead. This needs changes in:   
- ldap-deployment.yaml
- ldap-service.yaml
- ports to ldap in configmap.yaml
- config-gcd.sh, config-os.sh and config-fpos.sh
   
When using IBM Verify Directory Server you need to fill in the license_key, see config in ldap-deployment.yaml   

first pull the image   
```bash
podman pull icr.io/isvd/verify-directory-server:10.0.4.0
```
apply yaml files (deployment, service and pvc)   
```bash
oc apply -f ~/install/ldap/ldap-pvc.yaml
oc apply -f ~/install/ldap/ldap-service.yaml
oc apply -f ~/install/ldap/ldap-deployment.yaml
```
wait till pod is running `oc get pods -n infra -w`
than install users and groups   
```bash
POD_NAME_LDAP=$(oc get pods -n infra | grep ldap | head -1 | awk '{print $1}')
oc cp ~/install/ldap/users.ldif -n infra ${POD_NAME_LDAP}:/tmp/users.ldif
oc cp ~/install/ldap/groups.ldif -n infra ${POD_NAME_LDAP}:/tmp/groups.ldif
```
enter pod to apply ldif   
```bash
oc exec -n infra ${POD_NAME_LDAP} -it -- /bin/bash
ldapadd -x -h localhost -p 9389 -D "cn=root" -w Password1 -f /tmp/users.ldif
ldapadd -x -h localhost -p 9389 -D "cn=root" -w Password1 -f /tmp/groups.ldif
```
### verify   
stil inside the pod try to see if ldapsearch gives results   
```bash
ldapsearch -x -h localhost -p 9389 -D "cn=bindldap,ou=dev,dc=demodom,dc=nl" -w Password1 -b "dc=demodom,dc=nl" "(objectClass=*)"
```

## Install Postgresql [link](https://catalog.redhat.com/software/containers/rhel8/postgresql-16/657c148efd40a94aa696f28e?image=683864ed60a2842a2b03e759)
first pull the image   
```bash
podman pull registry.redhat.io/rhel8/postgresql-16:1-44
```
apply yaml files (deployment, service and pvc)   
```bash
oc apply -f ~/install/db/postgresql-pvc.yaml
oc apply -f ~/install/db/postgresql-svc.yaml
oc apply -f ~/install/db/postgresql-deployment.yaml
```
### verify postgres pod
```bash
oc get pods -n infra
oc describe pod postgres
```

### create databases
create folders for databases   
```bash
POD_NAME_POSTGRES=$(oc get pods -n infra | grep postgres | head -1 | awk '{print $1}')
oc exec -it ${POD_NAME_POSTGRES} -n infra -- bash

# inside pod make directories

mkdir /var/lib/pgsql/data/icn_db
mkdir /var/lib/pgsql/data/ldap_db
mkdir /var/lib/pgsql/data/fn_gcd_db
mkdir /var/lib/pgsql/data/fn_os_db
mkdir /var/lib/pgsql/data/fn_os_db/data
mkdir /var/lib/pgsql/data/fn_os_db/index
mkdir /var/lib/pgsql/data/fn_fpos_db
mkdir /var/lib/pgsql/data/fn_fpos_db/data
mkdir /var/lib/pgsql/data/fn_fpos_db/index
```
exit pod and enter pod with psql
```bash
oc exec -it ${POD_NAME_POSTGRES} -n infra -- psql -U postgres
```
inside psql run scripts to create databases (you can copy and paste stuff from the files)   
- ~\install\db\createGCD.sql
- ~\install\db\createFPOS.sql
- ~\install\db\createObjectstore.sql
- ~\install\db\createICN.sql

#### verify databases
```bash
# list databases
\l
# list users
\du
# list tablespaces
\db
```
To exit psql use `\q`
## Install CPE
first pull the image   
```bash
podman pull cp.icr.io/cp/cp4a/fncm/cpe:ga-570-p8cpe
```
apply yaml files (deployment, service and pvc)   
```bash
oc apply -f ~/install/fn/filenet-pvc.yaml -n filenet
oc apply -f ~/install/fn/filenet-deployment.yaml -n filenet
oc apply -f ~/install/fn/filenet-service.yaml -n filenet
```
copy the config files to create the domain and objectstores   
```bash
POD_NAME_FILENET=$(oc get pods -n filenet | grep cpe | head -1 | awk '{print $1}')
oc cp ~/install/fn/config-gcd.sh ${POD_NAME_FILENET}:/home/liberty/config-gcd.sh -n filenet
oc cp ~/install/fn/config-os.sh ${POD_NAME_FILENET}:/home/liberty/config-os.sh -n filenet
oc cp ~/install/fn/config-fpos.sh ${POD_NAME_FILENET}:/home/liberty/config-fpos.sh -n filenet
```
execute the config files to install the gcd and objectstores   
```bash
oc exec -it ${POD_NAME_FILENET} -n filenet -- /bin/bash
/home/liberty/config-gcd.sh
/home/liberty/config-os.sh
/home/liberty/config-fpos.sh
```
## Install GraphQL
```bash
podman pull cp.icr.io/cp/cp4a/fncm/graphql:ga-570-p8cgql
```
apply yaml files (deployment, service and pvc)   
```bash
oc apply -f ~/install/graphql/graphql-pvc.yaml -n filenet
oc apply -f ~/install/graphql/graphql-deployment.yaml -n filenet
oc apply -f ~/install/graphql/graphql-service.yaml -n filenet
```
## Install Content Navigator
```bash
podman pull cp.icr.io/cp/cp4a/ban/navigator:ga-320-icn
```
apply yaml files (deployment, service and pvc)   
```bash
oc apply -f ~/install/icn/icn-pvc.yaml -n filenet
oc apply -f ~/install/icn/icn-deployment.yaml -n filenet
oc apply -f ~/install/icn/icn-service.yaml -n filenet
```
### configure repos, desktop, etc.. manually   
for repos use following data
#### Objectstore   
wsi: http://cpe-svc.filenet.svc.cluster.local:9080/wsi/FNCEWS40MTOM   
displayName: Objectstore   
symbolicName: OS   
#### Fileplan Objectstore   
wsi: http://cpe-svc.filenet.svc.cluster.local:9080/wsi/FNCEWS40MTOM   
displayName: Fileplan Objectstore   
symbolicName: FPOS   

## Install Taskmanager
```bash
podman pull cp.icr.io/cp/cp4a/fncm/taskmgr:ga-320-tm
```
apply yaml files (deployment, service and pvc)   
```bash
oc apply -f ~/install/tm/tm-pvc.yaml -n filenet
oc apply -f ~/install/tm/tm-deployment.yaml -n filenet
oc apply -f ~/install/tm/tm-service.yaml -n filenet
```
### configure taskmanager in navigator
uri:  http://tm-svc.filenet.svc.cluster.local:9080/taskManagerWeb/api/v1   
log:  /opt/ibm/wlp/usr/servers/defaultServer/logs/taskMgr   
user: p8admin   
pass: Password1   
## Install Enterprise Records
```bash
podman pull cp.icr.io/cp/cp4a/ier/ier:ga-5218-if008-ier-2500
```
apply yaml files (deployment, service and pvc)   
```bash
oc apply -f ~/install/ier/ier-pvc.yaml -n filenet
oc apply -f ~/install/ier/ier-deployment.yaml -n filenet
oc apply -f ~/install/ier/ier-service.yaml -n filenet
```
to configure filenet you have to use the traditional configuration tool :'(   
[https://www.ibm.com/docs/en/enterprise-records/5.2.1?topic=containers-completing-post-deployment-tasks-enterprise-records](https://www.ibm.com/docs/en/enterprise-records/5.2.1?topic=containers-completing-post-deployment-tasks-enterprise-records)   

### installing plugin 
In navigator load plugin, using link   
`https://ier-svc.filenet.svc.cluster.local:9443/EnterpriseRecordsPlugin/IERApplicationPlugin.jar`
I had a lot of trouble to get the plugin loading and working and found the following fixes   
#### Fix java.lang.NoClassDefFoundError: org.apache.xerces.xni.parser.XMLEntityResolver   
[https://www.ibm.com/support/pages/system/files/inline-files/ier_5.2.1.8-IF004_readme.pdf](https://www.ibm.com/support/pages/system/files/inline-files/ier_5.2.1.8-IF004_readme.pdf)   
When running the IER Security Script while configuring IER Desktop (Accessing Desktop for first time), you may get the following error message:   
`java.lang.NoClassDefFoundError: org.apache.xerces.xni.parser.XMLEntityResolver`   
Resolution: Follow the below steps
1. Download the ier-library.xml file from GitHub https://github.com/ibm-ecm/ier-samples.
2. Put the ier-jars.xml into ICN Container in the path (already in see configmap and icn-deployment file) /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides.
3. In the same path i.e /opt/ibm/wlp/usr/servers/defaultServer/configDropins/overrides, create a folder named "ier-jars" (auto created by the initContainer script)
4. and copy and paste the xercesImpl.jar, xml.jar and xml-apis.jar from <ier_on-prem_installation>\API\JARM to the newly created "ier-jars" folder. 
5. Restart the ICN pod and access IER Desktop.
#### Fix Not using pod -_- (Only in case of problems)
[https://www.ibm.com/support/pages/node/7097611](https://www.ibm.com/support/pages/node/7097611)   
download: https://<hostname>/EnterpriseRecordsPlugin/IERApplicationPlugin.jar   
copy downloaded plugin to the navigator plugin folder (should be in volume)   
load plugin: /opt/ibm/plugins/IERApplicationPlugin.jar   
restart icn: `oc delete pods -n filenet <icn-pod-name>`   
    
## Install Routes
Prepare you clients host file   
add to hostfile in windows (if you have another hostname use that)   
```
<vmware-ipadress>     	<rhel-hostname>   
```
nb.   
- linux/mac: /etc/hosts
- windows: C:\Windows\System32\drivers\etc\hosts

### apply routes
Create and add the certificates to the routes.yaml file
```bash
oc apply -f ~/install/routes/routes.yaml -n filenet
```

After the routes are installed you should be able to access the following links   
- https://<hostname>/navigator
- https://<hostname>/acce
- https://<hostname>/content-services-graphql
- https://<hostname>/taskManagerWeb/api/v1
- https://<hostname>/FileNet/Engine
- https://<hostname>/wsi/FNCEWS40MTOM
   
There are more link, so study the routes.yaml :P   

# IBM FileNet Installation on MicroShift

## Disclaimer
This project is not affiliated with, endorsed by, or sponsored by IBM Corporation. 
IBM, FileNet, Navigator, and related product names are trademarks or registered 
trademarks of International Business Machines Corporation.

This documentation is provided for educational and informational purposes only. 
Always consult official IBM documentation for authoritative guidance.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments
- IBM for their FileNet and Navigator products
- The MicroShift community