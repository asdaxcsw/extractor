#!/bin/bash

echo "=========================================="
echo "代理中转管理系统 - 一键部署"
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

# 快速安装依赖
echo ""
echo "[3/6] 检查并安装依赖..."
export DEBIAN_FRONTEND=noninteractive

MISSING_PKGS=""
for pkg in php-cli php-curl curl socat lsof; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "需要安装:$MISSING_PKGS"
    apt-get update -qq -o DPkg::Lock::Timeout=60 2>/dev/null || true
    apt-get install -y --no-install-recommends $MISSING_PKGS 2>/dev/null || true
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

# 生成完整PHP文件
cat > /var/www/html/index.php << 'PHPEOF'
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
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>代理中转管理系统</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Microsoft YaHei",sans-serif;font-size:14px;line-height:1.6;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;padding:30px 20px}
.container{max-width:1400px;margin:0 auto}
.header{background:rgba(255,255,255,.95);backdrop-filter:blur(10px);border-radius:16px;padding:30px;margin-bottom:24px;box-shadow:0 8px 32px rgba(0,0,0,.1)}
.header h1{font-size:28px;font-weight:700;color:#1a202c;margin-bottom:8px}
.header .subtitle{font-size:14px;color:#718096;font-weight:400}
.info-card{background:linear-gradient(135deg,#ffeaa7 0%,#fdcb6e 100%);border-radius:12px;padding:18px 24px;margin-bottom:24px;box-shadow:0 4px 16px rgba(253,203,110,.3)}
.info-card strong{font-size:14px;font-weight:600;color:#2d3436}
.info-card span{font-size:14px;color:#2d3436;font-weight:400}
.info-card .server-ip{display:inline-block;background:#fff;padding:4px 12px;border-radius:6px;margin-left:8px;font-family:monospace;color:#667eea;font-weight:600}
.controls{background:rgba(255,255,255,.95);backdrop-filter:blur(10px);border-radius:16px;padding:24px;margin-bottom:24px;box-shadow:0 8px 32px rgba(0,0,0,.1);display:flex;gap:12px;flex-wrap:wrap}
.btn{padding:12px 28px;border:none;border-radius:10px;cursor:pointer;font-size:14px;font-weight:600;transition:all .3s cubic-bezier(.4,0,.2,1);box-shadow:0 4px 12px rgba(0,0,0,.15);font-family:inherit}
.btn:hover{transform:translateY(-2px);box-shadow:0 8px 20px rgba(0,0,0,.2)}
.btn:active{transform:translateY(0)}
.btn-primary{background:linear-gradient(135deg,#11998e 0%,#38ef7d 100%);color:#fff}
.btn-info{background:linear-gradient(135deg,#4facfe 0%,#00f2fe 100%);color:#fff}
.btn-danger{background:linear-gradient(135deg,#ff416c 0%,#ff4b2b 100%);color:#fff}
.table-container{background:rgba(255,255,255,.95);backdrop-filter:blur(10px);border-radius:16px;overflow:hidden;box-shadow:0 8px 32px rgba(0,0,0,.1)}
table{width:100%;border-collapse:collapse}
thead{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%)}
th{padding:16px;text-align:left;font-size:14px;font-weight:600;color:#fff;text-transform:uppercase;letter-spacing:.5px}
td{padding:16px;font-size:14px;color:#2d3436;border-bottom:1px solid #e9ecef;font-weight:400}
tbody tr{transition:all .2s ease}
tbody tr:hover{background:#f8f9fa}
tbody tr:last-child td{border-bottom:none}
.empty-state{text-align:center;padding:60px 20px;color:#a0aec0;font-size:14px}
.badge{display:inline-block;padding:6px 12px;border-radius:20px;font-size:13px;font-weight:600}
.badge-country{background:linear-gradient(135deg,#fa709a 0%,#fee140 100%);color:#fff}
.badge-channel{background:linear-gradient(135deg,#30cfd0 0%,#330867 100%);color:#fff}
.badge-status{background:linear-gradient(135deg,#11998e 0%,#38ef7d 100%);color:#fff}
code{background:#f1f3f5;padding:6px 12px;border-radius:6px;font-family:"SF Mono",Monaco,Consolas,monospace;font-size:13px;color:#495057;font-weight:500}
.code-highlight{color:#667eea;font-weight:600}
@media (max-width:768px){
body{padding:15px;font-size:13px}
.header{padding:20px}
.header h1{font-size:22px}
.controls{padding:16px}
.btn{padding:10px 20px;font-size:13px}
th,td{padding:12px;font-size:13px}
}
</style>
</head>
<body>
<div class="container">
<div class="header">
<h1>代理中转管理系统</h1>
<div class="subtitle">当前服务器 <code class="code-highlight"><?php echo $serverIp; ?></code></div>
</div>
<div class="info-card">
<strong>智能守护模式</strong>
<span>生成代理后可直接关闭网页，中转进程已独立运行，永久保持在线状态</span>
<span class="server-ip"><?php echo $serverIp; ?></span>
</div>
<div class="controls">
<form method="post" style="display:inline">
<button type="submit" name="generate" class="btn btn-primary">生成新代理 (主通道)</button>
</form>
<form method="post" style="display:inline">
<button type="submit" name="generate_backup" class="btn btn-info">生成新代理 (备用通道)</button>
</form>
<form method="post" style="display:inline">
<button type="submit" name="clear" class="btn btn-danger" onclick="return confirm('确定要清理所有代理进程吗？')">清理全部</button>
</form>
</div>
<div class="table-container">
<table>
<thead>
<tr>
<th>地区</th>
<th>通道来源</th>
<th>中转 IP</th>
<th>中转端口</th>
<th>用户名</th>
<th>密码</th>
<th>运行状态</th>
</tr>
</thead>
<tbody>
<?php if (empty($data)): ?>
<tr>
<td colspan="7" class="empty-state">
<div>暂无代理数据</div>
<div style="margin-top:8px;font-size:13px">点击上方按钮生成新的代理配置</div>
</td>
</tr>
<?php else: ?>
<?php foreach ($data as $row): ?>
<tr>
<td><span class="badge badge-country"><?php echo htmlspecialchars($row['country']); ?></span></td>
<td><span class="badge badge-channel"><?php echo htmlspecialchars($row['channel'] ?? '主通道'); ?></span></td>
<td><code><?php echo htmlspecialchars($row['ip']); ?></code></td>
<td><code class="code-highlight"><?php echo htmlspecialchars($row['local_port']); ?></code></td>
<td><code><?php echo htmlspecialchars($row['user']); ?></code></td>
<td><code><?php echo htmlspecialchars($row['pass']); ?></code></td>
<td><span class="badge badge-status">运行中</span></td>
</tr>
<?php endforeach; ?>
<?php endif; ?>
</tbody>
</table>
</div>
</div>
</body>
</html>
PHPEOF

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
