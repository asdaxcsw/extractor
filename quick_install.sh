#!/bin/bash

echo "=========================================="
echo "快速部署代理中转管理系统"
echo "=========================================="

# 检测服务器IP
echo ""
echo "[1/6] 检测服务器IP..."
SERVER_IP=$(timeout 5 curl -s ifconfig.me 2>/dev/null || timeout 5 curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')
if [ -z "$SERVER_IP" ]; then
    echo "❌ 无法检测IP，请手动输入服务器公网IP:"
    read SERVER_IP
fi
echo "✓ 服务器IP: $SERVER_IP"

# 检测可用端口
echo ""
echo "[2/6] 检测可用端口..."
WEB_PORT=966
if command -v lsof &> /dev/null; then
    while lsof -i:$WEB_PORT &> /dev/null && [ $WEB_PORT -lt 980 ]; do
        WEB_PORT=$((WEB_PORT + 1))
    done
fi
echo "✓ 使用端口: $WEB_PORT"

# 快速安装依赖（跳过已安装的）
echo ""
echo "[3/6] 检查并安装依赖..."
export DEBIAN_FRONTEND=noninteractive

# 只安装缺失的包
MISSING_PKGS=""
for pkg in php-cli php-curl curl socat lsof; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "需要安装:$MISSING_PKGS"
    apt-get update -qq -o DPkg::Lock::Timeout=60 2>/dev/null || true
    apt-get install -y --no-install-recommends $MISSING_PKGS 2>/dev/null || {
        echo "⚠ 部分包安装失败，继续尝试..."
    }
else
    echo "✓ 所有依赖已安装"
fi

# 配置防火墙
echo ""
echo "[4/6] 配置防火墙..."
if command -v ufw &> /dev/null; then
    ufw disable 2>/dev/null || true
fi
iptables -F 2>/dev/null || true
echo "✓ 防火墙已配置"

# 创建工作目录
echo ""
echo "[5/6] 创建工作目录..."
mkdir -p /var/www/html
chmod 755 /var/www/html
echo "[]" > /var/www/html/proxies.json
chmod 666 /var/www/html/proxies.json

# 生成PHP文件
cat > /var/www/html/index.php << 'PHPCODE'
<?php
$configFile = 'proxies.json';
$serverIp = getenv('SERVER_IP') ?: $_SERVER['SERVER_ADDR'] ?? '127.0.0.1';
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
    $country = 'JP';
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
        list($proxyHost, $proxyPort, $user, $pass) = explode(':', trim($response), 4);
        
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
    <title>代理中转管理</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f5f7fa; padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; }
        h2 { color: #2c3e50; margin-bottom: 20px; }
        .info { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin-bottom: 20px; border-radius: 4px; }
        .controls { margin-bottom: 20px; }
        .btn { padding: 12px 24px; border: none; border-radius: 4px; cursor: pointer; font-size: 14px; font-weight: 600; margin-right: 10px; transition: all 0.3s; }
        .btn:hover { transform: translateY(-2px); box-shadow: 0 4px 8px rgba(0,0,0,0.2); }
        .btn-primary { background: #28a745; color: white; }
        .btn-info { background: #17a2b8; color: white; }
        .btn-danger { background: #dc3545; color: white; }
        table { width: 100%; background: white; border-radius: 8px; overflow: hidden; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        th, td { padding: 14px; text-align: left; border-bottom: 1px solid #e9ecef; }
        th { background: #007bff; color: white; font-weight: 600; }
        tr:hover { background: #f8f9fa; }
        code { background: #f4f4f4; padding: 4px 8px; border-radius: 3px; font-family: monospace; }
        .status { color: #28a745; font-weight: 600; }
    </style>
</head>
<body>
    <div class="container">
        <h2>🚀 代理中转管理面板 (<?php echo $serverIp; ?>)</h2>
        
        <div class="info">
            <strong>💡 提示：</strong> 生成数据后可直接关闭网页，中转进程已独立运行，不受网页影响。
        </div>

        <div class="controls">
            <form method="post" style="display: inline;">
                <button type="submit" name="generate" class="btn btn-primary">生成新代理 (主通道)</button>
            </form>
            <form method="post" style="display: inline;">
                <button type="submit" name="generate_backup" class="btn btn-info">生成新代理 (备用通道)</button>
            </form>
            <form method="post" style="display: inline;">
                <button type="submit" name="clear" class="btn btn-danger" onclick="return confirm('确定清理所有代理？')">清理全部</button>
            </form>
        </div>

        <table>
            <thead>
                <tr>
                    <th>地区</th>
                    <th>通道</th>
                    <th>中转IP</th>
                    <th>中转端口</th>
                    <th>用户名</th>
                    <th>密码</th>
                    <th>状态</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($data)): ?>
                <tr><td colspan="7" style="text-align: center; color: #999;">暂无数据，点击上方按钮生成代理</td></tr>
                <?php else: ?>
                <?php foreach ($data as $row): ?>
                <tr>
                    <td><?php echo htmlspecialchars($row['country']); ?></td>
                    <td><strong><?php echo htmlspecialchars($row['channel'] ?? '主通道'); ?></strong></td>
                    <td><code><?php echo htmlspecialchars($row['ip']); ?></code></td>
                    <td><code style="color:#007bff; font-weight:bold;"><?php echo htmlspecialchars($row['local_port']); ?></code></td>
                    <td><?php echo htmlspecialchars($row['user']); ?></td>
                    <td><?php echo htmlspecialchars($row['pass']); ?></td>
                    <td class="status">✓ 运行中</td>
                </tr>
                <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
</body>
</html>
PHPCODE

echo "✓ PHP文件已生成"

# 启动Web服务
echo ""
echo "[6/6] 启动Web服务..."
pkill -f "php -S 0.0.0.0:$WEB_PORT" 2>/dev/null
sleep 1

cd /var/www/html
export SERVER_IP=$SERVER_IP
nohup php -S 0.0.0.0:$WEB_PORT > /tmp/php_server.log 2>&1 &
sleep 2

# 验证服务
if pgrep -f "php -S 0.0.0.0:$WEB_PORT" > /dev/null; then
    echo "✓ Web服务已启动"
else
    echo "⚠ 服务可能未正常启动，查看日志: cat /tmp/php_server.log"
fi

echo ""
echo "=========================================="
echo "✓ 部署完成！"
echo "=========================================="
echo "访问地址: http://$SERVER_IP:$WEB_PORT"
echo ""
echo "如果无法访问，请检查:"
echo "1. 云服务器安全组是否开放端口 $WEB_PORT"
echo "2. 查看服务状态: ps aux | grep php"
echo "3. 查看日志: cat /tmp/php_server.log"
echo "=========================================="
