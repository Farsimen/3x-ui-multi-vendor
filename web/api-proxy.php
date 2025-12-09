<?php
/**
 * 3X-UI Multi-Vendor RBAC API Proxy
 * This proxy sits between vendors and 3X-UI backend
 * Filters API responses based on vendor permissions
 */

session_start();
header('Content-Type: application/json');

// Configuration
define('DB_PATH', '/etc/x-ui/x-ui.db');
define('X_UI_API_BASE', 'http://127.0.0.1:54321'); // Change to your 3X-UI port

// CORS headers if needed
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

// Database connection
function getDB() {
    static $db = null;
    if ($db === null) {
        try {
            $db = new PDO('sqlite:' . DB_PATH);
            $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        } catch (PDOException $e) {
            error_log('Database connection failed: ' . $e->getMessage());
            http_response_code(500);
            echo json_encode(['success' => false, 'msg' => 'Database error']);
            exit;
        }
    }
    return $db;
}

// Get user role and permissions
function getUserPermissions($username) {
    $db = getDB();
    
    $stmt = $db->prepare('
        SELECT 
            u.id,
            u.username,
            ur.role,
            GROUP_CONCAT(ia.inbound_id) as allowed_inbounds
        FROM users u
        LEFT JOIN user_roles ur ON u.id = ur.user_id
        LEFT JOIN inbound_access ia ON u.id = ia.user_id
        WHERE u.username = :username
        GROUP BY u.id, u.username, ur.role
    ');
    
    $stmt->execute([':username' => $username]);
    return $stmt->fetch(PDO::FETCH_ASSOC);
}

// Authenticate user (Basic Auth or Session)
function authenticate() {
    // Try session first
    if (isset($_SESSION['username'])) {
        return $_SESSION['username'];
    }
    
    // Try Basic Auth
    if (isset($_SERVER['PHP_AUTH_USER'])) {
        $username = $_SERVER['PHP_AUTH_USER'];
        $password = $_SERVER['PHP_AUTH_PW'];
        
        $db = getDB();
        $stmt = $db->prepare('SELECT password FROM users WHERE username = :username');
        $stmt->execute([':username' => $username]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($user && password_verify($password, $user['password'])) {
            return $username;
        }
    }
    
    // Try cookie/token
    if (isset($_COOKIE['3x-ui'])) {
        // Parse 3X-UI session cookie
        // This is simplified - actual implementation depends on 3X-UI's auth
        $username = parseSessionCookie($_COOKIE['3x-ui']);
        if ($username) {
            return $username;
        }
    }
    
    http_response_code(401);
    echo json_encode(['success' => false, 'msg' => 'Authentication required']);
    exit;
}

// Parse session cookie (simplified)
function parseSessionCookie($cookie) {
    // This needs to match 3X-UI's session handling
    // For now, return null - needs implementation
    return null;
}

// Filter inbounds based on permissions
function filterInbounds($inbounds, $permissions) {
    if ($permissions['role'] === 'admin' || empty($permissions['role'])) {
        return $inbounds; // Admins see everything
    }
    
    if ($permissions['role'] === 'vendor') {
        $allowedIds = $permissions['allowed_inbounds'] 
            ? explode(',', $permissions['allowed_inbounds']) 
            : [];
        
        return array_filter($inbounds, function($inbound) use ($allowedIds) {
            return in_array((string)$inbound['id'], $allowedIds);
        });
    }
    
    return [];
}

// Proxy request to 3X-UI
function proxyRequest($method, $path, $data = null) {
    $url = X_UI_API_BASE . $path;
    
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    
    // Forward cookies
    if (isset($_COOKIE['3x-ui'])) {
        curl_setopt($ch, CURLOPT_COOKIE, '3x-ui=' . $_COOKIE['3x-ui']);
    }
    
    // Forward headers
    $headers = [];
    if (isset($_SERVER['CONTENT_TYPE'])) {
        $headers[] = 'Content-Type: ' . $_SERVER['CONTENT_TYPE'];
    }
    
    if ($data !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($data));
        $headers[] = 'Content-Type: application/json';
    }
    
    if (!empty($headers)) {
        curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
    }
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    return [
        'code' => $httpCode,
        'body' => json_decode($response, true) ?: $response
    ];
}

// Main routing
$requestUri = $_SERVER['REQUEST_URI'];
$requestMethod = $_SERVER['REQUEST_METHOD'];

// Parse request path
$path = parse_url($requestUri, PHP_URL_PATH);
$path = str_replace('/api-proxy.php', '', $path);

// Authenticate
$username = authenticate();
$permissions = getUserPermissions($username);

if (!$permissions) {
    http_response_code(403);
    echo json_encode(['success' => false, 'msg' => 'Permission denied']);
    exit;
}

// Get request data
$requestData = null;
if (in_array($requestMethod, ['POST', 'PUT'])) {
    $requestData = json_decode(file_get_contents('php://input'), true);
}

// Route specific endpoints
if (preg_match('#^/panel/api/inbounds/list#', $path)) {
    // List inbounds - needs filtering
    $response = proxyRequest('GET', '/panel/api/inbounds/list', null);
    
    if ($response['code'] === 200 && isset($response['body']['obj'])) {
        // Filter inbounds based on permissions
        $filteredInbounds = filterInbounds($response['body']['obj'], $permissions);
        $response['body']['obj'] = array_values($filteredInbounds);
    }
    
    http_response_code($response['code']);
    echo json_encode($response['body']);
    
} elseif (preg_match('#^/panel/api/inbounds/get/(\d+)#', $path, $matches)) {
    // Get specific inbound - check permission
    $inboundId = $matches[1];
    
    if ($permissions['role'] === 'vendor') {
        $allowedIds = explode(',', $permissions['allowed_inbounds'] ?: '');
        if (!in_array($inboundId, $allowedIds)) {
            http_response_code(403);
            echo json_encode(['success' => false, 'msg' => 'Access denied to this inbound']);
            exit;
        }
    }
    
    $response = proxyRequest('GET', '/panel/api/inbounds/get/' . $inboundId, null);
    http_response_code($response['code']);
    echo json_encode($response['body']);
    
} elseif (preg_match('#^/panel/api/inbounds/add#', $path)) {
    // Add inbound - vendors cannot do this
    if ($permissions['role'] === 'vendor') {
        http_response_code(403);
        echo json_encode(['success' => false, 'msg' => 'Vendors cannot create inbounds']);
        exit;
    }
    
    $response = proxyRequest('POST', '/panel/api/inbounds/add', $requestData);
    http_response_code($response['code']);
    echo json_encode($response['body']);
    
} elseif (preg_match('#^/panel/api/inbounds/del/(\d+)#', $path, $matches)) {
    // Delete inbound - vendors cannot do this
    if ($permissions['role'] === 'vendor') {
        http_response_code(403);
        echo json_encode(['success' => false, 'msg' => 'Vendors cannot delete inbounds']);
        exit;
    }
    
    $inboundId = $matches[1];
    $response = proxyRequest('POST', '/panel/api/inbounds/del/' . $inboundId, null);
    http_response_code($response['code']);
    echo json_encode($response['body']);
    
} elseif (preg_match('#^/panel/api/inbounds/update/(\d+)#', $path, $matches)) {
    // Update inbound - check permission
    $inboundId = $matches[1];
    
    if ($permissions['role'] === 'vendor') {
        $allowedIds = explode(',', $permissions['allowed_inbounds'] ?: '');
        if (!in_array($inboundId, $allowedIds)) {
            http_response_code(403);
            echo json_encode(['success' => false, 'msg' => 'Access denied to this inbound']);
            exit;
        }
    }
    
    $response = proxyRequest('POST', '/panel/api/inbounds/update/' . $inboundId, $requestData);
    http_response_code($response['code']);
    echo json_encode($response['body']);
    
} elseif (preg_match('#^/panel/api/inbounds/addClient#', $path)) {
    // Add client - check inbound permission
    if ($permissions['role'] === 'vendor' && isset($requestData['id'])) {
        $allowedIds = explode(',', $permissions['allowed_inbounds'] ?: '');
        if (!in_array((string)$requestData['id'], $allowedIds)) {
            http_response_code(403);
            echo json_encode(['success' => false, 'msg' => 'Access denied to this inbound']);
            exit;
        }
    }
    
    $response = proxyRequest('POST', '/panel/api/inbounds/addClient', $requestData);
    http_response_code($response['code']);
    echo json_encode($response['body']);
    
} else {
    // Forward all other requests as-is
    $response = proxyRequest($requestMethod, $path, $requestData);
    http_response_code($response['code']);
    echo is_array($response['body']) ? json_encode($response['body']) : $response['body'];
}
?>