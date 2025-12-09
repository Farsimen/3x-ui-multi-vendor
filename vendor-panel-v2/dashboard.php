<?php
$vendorId = $_SESSION['vendor_id'];
$vendorName = $_SESSION['vendor_name'];
$vendorRole = $_SESSION['vendor_role'];

$db = getDB();

// Get vendor inbounds
if ($vendorRole === 'admin') {
    $stmt = $db->query('SELECT * FROM inbounds WHERE enable = 1');
} else {
    $stmt = $db->prepare('SELECT i.* FROM inbounds i JOIN inbound_access ia ON i.id = ia.inbound_id WHERE ia.user_id = ? AND i.enable = 1');
    $stmt->execute([$vendorId]);
}
$inbounds = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Get all clients
$allClients = [];
foreach ($inbounds as $inbound) {
    $settings = json_decode($inbound['settings'], true);
    if (isset($settings['clients'])) {
        foreach ($settings['clients'] as $client) {
            $client['inbound_id'] = $inbound['id'];
            $client['inbound_remark'] = $inbound['remark'] ?: 'Inbound '.$inbound['id'];
            $client['protocol'] = $inbound['protocol'];
            $client['port'] = $inbound['port'];
            $allClients[] = $client;
        }
    }
}

$activeClients = count(array_filter($allClients, fn($c) => $c['enable'] ?? false));
$serverIP = trim(@file_get_contents('http://ifconfig.me'));
?>
<!DOCTYPE html>
<html dir="rtl" lang="fa">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>پنل Vendor - <?= htmlspecialchars($vendorName) ?></title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="navbar">
        <div class="container">
            <div class="navbar-brand">📊 پنل Vendor</div>
            <div class="navbar-menu">
                <span class="user-badge"><?= htmlspecialchars($vendorName) ?></span>
                <a href="?logout" class="btn btn-logout">خروج</a>
            </div>
        </div>
    </div>

    <div class="container">
        <div class="stats-grid">
            <div class="stat-card blue">
                <div class="stat-icon">🖥️</div>
                <div class="stat-value"><?= count($inbounds) ?></div>
                <div class="stat-label">Inbound مجاز</div>
            </div>
            <div class="stat-card green">
                <div class="stat-icon">👥</div>
                <div class="stat-value"><?= count($allClients) ?></div>
                <div class="stat-label">کل کاربران</div>
            </div>
            <div class="stat-card orange">
                <div class="stat-icon">✅</div>
                <div class="stat-value"><?= $activeClients ?></div>
                <div class="stat-label">کاربران فعال</div>
            </div>
        </div>

        <div class="card">
            <div class="card-header">
                <h2>مدیریت کاربران</h2>
                <button class="btn btn-primary" onclick="showAddModal()">➕ کاربر جدید</button>
            </div>
            <div class="table-responsive">
                <table>
                    <thead>
                        <tr>
                            <th>Email</th>
                            <th>Inbound</th>
                            <th>پروتکل</th>
                            <th>حجم</th>
                            <th>تاریخ</th>
                            <th>وضعیت</th>
                            <th>عملیات</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($allClients as $client): ?>
                        <tr>
                            <td><?= htmlspecialchars($client['email']) ?></td>
                            <td><?= htmlspecialchars($client['inbound_remark']) ?></td>
                            <td><span class="badge badge-info"><?= strtoupper($client['protocol']) ?></span></td>
                            <td><?= isset($client['totalGB']) && $client['totalGB'] > 0 ? round($client['totalGB']/1073741824, 2).' GB' : 'نامحدود' ?></td>
                            <td><?= isset($client['expiryTime']) && $client['expiryTime'] > 0 ? date('Y/m/d', $client['expiryTime']/1000) : 'نامحدود' ?></td>
                            <td>
                                <span class="badge <?= ($client['enable'] ?? false) ? 'badge-success' : 'badge-danger' ?>">
                                    <?= ($client['enable'] ?? false) ? 'فعال' : 'غیرفعال' ?>
                                </span>
                            </td>
                            <td>
                                <button class="btn btn-sm btn-info" onclick='showConfig(<?= json_encode($client) ?>, "<?= $serverIP ?>")'>📱 کانفیگ</button>
                                <button class="btn btn-sm btn-warning" onclick='editClient(<?= json_encode($client) ?>)'>✏️</button>
                                <button class="btn btn-sm <?= ($client['enable'] ?? false) ? 'btn-danger' : 'btn-success' ?>" 
                                    onclick="toggleClient(<?= $client['inbound_id'] ?>, '<?= $client['id'] ?>', <?= ($client['enable'] ?? false) ? 'false' : 'true' ?>)">
                                    <?= ($client['enable'] ?? false) ? '⏸️' : '▶️' ?>
                                </button>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <div id="addModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h3>➕ افزودن کاربر جدید</h3>
                <button class="modal-close" onclick="closeModal('addModal')">✖</button>
            </div>
            <form id="addForm">
                <div class="form-group">
                    <label>Inbound:</label>
                    <select name="inbound_id" required>
                        <?php foreach ($inbounds as $inbound): ?>
                        <option value="<?= $inbound['id'] ?>"><?= htmlspecialchars($inbound['remark'] ?: 'Inbound '.$inbound['id']) ?> (<?= strtoupper($inbound['protocol']) ?>)</option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="form-group">
                    <label>Email:</label>
                    <input type="text" name="email" required>
                </div>
                <div class="form-group">
                    <label>حجم (GB):</label>
                    <input type="number" name="total_gb" value="0" step="0.1">
                    <small>0 = نامحدود</small>
                </div>
                <div class="form-group">
                    <label>تعداد روز اعتبار:</label>
                    <input type="number" name="expiry_days" value="0">
                    <small>0 = نامحدود</small>
                </div>
                <button type="submit" class="btn btn-primary btn-block">ایجاد</button>
            </form>
        </div>
    </div>

    <div id="configModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h3>📱 اطلاعات کانفیگ</h3>
                <button class="modal-close" onclick="closeModal('configModal')">✖</button>
            </div>
            <div id="configContent"></div>
        </div>
    </div>

    <div id="editModal" class="modal">
        <div class="modal-content">
            <div class="modal-header">
                <h3>✏️ ویرایش کاربر</h3>
                <button class="modal-close" onclick="closeModal('editModal')">✖</button>
            </div>
            <form id="editForm">
                <input type="hidden" name="inbound_id" id="edit_inbound_id">
                <input type="hidden" name="client_id" id="edit_client_id">
                <div class="form-group">
                    <label>حجم جدید (GB):</label>
                    <input type="number" name="total_gb" id="edit_total_gb" step="0.1" required>
                </div>
                <div class="form-group">
                    <label>تعداد روز اعتبار جدید:</label>
                    <input type="number" name="expiry_days" id="edit_expiry_days" required>
                </div>
                <button type="submit" class="btn btn-primary btn-block">ذخیره</button>
            </form>
        </div>
    </div>

    <script src="script.js"></script>
</body>
</html>