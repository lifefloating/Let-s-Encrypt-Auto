#!/bin/bash

# Let's Encrypt证书维护工具
# 作者: fuyou imshuazi@126.com
# 版本: 1.0.0

# 设置颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复默认颜色

# 检查acme.sh是否已安装
check_acme_installed() {
  if [ ! -f ~/.acme.sh/acme.sh ]; then
    echo -e "${RED}错误: acme.sh 未安装!${NC}"
    echo "请先运行 ssl-auto.sh 申请证书后再使用此维护工具。"
    exit 1
  fi
}

# 显示帮助信息
show_help() {
  echo -e "${BLUE}Let's Encrypt证书维护工具${NC}"
  echo ""
  echo "用法: $0 [命令] [选项]"
  echo ""
  echo "命令:"
  echo "  list                     列出所有已申请的证书及其状态"
  echo "  info <域名>              显示指定域名证书的详细信息"
  echo "  renew <域名>             手动续期指定域名的证书"
  echo "  renew-all                手动续期所有证书"
  echo "  revoke <域名>            吊销指定域名的证书"
  echo "  remove <域名>            删除指定域名的证书"
  echo "  check-cron              检查定时任务是否正确配置"
  echo "  reinstall-cron          重新安装定时任务"
  echo "  update                  更新acme.sh客户端"
  echo "  help                    显示此帮助信息"
  echo ""
  echo "示例:"
  echo "  $0 list"
  echo "  $0 renew example.com"
  echo "  $0 update"
  echo ""
}

# 列出所有证书
list_certs() {
  echo -e "${BLUE}已申请的证书列表:${NC}"
  echo "------------------------------------"
  ~/.acme.sh/acme.sh --list
  
  # 显示检查提示
  echo ""
  echo -e "${YELLOW}提示: 使用 '$0 info <域名>' 查看指定域名证书的详细信息${NC}"
}

# 显示证书详细信息
show_cert_info() {
  local domain="$1"
  
  # 检查参数
  if [ -z "$domain" ]; then
    echo -e "${RED}错误: 必须指定域名${NC}"
    echo "用法: $0 info <域名>"
    exit 1
  fi
  
  # 检查证书是否存在
  if [ ! -d ~/.acme.sh/"$domain" ]; then
    echo -e "${RED}错误: 找不到域名 '$domain' 的证书${NC}"
    echo "请使用 '$0 list' 查看所有已申请的证书。"
    exit 1
  fi
  
  echo -e "${BLUE}证书详细信息 - $domain:${NC}"
  echo "------------------------------------"
  
  # 获取证书到期时间
  expiry_date=$(openssl x509 -noout -enddate -in ~/.acme.sh/"$domain"/"$domain".cer | cut -d= -f2)
  current_date=$(date +%s)
  expiry_date_seconds=$(date -d "$expiry_date" +%s)
  days_left=$(( (expiry_date_seconds - current_date) / 86400 ))
  
  # 显示证书信息
  echo -e "域名: ${GREEN}$domain${NC}"
  echo -e "证书路径: ${YELLOW}~/.acme.sh/$domain/${NC}"
  echo -e "证书文件: ${YELLOW}~/.acme.sh/$domain/$domain.cer${NC}"
  echo -e "密钥文件: ${YELLOW}~/.acme.sh/$domain/$domain.key${NC}"
  echo -e "完整链文件: ${YELLOW}~/.acme.sh/$domain/fullchain.cer${NC}"
  echo -e "到期日期: ${YELLOW}$expiry_date${NC}"
  
  # 显示剩余天数及状态
  if [ $days_left -lt 0 ]; then
    echo -e "状态: ${RED}已过期 ($days_left 天)${NC}"
  elif [ $days_left -lt 10 ]; then
    echo -e "状态: ${RED}即将过期 (剩余 $days_left 天)${NC}"
  elif [ $days_left -lt 30 ]; then
    echo -e "状态: ${YELLOW}需要关注 (剩余 $days_left 天)${NC}"
  else
    echo -e "状态: ${GREEN}正常 (剩余 $days_left 天)${NC}"
  fi
  
  echo ""
  echo -e "${BLUE}证书内容:${NC}"
  echo "------------------------------------"
  openssl x509 -noout -text -in ~/.acme.sh/"$domain"/"$domain".cer | grep -E 'Subject:|Issuer:|Not Before:|Not After :|DNS:'
}

# 手动续期指定证书
renew_cert() {
  local domain="$1"
  local force="$2"
  
  # 检查参数
  if [ -z "$domain" ]; then
    echo -e "${RED}错误: 必须指定域名${NC}"
    echo "用法: $0 renew <域名> [--force]"
    exit 1
  fi
  
  # 检查证书是否存在
  if [ ! -d ~/.acme.sh/"$domain" ]; then
    echo -e "${RED}错误: 找不到域名 '$domain' 的证书${NC}"
    echo "请使用 '$0 list' 查看所有已申请的证书。"
    exit 1
  fi
  
  echo -e "${BLUE}开始续期证书 - $domain${NC}"
  echo "------------------------------------"
  
  # 根据是否强制续期执行不同命令
  if [ "$force" == "--force" ]; then
    echo "强制续期模式..."
    ~/.acme.sh/acme.sh --renew -d "$domain" --force
  else
    ~/.acme.sh/acme.sh --renew -d "$domain"
  fi
  
  # 检查续期结果
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}证书续期完成!${NC}"
    echo "请检查续期是否成功，如果证书尚未到期，可能不会实际更新证书。"
    echo "可以使用 --force 参数强制续期: $0 renew $domain --force"
  else
    echo -e "${RED}证书续期失败!${NC}"
    echo "请检查日志文件 ~/.acme.sh/acme.sh.log 获取更多信息。"
  fi
}

# 续期所有证书
renew_all_certs() {
  local force="$1"
  
  echo -e "${BLUE}开始续期所有证书${NC}"
  echo "------------------------------------"
  
  # 根据是否强制续期执行不同命令
  if [ "$force" == "--force" ]; then
    echo "强制续期模式..."
    ~/.acme.sh/acme.sh --renew-all --force
  else
    ~/.acme.sh/acme.sh --renew-all
  fi
  
  # 检查续期结果
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}所有证书续期操作完成!${NC}"
    echo "请检查日志文件 ~/.acme.sh/acme.sh.log 获取详细信息。"
  else
    echo -e "${RED}部分证书续期可能失败!${NC}"
    echo "请检查日志文件 ~/.acme.sh/acme.sh.log 获取更多信息。"
  fi
}

# 吊销证书
revoke_cert() {
  local domain="$1"
  
  # 检查参数
  if [ -z "$domain" ]; then
    echo -e "${RED}错误: 必须指定域名${NC}"
    echo "用法: $0 revoke <域名>"
    exit 1
  fi
  
  # 检查证书是否存在
  if [ ! -d ~/.acme.sh/"$domain" ]; then
    echo -e "${RED}错误: 找不到域名 '$domain' 的证书${NC}"
    echo "请使用 '$0 list' 查看所有已申请的证书。"
    exit 1
  fi
  
  echo -e "${YELLOW}警告: 您即将吊销域名 '$domain' 的证书${NC}"
  echo "吊销操作不可逆，请确认此操作。"
  read -p "是否继续? (y/n): " confirm
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "操作已取消"
    exit 0
  fi
  
  echo -e "${BLUE}开始吊销证书 - $domain${NC}"
  echo "------------------------------------"
  
  ~/.acme.sh/acme.sh --revoke -d "$domain"
  
  # 检查吊销结果
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}证书已成功吊销!${NC}"
  else
    echo -e "${RED}证书吊销失败!${NC}"
    echo "请检查日志文件 ~/.acme.sh/acme.sh.log 获取更多信息。"
  fi
}

# 删除证书
remove_cert() {
  local domain="$1"
  
  # 检查参数
  if [ -z "$domain" ]; then
    echo -e "${RED}错误: 必须指定域名${NC}"
    echo "用法: $0 remove <域名>"
    exit 1
  fi
  
  # 检查证书是否存在
  if [ ! -d ~/.acme.sh/"$domain" ]; then
    echo -e "${RED}错误: 找不到域名 '$domain' 的证书${NC}"
    echo "请使用 '$0 list' 查看所有已申请的证书。"
    exit 1
  fi
  
  echo -e "${YELLOW}警告: 您即将删除域名 '$domain' 的证书${NC}"
  echo "删除操作不可逆，请确认此操作。"
  read -p "是否继续? (y/n): " confirm
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "操作已取消"
    exit 0
  fi
  
  echo -e "${BLUE}开始删除证书 - $domain${NC}"
  echo "------------------------------------"
  
  ~/.acme.sh/acme.sh --remove -d "$domain"
  
  # 检查删除结果
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}证书已成功删除!${NC}"
  else
    echo -e "${RED}证书删除失败!${NC}"
    echo "请检查日志文件 ~/.acme.sh/acme.sh.log 获取更多信息。"
  fi
}

# 检查crontab定时任务
check_cron() {
  echo -e "${BLUE}检查acme.sh定时任务配置${NC}"
  echo "------------------------------------"
  
  # 检查crontab中是否有acme.sh的定时任务
  cron_entry=$(crontab -l 2>/dev/null | grep -c "acme.sh")
  
  if [ "$cron_entry" -gt 0 ]; then
    echo -e "${GREEN}定时任务已配置:${NC}"
    crontab -l | grep "acme.sh"
    echo ""
    echo "acme.sh将根据上述配置自动检查并续期证书"
  else
    echo -e "${RED}未找到acme.sh定时任务!${NC}"
    echo "推荐使用 '$0 reinstall-cron' 命令重新安装定时任务。"
  fi
}

# 重新安装crontab定时任务
reinstall_cron() {
  echo -e "${BLUE}重新安装acme.sh定时任务${NC}"
  echo "------------------------------------"
  
  ~/.acme.sh/acme.sh --install-cronjob
  
  # 检查安装结果
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}定时任务已成功安装!${NC}"
    echo "当前配置:"
    crontab -l | grep "acme.sh"
  else
    echo -e "${RED}定时任务安装失败!${NC}"
    echo "请检查日志获取更多信息。"
  fi
}

# 更新acme.sh客户端
update_acme() {
  echo -e "${BLUE}更新acme.sh客户端${NC}"
  echo "------------------------------------"
  
  ~/.acme.sh/acme.sh --upgrade
  
  # 检查更新结果
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}acme.sh客户端已更新至最新版本!${NC}"
  else
    echo -e "${RED}acme.sh客户端更新失败!${NC}"
    echo "请检查网络连接或日志获取更多信息。"
  fi
}

# 主函数
main() {
  # 检查acme.sh是否已安装
  check_acme_installed
  
  # 解析命令
  local command="$1"
  shift
  
  case "$command" in
    list)
      list_certs
      ;;
    info)
      show_cert_info "$1"
      ;;
    renew)
      renew_cert "$1" "$2"
      ;;
    renew-all)
      renew_all_certs "$1"
      ;;
    revoke)
      revoke_cert "$1"
      ;;
    remove)
      remove_cert "$1"
      ;;
    check-cron)
      check_cron
      ;;
    reinstall-cron)
      reinstall_cron
      ;;
    update)
      update_acme
      ;;
    help|--help|-h)
      show_help
      ;;
    *)
      echo -e "${RED}错误: 未知命令 '$command'${NC}"
      show_help
      exit 1
      ;;
  esac
}

# 如果没有参数，显示帮助信息
if [ $# -eq 0 ]; then
  show_help
  exit 1
fi

# 执行主函数
main "$@" 