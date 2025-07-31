#!/bin/bash

DEFAULT_PASSWORD="Password1"

if [ -z "${KEYSTORE_PASSWORD:-}" ]
then
  KEYSTORE_PASSWORD=$(cat /credentials/KEYSTORE_PASSWORD || true)
fi

if [ -z "${KEYSTORE_PASSWORD:-}" ]
then
  echo "Using default keystore password"
  KEYSTORE_PASSWORD=$DEFAULT_PASSWORD
fi

if [ -z "${FIPS_ENABLED:-}" ]
then
  echo "FIPS DISABLE MODE"
  FIPS_ENABLED="false"
fi

GENERATE_TRUSTSTORE="GENERATE-TRUSTSTORE"
GENERATE_KEYSTORE="GENERATE-KEYSTORE"
GENERATE_BOTH="GENERATE-BOTH"

if [[ "$FIPS_ENABLED" == "true" ]]
then
  # By default, generate keystores in PEM and P12 in FIPS MODE
  : "${STORE_TYPES:=PEM:P12}"
else
  # By default, generate keystores in all three supported formats
  : "${STORE_TYPES:=PEM:JKS:P12}"
fi

echo "STORE_TYPES: $STORE_TYPES"

# By default, generate the truststore in same format as keystore
if [[ -z "${TRUSTSTORE_TYPES:-}" ]] ; then
  TRUSTSTORE_TYPES=$STORE_TYPES
fi

# return 0 means the input file is PEM format
# return 1 means the input file is not PEM format
function checkPEMFormat {
  local file_name=$1
  # do not want to exit immediately
  set +e
  if grep -Fq -- '-----BEGIN CERTIFICATE-----' $file_name
  then
    # find the expected comments, further check health
    openssl x509 -in $file_name -text -noout > /dev/null
    if [[ $? == 0 ]]
    then
      return 0
    else
      return 1
    fi
  else
    echo "Can not find '-----BEGIN CERTIFICATE-----' at file $file_name"
    return 1
  fi
}

# return 0 means the input string is ip address
# return 1 means the input string is not ip address
function validIP()
{
    local  ipaddress=$1
    local  result=1

    local ipv4regex='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
    local ipv6regex='^([0-9a-fA-F]{0,4}:){1,7}[0-9a-fA-F]{0,4}$'

    if [[ $ipaddress =~ $ipv6regex ]]; then
      result=0

    elif [[ $ipaddress =~ $ipv4regex ]]; then
        OIFS=$IFS
        IFS='.'
        ipaddress=($ipaddress)
        IFS=$OIFS
        if [[ ${ipaddress[0]} -le 255 && ${ipaddress[1]} -le 255 && ${ipaddress[2]} -le 255 && ${ipaddress[3]} -le 255 ]]
        then
          result=0
        else
          result=1
        fi
    fi
    return $result
}


