#!/bin/bash

# ================= 自动配置区 =================
# 自动检测服务器公网IP
echo "正在自动检测服务器公网IP..."
SERVER_IP=$(curl -s ifconfig.me || curl -s icanhazip.com || curl -s ipinfo.io/ip || curl -s api.ipify.org)

if [ -z "$SERVER_IP" ]; then
    echo "❌ 无法自动检测服务器IP，请检查网络连接"
    exit 1
fi

echo "✓ 检测到服务器IP: $SERVER_IP"

# 自动检测可用端口（从966开始尝试）
WEB_PORT=966
while lsof -i:$WEB_PORT >/dev/null 2>&1; do
    echo "端口 $WEB_PORT 已被占用，尝试下一个..."
    WEB_PORT=$((WEB_PORT + 1))
done
echo "✓ 使用Web端口: $WEB_PORT"

# API配置（保持原始完整链接）
API_BASE_MAIN="https://webipapi.cliproxy.com/api/getIpInfo?key=5h3vezyqtraalznfgd8z"
API_BASE_BACKUP="https://s5api.novproxy.com/api/getIpInfo?key=aeunxiovaoupb6vep6wi"
DATA_FILE="/var/www/html/proxies.json"
# ==============================================

# 1. 环境修复与权限开放
echo "正在修复系统环境与权限..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y ufw socat php-cli php-curl curl jq psmisc lsof >/dev/null 2>&1

# 开放所有端口并关闭防火墙
ufw disable >/dev/null 2>&1
iptables -F >/dev/null 2>&1
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# 创建工作目录并开放最高权限
mkdir -p /var/www/html
chmod -R 777 /var/www/html
if [ ! -f "$DATA_FILE" ]; then
    echo "[]" > $DATA_FILE
fi
chmod 666 $DATA_FILE

# 2. 生成 PHP 后端逻辑（动态注入服务器IP和API配置）
cat << EOF > /var/www/html/index.php
<?php
\$configFile = 'proxies.json';
\$serverIp = "$SERVER_IP";
\$apiBaseMain = "$API_BASE_MAIN";
\$apiBaseBackup = "$API_BASE_BACKUP";

// 处理清理请求
if (isset(\$_POST['clear'])) {
    \$current = json_decode(file_get_contents(\$configFile), true) ?: [];
    foreach (\$current as \$item) {
        shell_exec("pkill -f 'socat.*TCP4-LISTEN:{\$item['local_port']}'");
    }
    file_put_contents(\$configFile, json_encode([]));
    header("Location: index.php");
    exit;
}

// 处理生成请求（主通道或备用通道）
if (isset(\$_POST['generate']) || isset(\$_POST['generate_backup'])) {
    \$countries = ['JP', 'JP'];
    \$country = \$countries[array_rand(\$countries)];
    \$randomApiPort = rand(433, 3000);
    
    if (isset(\$_POST['generate_backup'])) {
        \$apiUrl = "{\$apiBaseBackup}&port={\$randomApiPort}&num=1&country={\$country}&type=2";
        \$channelName = "备用通道";
    } else {
        \$apiUrl = "{\$apiBaseMain}&port={\$randomApiPort}&num=1&country={\$country}&type=2";
        \$channelName = "主通道";
    }
    
    \$response = @file_get_contents(\$apiUrl);
    if (\$response && substr_count(trim(\$response), ':') >= 3) {
        list(\$proxyHost, \$proxyPort, \$user, \$pass) = explode(':', trim(\$response));
        
        do {
            \$localPort = rand(9000, 20000);
            \$check = shell_exec("lsof -i :{\$localPort} 2>&1");
        } while (!empty(\$check));
        
        \$cmdTcp = "setsid socat TCP4-LISTEN:{\$localPort},reuseaddr,fork TCP4:{\$proxyHost}:{\$proxyPort} </dev/null >/dev/null 2>&1 &";
        shell_exec(\$cmdTcp);
        
        \$current = json_decode(file_get_contents(\$configFile), true) ?: [];
        array_unshift(\$current, [
            'country' => \$country,
            'ip' => \$serverIp,
            'local_port' => \$localPort,
            'user' => \$user,
            'pass' => \$pass,
            'channel' => \$channelName,
            'status' => 'Running'
        ]);
        
        \$current = array_slice(\$current, 0, 20);
        file_put_contents(\$configFile, json_encode(\$current));
    }
    header("Location: index.php");
    exit;
}

\$data = json_decode(file_get_contents(\$configFile), true) ?: [];
?>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Proxy Manager</title>
    <style>
        body { font-family: sans-serif; background: #f4f4f4; padding: 20px; }
        table { width: 100%; border-collapse: collapse; background: #fff; margin-top: 20px; }
        th, td { padding: 12px; border: 1px solid #ddd; text-align: left; }
        th { background: #007bff; color: white; }
        .btn { padding: 10px 20px; cursor: pointer; border: none; color: white; border-radius: 4px; margin-right: 5px; font-weight: bold; }
        .gen { background: #28a745; }
        .backup { background: #17a2b8; }
        .clear { background: #dc3545; }
        .tip { background: #fff3cd; color: #856404; padding: 15px; border-radius: 4px; margin-bottom: 20px; border: 1px solid #ffeeba; }
    </style>
</head>
<body>
    <h2>中转管理面板 (<?php echo \$serverIp; ?>)</h2>
    
    <div class="tip">
        <strong>⚡️ 独立进程守护已生效：</strong> 
        生成数据后，您可以<strong>直接关闭本网页</strong>，中转进程已经和网页生命周期完全剥离，网络保持永久畅通。
    </div>

    <form method="post" style="display: inline;">
        <button type="submit" name="generate" class="btn gen">生成新数据 (主通道)</button>
    </form>
    <form method="post" style="display: inline;">
        <button type="submit" name="generate_backup" class="btn backup">生成新数据 (备用通道)</button>
    </form>
    <form method="post" style="display: inline;">
        <button type="submit" name="clear" class="btn clear" onclick="return confirm('确定要清理所有通道的中转进程和历史吗？')">一键清理历史</button>
    </form>

    <table>
        <tr>
            <th>地区</th>
            <th>来源通道</th>
            <th>中转IP (服务器IP)</th>
            <th>中转端口</th>
            <th>认证账号</th>
            <th>认证密码</th>
            <th>SOCAT状态</th>
        </tr>
        <?php foreach (\$data as \$row): ?>
        <tr>
            <td><?php echo htmlspecialchars(\$row['country']); ?></td>
            <td><strong><?php echo htmlspecialchars(isset(\$row['channel']) ? \$row['channel'] : '主通道'); ?></strong></td>
            <td><code><?php echo htmlspecialchars(\$row['ip']); ?></code></td>
            <td><code style="color:#1a73e8; font-weight:bold;"><?php echo htmlspecialchars(\$row['local_port']); ?></code></td>
            <td><?php echo htmlspecialchars(\$row['user']); ?></td>
            <td><?php echo htmlspecialchars(\$row['pass']); ?></td>
            <td style="color: green; font-weight: bold;">✓ 永久运行中</td>
        </tr>
        <?php endforeach; ?>
    </table>
</body>
</html>
EOF

# 3. 强力重启 Web 服务
echo "正在强力重启 Web 服务..."
pkill -f "php -S 0.0.0.0:$WEB_PORT" >/dev/null 2>&1
sleep 0.5
PORT_PID=$(lsof -t -i:$WEB_PORT 2>/dev/null)
if [ ! -z "$PORT_PID" ]; then
    kill -9 $PORT_PID >/dev/null 2>&1
fi

nohup php -S 0.0.0.0:$WEB_PORT -t /var/www/html/ </dev/null >/dev/null 2>&1 &

echo "================================================"
echo "✓ 双通道常驻版本部署完成！"
echo "✓ 服务器IP: $SERVER_IP (自动检测)"
echo "✓ Web端口: $WEB_PORT (自动分配)"
echo "✓ 访问地址: http://$SERVER_IP:$WEB_PORT"
echo "================================================"
echo "核心特性："
echo "  • 自动检测服务器公网IP"
echo "  • 自动分配可用端口"
echo "  • 双通道API完整保留"
echo "  • 进程永久守护运行"
echo "================================================"
