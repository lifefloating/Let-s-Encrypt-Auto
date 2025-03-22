# Let's Encrypt 证书自动化工具

这是一个自动化申请和管理 Let's Encrypt SSL 证书的工具，支持自动续期，可以轻松配置到 Nginx 等 Web 服务器中。

## 功能特点

- 自动安装依赖和必要工具
- 支持多种域名验证方式（Webroot 和 DNS）
- 支持申请通配符证书
- 生成Nginx配置文件（不会自动应用）
- 自动设置证书续期和部署钩子
- 自动检测操作系统并安装相应依赖
- 提供证书维护工具，方便管理证书

## 系统要求

- Linux 操作系统（支持 Debian/Ubuntu、RHEL/CentOS、Arch Linux）
- root 权限或 sudo 权限
- 互联网连接

## 快速开始

1. 下载脚本：

```bash
curl -O https://github.com/lifefloating/ssl-auto.sh
curl -O https://github.com/lifefloating/ssl-maintain.sh
chmod +x ssl-auto.sh ssl-maintain.sh
```

2. 使用 Webroot 验证方式申请证书：

```bash
./ssl-auto.sh -d example.com -e admin@example.com -w /var/www/html --nginx-conf ~/nginx-configs
```

3. 使用 DNS API 验证方式申请通配符证书（以 Cloudflare 为例）：

```bash
./ssl-auto.sh -d "*.example.com" -e admin@example.com --dns dns_cf --credentials "CF_Key=你的CF密钥 CF_Email=你的CF邮箱" --nginx-conf ~/nginx-configs
```

## 参数说明

### ssl-auto.sh 参数

| 参数 | 说明 |
|------|------|
| `-d, --domain` | 指定要申请证书的域名（必需） |
| `-e, --email` | 指定邮箱地址（必需） |
| `-w, --webroot` | 使用网站根目录验证方式并指定路径 |
| `--dns` | 使用DNS API验证方式并指定API（如: dns_cf 表示Cloudflare） |
| `--credentials` | DNS API凭证，格式取决于所选DNS API |
| `--nginx-conf` | 生成Nginx配置文件并指定保存目录（默认: ~/nginx-ssl-configs） |
| `--cron` | 自定义证书检查的cron计划（默认: "0 0,12 * * *"） |
| `--evening-check` | 设置为每晚22点检查（"0 22 * * *"） |
| `-h, --help` | 显示帮助信息 |

### ssl-maintain.sh 命令

| 命令 | 说明 |
|------|------|
| `list` | 列出所有已申请的证书及其状态 |
| `info <域名>` | 显示指定域名证书的详细信息 |
| `renew <域名>` | 手动续期指定域名的证书 |
| `renew-all` | 手动续期所有证书 |
| `revoke <域名>` | 吊销指定域名的证书 |
| `remove <域名>` | 删除指定域名的证书 |
| `check-cron` | 检查定时任务是否正确配置 |
| `reinstall-cron` | 重新安装定时任务 |
| `update` | 更新acme.sh客户端 |

## 验证方式说明

### Webroot 验证

Webroot 验证需要您的网站已经可以通过 HTTP 访问，并且您有权限访问网站根目录。该验证方式通过创建一个特殊的文件在 `/.well-known/acme-challenge/` 目录下来验证您对域名的控制权。

示例：
```bash
./ssl-auto.sh -d example.com -e admin@example.com -w /var/www/html
```

### DNS 验证

DNS 验证通过添加一条 TXT 记录到您的域名 DNS 解析中来验证您对域名的控制权。此方法**必须**用于申请通配符证书。

本脚本支持通过 DNS API 自动完成验证，目前支持多种 DNS 提供商，包括：

- Cloudflare (`dns_cf`)
- Aliyun (`dns_ali`)
- DNSPod/腾讯云 (`dns_dp`)
- 更多 DNS API 可参考 [acme.sh DNS API 文档](https://github.com/acmesh-official/acme.sh/wiki/dnsapi)

#### 腾讯云DNS设置说明

腾讯云DNS使用DNSPod的API，您需要进行以下设置：

1. 登录腾讯云控制台，访问 [API密钥管理](https://console.cloud.tencent.com/cam/capi)
2. 创建一个API密钥（如果没有的话）
3. 记录您的 SecretId 和 SecretKey
4. 使用以下命令申请证书：

```bash
./ssl-auto.sh -d "*.example.com" -e admin@example.com --dns dns_dp --credentials "DP_Id=您的SecretId DP_Key=您的SecretKey" --nginx-conf ~/nginx-configs
```

示例（Cloudflare）：
```bash
./ssl-auto.sh -d "*.example.com" -e admin@example.com --dns dns_cf --credentials "CF_Key=您的CF密钥 CF_Email=您的CF邮箱" --nginx-conf ~/nginx-configs
```

## Nginx 配置

使用 `--nginx-conf` 选项时，脚本会：

1. 在指定目录生成 Nginx 配置文件
2. 不会自动应用此配置，需要您手动复制到 Nginx 配置目录

配置文件示例：
```
# Nginx SSL配置 - example.com
# 由Let's Encrypt自动化脚本生成
# 生成时间: 2023-05-01 12:00:00
#
# 使用方法:
# 1. 将此文件复制到您的Nginx配置目录 (通常是 /etc/nginx/conf.d/ 或 /etc/nginx/sites-available/)
# 2. 如果复制到sites-available，需创建符号链接: sudo ln -s /etc/nginx/sites-available/example.com.conf /etc/nginx/sites-enabled/
# 3. 测试配置: sudo nginx -t
# 4. 重载Nginx: sudo systemctl reload nginx

server {
    listen 80;
    server_name example.com;
    
    # 将HTTP请求重定向到HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name example.com;
    
    ssl_certificate /root/.acme.sh/example.com/example.com.cer;
    ssl_certificate_key /root/.acme.sh/example.com/example.com.key;
    
    # SSL配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets off;
    
    # OCSP Stapling
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # 网站根目录
    root /var/www/html;
    index index.html index.htm index.php;
    
    location / {
        try_files $uri $uri/ =404;
    }
}
```

## 证书维护

使用 `ssl-maintain.sh` 脚本可以方便地管理和维护证书：

### 查看证书列表

```bash
./ssl-maintain.sh list
```

### 查看证书详情

```bash
./ssl-maintain.sh info example.com
```

### 手动续期证书

```bash
./ssl-maintain.sh renew example.com
# 强制续期
./ssl-maintain.sh renew example.com --force
```

### 续期所有证书

```bash
./ssl-maintain.sh renew-all
```

### 检查定时任务

```bash
./ssl-maintain.sh check-cron
```

## 证书自动续期

脚本使用 acme.sh 的定时任务功能，会自动检查并续期证书。您无需手动操作，一切都将自动完成。

### 自定义检查时间

默认情况下，acme.sh 会在每天的 0:00 和 12:00 检查证书状态。您可以使用以下选项自定义检查时间：

1. 使用 `--evening-check` 参数设置为每晚 22:00（10PM）检查：

```bash
./ssl-auto.sh -d example.com -e admin@example.com -w /var/www/html --evening-check
```

2. 使用 `--cron` 参数设置自定义的 cron 时间表：

```bash
# 每天早上8点和晚上8点检查
./ssl-auto.sh -d example.com -e admin@example.com -w /var/www/html --cron "0 8,20 * * *"

# 每周日凌晨3点检查
./ssl-auto.sh -d example.com -e admin@example.com -w /var/www/html --cron "0 3 * * 0"
```

如果需要检查定时任务是否正确配置，可以使用：

```bash
./ssl-maintain.sh check-cron
```

## 证书部署钩子

当证书续期后，脚本会使用自定义部署钩子。您可以修改 `~/.acme.sh/deploy/custom.sh` 脚本来定义证书续期后的自定义行为，例如重新加载服务器配置等。

## 常见问题

### 1. 如何查看证书信息？

```bash
./ssl-maintain.sh info example.com
```

### 2. 如何手动强制续期证书？

```bash
./ssl-maintain.sh renew example.com --force
```

### 3. 如何查看日志？

acme.sh 的日志文件位于 `~/.acme.sh/acme.sh.log`

### 4. 证书文件在哪里？

证书文件存储在 `~/.acme.sh/域名/` 目录下：

- `域名.cer` - 证书文件
- `域名.key` - 密钥文件
- `fullchain.cer` - 完整证书链文件

## 注意事项

- 请确保您的服务器可以通过互联网访问
- 对于 DNS 验证，请确保提供正确的 API 凭证
- 该脚本需要 root 权限或 sudo 权限才能安装依赖和配置服务
- Nginx 配置文件需要手动应用到 Nginx 配置目录

## 许可证

MIT 