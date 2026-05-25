# Test Server SSL

 Test the SSL/TLS configuration of the server. Here's a step-by-step guide to help you through this:

### 1. Check PostgreSQL SSL Configuration

First, ensure that your PostgreSQL server is configured to use SSL. You can check this by looking at the `postgresql.conf` file, usually located in the data directory of your PostgreSQL installation. Look for the line:

```conf
ssl = on
```

If SSL is enabled, you'll also want to check the `ssl_ciphers` setting in the same configuration file to see which ciphers are allowed. This setting specifies the cipher suites that PostgreSQL will accept for SSL connections. For example:

```conf
ssl_ciphers = 'HIGH:MEDIUM:!LOW:!EXP:!NULL'
```

This example configuration permits high and medium strength ciphers while explicitly disallowing low strength, export, and null ciphers.

### 2. Understanding Cipher Suites

The cipher suites defined in `ssl_ciphers` follow the OpenSSL cipher suite naming conventions. You're interested in cipher suites that offer medium strength encryption. However, PostgreSQL documentation might not list all supported cipher suites explicitly in terms of their encryption strength (e.g., "medium").

To find out if medium strength encryption is supported (as per your definition), you may need to refer to OpenSSL documentation or other resources that list cipher suites by their encryption strength. 

### 3. Use External Tools

You can use external tools such as `openssl` or `nmap` to test the SSL/TLS configuration of your PostgreSQL server, including which ciphers are supported. Here's how you could use each tool:

- **Using `openssl`**:

  You can test a specific cipher suite by connecting to your PostgreSQL server using the `openssl s_client` command. For example:

  ```bash
  openssl s_client -connect your_postgres_server:5432 -cipher 'MEDIUM' -starttls postgres
  ```

  This command attempts to establish a connection using medium strength ciphers. Replace `your_postgres_server` with your server's address or hostname. The output will show if the connection was successful and provide details about the encryption used.

- **Using `nmap`**:

  `nmap` has scripts to test SSL services, including the `ssl-enum-ciphers` script, which will list supported cipher suites:

  ```bash
  nmap -p 5432 --script ssl-enum-ciphers your_postgres_server
  ```

  This script will provide detailed information about each cipher suite supported by the server, including its strength. You can then review this list to determine if any of the supported cipher suites match your criteria for medium strength encryption.

### 4. Review PostgreSQL Documentation

Always refer to the PostgreSQL documentation relevant to your version for the most accurate and detailed information regarding SSL/TLS configuration, including supported cipher suites and security practices.

### Conclusion

By reviewing your PostgreSQL configuration, specifically the `ssl_ciphers` setting, and possibly using external tools to enumerate supported cipher suites, you can determine if your server supports medium strength encryption as defined by your criteria.