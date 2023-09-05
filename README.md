# AO.space Platform Deployment Guide

English | [简体中文](./README_cn.md)

## Component Overview

| Service component   | Purpose        | Installation method | Operation method  |  Network port                  |
| ------------------- | ---------------- | -------------- | --------- | ----------------------------------------- |
| docker              | Container runtime | rpm/deb        | systemd   | -                                         |
| platform-mysql    | Relational database | docker-compose | container | -                                     |
| platform-redis    | Non relational database | docker-compose | container | -                                   |
| platform-proxy    | Network rule proxy service | docker-compose | container | 127.0.0.1:61011/tcp                |
| gt-server    | Network tunnel service | docker-compose | container | 127.0.0.1:61012/tcp, 0.0.0.0:61012/udp |
| platform-base | Platform base service | docker-compose | container | 127.0.0.1:61013/tcp                       |
| platform-nginx | Platform route service | docker-compose | container | 0.0.0.0:80/tcp, 0.0.0.0:443/tcp            |

## Configuration Requirements

-Resource allocation:

- CPU: 4C
- RAM: 8G
- Storage: 120G
-Operating system:
- Linux operating system with X86_64 or aarch64 architecture that supports Docker.
- It is recommended to use operating systems such as Fedora, CentOS, Redhat, Debian, Ubuntu, openEuler, and EulixOS with kernel versions greater than 4.19.

## Preparation Work

- Domain name: A domain name with DNS record setting permissions.
- SSL certificate: One wild-domain certificate corresponding to the domain name (including 7 CN certificates such as domain, *.domain,*.res.domain, *.upload.domain,*.download.domain, *.push.domain,*.platform.domain).
- Public IP: The server has a public IP or supports server public network mapping (80/tcp, 443/tcp, 61012/tcp, 61012/udp)
- Server: A newly installed Linux operating system server, such as cloud host, physical machine, virtual machine.

## Service Deployment

The entire article takes '/opt/aoplatform/' as an example of service deployment directory, 'eulix.cn' as an example of domain name, and '1.2.3.4' as an example of public IP.

Download the service deployment repository using the Git. After installation, the data will be persisted to the warehouse directory ('./data'). Please select the appropriate location for download.

```bash
yum install git -y || (apt update && apt install git -y) # Install Git。
git clone -b dev https://github.com/ao-space/platform-deploy.git /opt/aoplatform/ # Download the service deployment repository to the '/opt/aoplatform/' directory, or change to another directory.
```

### Container Runtime Installation

If the operating system is Fedora, CentOS, Redhat, Debian, Ubuntu, and other operating systems:

```bash
curl -sSL https://get.docker.com | sh
```

If the operating system is OpenEuler, EulixOS, EulerOS, OpenAnolis, AliyunLinux, AnolisOS, and other operating systems:

```bash
dnf install docker -y
```

After waiting for the Docker installation to complete, set the Docker to start automatically and start the Docker:

```bash
systemctl enable --now docker
```

### Configure DNS resolution

Log in to the domain name DNS resolution console or zone host, and add the following DNS records to the DNS information (taking the public IP as 1.2.3.4 as an example, please replace your own public IP with 1.2.3.4).

If it is a web console:

- Entry 1:
  - Host record：@（Some resolution service providers can not enter @ and can leave the host record blank）
  - Record type：A
  - Record value：1.2.3.4
  - TTL：600 or default value
- Entry 2:
  - Host record：*
  - Record type：A
  - Record value：1.2.3.4
  - TTL：600 or default value

If it is a zone host:

```bash
; AO.space Platform Service region file - Please append the following data to the region file
@ 600 IN A 1.2.3.4
* 600 IN A 1.2.3.4
```

### Obtain domain name wild-domain certificate (skip if you already have a wild-domain certificate)

Users can directly deploy this service using existing wild-domain certificates, or obtain open-source wild-domain certificates (with a 90 day validity period) based on the following guidelines.

Using [Certbot](https://certbot.eff.org/) or [acme.sh](https://acme.sh) obtain an open-source wild-domain certificate. The wild-domain certificate issuer obtained in this step is letsencrypt.org or zerossl.com.

```bash
cd /opt/aoplatform/
docker run --rm -v $PWD/data/acme.sh/:/acme.sh/ neilpang/acme.sh --register-account -m service@ao.space # Create an ACME client token and use your own email for the - m parameter to receive SSL expiration notifications. The SSL certificate applied for in this way has a validity period of three months (90 days).
```

```bash
cd /opt/aoplatform/
docker run --rm -v $PWD/data/acme.sh/:/acme.sh/ neilpang/acme.sh --issue --dns -d eulix.cn -d *.eulix.cn -d *.res.eulix.cn -d *.upload.eulix.cn -d *.download.eulix.cn -d *.push.eulix.cn -d *.platform.eulix.cn --yes-I-know-dns-manual-mode-enough-go-ahead-please -k 2048 # Create SSL certificates through DNS.

# The following logs will be generated

[Sun Jan  1 21:56:59 UTC 2023] Using CA: https://acme.zerossl.com/v2/DV90
[Sun Jan  1 21:56:59 UTC 2023] Multi domain='DNS:eulix.cn,DNS:*.eulix.cn,DNS:*.res.eulix.cn,DNS:*.upload.eulix.cn,DNS:*.download.eulix.cn,DNS:*.push.eulix.cn,DNS:*.platform.eulix.cn'
[Sun Jan  1 21:56:59 UTC 2023] Getting domain auth token for each domain
[Sun Jan  1 21:57:34 UTC 2023] Getting webroot for domain='eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] Getting webroot for domain='*.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] Getting webroot for domain='*.res.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] Getting webroot for domain='*.upload.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] Getting webroot for domain='*.download.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] Getting webroot for domain='*.push.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] Getting webroot for domain='*.platform.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] Add the following TXT record:
[Sun Jan  1 21:57:34 UTC 2023] Domain: '_acme-challenge.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] TXT value: '0928VkpG6oOOTMO9C1tEHsonsNXM76SQBb1BGmxdGfk'
[Sun Jan  1 21:57:34 UTC 2023] Please be aware that you prepend _acme-challenge. before your domain
[Sun Jan  1 21:57:34 UTC 2023] so the resulting subdomain will be: _acme-challenge.eulix.cn
[Sun Jan  1 21:57:34 UTC 2023] Add the following TXT record:
[Sun Jan  1 21:57:34 UTC 2023] Domain: '_acme-challenge.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] TXT value: 'ttOvwy670kbAF34fg4XJsfut4lJjG8Ay_Pd4nFXzAs0'
[Sun Jan  1 21:57:34 UTC 2023] Please be aware that you prepend _acme-challenge. before your domain
[Sun Jan  1 21:57:34 UTC 2023] so the resulting subdomain will be: _acme-challenge.eulix.cn
[Sun Jan  1 21:57:34 UTC 2023] Add the following TXT record:
[Sun Jan  1 21:57:34 UTC 2023] Domain: '_acme-challenge.res.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] TXT value: 'ezyDktWatt4SHINHjVGCyItLCXM3yW05CzBexr9pHc8'
[Sun Jan  1 21:57:34 UTC 2023] Please be aware that you prepend _acme-challenge. before your domain
[Sun Jan  1 21:57:34 UTC 2023] so the resulting subdomain will be: _acme-challenge.res.eulix.cn
[Sun Jan  1 21:57:34 UTC 2023] Add the following TXT record:
[Sun Jan  1 21:57:34 UTC 2023] Domain: '_acme-challenge.upload.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] TXT value: 'EZWX0Gzng7J1blFWgEjrfIe3elL_-ms6EsB3z2XiQFE'
[Sun Jan  1 21:57:34 UTC 2023] Please be aware that you prepend _acme-challenge. before your domain
[Sun Jan  1 21:57:34 UTC 2023] so the resulting subdomain will be: _acme-challenge.upload.eulix.cn
[Sun Jan  1 21:57:34 UTC 2023] Add the following TXT record:
[Sun Jan  1 21:57:34 UTC 2023] Domain: '_acme-challenge.download.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] TXT value: '0mjodbxuUfbJC3ZDWVpDRu1_j791RalMI08uSmRAe0Y'
[Sun Jan  1 21:57:34 UTC 2023] Please be aware that you prepend _acme-challenge. before your domain
[Sun Jan  1 21:57:34 UTC 2023] so the resulting subdomain will be: _acme-challenge.download.eulix.cn
[Sun Jan  1 21:57:34 UTC 2023] Add the following TXT record:
[Sun Jan  1 21:57:34 UTC 2023] Domain: '_acme-challenge.push.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] TXT value: 'buFAZofgN18n7uF1CsCRVp9_idDOkN5T-As_vQQnCoU'
[Sun Jan  1 21:57:34 UTC 2023] Please be aware that you prepend _acme-challenge. before your domain
[Sun Jan  1 21:57:34 UTC 2023] so the resulting subdomain will be: _acme-challenge.push.eulix.cn
[Sun Jan  1 21:57:34 UTC 2023] Add the following TXT record:
[Sun Jan  1 21:57:34 UTC 2023] Domain: '_acme-challenge.platform.eulix.cn'
[Sun Jan  1 21:57:34 UTC 2023] TXT value: 'PYfzV4yTP-R1P-7YiLc-ciwRspR4E3LDh4NYDa_AlCk'
[Sun Jan  1 21:57:34 UTC 2023] Please be aware that you prepend _acme-challenge. before your domain
[Sun Jan  1 21:57:34 UTC 2023] so the resulting subdomain will be: _acme-challenge.platform.eulix.cn
[Sun Jan  1 21:57:34 UTC 2023] Please add the TXT records to the domains, and re-run with --renew.
[Sun Jan  1 21:57:34 UTC 2023] Please add '--debug' or '--log' to check more details.
[Sun Jan  1 21:57:34 UTC 2023] See: https://github.com/acmesh-official/acme.sh/wiki/How-to-debug-acme.sh
```

Add the seven TXT records mentioned above to the DNS information.

If it is a web console:

- Entry 1:
  - Host record：_acme-challenge
  - Record type：TXT
  - Record value(added according to actual value)：0928VkpG6oOOTMO9C1tEHsonsNXM76SQBb1BGmxdGfk
  - TTL：600 or default value
- Entry 2:
  - Host record：_acme-challenge
  - Record type：TXT
  - Record value(added according to actual value)：ttOvwy670kbAF34fg4XJsfut4lJjG8Ay_Pd4nFXzAs0
  - TTL：600 or default value
- Entry 3:
  - Host record：_acme-challenge.res
  - Record type：TXT
  - Record value(added according to actual value)：ezyDktWatt4SHINHjVGCyItLCXM3yW05CzBexr9pHc8
  - TTL：600 or default value
- Entry 4:
  - Host record：_acme-challenge.update
  - Record type：TXT
  - Record value(added according to actual value)：EZWX0Gzng7J1blFWgEjrfIe3elL_-ms6EsB3z2XiQFE
  - TTL：600 or default value
- Entry 5:
  - Host record：_acme-challenge.download
  - Record type：TXT
  - Record value(added according to actual value)：0mjodbxuUfbJC3ZDWVpDRu1_j791RalMI08uSmRAe0Y
  - TTL：600 or default value
- Entry 6:
  - Host record：_acme-challenge.push
  - Record type：TXT
  - Record value(added according to actual value)：buFAZofgN18n7uF1CsCRVp9_idDOkN5T-As_vQQnCoU
  - TTL：600 or default value
- Entry 7:
  - Host record：_acme-challenge.platform
  - Record type：TXT
  - Record value(added according to actual value)：PYfzV4yTP-R1P-7YiLc-ciwRspR4E3LDh4NYDa_AlCk
  - TTL：600 or default value

If it is a zone host:

```bash
; AO.space Platform Service region file - Please append the following data to the region file
_acme-challenge          600 IN TXT "0928VkpG6oOOTMO9C1tEHsonsNXM76SQBb1BGmxdGfk"
_acme-challenge          600 IN TXT "ttOvwy670kbAF34fg4XJsfut4lJjG8Ay_Pd4nFXzAs0"
_acme-challenge.res      600 IN TXT "ezyDktWatt4SHINHjVGCyItLCXM3yW05CzBexr9pHc8"
_acme-challenge.update   600 IN TXT "EZWX0Gzng7J1blFWgEjrfIe3elL_-ms6EsB3z2XiQFE"
_acme-challenge.download 600 IN TXT "0mjodbxuUfbJC3ZDWVpDRu1_j791RalMI08uSmRAe0Y"
_acme-challenge.push     600 IN TXT "buFAZofgN18n7uF1CsCRVp9_idDOkN5T-As_vQQnCoU"
_acme-challenge.platform 600 IN TXT "PYfzV4yTP-R1P-7YiLc-ciwRspR4E3LDh4NYDa_AlCk"
```

Obtain a certificate after adding TXT records:

```text
cd /opt/aoplatform/
docker run --rm -v $PWD/data/acme.sh/:/acme.sh/ neilpang/acme.sh --renew --dns -d eulix.cn -d *.eulix.cn -d *.res.eulix.cn -d *.upload.eulix.cn -d *.download.eulix.cn -d *.push.eulix.cn -d *.platform.eulix.cn --yes-I-know-dns-manual-mode-enough-go-ahead-please -k 2048 # The difference between obtaining TXT records is using --renew

# The following logs will be generated

[Sun Jan  1 22:02:20 UTC 2023] Renew: 'eulix.cn'
[Sun Jan  1 22:02:20 UTC 2023] Renew to Le_API=https://acme.zerossl.com/v2/DV90
[Sun Jan  1 22:02:21 UTC 2023] Using CA: https://acme.zerossl.com/v2/DV90
[Sun Jan  1 22:02:21 UTC 2023] Multi domain='DNS:eulix.cn,DNS:*.eulix.cn,DNS:*.res.eulix.cn,DNS:*.upload.eulix.cn,DNS:*.download.eulix.cn,DNS:*.push.eulix.cn,DNS:*.platform.eulix.cn'
[Sun Jan  1 22:02:21 UTC 2023] Getting domain auth token for each domain
[Sun Jan  1 22:02:21 UTC 2023] Verifying: eulix.cn
[Sun Jan  1 22:02:30 UTC 2023] Processing, The CA is processing your order, please just wait. (1/30)
[Sun Jan  1 22:02:36 UTC 2023] Success
[Sun Jan  1 22:02:36 UTC 2023] Verifying: *.eulix.cn
[Sun Jan  1 22:02:39 UTC 2023] Processing, The CA is processing your order, please just wait. (1/30)
[Sun Jan  1 22:02:44 UTC 2023] Success
[Sun Jan  1 22:02:44 UTC 2023] Verifying: *.res.eulix.cn
[Sun Jan  1 22:02:47 UTC 2023] Processing, The CA is processing your order, please just wait. (1/30)
[Sun Jan  1 22:02:52 UTC 2023] Success
[Sun Jan  1 22:02:52 UTC 2023] Verifying: *.upload.eulix.cn
[Sun Jan  1 22:02:56 UTC 2023] Processing, The CA is processing your order, please just wait. (1/30)
[Sun Jan  1 22:03:01 UTC 2023] Success
[Sun Jan  1 22:03:01 UTC 2023] Verifying: *.download.eulix.cn
[Sun Jan  1 22:03:04 UTC 2023] Processing, The CA is processing your order, please just wait. (1/30)
[Sun Jan  1 22:03:08 UTC 2023] Success
[Sun Jan  1 22:03:08 UTC 2023] Verifying: *.push.eulix.cn
[Sun Jan  1 22:03:11 UTC 2023] Processing, The CA is processing your order, please just wait. (1/30)
[Sun Jan  1 22:03:16 UTC 2023] Success
[Sun Jan  1 22:03:16 UTC 2023] Verifying: *.platform.eulix.cn
[Sun Jan  1 22:03:19 UTC 2023] Processing, The CA is processing your order, please just wait. (1/30)
[Sun Jan  1 22:03:24 UTC 2023] Success
[Sun Jan  1 22:03:24 UTC 2023] Verify finished, start to sign.
[Sun Jan  1 22:03:24 UTC 2023] Lets finalize the order.
[Sun Jan  1 22:03:24 UTC 2023] Le_OrderFinalize='https://acme.zerossl.com/v2/DV90/order/XXX/finalize'
[Sun Jan  1 22:03:27 UTC 2023] Order status is processing, lets sleep and retry.
[Sun Jan  1 22:03:27 UTC 2023] Retry after: 15
[Sun Jan  1 22:03:42 UTC 2023] Polling order status: https://acme.zerossl.com/v2/DV90/order/XXX
[Sun Jan  1 22:03:47 UTC 2023] Downloading cert.
[Sun Jan  1 22:03:47 UTC 2023] Le_LinkCert='https://acme.zerossl.com/v2/DV90/cert/XXX'
[Sun Jan  1 22:03:51 UTC 2023] Cert success.
-----BEGIN CERTIFICATE-----
XXXX
-----END CERTIFICATE-----
[Sun Jan  1 22:03:51 UTC 2023] Your cert is in: /acme.sh/eulix.cn/eulix.cn.cer
[Sun Jan  1 22:03:51 UTC 2023] Your cert key is in: /acme.sh/eulix.cn/eulix.cn.key
[Sun Jan  1 22:03:51 UTC 2023] The intermediate CA cert is in: /acme.sh/eulix.cn/ca.cer
[Sun Jan  1 22:03:51 UTC 2023] And the full chain certs is there: /acme.sh/eulix.cn/fullchain.cer
```

The certificate will be saved in the domain name folder under the '/opt/oplatform/data/acme.sh/' directory, where fullchain.cer is the SSL certificate and eulix.cn.key is the SSL private key.

### Start Service

- Taking eulix.cn as an example for the domain name
- The SSL certificate path takes/opt/aoplatform/data/acme.sh/eulix.cn/fulchan.cer as an example
- The SSL private key path takes/opt/aoplatform/data/acme.sh/eulix.cn/eulix.cn.key as an example

```bash
cd /opt/aoplatform/
./install.sh -d eulix.cn -c data/acme.sh/eulix.cn/fullchain.cer -k data/acme.sh/eulix.cn/eulix.cn.key
```

### Service Configuration Description

Execute `./install.sh', the database password will be randomly generated and the configuration file will be generated in the .env file.

## Contribution Guidelines

Contributions to this project are very welcome. Here are some guidelines and suggestions to help you get involved in the project.

[Contribution Guidelines](https://github.com/ao-space/ao.space/blob/dev/docs/en/contribution-guidelines.md)

## Contact us

- Email: <developer@ao.space>
- [Official Website](https://ao.space)
- [Discussion group](https://slack.ao.space)
