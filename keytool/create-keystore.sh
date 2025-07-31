#!/bin/bash
# create keystore based on the tls.key and tls.crt at the /shared/resources/keypair

set -e

BASEDIR="$HOME/keytool"
source $BASEDIR/set-env.sh

if [[ "$KEYTOOL_ACTION" == "$GENERATE_TRUSTSTORE" ]]
then
  echo "KEYTOOL_ACTION=${KEYTOOL_ACTION}, only generate trust store, skip create key store"
  exit 0;
fi


start_time=$(date +%s)

# clean the ouput folder in case it's failed retry
rm -Rf $HOME/keytool/$IMAGE_NAME/keystore/keypair $HOME/keytool/$IMAGE_NAME/keystore/jks $HOME/keytool/$IMAGE_NAME/keystore/pkcs12
mkdir -p $HOME/keytool/$IMAGE_NAME/keystore/keypair $HOME/keytool/$IMAGE_NAME/keystore/jks $HOME/keytool/$IMAGE_NAME/keystore/pkcs12

# Allow to set custom -subj parameter when create a certificate signing request (CSR) 
if [ -z "$SUBJ_OWNER" ]
    then
        subjOwner="/O=NON-PRODUCTION/CN=*"
    else
        subjOwner="$SUBJ_OWNER"
fi

if [ -f $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.key ] && [ -f $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.crt ] || [ "$CREATE_KEYPAIR" == "true" ]
then
  if [[ "$CREATE_KEYPAIR" == "true" ]]
  then
    echo "CREATE_KEYPAIR is true, generate the private key and certificate"
    if [ ! -f $HOME/keytool/ca/tls.crt ]
    then
      echo "Error: cannot find the predefined CA's certificate file: /etc/predefined-ca/tls.crt, exit with error"
      exit 1;
    fi

    if [ ! -f $HOME/keytool/ca/tls.key ]
    then
      echo "Error: cannot find the predefined CA's private key file: /etc/predefined-ca/tls.key, exit with error"
      exit 1;
    fi

    mkdir -p $HOME/keytool/$IMAGE_NAME/keystore/keypair $HOME/keytool/$IMAGE_NAME/keystore/tmp
	
    openssl genrsa -out $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.key 2048
    openssl pkcs8 -inform PEM -outform PEM -in $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.key -topk8 -nocrypt -v1 PBE-SHA1-3DES -out $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls-pkcs8.key
    openssl req -new -sha256 -key $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.key -subj "/C=NL/ST=Demodom/L=Demodom/O=Novadoc/OU=Development/CN=$IMAGE_NAME" \
            -out $HOME/keytool/$IMAGE_NAME/keystore/tmp/server.csr

    if [ -z "$SUBJECT_ALT_NAMES" ]
    then
      openssl x509 -req -in $HOME/keytool/$IMAGE_NAME/keystore/tmp/server.csr -CA $HOME/keytool/ca/tls.crt -CAkey $HOME/keytool/ca/tls.key \
              -CAcreateserial -out $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.crt -days 10000 -sha256 -CAserial $HOME/keytool/$IMAGE_NAME/keystore/tmp/server.srl
    else
      subjectAltName=""
      IFS=',' read -ra name_list <<< "$SUBJECT_ALT_NAMES"
      for SUBJECT_ALT_NAME in "${name_list[@]}"; do
        #trim the string
        SUBJECT_ALT_NAME=`echo $SUBJECT_ALT_NAME | xargs`
        if validIP $SUBJECT_ALT_NAME; then
          # the input subject alternative name is a ip ipaddress
          subjectAltName="$subjectAltName,IP:$SUBJECT_ALT_NAME"
        else
          # the input subject alternative name is a domain name
          subjectAltName="$subjectAltName,DNS:$SUBJECT_ALT_NAME"
        fi
      done
      subjectAltName="${subjectAltName:1}"
      openssl x509 -req -extfile <(printf "subjectAltName=$subjectAltName") -in $HOME/keytool/$IMAGE_NAME/keystore/tmp/server.csr -CA $HOME/keytool/ca/tls.crt -CAkey $HOME/keytool/ca/tls.key \
              -CAcreateserial -out $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.crt -days 10000 -sha256 -CAserial $HOME/keytool/$IMAGE_NAME/keystore/tmp/server.srl
			  
	  mkdir -p $HOME/keytool/trust
	  cp $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.crt $HOME/keytool/trust/$IMAGE_NAME-tls.crt
    fi

  else
    echo "Copy the keypair"
    cp /shared/resources/keypair/tls.key /shared/tls/keystore/keypair
    cp /shared/resources/keypair/tls.crt /shared/tls/keystore/keypair
  fi

  keypair_gen_end=$(date +%s)

  if [[ "$STORE_TYPES" =~ JKS|P12 ]] ; then
    echo "Generate PKCS12 key store"
    if [[ "$FIPS_ENABLED" != "true" ]] ; then
      openssl pkcs12 -export -out $HOME/keytool/$IMAGE_NAME/keystore/pkcs12/server.p12 -in $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.crt \
              -inkey $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.key -certfile $HOME/keytool/ca/tls.crt -passout pass:$KEYSTORE_PASSWORD
    else
      openssl pkcs12 -export -out $HOME/keytool/$IMAGE_NAME/keystore/pkcs12/server.p12 -in $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.crt \
              -inkey $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.key -passout pass:$KEYSTORE_PASSWORD -certpbe AES-256-CBC \
              -keypbe AES-256-CBC -macalg sha256
    fi

    p12_gen_end=$(date +%s)
    if [[ "$FIPS_ENABLED" != "true" ]] ; then
      if [[ "$STORE_TYPES" =~ JKS ]] ; then
        echo "Generate the Java Key Store file"
        java -version;
        keytool -importkeystore -srckeystore $HOME/keytool/$IMAGE_NAME/keystore/pkcs12/server.p12 \
                -destkeystore $HOME/keytool/$IMAGE_NAME/keystore/jks/server.jks -srcstoretype pkcs12 \
                -srcstorepass $KEYSTORE_PASSWORD  -deststorepass $KEYSTORE_PASSWORD -noprompt
      fi
    fi
    jks_gen_end=$(date +%s)
  else
    p12_gen_end=$(date +%s)
    jks_gen_end=$p12_gen_end
  fi
  echo "create key stores successful"
else
  if [ -z "$KEYTOOL_ACTION" ]
  then
    echo "Did not find the expected file(tls.key or tls.crt) at folder /shared/resources/keypair, skip create key store"
    exit 0;
  else
    if [[ "$KEYTOOL_ACTION" == "$GENERATE_KEYSTORE" ]] || [[ "$KEYTOOL_ACTION" == "$GENERATE_BOTH" ]]
    then
      echo "Error: KEYTOOL_ACTION=${KEYTOOL_ACTION}, but did not find the expected file(tls.key or tls.crt) at folder /shared/resources/keypair, exit with error"
      exit 1;
    fi
  fi
fi

# check the output
if [[ ! ( -f $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.key && -f $HOME/keytool/$IMAGE_NAME/keystore/keypair/tls.crt ) \
   && ! -f $HOME/keytool/$IMAGE_NAME/keystore/pkcs12/server.p12  && ! -f $HOME/keytool/$IMAGE_NAME/keystore/jks/server.jks ]]
then
  echo "Error: KEYTOOL_ACTION=${KEYTOOL_ACTION}, but did not create key stores correctly, exit with error"
  exit 1
fi

end_time=$(date +%s)

keygen_dur=$(( $keypair_gen_end - $start_time ))
p12gen_dur=$(( $p12_gen_end - $keypair_gen_end ))
jksgen_dur=$(( $jks_gen_end - $p12_gen_end ))
total_dur=$(( $end_time - $start_time ))

printf "\nKeystore generation timing:\n"
printf "TIMING: keypair generation: %ss\n" $keygen_dur
printf "TIMING: p12 generation    : %ss\n" $p12gen_dur
printf "TIMING: jks generation    : %ss\n" $jksgen_dur
printf "TIMING: total             : %ss\n\n" $total_dur
