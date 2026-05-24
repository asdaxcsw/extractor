#!/bin/bash

# ================= 自动配置区 =================
echo "正在自动检测服务器IP..."
SERVER_IP=$(timeout 5 curl -s ifconfig.me 2>/dev/null || timeout 5 curl -s icanhazip.com 2>/dev/null || hostname -I | awk '{print $1}')

if [ -z "$SERVER_IP" ]; then
    echo "❌ 无法自动检测服务器IP，请手动输入："
    read SERVER_IP
fi
echo "✓ 检测到服务器IP: $SERVER_IP"

# 让用户设置端口
echo ""
echo "请输入Web端口 (直接回车默认使用966):"
read USER_PORT
WEB_PORT=${USER_PORT:-966}
echo "✓ 使用端口: $WEB_PORT"

API_BASE_MAIN="https://webipapi.cliproxy.com/api/getIpInfo?key=5h3vezyqtraalznfgd8z"
API_BASE_BACKUP="https://s5api.novproxy.com/api/getIpInfo?key=aeunxiovaoupb6vep6wi"
DATA_FILE="/var/www/html/proxies.json"
# ==============================================

# 1. 环境修复与权限开放
echo ""
echo "正在修复系统环境与权限..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y ufw socat php-cli php-curl curl jq psmisc lsof

# 开放所有端口并关闭防火墙
ufw disable
iptables -F
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# 创建工作目录并开放最高权限
mkdir -p /var/www/html
chmod -R 777 /var/www/html
if [ ! -f "$DATA_FILE" ]; then
    echo "[]" > $DATA_FILE
fi
chmod 666 $DATA_FILE

# 2. 生成美化版 PHP 后端逻辑
cat << 'PHPEOF' > /var/www/html/index.php
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
.info-card{background:linear-gradient(135deg,#ffeaa7 0%,#fdcb6e 100%);border-radius:12px;padding:18px 24px;margin-bottom:24px;box-shadow:0 4px 16px rgba(253,203,110,.3);text-align:center}
.info-card strong{font-size:16px;font-weight:700;color:#2d3436;display:block;margin-bottom:8px}
.info-card .server-ip{display:inline-block;background:#fff;padding:8px 16px;border-radius:8px;font-family:monospace;color:#667eea;font-weight:700;font-size:18px;box-shadow:0 2px 8px rgba(0,0,0,.1)}
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
.info-card .server-ip{font-size:16px;padding:6px 12px}
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
<strong>服务器 IP</strong>
<div class="server-ip"><?php echo $serverIp; ?></div>
</div>
<div class="controls">
<form method="post" style="display:inline">
<button type="submit" name="generate" class="btn btn-primary">生成新数据 (主通道)</button>
</form>
<form method="post" style="display:inline">
<button type="submit" name="generate_backup" class="btn btn-info">生成新数据 (备用通道)</button>
</form>
<form method="post" style="display:inline">
<button type="submit" name="clear" class="btn btn-danger" onclick="return confirm('确定要清理所有通道的中转进程和历史吗？')">一键清理历史</button>
</form>
</div>
<div class="table-container">
<table>
<thead>
<tr>
<th>地区</th>
<th>来源通道</th>
<th>中转IP</th>
<th>中转端口</th>
<th>认证账号</th>
<th>认证密码</th>
<th>SOCAT状态</th>
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
<td><span class="badge badge-status">永久运行中</span></td>
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

# 3. 强力重启 Web 服务
echo ""
echo "正在强力重启 Web 服务..."
pkill -f "php -S 0.0.0.0:$WEB_PORT"
sleep 0.5
PORT_PID=$(lsof -t -i:$WEB_PORT 2>/dev/null)
if [ ! -z "$PORT_PID" ]; then
    kill -9 $PORT_PID
fi

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
echo "================================================"
echo "✓ 双通道常驻版本部署完成！"
echo "================================================"
echo "服务器IP: $SERVER_IP (自动检测)"
echo "Web端口: $WEB_PORT (用户设置)"
echo "访问地址: http://$SERVER_IP:$WEB_PORT"
echo ""
echo "核心特性："
echo "  • 自动检测服务器公网IP"
echo "  • 用户自定义端口设置"
echo "  • 双通道API完整保留"
echo "  • 进程永久守护运行"
echo "  • 美化渐变色界面"
echo "  • 醒目红色清理按钮"
echo ""
echo "如果无法访问，请检查:"
echo "1. 云服务器安全组是否开放端口 $WEB_PORT"
echo "2. 查看服务状态: ps aux | grep php"
echo "3. 查看日志: cat /tmp/php_server.log"
echo "================================================"
