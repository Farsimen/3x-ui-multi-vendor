<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ورود به پنل Vendor</title>
    <link rel="stylesheet" href="style.css">
</head>
<body class="login-page">
    <div class="login-container">
        <div class="login-box">
            <div class="login-header">
                <h1>🔐 ورود به پنل</h1>
                <p>سیستم مدیریت Vendor</p>
            </div>
            <?php if (isset($error)): ?>
                <div class="alert alert-error"><?= $error ?></div>
            <?php endif; ?>
            <form method="POST" class="login-form">
                <div class="form-group">
                    <label>نام کاربری:</label>
                    <input type="text" name="username" required autofocus>
                </div>
                <div class="form-group">
                    <label>رمز عبور:</label>
                    <input type="password" name="password" required>
                </div>
                <button type="submit" name="login" class="btn btn-primary btn-block">ورود</button>
            </form>
        </div>
    </div>
</body>
</html>