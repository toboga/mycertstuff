#!/bin/bash
# Generate a root-cert and a script to generate certs signed by the new "CA"

########################
# root-ca
########################
mkdir ROOTCA
mkdir TEMPLATES
mkdir INSTALL 
echo "____________"
echo "we are creating a quick and dirty ROOT-CA from wich we can create certs with a script"
echo "____________"
echo ""
echo "Enter the name of the root-CA"
read -p 'ROOT-CA Subject: ' ROOT_CA_SUBJECT 
echo "_____________"
echo "now enter the country (Parameter 'C') and the state (parameter 'ST') and the organisation (parameter 'O') for the template of the generated server-certs" 
read -p 'Server certificate Country: ' SERVERCERT_C
echo SC_C=${SERVERCERT_C} > TEMPLATES/server.tmpl
read -p 'server certificate State: ' SERVERCERT_ST
echo SC_ST=${SERVERCERT_ST} >> TEMPLATES/server.tmpl
read -p 'server certificate Organisation: ' SERVERCERT_O
echo SC_O=${SERVERCERT_O} >> TEMPLATES/server.tmpl
read -e -p 'root-CA key length: ' -i 4096 ROOTKEY_LENGTH 
read -e -p 'Server-key length: ' -i 2048 SERVERKEY_LENGTH 
echo SERVERKEY_LENGTH=${SERVERKEY_LENGTH} >> TEMPLATES/server.tmpl

# generate a config-file for the root-certificate
# using bash heredoc
cat << EOF > ROOTCA/crt_ca.conf
[ v3_ca ]
basicConstraints = critical,CA:TRUE
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${ROOTCA_SUBJECT}
EOF

#create private Key for root-ca
openssl genrsa -out ROOTCA/rootCA.key ${ROOTKEY_LENGTH} 

# create Public-Key for root-ca
openssl req -x509 -new -nodes -key ROOTCA/rootCA.key -sha256 -days 1024 -subj "/CN=${ROOT_CA_SUBJECT}" \
-reqexts v3_req -extensions v3_ca \
-out ROOTCA/rootCA.crt -config ROOTCA/crt_ca.conf

########################
# script to sign the certificates
########################
cat << 'CCF' > create_cert_for.sh
#!/bin/bash
# script to generate a signed certificate from our root-ca
STAMP=$(date "+%Y-%M-%d_%H-%m-%S")
#we create a folder containing name and timestamp
STAMPPATH="certs/${1}__${STAMP}"
mkdir -p ${STAMPPATH} 
# create a config-file for our Certificates 

#get env_vars
source TEMPLATES/server.tmpl

cat << EOF > ${STAMPPATH}/crt_cert.conf
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
extendedKeyUsage=serverAuth
subjectAltName=DNS:${1}

[alt_names]
DNS.1 = ${1}
EOF

# generate a private key for the certificate-pair
openssl genrsa -out ${STAMPPATH}/${1}.key ${SERVERKEY_LENGTH}
# create a certificate request
openssl req -new -sha256 -key ${STAMPPATH}/${1}.key -config ${STAMPPATH}/crt_cert.conf -subj "/C=${SC_C}/ST=${SC_ST}/O=${SC_O}/CN=${1}" -out ${STAMPPATH}/${1}.csr

# (optional) - show the content of the certificate-request
openssl req -in ${STAMPPATH}/${1}.csr -noout -text
# sign the certifiate
openssl x509 -req -in ${STAMPPATH}/${1}.csr -CA ROOTCA/rootCA.crt -CAkey ROOTCA/rootCA.key -CAcreateserial -out ${STAMPPATH}/${1}.crt -days 500 -sha256
CCF

mv $0 INSTALL/ 
