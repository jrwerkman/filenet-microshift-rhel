#!/bin/bash

echo "Creating GCD..."

# create domain
RESPONSE=$(curl -s -X POST \
  "http://localhost:9080/cpe/init/v1/domain" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -u "p8admin:Password1" \
  -d '{"serviceUserPassword": "Password1", "serviceUser": "p8admin", "encryptionKeyLength": "128", "domainName": "Demodom"}' \
  -k --connect-timeout 300)

# Extract HTTP status code (last 3 characters)
echo ${RESPONSE}

# Create the JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "adminUserNames": ["p8admin"],
  "groupMembershipSearchFilter": "(|(&(objectclass=groupofnames)(member={0}))(&(objectclass=groupofuniquenames)(uniquemember={0})))",
  "groupSearchFilter": "(&(cn={0})(|(objectclass=groupofnames)(objectclass=groupofuniquenames)(objectclass=groupofurls)))",
  "dirSvcUser": "cn=bindldap,ou=dev,dc=demodom,dc=nl",
  "userBaseDN": "dc=demodom,dc=nl",
  "sslEnabled": "false",
  "groupDisplayNameAttr": "cn",
  "adminsGroupNames": ["p8admins"],
  "dirSvcHostname": "ldap-svc.infra.svc.cluster.local",
  "dcType": "Tivoli",
  "directoryProviderName": "ldap",
  "userSearchFilter": "(&(uid={0})(objectclass=person))",
  "groupNameAttribute": "cn",
  "userNameAttribute": "uid",
  "dirSvcPort": "9389",
  "groupBaseDN": "dc=demodom,dc=nl",
  "userDisplayNameAttr": "uid",
  "allowEmailOrUPNShortNames": "false",
  "dirSvcPasswd": "Password1",
  "userUniqueIDAttribute": "ibm-entryUuid",
  "groupUniqueIDAttribute": "ibm-entryUuid"
}
EOF
)


echo "Creating directory configuration..."

RESPONSE=$(curl -s -X POST \
  "http://localhost:9080/cpe/init/v1/domain/directoryConfigs" \
  -u "p8admin:Password1" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "${JSON_PAYLOAD}" \
  --connect-timeout 300)

HTTP_STATUS="${RESPONSE: -3}"
RESPONSE_BODY="${RESPONSE%???}"

echo ${RESPONSE}
