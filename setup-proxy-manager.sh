#!/bin/bash

# ================= 自动配置区 =================
echo "正在自动获取服务器公网IP..."
SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
if [ -z "$SERVER_IP" ]; then
    echo "错误：无法自动获取服务器IP，请检查网络连接"
    exit 1
fi
echo "✓ 检测到服务器IP: $SERVER_IP"

read -p "请输入Web服务端口 [默认: 966]: " WEB_PORT
WEB_PORT=${WEB_PORT:-966}
echo "✓ 使用端口: $WEB_PORT"

API_BASE_MAIN="https://webipapi.cliproxy.com/api/getIpInfo?key=5h3vezyqtraalznfgd8z"
API_BASE_BACKUP="https://s5api.novproxy.com/api/getIpInfo?key=aeunxiovaoupb6vep6wi"
DATA_FILE="/var/www/html/proxies.json"
# ==============================================

echo "正在修复系统环境与权限..."
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y ufw socat php-cli php-curl curl jq psmisc lsof

ufw disable
iptables -F
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

mkdir -p /var/www/html
chmod -R 777 /var/www/html
if [ ! -f "$DATA_FILE" ]; then
    echo "[]" > $DATA_FILE
fi
chmod 666 $DATA_FILE

# 生成 PHP 文件
cat > /var/www/html/index.php << 'PHPEOF'
<?php
$configFile = 'proxies.json';
$serverIp = "SERVER_IP_PLACEHOLDER";
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
<html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>代理中转管理面板</title><style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:'Segoe UI',sans-serif;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);min-height:100vh;padding:20px}
.container{max-width:1400px;margin:0 auto;background:#fff;border-radius:16px;box-shadow:0 20px 60px rgba(0,0,0,.3);overflow:hidden}
.header{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;padding:30px;text-align:center}
.header h1{font-size:32px;margin-bottom:10px;text-shadow:2px 2px 4px rgba(0,0,0,.2)}
.server-info{font-size:18px;background:rgba(255,255,255,.2);display:inline-block;padding:8px 20px;border-radius:20px;margin-top:10px}
.controls{padding:30px;background:#f8f9fa;border-bottom:2px solid #e9ecef;display:flex;gap:15px;flex-wrap:wrap;justify-content:center}
.btn{padding:14px 28px;cursor:pointer;border:none;color:#fff;border-radius:8px;font-weight:bold;font-size:15px;transition:all .3s;box-shadow:0 4px 15px rgba(0,0,0,.2)}
.btn:hover{transform:translateY(-2px);box-shadow:0 6px 20px rgba(0,0,0,.3)}
.gen{background:linear-gradient(135deg,#11998e 0%,#38ef7d 100%)}
.backup{background:linear-gradient(135deg,#4facfe 0%,#00f2fe 100%)}
.clear{background:linear-gradient(135deg,#ff6b6b 0%,#ee5a6f 100%)}
.content{padding:30px}
.table-wrapper{overflow-x:auto;border-radius:12px;box-shadow:0 4px 15px rgba(0,0,0,.1)}
table{width:100%;border-collapse:collapse;background:#fff}
th{background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:#fff;padding:16px;text-align:left;font-weight:600;font-size:14px}
td{padding:16px;border-bottom:1px solid #e9ecef;font-size:14px}
tr:hover{background:#f8f9fa}
tr:last-child td{border-bottom:none}
.channel-badge{display:inline-block;padding:6px 12px;border-radius:20px;font-weight:bold;font-size:12px;color:#fff}
.channel-main{background:linear-gradient(135deg,#11998e 0%,#38ef7d 100%)}
.channel-backup{background:linear-gradient(135deg,#4facfe 0%,#00f2fe 100%)}
.status-running{color:#28a745;font-weight:bold}
.status-running::before{content:"●";margin-right:5px;animation:blink 1.5s infinite}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.3}}
code{background:#f1f3f5;padding:4px 8px;border-radius:4px;font-family:'Courier New',monospace;font-size:13px;color:#495057}
.port-code{background:#e7f5ff;color:#1971c2;font-weight:bold;font-size:15px}
.empty-state{text-align:center;padding:60px 20px;color:#868e96}
.empty-state h3{font-size:24px;margin-bottom:10px}
</style></head><body><div class="container">
<div class="header"><h1>代理中转管理面板</h1><div class="server-info">服务器: <?php echo $serverIp;?></div></div>
<div class="controls">
<form method="post" style="display:inline"><button type="submit" name="generate" class="btn gen">生成新代理 (主通道)</button></form>
<form method="post" style="display:inline"><button type="submit" name="generate_backup" class="btn backup">生成新代理 (备用通道)</button></form>
<form method="post" style="display:inline"><button type="submit" name="clear" class="btn clear" onclick="return confirm('确定要清理所有通道的中转进程和历史记录吗？')">一键清理历史</button></form>
</div><div class="content">
<?php if(empty($data)):?>
<div class="empty-state"><h3>暂无代理数据</h3><p>点击上方按钮生成新的代理通道</p></div>
<?php else:?>
<div class="table-wrapper"><table><thead><tr>
<th>地区</th><th>来源通道</th><th>中转IP</th><th>中转端口</th><th>认证账号</th><th>认证密码</th><th>运行状态</th>
</tr></thead><tbody>
<?php foreach($data as $row):?>
<tr>
<td><?php echo htmlspecialchars($row['country']);?></td>
<td><span class="channel-badge <?php echo($row['channel']??'主通道')==='主通道'?'channel-main':'channel-backup';?>"><?php echo htmlspecialchars($row['channel']??'主通道');?></span></td>
<td><code><?php echo htmlspecialchars($row['ip']);?></code></td>
<td><code class="port-code"><?php echo htmlspecialchars($row['local_port']);?></code></td>
<td><?php echo htmlspecialchars($row['user']);?></td>
<td><?php echo htmlspecialchars($row['pass']);?></td>
<td class="status-running">永久运行中</td>
</tr>
<?php endforeach;?>
</tbody></table></div>
<?php endif;?>
</div></div></body></html>
PHPEOF

sed -i "s/SERVER_IP_PLACEHOLDER/$SERVER_IP/g" /var/www/html/index.php

echo "正在强力重启 Web 服务..."
pkill -f "php -S 0.0.0.0:$WEB_PORT"
sleep 0.5
PORT_PID=$(lsof -t -i:$WEB_PORT)
if [ ! -z "$PORT_PID" ]; then
    kill -9 $PORT_PID
fi

nohup php -S 0.0.0.0:$WEB_PORT -t /var/www/html/ </dev/null >/dev/null 2>&1 &

echo ""
echo "================================================"
echo "✓ 双通道常驻版本部署完成！"
echo "================================================"
echo "服务器IP: $SERVER_IP"
echo "访问地址: http://$SERVER_IP:$WEB_PORT"
echo "数据文件: $DATA_FILE"
echo "================================================"
