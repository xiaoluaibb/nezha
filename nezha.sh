#!/bin/bash
# 哪吒监控 一键管理脚本 - nezha.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
    echo -e "12. 修改域名配置"
    echo -e "13. 管理定时更新任务"
    echo -e "0. 退出脚本"
    echo -e "${GREEN}=======================================${NC}"
    echo -n "请输入选项 [0-13]: "
}

view_system_info() {
    echo -e "${YELLOW}=== 系统信息 ===${NC}"
    cat /etc/os-release 2>/dev/null || echo "无法读取系统版本"
    uname -a
    free -h
    df -h
}

view_status() {
    echo -e "${YELLOW}=== Docker 容器 ===${NC}"
    docker ps | grep -E 'nezha|dashboard' || echo "未找到 Docker 容器"
    echo -e "\n${YELLOW}=== Agent 进程 ===${NC}"
    ps aux | grep nezha-agent || echo "Agent 未运行"
    echo -e "\n${YELLOW}=== Nginx 状态 ===${NC}"
    systemctl status nginx --no-pager | head -n 15
}

install_nezha() {
    echo "正在下载并执行完整安装脚本..."
    wget -O nezha-full-install.sh https://raw.githubusercontent.com/xiaoluaibb/nezha/refs/heads/main/nezha-full-install.sh
    chmod +x nezha-full-install.sh
    ./nezha-full-install.sh
}

case_menu() {
    case $1 in
        1) view_system_info ;;
        2) view_status ;;
        3) install_nezha ;;
        4) echo "正在重启..."; docker restart nezha-dashboard 2>/dev/null || true; systemctl restart nginx nezha-agent; echo "重启完成" ;;
        5) echo "正在停止..."; docker stop nezha-dashboard 2>/dev/null || true; systemctl stop nginx nezha-agent; echo "已停止" ;;
        6) echo "正在启动..."; docker start nezha-dashboard 2>/dev/null || true; systemctl start nginx nezha-agent; echo "已启动" ;;
        7) echo "按 Ctrl+C 退出日志查看"; docker logs -f --tail 100 nezha-dashboard ;;
        8) echo "按 Ctrl+C 退出日志查看"; journalctl -u nezha-agent -f ;;
        9) echo "检查更新..."; cd /opt/nezha 2>/dev/null && ./nezha.sh install || echo "未找到更新脚本" ;;
        10) echo "警告：即将卸载！确认？(y/n)"; read confirm; [[ "$confirm" == "y" ]] && docker rm -f nezha-dashboard 2>/dev/null; rm -rf /opt/nezha; rm -f /etc/nginx/sites-enabled/nezha; echo "卸载完成" ;;
        11) sed -i 's/enable_terminal: true/enable_terminal: false/' /opt/nezha/dashboard/data/config.yaml 2>/dev/null && echo "WebSSH 已关闭" || echo "未找到配置文件" ;;
        12) echo "请输入新域名："; read domain; sed -i "s/server_name .*/server_name $domain;/" /etc/nginx/sites-available/nezha 2>/dev/null; nginx -t && systemctl reload nginx && echo "域名修改完成" ;;
        13) echo "1) 添加定时任务  2) 删除定时任务"; read t; 
            if [ "$t" = "1" ]; then
                echo "0 3 * * * root cd /opt/nezha && ./nezha.sh install" > /etc/cron.d/nezha-update
                echo "定时任务已添加（每天 3:00）"
            elif [ "$t" = "2" ]; then
                rm -f /etc/cron.d/nezha-update
                echo "定时任务已删除"
            fi ;;
        0) echo "退出脚本"; exit 0 ;;
        *) echo "无效选项，请重新输入" ;;
    esac
}

while true; do
    show_menu
    read -r choice
    case_menu "$choice"
    echo -e "\n${GREEN}按任意键返回主菜单...${NC}"
    read -n 1
done
