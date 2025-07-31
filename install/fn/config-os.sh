#!/bin/bash

DS="FNOSDS"
DSXA="FNOSDSXA"
DBC_NAME="OSDB"
OS_NAME="Objectstore"
OS_SYMBOLIC_NAME="OS"
INDEX_LOC="fn_os_dbindexts"
WORKFLOW_NAME="os"

###################################################################
###################################################################
###################################################################

echo "Creating Database Connection"

JSON_PAYLOAD=$(cat <<EOF
{
  "jndiDataSource": "${DS}",
  "jndiXaDataSource": "${DSXA}",
  "siteName": "InitialSite",
  "databaseConnectionName": "${DBC_NAME}"
}
EOF
)

RESPONSE=$(curl -s -X POST \
  "http://localhost:9080/cpe/init/v1/databaseconnections" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "p8admin:Password1" \
  -d "${JSON_PAYLOAD}" \
  -k --connect-timeout 300)

echo ${RESPONSE}

###################################################################
###################################################################
###################################################################

echo "Creating ObjectStore"

JSON_PAYLOAD=$(cat <<EOF
{
  "databaseConnectionName": "${DBC_NAME}",
  "objectStoreDisplayName": "${OS_NAME}",
  "objectStoreSymbolicName": "${OS_SYMBOLIC_NAME}",
  "databaseIndexStorageLocation": "${INDEX_LOC}",
  "adminUserGroups": ["p8admins", "p8admin"],
  "basicUserGroups": ["p8users"]
}
EOF
)

RESPONSE=$(curl -s -X POST \
  "http://localhost:9080/cpe/init/v1/objectstores" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "p8admin:Password1" \
  -d "${JSON_PAYLOAD}" \
  -k --connect-timeout 300)

echo ${RESPONSE}

###################################################################
###################################################################
###################################################################

echo "Creating Advance Storage Area"

JSON_PAYLOAD=$(cat <<EOF
{
  "storageAreaName": "${OS_NAME}_asa", 
  "fileSystemStorageDevices": [
    {
	  "fileSystemStorageDeviceName": "${OS_NAME}_file_system_storage", 
	  "rootDirectoryPath": "/opt/ibm/asa/${OS_NAME}_storagearea"
	}
  ]
}
EOF
)

RESPONSE=$(curl -s -X POST \
  "http://localhost:9080/cpe/init/v1/objectstores/${OS_SYMBOLIC_NAME}/advancedstorageareas/" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "p8admin:Password1" \
  -d "${JSON_PAYLOAD}" \
  -k --connect-timeout 300)

echo ${RESPONSE}

###################################################################
###################################################################
###################################################################

echo "Install Addons ..."

ADDONS=("{CE460ADD-0000-0000-0000-000000000004}" "{CE460ADD-0000-0000-0000-000000000001}" "{CE460ADD-0000-0000-0000-000000000003}" "{CE511ADD-0000-0000-0000-000000000006}" "{CE460ADD-0000-0000-0000-000000000008}" "{CE460ADD-0000-0000-0000-000000000007}" "{CE460ADD-0000-0000-0000-000000000009}" "{CE460ADD-0000-0000-0000-00000000000A}" "{CE460ADD-0000-0000-0000-00000000000B}" "{CE460ADD-0000-0000-0000-00000000000D}" "{CE511ADD-0000-0000-0000-00000000000F}")

for ADDON in "${ADDONS[@]}"; do

JSON_PAYLOAD=$(cat <<EOF
{
  "addonId": "${ADDON}"
}
EOF
)

RESPONSE=$(curl -s -X PUT \
  "http://localhost:9080/cpe/init/v1/objectstores/${OS_SYMBOLIC_NAME}/addons/" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "p8admin:Password1" \
  -d "${JSON_PAYLOAD}" \
  -k --connect-timeout 300)

echo ${RESPONSE}

done

###################################################################
###################################################################
###################################################################

echo "Configure Workflow ..."

JSON_PAYLOAD=$(cat <<EOF
{
  "adminGroup": "p8admins",
  "configGroup": "p8admins",
  "indexTableSpace": "fn_${WORKFLOW_NAME}_dbindexts",
  "dataTableSpace": "fn_${WORKFLOW_NAME}_db_tbs",
  "connectionPointName": "${WORKFLOW_NAME}-cp",
  "regionName": "${WORKFLOW_NAME}-region",
  "regionNumber": "1",
  "dateTimeMask": "mm/dd/yy hh:tt am",
  "locale": "en"
}
EOF
)

RESPONSE=$(curl -s -X POST \
  "http://localhost:9080/cpe/init/v1/objectstores/${OS_SYMBOLIC_NAME}/workflow/" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "p8admin:Password1" \
  -d "${JSON_PAYLOAD}" \
  -k --connect-timeout 300)

echo ${RESPONSE}
