#!/bin/bash
# 哪吒监控 一键管理脚本 - nezha.sh（最终版）

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 强化依赖安装
install_deps() {
    echo "正在检查并安装必要依赖（包括 unzip）..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y curl wget git tar nginx socat unzip ca-certificates
    elif command -v yum >/dev/null 2>&1; then
        yum install -y curl wget git tar nginx socat unzip ca-certificates
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y curl wget git tar nginx socat unzip ca-certificates
    fi
}

show_menu() {
    clear
    echo -e "${GREEN}=======================================${NC}"
    echo -e "${BLUE}       哪吒监控 管理菜单       ${NC}"
    echo -e "${GREEN}=======================================${NC}"
    echo -e "1. 查看系统信息"
    echo -e "2. 查看哪吒运行状态"
    echo -e "3. 一键安装哪吒（Docker + Nginx + 自动SSL）"
    echo -e "4. 重启哪吒面板"
    echo -e "5. 停止哪吒面板"
    echo -e "6. 启动哪吒面板"
    echo -e "7. 查看 Dashboard 实时日志"
    echo -e "8. 查看 Agent 实时日志"
    echo -e "9. 检查并更新哪吒"
    echo -e "10. 卸载哪吒面板"
    echo -e "11. 关闭 WebSSH（安全推荐）"
    echo -e "0. 退出脚本"
    echo -e "${GREEN}=======================================${NC}"
    echo -n "请输入选项 [0-11]: "
}

install_nezha() {
    install_deps
    echo "正在下载并执行完整安装脚本..."
    cat > nezha-full-install.sh << 'FULL'
#!/bin/bash
set -e
echo "=== 哪吒完整安装 ==="
apt-get install -y curl wget git tar nginx socat unzip
echo -n "请输入域名: "
read DOMAIN
curl -L https://raw.githubusercontent.com/nezhahq/scripts/main/install.sh -o nezha.sh && chmod +x nezha.sh
env NZ_DOMAIN=$DOMAIN NZ_PORT=8008 ./nezha.sh install
echo "安装完成！面板地址: https://$DOMAIN"
FULL
    chmod +x nezha-full-install.sh
    ./nezha-full-install.sh
}

while true; do
    show_menu
    read -r choice
    case $choice in
        1)
            echo "=== 系统信息 ==="
            cat /etc/os-release 2>/dev/null
            uname -a
            free -h
            df -h
            ;;
        2)
            echo "=== Docker ==="; docker ps | grep -E 'nezha|dashboard'
            echo -e "\n=== Agent ==="; ps aux | grep nezha-agent
            echo -e "\n=== Nginx ==="; systemctl status nginx --no-pager | head -15
            ;;
        3) install_nezha ;;
        4) docker restart nezha-dashboard 2>/dev/null || true; systemctl restart nginx nezha-agent; echo "重启完成" ;;
        5) docker stop nezha-dashboard 2>/dev/null || true; systemctl stop nginx nezha-agent; echo "已停止" ;;
        6) docker start nezha-dashboard 2>/dev/null || true; systemctl start nginx nezha-agent; echo "已启动" ;;
        7) docker logs -f --tail 100 nezha-dashboard ;;
        8) journalctl -u nezha-agent -f ;;
        9) cd /opt/nezha 2>/dev/null && ./nezha.sh install || echo "更新失败" ;;
        10) echo "确认卸载？(y/n)"; read c; [[ $c == "y" ]] && docker rm -f nezha-dashboard 2>/dev/null; rm -rf /opt/nezha; echo "卸载完成" ;;
        11) sed -i 's/enable_terminal: true/enable_terminal: false/' /opt/nezha/dashboard/data/config.yaml 2>/dev/null && echo "WebSSH 已关闭" ;;
        0) echo "退出"; exit 0 ;;
        *) echo "无效选项" ;;
    esac
    echo -e "\n按任意键返回菜单..."
    read -n 1
done
