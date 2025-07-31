# Using keytool
Note sh files are reused from the filenet container   
Copy keytool folder to the home folder of yout rhel vmware (ie. /home/admin)   
Install openjdk on vmware for keytool
```bash
sudo dnf install java-21-openjdk java-21-openjdk-devel
```
## create a root ca
```bash
sudo chmod +x ~/keytool/create-ca.sh
~/keytool/create-ca.sh
```
## create keystores
Set evn variables using in bash scripts   
```bash
export CREATE_KEYPAIR="true"
export KEYTOOL_ACTION="GENERATE-BOTH"
```
## create keystores
nb replace <hostname> with your actual hostname

```bash
# FILENET KEYSTORE
export IMAGE_NAME="Filenet"
export SUBJECT_ALT_NAMES="rhel-microshift,<hostname>,cpe-svc,cpe-svc.filenet.svc,cpe-svc.filenet.svc.cluster.local,localhost,127.0.0.1,::1" 
~/keytool/create-keystore.sh

# GRAPHQL KEYSTORE
export IMAGE_NAME="GraphQL"
export SUBJECT_ALT_NAMES="rhel-microshift,<hostname>,graphql-svc,graphql-svc.filenet.svc,graphql-svc.filenet.svc.cluster.local,localhost,127.0.0.1,::1" 
~/keytool/create-keystore.sh

# ICN KEYSTORE
export IMAGE_NAME="ContentNavigator"
export SUBJECT_ALT_NAMES="rhel-microshift,<hostname>,icn-svc,icn-svc.filenet.svc,icn-svc.filenet.svc.cluster.local,localhost,127.0.0.1,::1" 
~/keytool/create-keystore.sh

# IER KEYSTORE
export IMAGE_NAME="EnterpriseRecords"
export SUBJECT_ALT_NAMES="rhel-microshift,<hostname>,ier-svc,ier-svc.filenet.svc,ier-svc.filenet.svc.cluster.local,localhost,127.0.0.1,::1" 
~/keytool/create-keystore.sh

# TASKMANAGER KEYSTORE
export IMAGE_NAME="TaskManager"
export SUBJECT_ALT_NAMES="rhel-microshift,<hostname>,tm-svc,tm-svc.filenet.svc,tm-svc.filenet.svc.cluster.local,localhost,127.0.0.1,::1" 
~/keytool/create-keystore.sh

# CSS KEYSTORE
export IMAGE_NAME="CSS"
export SUBJECT_ALT_NAMES="rhel-microshift,<hostname>,css-svc,css-svc.filenet.svc,css-svc.filenet.svc.cluster.local,localhost,127.0.0.1,::1" 
~/keytool/create-keystore.sh
```
## create truststores
```bash
# FILENET TRUSTSTORE
export IMAGE_NAME="Filenet"
~/keytool/create-truststore.sh

# GRAPHQL TRUSTSTORE
export IMAGE_NAME="GraphQL"
~/keytool/create-truststore.sh

# ICN TRUSTSTORE
export IMAGE_NAME="ContentNavigator"
~/keytool/create-truststore.sh

# IER TRUSTSTORE
export IMAGE_NAME="EnterpriseRecords"
~/keytool/create-truststore.sh

# TASKMANAGER TRUSTSTORE
export IMAGE_NAME="TaskManager"
~/keytool/create-truststore.sh

# CSS TRUSTSTORE
export IMAGE_NAME="CSS"
~/keytool/create-truststore.sh
```
## create binary for configmap
With the binary data you can create the configmap > see example-ssl-configmap.yaml
```bash
base64 -w 0 ~/keytool/Filenet/keystore/pkcs12/server.p12 > cpe-keystore.txt
base64 -w 0 ~/keytool/Filenet/truststore/pkcs12/trusts.p12 > cpe-truststore.txt
base64 -w 0 ~/keytool/GraphQL/keystore/pkcs12/server.p12 > graphql-keystore.txt
base64 -w 0 ~/keytool/GraphQL/truststore/pkcs12/trusts.p12 > graphql-truststore.txt
base64 -w 0 ~/keytool/ContentNavigator/keystore/pkcs12/server.p12 > icn-keystore.txt
base64 -w 0 ~/keytool/ContentNavigator/truststore/pkcs12/trusts.p12 > icn-truststore.txt
base64 -w 0 ~/keytool/EnterpriseRecords/keystore/pkcs12/server.p12 > ier-keystore.txt
base64 -w 0 ~/keytool/EnterpriseRecords/truststore/pkcs12/trusts.p12 > ier-truststore.txt
base64 -w 0 ~/keytool/TaskManager/keystore/pkcs12/server.p12 > tm-keystore.txt
base64 -w 0 ~/keytool/TaskManager/truststore/pkcs12/trusts.p12 > tm-truststore.txt
base64 -w 0 ~/keytool/CSS/keystore/pkcs12/server.p12 > css-keystore.txt
base64 -w 0 ~/keytool/CSS/truststore/pkcs12/trusts.p12 > css-truststore.txt
```
fill binary files in ssl-configmap (see install/ssl-configmap.yaml)    
## create certs for route  
```bash
export CREATE_KEYPAIR="true"
export KEYTOOL_ACTION="GENERATE-BOTH"
export IMAGE_NAME="Route"
export SUBJECT_ALT_NAMES="rhel-microshift,<hostname>,localhost,127.0.0.1,::1" 
~/keytool/create-keystore.sh
~/keytool/create-truststore.sh
```
use key and crt for route (key and certificate)   
and use root ca for caCertificate and destinationCACertificate   
see install/routes/routes.yaml for an example   