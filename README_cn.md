# AO.space Platform 部署指南

[English](./README.md) | 简体中文

## 组件概览

| 服务组件            | 用途             | 安装方式       | 运行方式  | 网络端口                                  |
| ------------------- | ---------------- | -------------- | --------- | ----------------------------------------- |
| docker              | 容器运行时       | rpm/deb        | systemd   | -                                         |
| platform-mysql    | 关系型数据库     | docker-compose | container | -                                     |
| platform-redis    | 非关系型数据库   | docker-compose | container | -                                   |
| platform-proxy    | 网络规则代理服务 | docker-compose | container | 127.0.0.1:61011/tcp                       |
| gt-server    | 网络隧道服务     | docker-compose | container | 127.0.0.1:61012/tcp, 0.0.0.0:61012/udp |
| platform-base | 平台服务         | docker-compose | container | 127.0.0.1:61013/tcp                       |
| platform-nginx    | 路由服务         | docker-compose | container | 0.0.0.0:80/tcp, 0.0.0.0:443/tcp            |

## 配置要求

- 资源配置：
  - CPU: 4C
  - RAM: 8G
  - Storage: 120G
- 操作系统：
  - 支持 docker 运行的 x86_64 或 aarch64 架构的 Linux 操作系统。
  - 推荐使用 Kernel 大于 4.19 版本的 Fedora, CentOS, Redhat, Debian, Ubuntu, openEuler, EulixOS 等操作系统。

## 准备工作

- 域名：有 DNS 记录设置权限的域名一个。
- SSL 证书：域名对应的泛域名证书一个（包含 domain, *.domain,*.res.domain, *.upload.domain,*.download.domain, *.push.domain,*.platform.domain 等 7 个 CN 的证书）。
- 公网 IP：服务器有公网 IP 或支持服务器公网映射（80/tcp, 443/tcp, 61012/tcp, 61012/udp）
- 服务器：全新安装的 Linux 操作系统服务器，可使用云主机、物理机、虚拟机均可。

## 服务部署

全文以 `/opt/aoplatform/` 作为服务部署目录示例，以 `eulix.cn` 作为域名示例，以 `1.2.3.4` 作为公网 IP 示例。

使用 Git 下载服务部署仓库，安装后数据将持久化到该仓库目录（`./data`）下 ，请选择合适的位置进行下载。

```bash
yum install git -y || (apt update && apt install git -y) # 安装 Git。
git clone -b dev https://github.com/ao-space/platform-deploy.git /opt/aoplatform/ # 将服务部署仓库下载到 /opt/aoplatform/ 目录下，也可更换其他目录。
```

### 容器运行时安装

如操作系统为 Fedora, CentOS, Redhat, Debian, Ubuntu 等操作系统：

```bash
curl -sSL https://get.docker.com | sh
```

如操作系统为 openEuler, EulixOS, EulerOS, OpenAnolis, AliyunLinux, AnolisOS 等操作系统：

```bash
dnf install docker -y
```

等待 docker 安装完成后，设置 docker 开机自启并启动 docker：

```bash
systemctl enable --now docker
```

### 配置 DNS 解析

登录到域名 DNS 解析控制台或域主机，将以下 DNS 记录添加到 DNS 信息中（以公网 IP 为 1.2.3.4 为例，请将自己的公网 IP 替换 1.2.3.4）。

如为 Web 控制台：

- 条目 1:
  - 主机记录：@（部分解析服务提供商无法输入 @ 可将主机记录置空）
  - 记录类型：A
  - 记录值：1.2.3.4
  - TTL：600 或默认值
- 条目 2:
  - 主机记录：*
  - 记录类型：A
  - 记录值：1.2.3.4
  - TTL：600 或默认值

如为 zone 主机：

```bash
; AO.space Platform 服务的区域文件 - 请将以下数据追加到区域文件中
@ 600 IN A 1.2.3.4
* 600 IN A 1.2.3.4
```

### 获取域名泛域名证书（如已有泛域名证书可跳过）

用户可直接使用已有的泛域名证书部署此服务，也可基于下述指南获取开源的泛域名证书（90天有效期）。

使用 [Certbot](https://certbot.eff.org/) 或 [acme.sh](https://acme.sh) 获取开源泛域名证书。此步骤获取的泛域名证书签发者为 letsencrypt.org 或 zerossl.com。

```bash
cd /opt/aoplatform/
docker run --rm -v $PWD/data/acme.sh/:/acme.sh/ neilpang/acme.sh --register-account -m service@ao.space # 创建 acme 客户端 token，-m 后面请使用自己的邮箱，用来接收 SSL 到期通知，以此方式申请的 SSL 证书有效期为三个月（90 天）
```

```bash
cd /opt/aoplatform/
docker run --rm -v $PWD/data/acme.sh/:/acme.sh/ neilpang/acme.sh --issue --dns -d eulix.cn -d *.eulix.cn -d *.res.eulix.cn -d *.upload.eulix.cn -d *.download.eulix.cn -d *.push.eulix.cn -d *.platform.eulix.cn --yes-I-know-dns-manual-mode-enough-go-ahead-please -k 2048 # 通过 dns 方式创建 ssl 证书

# 会产生如下日志

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

添加上述七条 TXT 记录到 DNS 记录中。

如为 Web 控制台：

- 条目 1:
  - 主机记录：_acme-challenge
  - 记录类型：TXT
  - 记录值（根据实际情况添加）：0928VkpG6oOOTMO9C1tEHsonsNXM76SQBb1BGmxdGfk
  - TTL：600 或默认值
- 条目 2:
  - 主机记录：_acme-challenge
  - 记录类型：TXT
  - 记录值（根据实际情况添加）：ttOvwy670kbAF34fg4XJsfut4lJjG8Ay_Pd4nFXzAs0
  - TTL：600 或默认值
- 条目 3:
  - 主机记录：_acme-challenge.res
  - 记录类型：TXT
  - 记录值（根据实际情况添加）：ezyDktWatt4SHINHjVGCyItLCXM3yW05CzBexr9pHc8
  - TTL：600 或默认值
- 条目 4:
  - 主机记录：_acme-challenge.update
  - 记录类型：TXT
  - 记录值（根据实际情况添加）：EZWX0Gzng7J1blFWgEjrfIe3elL_-ms6EsB3z2XiQFE
  - TTL：600 或默认值
- 条目 5:
  - 主机记录：_acme-challenge.download
  - 记录类型：TXT
  - 记录值（根据实际情况添加）：0mjodbxuUfbJC3ZDWVpDRu1_j791RalMI08uSmRAe0Y
  - TTL：600 或默认值
- 条目 6:
  - 主机记录：_acme-challenge.push
  - 记录类型：TXT
  - 记录值（根据实际情况添加）：buFAZofgN18n7uF1CsCRVp9_idDOkN5T-As_vQQnCoU
  - TTL：600 或默认值
- 条目 7:
  - 主机记录：_acme-challenge.platform
  - 记录类型：TXT
  - 记录值（根据实际情况添加）：PYfzV4yTP-R1P-7YiLc-ciwRspR4E3LDh4NYDa_AlCk
  - TTL：600 或默认值

如为 zone 主机：

```text
AO.space Platform 服务的区域文件 - 请将以下数据追加到区域文件中
_acme-challenge          600 IN TXT "0928VkpG6oOOTMO9C1tEHsonsNXM76SQBb1BGmxdGfk"
_acme-challenge          600 IN TXT "ttOvwy670kbAF34fg4XJsfut4lJjG8Ay_Pd4nFXzAs0"
_acme-challenge.res      600 IN TXT "ezyDktWatt4SHINHjVGCyItLCXM3yW05CzBexr9pHc8"
_acme-challenge.update   600 IN TXT "EZWX0Gzng7J1blFWgEjrfIe3elL_-ms6EsB3z2XiQFE"
_acme-challenge.download 600 IN TXT "0mjodbxuUfbJC3ZDWVpDRu1_j791RalMI08uSmRAe0Y"
_acme-challenge.push     600 IN TXT "buFAZofgN18n7uF1CsCRVp9_idDOkN5T-As_vQQnCoU"
_acme-challenge.platform 600 IN TXT "PYfzV4yTP-R1P-7YiLc-ciwRspR4E3LDh4NYDa_AlCk"
```

TXT 记录添加完成后获取证书：

```text
cd /opt/aoplatform/
docker run --rm -v $PWD/data/acme.sh/:/acme.sh/ neilpang/acme.sh --renew --dns -d eulix.cn -d *.eulix.cn -d *.res.eulix.cn -d *.upload.eulix.cn -d *.download.eulix.cn -d *.push.eulix.cn -d *.platform.eulix.cn --yes-I-know-dns-manual-mode-enough-go-ahead-please -k 2048 # 与获取 TXT 记录不同之处为使用 --renew 

# 会产生如下日志：

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

证书会保存在 `/opt/aoplatform/data/acme.sh/` 目录下的域名文件夹中，其中 fullchain.cer 为 SSL 证书，域名.key 为 SSL 私钥。

### 启动服务

- 域名以 eulix.cn 为例
- ssl 证书路径以 /opt/aoplatform/data/acme.sh/eulix.cn/fullchain.cer 为例
- ssl 私钥路径以 /opt/aoplatform/data/acme.sh/eulix.cn/eulix.cn.key 为例

```bash
cd /opt/aoplatform/
./install.sh -d eulix.cn -c data/acme.sh/eulix.cn/fullchain.cer -k data/acme.sh/eulix.cn/eulix.cn.key
```

### 服务配置说明

执行 `./install.sh` 后会随机生成数据库密码，并将配置文件生成在 .env 文件中。

## 贡献指南

我们非常欢迎对本项目进行贡献。以下是一些指导原则和建议，希望能够帮助您参与到项目中来。

[贡献指南](https://github.com/ao-space/ao.space/blob/dev/docs/cn/contribution-guidelines.md)

## 联系我们

- 邮箱：<developer@ao.space>
- [官方网站](https://ao.space)
- [讨论组](https://slack.ao.space)
