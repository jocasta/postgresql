##!/bin/bash

## This is not the first time I’ve struggled getting SSL certificate validation to work,
## so I thought this time I better write down how I did to avoid future time-waste.

## For security and convenience reasons, I want to do the signing of client certificates
## on a separate dedicated machine, also known as certificate authority (CA).

## This allows us to grant new clients access without having to login to the PostgreSQL
## server signing certs or modifying pg_hba.conf.

## We will create a special database group called sslcertusers.
## All users in this group will be able to connect provided they have a
## client certificate signed by the CA.

#######################################################################################

## (1) Setup CA

## The CA should be an offline computer locked in a safe.

## Generate CA private key
sudo openssl genrsa -des3 -out /etc/ssl/private/trustly-ca.key 2048
sudo chown root:ssl-cert /etc/ssl/private/trustly-ca.key
sudo chmod 640 /etc/ssl/private/trustly-ca.key

## Generate CA public certificate
sudo openssl req -new -x509 -days 3650 \
-subj '/C=SE/ST=Stockholm/L=Stockholm/O=Trustly/CN=trustly' \
-key /etc/ssl/private/trustly-ca.key \
-out /usr/local/share/ca-certificates/trustly-ca.crt
sudo update-ca-certificates

#######################################################################################

## (2) Configure PostgreSQL-server

## Generate PostgreSQL-server private key

# Enter a passphrase
sudo -u postgres openssl genrsa -des3 -out /var/lib/postgresql/9.1/main/server.key 2048
# Remove the passphrase
sudo -u postgres openssl rsa -in /var/lib/postgresql/9.1/main/server.key -out /var/lib/postgresql/9.1/main/server.key
sudo -u postgres chmod 400 /var/lib/postgresql/9.1/main/server.key

## Request CA to sign PostgreSQL-server key
sudo -u postgres openssl req -new -nodes -key /var/lib/postgresql/9.1/main/server.key -days 3650 -out /tmp/server.csr -subj '/C=SE/ST=Stockholm/L=Stockholm/O=Trustly/CN=postgres'

## Sign PostgreSQL-server key with CA private key
sudo openssl x509 -days 3650 \
-req -in /tmp/server.csr \
-CA /usr/local/share/ca-certificates/trustly-ca.crt \
-CAkey /etc/ssl/private/trustly-ca.key -CAcreateserial \
-out /var/lib/postgresql/9.1/main/server.crt
sudo chown postgres:postgres /var/lib/postgresql/9.1/main/server.crt

## Create root cert = PostgreSQL-server cert + CA cert
sudo -u postgres sh -c 'cat /var/lib/postgresql/9.1/main/server.crt /etc/ssl/certs/trustly-ca.pem &gt; /var/lib/postgresql/9.1/main/root.crt'
sudo cp /var/lib/postgresql/9.1/main/root.crt /usr/local/share/ca-certificates/trustly-postgresql.crt
sudo update-ca-certificates

## Grant access
CREATE GROUP sslcertusers;
ALTER GROUP sslcertusers ADD USER joel;

## /etc/postgresql/9.1/main/pg_hba.conf:
hostssl nameofdatabase +sslcertusers 192.168.1.0/24 cert clientcert=1

## Restart PostgreSQL
sudo service postgresql restart

#######################################################################################

## (3) PostgreSQL-client(s)

## Copy root cert from PostgreSQL-server
mkdir ~/.postgresql
cp /etc/ssl/certs/trustly-postgresql.pem ~/.postgresql/root.crt

## Generate PostgreSQL-client private key
openssl genrsa -des3 -out ~/.postgresql/postgresql.key 1024
 
### If this is a server, remove the passphrase:
openssl rsa -in ~/.postgresql/postgresql.key -out ~/.postgresql/postgresql.key

## Request CA to sign PostgreSQL-client key
# Replace "joel" with username:
openssl req -new -key ~/.postgresql/postgresql.key -out ~/.postgresql/postgresql.csr -subj '/C=SE/ST=Stockholm/L=Stockholm/O=Trustly/CN=joel'
sudo openssl x509 -days 3650 -req -in ~/.postgresql/postgresql.csr -CA /etc/ssl/certs/trustly-ca.pem -CAkey /etc/ssl/private/trustly-ca.key -out ~/.postgresql/postgresql.crt -CAcreateserial
sudo chown joel:joel -R ~/.postgresql
sudo chmod 400 -R ~/.postgresql/postgresql.key

#######################################################################################


## Files

## The following files are created/modififed on each machine:

## CA ##########################
/etc/ssl/private/trustly-ca.key
/usr/local/share/ca-certificates/trustly-ca.crt
/etc/ssl/certs/trustly-ca.pem -&gt; /usr/local/share/ca-certificates/trustly-ca.crt

## PostgreSQL-server ##########
/var/lib/postgresql/9.1/main/server.key
/var/lib/postgresql/9.1/main/server.crt
/var/lib/postgresql/9.1/main/root.crt
/usr/local/share/ca-certificates/trustly-ca.crt
/usr/local/share/ca-certificates/trustly-postgresql.crt
/etc/ssl/certs/trustly-ca.pem -&gt; /usr/local/share/ca-certificates/trustly-ca.crt
/etc/ssl/certs/trustly-postgresql.pem -&gt; /usr/local/share/ca-certificates/trustly-postgresql.crt
/etc/postgresql/9.1/main/pg_hba.conf

## PostgreSQL-client ##########
~/.postgresql/root.crt
~/.postgresql/postgresql.key
~/.postgresql/postgresql.crt
