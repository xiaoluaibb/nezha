#!/bin/bash
# Nezha Dashboard 一键完整安装脚本（Docker + Nginx + SSL）
# 专为单个域名 + Cloudflare/腾讯CDN 优化

set -e

echo "=== 哪吒监控 Dashboard 一键完整安装脚本（安全版） ==="

DOMAIN=""  # 将在后面交互输入

# 检查必要组件
install_deps() {
    echo "检查并安装必要组件..."
    apt update -qq || yum update -q
    apt install -y curl wget git tar nginx socat || yum install -y curl wget git tar nginx socat
}

# 安装 acme.sh 并申请证书
install_ssl() {
    echo "正在安装 acme.sh 并申请 SSL 证书..."
    curl -s https://get.acme.sh | sh -s email=admin@$DOMAIN
    ~/.acme.sh/acme.sh --issue -d $DOMAIN --nginx --force || true
    ~/.acme.sh/acme.sh --install-cert -d $DOMAIN \
        --key-file /etc/nginx/ssl/$DOMAIN.key \
        --fullchain-file /etc/nginx/ssl/$DOMAIN.crt \
        --reloadcmd "systemctl reload nginx"
}

# 主安装流程
install_deps

echo -n "请输入你的域名 (例如: nezha.example.com): "
read -r DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "域名不能为空！"
    exit 1
fi

# 检查是否已安装
if docker ps | grep -q nezha-dashboard; then
    echo "检测到已安装哪吒面板，是否更新？(y/n)"
    read -r choice
    [[ "$choice" != "y" && "$choice" != "Y" ]] && exit 0
fi

# 安装官方脚本
curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/install.sh -o nezha.sh
chmod +x nezha.sh

# 使用环境变量非交互安装 Docker 版
env NZ_DOMAIN=$DOMAIN \
    NZ_PORT=8008 \
    ./nezha.sh install

# 配置 Nginx 反代
mkdir -p /etc/nginx/ssl
cat > /etc/nginx/sites-available/nezha <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/nginx/ssl/$DOMAIN.crt;
    ssl_certificate_key /etc/nginx/ssl/$DOMAIN.key;

    # gRPC 支持 (Agent)
    location ^~ /proto.NezhaService/ {
        grpc_pass grpc://127.0.0.1:8008;
        grpc_set_header Host \$host;
        grpc_set_header X-Real-IP \$remote_addr;
        grpc_read_timeout 600s;
        grpc_send_timeout 600s;
    }

    # WebSocket 支持
    location ~* ^/api/v1/ws/ {
        proxy_pass http://127.0.0.1:8008;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_read_timeout 3600s;
    }

    # 普通网页
    location / {
        proxy_pass http://127.0.0.1:8008;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 3600s;
    }
}
EOF

ln -sf /etc/nginx/sites-available/nezha /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# 关闭 WebSSH（安全）
sed -i 's/enable_terminal: true/enable_terminal: false/' /opt/nezha/dashboard/data/config.yaml 2>/dev/null || true

# 添加定时更新任务
echo "是否添加自动检查更新任务？(y/n)"
read -r cron_choice
if [[ "$cron_choice" == "y" || "$cron_choice" == "Y" ]]; then
    echo "选择检查频率：1) 每小时  2) 每天  3) 每3天"
    read -r freq
    case $freq in
        1) cron="0 * * * *";;
        2) cron="0 3 * * *";;
        3) cron="0 3 */3 * *";;
        *) cron="0 3 * * *";;
    esac
    echo "$cron root cd /opt/nezha && ./nezha.sh restart_and_update" > /etc/cron.d/nezha-update
    echo "定时更新任务已添加！"
fi

echo "=== 安装完成！ ==="
echo "访问地址: https://$DOMAIN"
echo "Agent 请使用: $DOMAIN:443 （或服务器IP:8008）"
echo "强烈建议立即修改后台密码！"
