#!/bin/bash

# 自动化Let's Encrypt证书申请与续期脚本
# 作者: fuyou imshuazi@126.com
# 版本: 1.0.0

# 设置变量
DOMAIN=""
EMAIL=""
WEBROOT=""
DNS_API=""
DNS_CREDENTIALS=""
INSTALL_NGINX=false
NGINX_CONFIG_DIR="$HOME/nginx-ssl-configs"

# 显示帮助信息
show_help() {
  echo "Let's Encrypt证书自动化申请和管理工具"
  echo ""
  echo "用法: $0 [选项]"
  echo ""
  echo "选项:"
  echo "  -d, --domain DOMAIN       指定要申请证书的域名 (必需)"
  echo "  -e, --email EMAIL         指定邮箱地址 (必需)"
  echo "  -w, --webroot PATH        使用网站根目录验证方式并指定路径"
  echo "  --dns API                 使用DNS API验证方式并指定API (如: dns_cf 表示Cloudflare)"
  echo "  --credentials PARAMS      DNS API凭证，格式取决于所选DNS API"
  echo "  --nginx-conf DIR          生成Nginx配置文件并保存到指定目录 (默认: ~/nginx-ssl-configs)"
  echo "  -h, --help                显示此帮助信息"
  echo ""
  echo "示例:"
  echo "  $0 -d example.com -e admin@example.com -w /var/www/html --nginx-conf /etc/nginx/conf.d/ssl"
  echo "  $0 -d '*.example.com' -e admin@example.com --dns dns_cf --credentials 'CF_Key=xxx CF_Email=xxx'"
  exit 1
}

# 解析命令行参数
parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -d|--domain)
        DOMAIN="$2"
        shift 2
        ;;
      -e|--email)
        EMAIL="$2"
        shift 2
        ;;
      -w|--webroot)
        WEBROOT="$2"
        shift 2
        ;;
      --dns)
        DNS_API="$2"
        shift 2
        ;;
      --credentials)
        DNS_CREDENTIALS="$2"
        shift 2
        ;;
      --nginx-conf)
        NGINX_CONFIG_DIR="$2"
        INSTALL_NGINX=true
        shift 2
        ;;
      -h|--help)
        show_help
        ;;
      *)
        echo "未知选项: $1"
        show_help
        ;;
    esac
  done

  # 验证必要参数
  if [[ -z "$DOMAIN" ]]; then
    echo "错误: 必须指定域名"
    show_help
  fi

  if [[ -z "$EMAIL" ]]; then
    echo "错误: 必须指定邮箱地址"
    show_help
  fi

  # 验证验证方式
  if [[ -z "$WEBROOT" && -z "$DNS_API" ]]; then
    echo "错误: 必须指定至少一种验证方式 (webroot 或 dns)"
    show_help
  fi

  # 如果使用DNS API验证，检查是否提供了凭证
  if [[ -n "$DNS_API" && -z "$DNS_CREDENTIALS" ]]; then
    echo "错误: 使用DNS API验证时必须提供凭证"
    show_help
  fi
}

# 检查并安装依赖
install_dependencies() {
  echo "检查并安装依赖..."
  
  # 检测操作系统
  if [ -f /etc/debian_version ]; then
    echo "检测到Debian/Ubuntu系统"
    apt-get update
    apt-get install -y curl wget socat
  elif [ -f /etc/redhat-release ]; then
    echo "检测到RHEL/CentOS系统"
    yum install -y curl wget socat
  elif [ -f /etc/arch-release ]; then
    echo "检测到Arch Linux系统"
    pacman -Sy --noconfirm curl wget socat
  else
    echo "未能识别的操作系统，请手动安装curl、wget和socat"
  fi
}

# 安装acme.sh
install_acme() {
  echo "安装acme.sh..."
  
  # 如果acme.sh已安装，则尝试升级
  if [ -f ~/.acme.sh/acme.sh ]; then
    echo "acme.sh已安装，尝试升级..."
    ~/.acme.sh/acme.sh --upgrade
  else
    echo "安装acme.sh..."
    curl https://get.acme.sh | sh -s email="$EMAIL"
  fi
  
  # 验证安装
  if [ ! -f ~/.acme.sh/acme.sh ]; then
    echo "acme.sh安装失败，请检查日志"
    exit 1
  fi
  
  # 设置默认CA为Let's Encrypt
  ~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
}

# 申请证书
issue_certificate() {
  echo "开始申请证书..."
  
  # 根据验证方式申请证书
  if [[ -n "$WEBROOT" ]]; then
    echo "使用Webroot验证方式申请证书..."
    ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --webroot "$WEBROOT" --keylength 2048
  elif [[ -n "$DNS_API" ]]; then
    echo "使用DNS API验证方式申请证书..."
    
    # 导出DNS API凭证
    export $DNS_CREDENTIALS
    
    # 对于通配符域名，必须使用DNS验证
    ~/.acme.sh/acme.sh --issue -d "$DOMAIN" --dns "$DNS_API" --keylength 2048
  fi
  
  # 检查是否成功申请
  if [ $? -ne 0 ]; then
    echo "证书申请失败，请检查日志"
    exit 1
  fi
  
  echo "证书申请成功!"
}

# 生成Nginx配置文件
generate_nginx_config() {
  if ! $INSTALL_NGINX; then
    return
  fi
  
  echo "生成Nginx SSL配置文件..."
  
  # 创建配置目录
  mkdir -p "$NGINX_CONFIG_DIR"
  
  # 去除通配符，获取基本域名
  BASE_DOMAIN=$(echo "$DOMAIN" | sed 's/^\*\.//')
  
  # 创建Nginx配置文件
  CONFIG_FILE="$NGINX_CONFIG_DIR/$BASE_DOMAIN.conf"
  echo "创建Nginx配置文件: $CONFIG_FILE"
  
  # 获取证书路径
  CERT_PATH=~/.acme.sh/"$DOMAIN"/"$DOMAIN".cer
  KEY_PATH=~/.acme.sh/"$DOMAIN"/"$DOMAIN".key
  
  # 创建配置文件
  cat > "$CONFIG_FILE" <<EOF
# Nginx SSL配置 - $DOMAIN
# 由Let's Encrypt自动化脚本生成
# 生成时间: $(date)
#
# 使用方法:
# 1. 将此文件复制到您的Nginx配置目录 (通常是 /etc/nginx/conf.d/ 或 /etc/nginx/sites-available/)
# 2. 如果复制到sites-available，需创建符号链接: sudo ln -s /etc/nginx/sites-available/$BASE_DOMAIN.conf /etc/nginx/sites-enabled/
# 3. 测试配置: sudo nginx -t
# 4. 重载Nginx: sudo systemctl reload nginx

server {
    listen 80;
    server_name $DOMAIN;
    
    # 将HTTP请求重定向到HTTPS
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name $DOMAIN;
    
    ssl_certificate $CERT_PATH;
    ssl_certificate_key $KEY_PATH;
    
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
    root ${WEBROOT:-/var/www/html};
    index index.html index.htm index.php;
    
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
  
  echo "Nginx配置文件已生成: $CONFIG_FILE"
  echo "请自行将此配置文件复制到您的Nginx配置目录并重新加载Nginx。"
}

# 设置自动更新钩子脚本
configure_deploy_hooks() {
  echo "配置证书部署钩子..."
  
  # 创建自定义钩子脚本
  mkdir -p ~/.acme.sh/deploy
  
  # 创建部署脚本
  cat > ~/.acme.sh/deploy/custom.sh <<EOF
#!/bin/bash

# 自定义证书部署脚本
# 证书续期后将自动执行此脚本

# 可用的环境变量:
# \$CERT_PATH: 证书文件路径
# \$KEY_PATH: 密钥文件路径
# \$CA_PATH: CA证书路径
# \$CERT_FULLCHAIN_PATH: 完整证书链路径
# \$DOMAIN: 域名

echo "证书已续期: \$DOMAIN"
echo "证书路径: \$CERT_FULLCHAIN_PATH"
echo "密钥路径: \$KEY_PATH"

# 在这里添加您的自定义部署逻辑
# 例如重启您的Web服务器或其他需要使用证书的服务
# 如果您使用了Nginx配置，可能需要重载Nginx: systemctl reload nginx
EOF
  
  chmod +x ~/.acme.sh/deploy/custom.sh
  
  # 配置使用此部署脚本
  ~/.acme.sh/acme.sh --deploy --deploy-hook custom -d "$DOMAIN"
}

# 主函数
main() {
  parse_args "$@"
  install_dependencies
  install_acme
  issue_certificate
  generate_nginx_config
  configure_deploy_hooks
  
  echo "==================================="
  echo "Let's Encrypt证书自动化配置完成!"
  echo "域名: $DOMAIN"
  echo "证书位置: ~/.acme.sh/$DOMAIN/"
  echo "证书将自动每60天续期一次"
  if $INSTALL_NGINX; then
    echo "Nginx配置文件: $NGINX_CONFIG_DIR/$BASE_DOMAIN.conf"
    echo "请手动将此配置文件复制到您的Nginx配置目录并重新加载Nginx"
  fi
  echo "==================================="
}

# 执行主函数
main "$@" 