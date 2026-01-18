```markdown
# Introduction

This is part 3 of the blog “Understanding Security Features in PostgreSQL”, in which I will be discussing how to apply TLS in both PostgreSQL server and client using the principles we have learned in part 2 of the blog. In the end, I will also briefly talk about Transparent Data Encryption (TDE) and security vulnerability.

Here is the overview of the security topics that will be covered in all parts of the blog:

## Part 1:

- PostgreSQL Server Listen Address
- Host-Based Authentication
- Authentication with LDAP Server
- Authentication with PAM
- Role-Based Access Control
- Assign Table and Column Level Privileges to Users
- Assign User Level Privileges as Roles
- Assign and Column Level Privileges via Roles
- Role Inheritance

## Part 2:

- Security Concepts around TLS
- Symmetrical Encryption
- Asymmetrical Encryption (a.k.a Public Key Cryptography)
- Block Cipher Mode of Operation (a.k.a Stream Cipher)
- Key Exchange Algorithm
- TLS Certificate and Chain of Trust
- Data Integrity Check / Data Authentication
- TLS Cipher Suite and TLS handshake
- TLS versions

## Part 3:

- Preparing TLS Certificates
- Enabling Transport Layer Security (TLS) to PostgreSQL Server
- Enabling Transport Layer Security (TLS) to PostgreSQL Client
- TLS Connect Examples
- Transparent Data Encryption (TDE)
- Security Vulnerability

# Preparing TLS Certificates

Before we can utilize TLS to secure both the server and the client, we must prepare a set of TLS certificates to ensure mutual trust. Normally the CA (Certificate Authority) certificates can be purchased from a trusted organization and used it to create more CA-Signed certificates for services and applications. In this section, I will show you how to create your own CA Certificate and CA-Signed certificates using OpenSSL command line tool for both PostgreSQL server and client.

You may also have heard the term self-signed certificate. This type of certificate is not signed by a trusted CA and is normally considered insecured in many applications. We will not go over the self-signed certificate generation in this blog.

## 2.1 Generate a Private Key for CA Certificate

Remember in the last blog we mention that each certificate contains organization information and public key, which is paired with a private key file. Let’s generate a private key file for our CA first.

```bash
$ openssl genrsa -des3 -out cacert.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
...............+++++
........................+++++
e is 65537 (0x010001)
Enter pass phrase for cacert.key:
Verifying - Enter pass phrase for cacert.key:
```

Your will be prompted with a pass phrase, which is recommended to provide as it will prevent someone else from generating more root CA certificate from this key.

## 2.2 Generate CA Certificate Using the Private key

Now, let’s generate the CA Certificate with the private key

```bash
$ openssl req -x509 -new -nodes -key cacert.key -sha256 -days 3650 -out cacert.pem
Enter pass phrase for cacert.key:
You are about to be asked to enter information that will be incorporated
into your certificate request.
What you are about to enter is what is called a Distinguished Name or a DN.
There are quite a few fields but you can leave some blank
For some fields there will be a default value,
If you enter '.', the field will be left blank.
-----
Country Name (2 letter code) [AU]:CA
State or Province Name (full name) [Some-State]:BC
Locality Name (eg, city) []:Vancouver
Organization Name (eg, company) [Internet Widgits Pty Ltd]:HighGo
Organizational Unit Name (eg, section) []:Software
Common Name (e.g. server FQDN or YOUR name) []:va.highgo.com
Email Address []:cary.huang@highgo.ca
```

Please note that OpenSSL will prompt you to enter several pieces of organizational information that identifies the CA certificate. You should enter these information suited to your organization. The most important field is Common Name, which is commonly checked against the hostname or domain name of the service. Depending on the security policy, some server will enforce the rule that common name must equal its host / domain name; some servers do not have this restriction.

## 2.3 Generate a private key for CA-Signed certificate

Like in the CA case, CA-signed certificate is also paired with a private key file

```bash
$ openssl genrsa -out server.key 2048
Generating RSA private key, 2048 bit long modulus (2 primes)
...................+++++
............................................................................+++++
e is 65537 (0x010001)
```

## 2.4 Generate a Certificate Signing Request for CA-Signed certificate

Then we create a Certificate Signing Request