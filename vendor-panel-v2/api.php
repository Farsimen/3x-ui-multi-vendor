<?php
session_start();
header('Content-Type: application/json');

define('DB_PATH', '/etc/x-ui/x-ui.db');

if (!isset($_SESSION['vendor_id'])) {
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

$vendorId = $_SESSION['vendor_id'];
$vendorRole = $_SESSION['vendor_role'];

function getDB() {
    static $db = null;
    if ($db === null) {
        $db = new PDO('sqlite:' . DB_PATH);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    }
    return $db;
}

function checkAccess($vendorId, $inboundId, $role) {
    if ($role === 'admin') return true;
    $db = getDB();
    $stmt = $db->prepare('SELECT 1 FROM inbound_access WHERE user_id = ? AND inbound_id = ?');
    $stmt->execute([$vendorId, $inboundId]);
    return $stmt->fetch() !== false;
}

function restartXUI() {
    exec('systemctl restart x-ui 2>&1', $output, $return);
    return $return === 0;
}

try {
    $action = $_POST['action'] ?? '';
    
    switch ($action) {
        case 'add_client':
            $inboundId = intval($_POST['inbound_id']);
            $email = trim($_POST['email']);
            $totalGB = floatval($_POST['total_gb']) * 1073741824; // GB to bytes
            $expiryDays = intval($_POST['expiry_days']);
            
            if (!checkAccess($vendorId, $inboundId, $vendorRole)) {
                throw new Exception('دسترسی مجاز نیست');
            }
            
            $db = getDB();
            $stmt = $db->prepare('SELECT * FROM inbounds WHERE id = ?');
            $stmt->execute([$inboundId]);
            $inbound = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if (!$inbound) {
                throw new Exception('Inbound یافت نشد');
            }
            
            // Generate UUID
            $uuid = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                mt_rand(0, 0xffff),
                mt_rand(0, 0x0fff) | 0x4000,
                mt_rand(0, 0x3fff) | 0x8000,
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
            );
            
            $subId = substr(md5(uniqid($email, true)), 0, 16);
            
            $newClient = [
                'id' => $uuid,
                'alterId' => 0,
                'email' => $email,
                'limitIp' => 0,
                'totalGB' => intval($totalGB),
                'expiryTime' => $expiryDays > 0 ? (time() + $expiryDays * 86400) * 1000 : 0,
                'enable' => true,
                'tgId' => '',
                'subId' => $subId,
                'reset' => 0
            ];
            
            if (in_array($inbound['protocol'], ['vless', 'vmess'])) {
                $newClient['flow'] = '';
            }
            
            $settings = json_decode($inbound['settings'], true);
            if (!isset($settings['clients'])) {
                $settings['clients'] = [];
            }
            $settings['clients'][] = $newClient;
            
            $stmt = $db->prepare('UPDATE inbounds SET settings = ? WHERE id = ?');
            $stmt->execute([json_encode($settings), $inboundId]);
            
            restartXUI();
            
            echo json_encode(['success' => true, 'message' => 'کاربر با موفقیت ایجاد شد']);
            break;
            
        case 'toggle_client':
            $inboundId = intval($_POST['inbound_id']);
            $clientId = $_POST['client_id'];
            $enable = $_POST['enable'] === 'true';
            
            if (!checkAccess($vendorId, $inboundId, $vendorRole)) {
                throw new Exception('دسترسی مجاز نیست');
            }
            
            $db = getDB();
            $stmt = $db->prepare('SELECT settings FROM inbounds WHERE id = ?');
            $stmt->execute([$inboundId]);
            $inbound = $stmt->fetch(PDO::FETCH_ASSOC);
            
            $settings = json_decode($inbound['settings'], true);
            foreach ($settings['clients'] as &$client) {
                if ($client['id'] === $clientId || $client['email'] === $clientId) {
                    $client['enable'] = $enable;
                    break;
                }
            }
            
            $stmt = $db->prepare('UPDATE inbounds SET settings = ? WHERE id = ?');
            $stmt->execute([json_encode($settings), $inboundId]);
            
            restartXUI();
            
            echo json_encode(['success' => true]);
            break;
            
        case 'update_client':
            $inboundId = intval($_POST['inbound_id']);
            $clientId = $_POST['client_id'];
            $totalGB = floatval($_POST['total_gb']) * 1073741824;
            $expiryDays = intval($_POST['expiry_days']);
            
            if (!checkAccess($vendorId, $inboundId, $vendorRole)) {
                throw new Exception('دسترسی مجاز نیست');
            }
            
            $db = getDB();
            $stmt = $db->prepare('SELECT settings FROM inbounds WHERE id = ?');
            $stmt->execute([$inboundId]);
            $inbound = $stmt->fetch(PDO::FETCH_ASSOC);
            
            $settings = json_decode($inbound['settings'], true);
            foreach ($settings['clients'] as &$client) {
                if ($client['id'] === $clientId || $client['email'] === $clientId) {
                    $client['totalGB'] = intval($totalGB);
                    if ($expiryDays > 0) {
                        $client['expiryTime'] = (time() + $expiryDays * 86400) * 1000;
                    }
                    break;
                }
            }
            
            $stmt = $db->prepare('UPDATE inbounds SET settings = ? WHERE id = ?');
            $stmt->execute([json_encode($settings), $inboundId]);
            
            restartXUI();
            
            echo json_encode(['success' => true]);
            break;
            
        default:
            throw new Exception('عملیات نامعتبر');
    }
} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>