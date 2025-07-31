#!/bin/bash
# create trust store base on all certificates can be found at
# the root folders /shared/resource/cert-trusted
set -e

BASEDIR="$HOME/keytool"
source $BASEDIR/set-env.sh

if [[ "$KEYTOOL_ACTION" == "$GENERATE_KEYSTORE" ]]
then
  echo "KEYTOOL_ACTION=${KEYTOOL_ACTION}, only generate key store, skip create trust store"
  exit 0;
fi

echo "Get the *.crt at folder $HOME/keytool/trust"
mapfile -t cert_list < <(find $HOME/keytool/trust -not -path '*/\.*' -iname "*.crt")

if [[ "$CREATE_KEYPAIR" == "true" ]]
then
  echo "CREATE_KEYPAIR is true, use the predefined CA"
  if [ -f $HOME/keytool/ca/tls.crt ]
  then
    cert_list+=("$HOME/keytool/ca/tls.crt")
  else
    echo "Error: Cannot find the predefined CA's certificate: $HOME/keytool/ca/tls.crt, exit with error"
    exit 1;
  fi
fi

printf "%s\n" "${cert_list[@]}"

# clean the ouput folder in case it's failed retry
rm -Rf $HOME/keytool/$IMAGE_NAME/truststore/jks $HOME/keytool/$IMAGE_NAME/truststore/pem $HOME/keytool/$IMAGE_NAME/truststore/pkcs12
mkdir -p $HOME/keytool/$IMAGE_NAME/truststore/jks $HOME/keytool/$IMAGE_NAME/truststore/pem $HOME/keytool/$IMAGE_NAME/truststore/pkcs12

start_time=$(date +%s)

if [ -z "${cert_list[0]}" ]
then
  if [ -z "$KEYTOOL_ACTION" ]
  then
    echo "Did not find certificate at $HOME/keytool/shared, skip create trust stores"
    exit 0;
  else
    if [[ "$KEYTOOL_ACTION" == "$GENERATE_TRUSTSTORE" ]] || [[ "$KEYTOOL_ACTION" == "$GENERATE_BOTH" ]]
    then
      echo "Error: KEYTOOL_ACTION=${KEYTOOL_ACTION}, but did not find certificate at $HOME/keytool/trust, exit with error"
      exit 1;
    fi
  fi
else
  echo "start creating the PEM store"

  for cert_file in "${cert_list[@]}"
  do
    echo "process certificate file: ${cert_file}"
    checkPEMFormat ${cert_file}
    checkPEM_result=$?
    if [[ $checkPEM_result != 0 ]]
    then
      echo "Error: $cert_file is not PEM format, exit with error"
      exit 1
    fi
    cat ${cert_file} >> $HOME/keytool/$IMAGE_NAME/truststore/pem/trusts.pem
    # add a linebreak blindly, it's fine if have double linebreak
    echo "" >> $HOME/keytool/$IMAGE_NAME/truststore/pem/trusts.pem
  done
  pem_store_end=$(date +%s)

  if [[ "$TRUSTSTORE_TYPES" =~ JKS|P12 ]] ; then
    # split the PEM file
    rm -Rf $HOME/keytool/$IMAGE_NAME/truststore/tmp/trusts
    mkdir -p $HOME/keytool/$IMAGE_NAME/truststore/tmp/trusts/
    csplit -zf $HOME/keytool/$IMAGE_NAME/truststore/tmp/trusts/trust-alias $HOME/keytool/$IMAGE_NAME/truststore/pem/trusts.pem '/-----BEGIN CERTIFICATE-----/' '{*}'
    # create java key store
    echo "start creating the java key store"
    mapfile -t trust_list < <(find $HOME/keytool/$IMAGE_NAME/truststore/tmp/trusts -not -path '*/\.*' -iname "trust-alias*")
    for trust_file in "${trust_list[@]}"
    do
      echo "process trusted certificate file: ${trust_file}"
      if [[ "$FIPS_ENABLED" != "true" ]]
      then
        keytool -import -v -trustcacerts -alias ${trust_file} -file ${trust_file} \
          -keystore $HOME/keytool/$IMAGE_NAME/truststore/jks/trusts.jks -storetype jks -keypass $KEYSTORE_PASSWORD -storepass $KEYSTORE_PASSWORD -noprompt
      else
        keytool -import -v -trustcacerts -alias ${trust_file} -file ${trust_file} \
          -keystore $HOME/keytool/$IMAGE_NAME/truststore/pkcs12/trusts.p12 -storetype PKCS12 -keypass $KEYSTORE_PASSWORD -storepass $KEYSTORE_PASSWORD -noprompt
      fi
    done
    rm -Rf $HOME/keytool/$IMAGE_NAME/truststore/tmp/trusts
    jks_store_end=$(date +%s)

    if [[ "$TRUSTSTORE_TYPES" =~ P12 && "$FIPS_ENABLED" != "true" ]] ; then
      # create pkcs12 from jks store
      echo "start creating pkcs12"
      keytool -importkeystore -srckeystore $HOME/keytool/$IMAGE_NAME/truststore/jks/trusts.jks \
        -destkeystore $HOME/keytool/$IMAGE_NAME/truststore/pkcs12/trusts.p12 -deststoretype PKCS12 -deststorepass $KEYSTORE_PASSWORD \
        -srcstorepass $KEYSTORE_PASSWORD -noprompt
    fi
    p12_store_end=$(date +%s)
  else
    jks_store_end=$(date +%s)
    p12_store_end=$jks_store_end
  fi
  echo "create trust stores successful"
fi

# If custom trust store is specified, we need to import the certificates from it to the trust store.
# In FIPS mode. We don't support external sourced trust store
if [[ -z "$CUSTOM_TRUSTSTORE_FILE" || "$FIPS_ENABLED" == "true" ]]
then
  echo "In FIPS mode $FIPS_ENABLED. No custom truststore configure is found, skip the import."
else
  # The truststore file must exist
  if [[ ! -f /shared/resources/cert-trusted/$CUSTOM_TRUSTSTORE_FILE ]]
  then
    echo "The custom truststore file is not found under /shared/resources/cert-trusted, pease make sure it exists."
    exit 1
  fi

  # The keystore type and keystore password are required.
  if [[ -z "$CUSTOM_TRUSTSTORE_TYPE" ]]
  then
    CUSTOM_TRUSTSTORE_TYPE=$(cat /credentials/CUSTOM_TRUSTSTORE_TYPE || true)
  fi
  if [[ -z "$CUSTOM_TRUSTSTORE_TYPE" ]]
  then
    echo "The required environment variable CUSTOM_TRUSTSTORE_TYPE is not specified, you should specify the keystore type (JKS or PKCS12) and the keystore password."
    exit 1
  fi
  if [[ -z "$CUSTOM_TRUSTSTORE_PASSWORD" ]]
  then
    echo "The required environment variables CUSTOM_TRUSTSTORE_PASSWORD is not specified, you should specify the keystore password and the keystore type (JKS or PKCS12)."
    exit 1
  fi
  # The keystore type should be  JKS or PKCS12.
  if [[ "$CUSTOM_TRUSTSTORE_TYPE" != "JKS" ]] && [[ "$CUSTOM_TRUSTSTORE_TYPE" != "PKCS12" ]]
  then
    echo "The keystore type [$CUSTOM_TRUSTSTORE_TYPE] is not supported, the valid value is JKS or PKCS12."
    exit 1
  fi

  if [[ -f $HOME/keytool/$IMAGE_NAME/truststore/jks/trusts.jks ]]
  then
    echo "Import the trust certificates in ${CUSTOM_TRUSTSTORE_FILE} to trusts.jks"
    keytool -importkeystore -srckeystore /shared/resources/cert-trusted/$CUSTOM_TRUSTSTORE_FILE \
      -srcstoretype $CUSTOM_TRUSTSTORE_TYPE -srcstorepass $CUSTOM_TRUSTSTORE_PASSWORD \
      -destkeystore $HOME/keytool/$IMAGE_NAME/truststore/jks/trusts.jks -deststoretype JKS \
      -deststorepass $KEYSTORE_PASSWORD -noprompt
  else
    echo "$HOME/keytool/$IMAGE_NAME/truststore/jks/trusts.jks is not found, skip the import."
  fi

  if [[ -f $HOME/keytool/$IMAGE_NAME/truststore/pkcs12/trusts.p12 ]]
  then
    echo "Import the trust certificates in ${CUSTOM_TRUSTSTORE_FILE} to trusts.p12"
    keytool -importkeystore -srckeystore /shared/resources/cert-trusted/$CUSTOM_TRUSTSTORE_FILE \
      -srcstoretype $CUSTOM_TRUSTSTORE_TYPE -srcstorepass $CUSTOM_TRUSTSTORE_PASSWORD \
      -destkeystore $HOME/keytool/$IMAGE_NAME/truststore/pkcs12/trusts.p12 -deststoretype PKCS12 \
      -deststorepass $KEYSTORE_PASSWORD -noprompt
  else
    echo "$HOME/keytool/$IMAGE_NAME/truststore/pkcs12/trusts.p12 is not found, skip the import."
  fi
fi
custom_store_end=$(date +%s)

# check the output
if [ ! -f $HOME/keytool/$IMAGE_NAME/truststore/pem/trusts.pem ] && [ ! -f $HOME/keytool/$IMAGE_NAME/truststore/jks/trusts.jks ] \
   && [ ! -f $HOME/keytool/$IMAGE_NAME/truststore/pkcs12/trusts.p12 ]
then
  echo "Error: KEYTOOL_ACTION=${KEYTOOL_ACTION}, but did not create trust stores correctly, exit with error"
  exit 1
fi

end_time=$(date +%s)

pemstore_dur=$(( $pem_store_end - $start_time ))
jksstore_dur=$(( $jks_store_end - $pem_store_end ))
p12store_dur=$(( $p12_store_end - $jks_store_end ))
custom_store_dur=$(( $custom_store_end - $p12_store_end ))
total_dur=$(( $end_time - $start_time ))

printf "\nTruststore generation timing:\n"
printf "TIMING: pem store generation       : %ss\n" $pemstore_dur
printf "TIMING: jks store generation       : %ss\n" $jksstore_dur
printf "TIMING: p12 store generation       : %ss\n" $p12store_dur
printf "TIMING: custom store processing    : %ss\n" $custom_store_dur

printf "TIMING: total             : %ss\n\n" $total_dur
