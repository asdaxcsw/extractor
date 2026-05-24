#!/bin/bash

echo "=========================================="
echo "开始诊断网页服务问题..."
echo "=========================================="

# 1. 检测服务器IP
echo ""
echo "[1/8] 检测服务器IP..."
SERVER_IP=$(curl -s --connect-timeout 5 ifconfig.me || curl -s --connect-timeout 5 icanhazip.com || curl -s --connect-timeout 5 ipinfo.io/ip || curl -s --connect-timeout 5 api.ipify.org)
if [ -z "$SERVER_IP" ]; then
    echo "❌ 无法检测服务器IP"
    echo "尝试使用本地IP..."
    SERVER_IP=$(hostname -I | awk '{print $1}')
fi
echo "✓ 服务器IP: $SERVER_IP"

# 2. 检查PHP是否安装
echo ""
echo "[2/8] 检查PHP安装..."
if ! command -v php &> /dev/null; then
    echo "❌ PHP未安装，正在安装..."
    apt-get update -qq
    apt-get install -y php-cli php-curl curl jq psmisc lsof socat ufw
else
    echo "✓ PHP已安装: $(php -v | head -n 1)"
fi

# 3. 检查端口占用
echo ""
echo "[3/8] 检查端口占用..."
WEB_PORT=966
for port in {966..976}; do
    if ! lsof -i:$port &> /dev/null; then
        WEB_PORT=$port
        echo "✓ 找到可用端口: $WEB_PORT"
        break
    else
        echo "端口 $port 已被占用"
    fi
done

# 4. 停止旧进程
echo ""
echo "[4/8] 清理旧进程..."
pkill -f "php -S 0.0.0.0" 2>/dev/null
sleep 1
echo "✓ 已清理旧PHP进程"

# 5. 创建工作目录
echo ""
echo "[5/8] 创建工作目录..."
mkdir -p /var/www/html
chmod -R 777 /var/www/html
echo "[]" > /var/www/html/proxies.json
chmod 666 /var/www/html/proxies.json
echo "✓ 工作目录已创建"

# 6. 生成PHP文件
echo ""
echo "[6/8] 生成PHP网页..."
cat > /var/www/html/index.php << 'PHPEOF'
<?php
$configFile = 'proxies.json';
$serverIp = getenv('SERVER_IP') ?: '127.0.0.1';
$apiBaseMain = "https://webipapi.cliproxy.com/api/getIpInfo?key=5h3vezyqtraalznfgd8z";
$apiBaseBackup = "https://s5api.novproxy.com/api/getIpInfo?key=aeunxiovaoupb6vep6wi";

if (isset($_POST['clear'])) {
    $current = json_decode(file_get_contents($configFile), true) ?: [];
    foreach ($current as $item) {
        shell_exec("pkill -f 'socat.*TCP4-LISTEN:{$item['local_port']}'");
    }
    file_put_contents($configFile, json_encode([]));
    header("Location: index.php");
    exit;
}

if (isset($_POST['generate']) || isset($_POST['generate_backup'])) {
    $countries = ['JP', 'JP'];
    $country = $countries[array_rand($countries)];
    $randomApiPort = rand(433, 3000);
    
    if (isset($_POST['generate_backup'])) {
        $apiUrl = "{$apiBaseBackup}&port={$randomApiPort}&num=1&country={$country}&type=2";
        $channelName = "备用通道";
    } else {
        $apiUrl = "{$apiBaseMain}&port={$randomApiPort}&num=1&country={$country}&type=2";
        $channelName = "主通道";
    }
    
    $response = @file_get_contents($apiUrl);
    if ($response && substr_count(trim($response), ':') >= 3) {
        list($proxyHost, $proxyPort, $user, $pass) = explode(':', trim($response));
        
        do {
            $localPort = rand(9000, 20000);
            $check = shell_exec("lsof -i :{$localPort} 2>&1");
        } while (!empty($check));
        
        $cmdTcp = "setsid socat TCP4-LISTEN:{$localPort},reuseaddr,fork TCP4:{$proxyHost}:{$proxyPort} </dev/null >/dev/null 2>&1 &";
        shell_exec($cmdTcp);
        
        $current = json_decode(file_get_contents($configFile), true) ?: [];
        array_unshift($current, [
            'country' => $country,
            'ip' => $serverIp,
            'local_port' => $localPort,
            'user' => $user,
            'pass' => $pass,
            'channel' => $channelName,
            'status' => 'Running'
        ]);
        
        $current = array_slice($current, 0, 20);
        file_put_contents($configFile, json_encode($current));
    }
    header("Location: index.php");
    exit;
}

$data = json_decode(file_get_contents($configFile), true) ?: [];
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
    <h2>中转管理面板 (<?php echo $serverIp; ?>)</h2>
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
            <th>中转IP</th>
            <th>中转端口</th>
            <th>认证账号</th>
            <th>认证密码</th>
            <th>状态</th>
        </tr>
        <?php foreach ($data as $row): ?>
        <tr>
            <td><?php echo htmlspecialchars($row['country']); ?></td>
            <td><strong><?php echo htmlspecialchars(isset($row['channel']) ? $row['channel'] : '主通道'); ?></strong></td>
            <td><code><?php echo htmlspecialchars($row['ip']); ?></code></td>
            <td><code style="color:#1a73e8; font-weight:bold;"><?php echo htmlspecialchars($row['local_port']); ?></code></td>
            <td><?php echo htmlspecialchars($row['user']); ?></td>
            <td><?php echo htmlspecialchars($row['pass']); ?></td>
            <td style="color: green; font-weight: bold;">✓ 运行中</td>
        </tr>
        <?php endforeach; ?>
    </table>
</body>
</html>
PHPEOF

echo "✓ PHP文件已生成"

# 7. 配置防火墙
echo ""
echo "[7/8] 配置防火墙..."
ufw disable 2>/dev/null
iptables -F 2>/dev/null
echo "✓ 防火墙已开放"

# 8. 启动Web服务
echo ""
echo "[8/8] 启动Web服务..."
cd /var/www/html
export SERVER_IP=$SERVER_IP
nohup php -S 0.0.0.0:$WEB_PORT > /tmp/php_server.log 2>&1 &
PHP_PID=$!
sleep 2

# 验证服务是否启动
if ps -p $PHP_PID > /dev/null; then
    echo "✓ Web服务已启动 (PID: $PHP_PID)"
else
    echo "❌ Web服务启动失败，查看日志:"
    cat /tmp/php_server.log
    exit 1
fi

# 测试本地访问
echo ""
echo "测试本地访问..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:$WEB_PORT)
if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ 本地访问成功 (HTTP $HTTP_CODE)"
else
    echo "❌ 本地访问失败 (HTTP $HTTP_CODE)"
    echo "PHP错误日志:"
    cat /tmp/php_server.log
fi

echo ""
echo "=========================================="
echo "✓ 部署完成！"
echo "=========================================="
echo "服务器IP: $SERVER_IP"
echo "Web端口: $WEB_PORT"
echo "访问地址: http://$SERVER_IP:$WEB_PORT"
echo ""
echo "如果无法访问，请检查:"
echo "1. 云服务器安全组是否开放端口 $WEB_PORT"
echo "2. 运行命令查看服务状态: ps aux | grep php"
echo "3. 查看PHP日志: cat /tmp/php_server.log"
echo "4. 测试本地访问: curl http://127.0.0.1:$WEB_PORT"
echo "=========================================="
