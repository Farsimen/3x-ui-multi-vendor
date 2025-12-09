<?php
session_start();

// Configuration
define('DB_PATH', '/etc/x-ui/x-ui.db');
define('PANEL_URL', 'http://YOUR_SERVER_IP:PORT/BASE_PATH');

// Database connection
try {
    $db = new PDO('sqlite:' . DB_PATH);
    $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    die('Database connection error');
}

// Login handler
if (isset($_POST['login'])) {
    $username = $_POST['username'];
    $password = $_POST['password'];
    
    $stmt = $db->prepare('SELECT u.id, u.username, u.password, ur.role 
                          FROM users u 
                          JOIN user_roles ur ON u.id = ur.user_id 
                          WHERE u.username = :user');
    $stmt->execute([':user' => $username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['user_id'] = $user['id'];
        $_SESSION['username'] = $user['username'];
        $_SESSION['role'] = $user['role'];
        header('Location: vendor-panel.php');
        exit;
    } else {
        $error = 'Invalid username or password';
    }
}

// Logout handler
if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: vendor-panel.php');
    exit;
}

// Check login
if (!isset($_SESSION['user_id'])) {
    ?>
    <!DOCTYPE html>
    <html dir="rtl" lang="fa">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>ورود به پنل Vendor</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { font-family: Tahoma, Arial; background: #1a1a2e; color: #fff; display: flex; justify-content: center; align-items: center; min-height: 100vh; }
            .login-box { background: #16213e; padding: 40px; border-radius: 10px; box-shadow: 0 0 20px rgba(0,0,0,0.5); width: 350px; }
            h2 { text-align: center; margin-bottom: 30px; color: #00d9ff; }
            input { width: 100%; padding: 12px; margin: 10px 0; border: 1px solid #0f3460; background: #0f3460; color: #fff; border-radius: 5px; }
            button { width: 100%; padding: 12px; background: #00d9ff; border: none; border-radius: 5px; color: #000; font-weight: bold; cursor: pointer; margin-top: 10px; }
            button:hover { background: #00b8d4; }
            .error { background: #ff4444; padding: 10px; border-radius: 5px; margin-bottom: 20px; text-align: center; }
        </style>
    </head>
    <body>
        <div class="login-box">
            <h2>🔐 ورود Vendor</h2>
            <?php if (isset($error)) echo "<div class='error'>$error</div>"; ?>
            <form method="POST">
                <input type="text" name="username" placeholder="نام کاربری" required>
                <input type="password" name="password" placeholder="رمز عبور" required>
                <button type="submit" name="login">ورود</button>
            </form>
        </div>
    </body>
    </html>
    <?php
    exit;
}

// Get vendor's inbounds
$stmt = $db->prepare('
    SELECT i.* 
    FROM inbounds i
    JOIN inbound_access ia ON i.id = ia.inbound_id
    WHERE ia.user_id = :user_id
');
$stmt->execute([':user_id' => $_SESSION['user_id']]);
$inbounds = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Get statistics
$stmt = $db->prepare('
    SELECT 
        ROUND(SUM(i.up) / 1024.0 / 1024.0, 2) as upload_mb,
        ROUND(SUM(i.down) / 1024.0 / 1024.0, 2) as download_mb
    FROM inbounds i
    JOIN inbound_access ia ON i.id = ia.inbound_id
    WHERE ia.user_id = :user_id
');
$stmt->execute([':user_id' => $_SESSION['user_id']]);
$stats = $stmt->fetch(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>پنل Vendor - <?= htmlspecialchars($_SESSION['username']) ?></title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: Tahoma, Arial; background: #1a1a2e; color: #fff; padding: 20px; }
        .header { background: #16213e; padding: 20px; border-radius: 10px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; flex-wrap: wrap; }
        .header h1 { color: #00d9ff; font-size: 24px; }
        .logout { background: #ff4444; color: #fff; padding: 10px 20px; border-radius: 5px; text-decoration: none; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 20px; }
        .stat-card { background: #16213e; padding: 20px; border-radius: 10px; text-align: center; }
        .stat-value { font-size: 32px; color: #00d9ff; font-weight: bold; }
        .stat-label { margin-top: 10px; color: #888; }
        .inbounds { background: #16213e; padding: 20px; border-radius: 10px; }
        .inbounds h2 { color: #00d9ff; margin-bottom: 20px; }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; text-align: right; border-bottom: 1px solid #0f3460; }
        th { background: #0f3460; color: #00d9ff; }
        .badge { padding: 5px 10px; border-radius: 5px; font-size: 12px; }
        .badge-success { background: #00ff00; color: #000; }
        .badge-danger { background: #ff0000; color: #fff; }
        .btn { padding: 8px 15px; background: #00d9ff; color: #000; text-decoration: none; border-radius: 5px; font-size: 12px; display: inline-block; }
        .btn:hover { background: #00b8d4; }
        .empty { text-align: center; padding: 40px; color: #888; font-size: 18px; }
        .footer { text-align: center; margin-top: 30px; color: #888; padding: 20px; }
        @media (max-width: 768px) {
            .header { flex-direction: column; gap: 10px; }
            .header h1 { font-size: 18px; }
            table { font-size: 12px; }
            th, td { padding: 8px; }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 پنل Vendor: <?= htmlspecialchars($_SESSION['username']) ?></h1>
        <a href="?logout" class="logout">خروج</a>
    </div>

    <div class="stats">
        <div class="stat-card">
            <div class="stat-value"><?= count($inbounds) ?></div>
            <div class="stat-label">تعداد Inbound</div>
        </div>
        <div class="stat-card">
            <div class="stat-value"><?= $stats['upload_mb'] ?? 0 ?></div>
            <div class="stat-label">آپلود (MB)</div>
        </div>
        <div class="stat-card">
            <div class="stat-value"><?= $stats['download_mb'] ?? 0 ?></div>
            <div class="stat-label">دانلود (MB)</div>
        </div>
    </div>

    <div class="inbounds">
        <h2>🔗 Inbound های مجاز شما</h2>
        <?php if (empty($inbounds)): ?>
            <div class="empty">❌ هیچ Inbound ای به شما اختصاص نیافته است</div>
        <?php else: ?>
            <table>
                <thead>
                    <tr>
                        <th>ID</th>
                        <th>Remark</th>
                        <th>پورت</th>
                        <th>پروتکل</th>
                        <th>وضعیت</th>
                        <th>عملیات</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($inbounds as $inbound): ?>
                    <tr>
                        <td><?= $inbound['id'] ?></td>
                        <td><?= htmlspecialchars($inbound['remark'] ?: '-') ?></td>
                        <td><?= $inbound['port'] ?></td>
                        <td><?= strtoupper($inbound['protocol']) ?></td>
                        <td>
                            <?php if ($inbound['enable']): ?>
                                <span class="badge badge-success">فعال</span>
                            <?php else: ?>
                                <span class="badge badge-danger">غیرفعال</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <a href="<?= PANEL_URL ?>" target="_blank" class="btn">مدیریت</a>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>

    <div class="footer">
        <p>⚠️ برای مدیریت Client ها باید از پنل اصلی 3X-UI استفاده کنید</p>
        <a href="<?= PANEL_URL ?>" target="_blank" class="btn" style="margin-top: 10px;">باز کردن پنل اصلی</a>
        <p style="margin-top: 20px; font-size: 12px;">
            Powered by <a href="https://github.com/Farsimen/3x-ui-multi-vendor" style="color: #00d9ff;">3X-UI Multi-Vendor</a>
        </p>
    </div>
</body>
</html>
