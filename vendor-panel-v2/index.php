<?php
session_start();
define('DB_PATH', '/etc/x-ui/x-ui.db');

function getDB() {
    static $db = null;
    if ($db === null) {
        $db = new PDO('sqlite:' . DB_PATH);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    }
    return $db;
}

// Login
if (isset($_POST['login'])) {
    $username = $_POST['username'];
    $password = $_POST['password'];
    
    $db = getDB();
    $stmt = $db->prepare('SELECT u.id, u.username, u.password, ur.role FROM users u JOIN user_roles ur ON u.id = ur.user_id WHERE u.username = ?');
    $stmt->execute([$username]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);
    
    if ($user && password_verify($password, $user['password'])) {
        $_SESSION['vendor_id'] = $user['id'];
        $_SESSION['vendor_name'] = $user['username'];
        $_SESSION['vendor_role'] = $user['role'];
        header('Location: index.php');
        exit;
    }
    $error = 'نام کاربری یا رمز عبور اشتباه است';
}

if (isset($_GET['logout'])) {
    session_destroy();
    header('Location: index.php');
    exit;
}

if (!isset($_SESSION['vendor_id'])) {
    include 'login.php';
    exit;
}

include 'dashboard.php';
?>