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
    try {
        $db = new PDO('sqlite:' . DB_PATH);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        $db->exec('PRAGMA journal_mode=WAL;');
        $db->exec('PRAGMA busy_timeout=5000;');
        return $db;
    } catch (Exception $e) {
        error_log('DB Error: ' . $e->getMessage());
        throw $e;
    }
}

function checkAccess($vendorId, $inboundId, $role) {
    if ($role === 'admin') return true;
    $db = getDB();
    $stmt = $db->prepare('SELECT 1 FROM inbound_access WHERE user_id = ? AND inbound_id = ?');
    $stmt->execute([$vendorId, $inboundId]);
    return $stmt->fetch() !== false;
}

function restartXUI() {
    exec('systemctl restart x-ui > /dev/null 2>&1 &');
    return true;
}

try {
    $action = $_POST['action'] ?? '';
    
    switch ($action) {
        case 'add_client':
            $inboundId = intval($_POST['inbound_id']);
            $email = trim($_POST['email']);
            $totalGB = floatval($_POST['total_gb']) * 1073741824;
            $expiryDays = intval($_POST['expiry_days']);
            
            if (empty($email)) {
                throw new Exception('ایمیل نمی‌تواند خالی باشد');
            }
            
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
            
            $subId = bin2hex(random_bytes(8));
            $timestamp = time() * 1000;
            
            $newClient = [
                'id' => $uuid,
                'email' => $email,
                'enable' => true,
                'limitIp' => 0,
                'totalGB' => intval($totalGB),
                'expiryTime' => $expiryDays > 0 ? (time() + $expiryDays * 86400) * 1000 : 0,
                'tgId' => '',
                'subId' => $subId,
                'reset' => 0,
                'created_at' => $timestamp,
                'updated_at' => $timestamp
            ];
            
            // Protocol specific fields
            if ($inbound['protocol'] === 'vless') {
                $newClient['flow'] = '';
                $newClient['security'] = '';
                $newClient['password'] = '';
            } elseif ($inbound['protocol'] === 'vmess') {
                $newClient['alterId'] = 0;
            } elseif ($inbound['protocol'] === 'trojan') {
                $newClient['password'] = bin2hex(random_bytes(16));
            }
            
            $settings = json_decode($inbound['settings'], true);
            if (!isset($settings['clients'])) {
                $settings['clients'] = [];
            }
            
            // Check duplicate email
            foreach ($settings['clients'] as $existingClient) {
                if ($existingClient['email'] === $email) {
                    throw new Exception('این ایمیل قبلاً استفاده شده است');
                }
            }
            
            $settings['clients'][] = $newClient;
            
            $stmt = $db->prepare('UPDATE inbounds SET settings = ? WHERE id = ?');
            $success = $stmt->execute([json_encode($settings, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), $inboundId]);
            
            if (!$success) {
                throw new Exception('خطا در ذخیره اطلاعات');
            }
            
            restartXUI();
            
            echo json_encode([
                'success' => true, 
                'message' => 'کاربر با موفقیت ایجاد شد',
                'client' => $newClient
            ]);
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
            $found = false;
            foreach ($settings['clients'] as &$client) {
                if ($client['id'] === $clientId || $client['email'] === $clientId) {
                    $client['enable'] = $enable;
                    $client['updated_at'] = time() * 1000;
                    $found = true;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('کاربر یافت نشد');
            }
            
            $stmt = $db->prepare('UPDATE inbounds SET settings = ? WHERE id = ?');
            $stmt->execute([json_encode($settings, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), $inboundId]);
            
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
            $found = false;
            foreach ($settings['clients'] as &$client) {
                if ($client['id'] === $clientId || $client['email'] === $clientId) {
                    $client['totalGB'] = intval($totalGB);
                    if ($expiryDays > 0) {
                        $client['expiryTime'] = (time() + $expiryDays * 86400) * 1000;
                    } else {
                        $client['expiryTime'] = 0;
                    }
                    $client['updated_at'] = time() * 1000;
                    $found = true;
                    break;
                }
            }
            
            if (!$found) {
                throw new Exception('کاربر یافت نشد');
            }
            
            $stmt = $db->prepare('UPDATE inbounds SET settings = ? WHERE id = ?');
            $stmt->execute([json_encode($settings, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), $inboundId]);
            
            restartXUI();
            
            echo json_encode(['success' => true]);
            break;
            
        default:
            throw new Exception('عملیات نامعتبر');
    }
} catch (Exception $e) {
    error_log('API Error: ' . $e->getMessage());
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
?>