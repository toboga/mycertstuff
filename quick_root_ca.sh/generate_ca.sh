#!/bin/bash
# Generate a root-cert and a script to generate certs signed by the new "CA"

# generate config-file
cat << EOF > crt_ca.conf
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
DNS.1 = t_root
EOF

#create private Key for root-ca
openssl genrsa -out rootCA.key 4096

# create Public-Key for root-ca
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -subj "/CN=rootCA.crt" \
-reqexts v3_req -extensions v3_ca \
-out rootCA.crt -config crt_ca.conf


cat << 'CCF' > create_cert_for.sh
#!/bin/bash
mkdir certs
# config-file erzeugen
cat << EOF > crt_cert.conf
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

openssl genrsa -out ${1}.key 2048
openssl req -new -sha256 -key ${1}.key -config crt_cert.conf -subj "/C=DE/ST=RLP/O=asdf/CN=${1}" -out ${1}.csr


openssl req -in ${1}.csr -noout -text
openssl x509 -req -in ${1}.csr -CA rootCA.crt -CAkey rootCA.key -CAcreateserial -out certs/${1}.crt -days 500 -sha256
CCF


