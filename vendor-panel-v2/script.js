function showAddModal() { document.getElementById('addModal').style.display = 'block'; }
function closeModal(id) { document.getElementById(id).style.display = 'none'; }
document.getElementById('addForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    formData.append('action', 'add_client');
    try {
        const res = await fetch('api.php', { method: 'POST', body: formData });
        const data = await res.json();
        if (data.success) {
            alert('کاربر با موفقیت ایجاد شد');
            location.reload();
        } else {
            alert('خطا: ' + data.error);
        }
    } catch (err) {
        alert('خطای شبکه: ' + err.message);
    }
});
document.getElementById('editForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    formData.append('action', 'update_client');
    try {
        const res = await fetch('api.php', { method: 'POST', body: formData });
        const data = await res.json();
        if (data.success) {
            alert('به‌روزرسانی شد');
            closeModal('editModal');
            location.reload();
        } else {
            alert('خطا: ' + data.error);
        }
    } catch (err) {
        alert('خطا: ' + err.message);
    }
});
async function toggleClient(inboundId, clientId, enable) {
    const formData = new FormData();
    formData.append('action', 'toggle_client');
    formData.append('inbound_id', inboundId);
    formData.append('client_id', clientId);
    formData.append('enable', enable);
    try {
        const res = await fetch('api.php', { method: 'POST', body: formData });
        const data = await res.json();
        if (data.success) {
            location.reload();
        } else {
            alert('خطا: ' + data.error);
        }
    } catch (err) {
        alert('خطا: ' + err.message);
    }
}
function editClient(client) {
    document.getElementById('edit_inbound_id').value = client.inbound_id;
    document.getElementById('edit_client_id').value = client.id;
    document.getElementById('edit_total_gb').value = (client.totalGB || 0) / 1073741824;
    document.getElementById('edit_expiry_days').value = 30;
    document.getElementById('editModal').style.display = 'block';
}
function showConfig(client, serverIP) {
    const protocol = client.protocol;
    const configLink = `${protocol}://${client.id}@${serverIP}:${client.port}?security=none#${encodeURIComponent(client.email)}`;
    const subLink = `http://${serverIP}:${client.port}/sub/${client.subId || 'none'}`;
    const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(configLink)}`;
    const html = `
        <div class="qr-container">
            <img src="${qrUrl}" alt="QR Code">
        </div>
        <div class="config-box">
            <h4>🔗 لینک کانفیگ:</h4>
            <div class="config-link" id="configLink">${configLink}</div>
            <button class="copy-btn" onclick="copyText('configLink')">📋 کپی</button>
        </div>
        <div class="config-box">
            <h4>🔄 لینک Subscription:</h4>
            <div class="config-link" id="subLink">${subLink}</div>
            <button class="copy-btn" onclick="copyText('subLink')">📋 کپی</button>
        </div>
    `;
    document.getElementById('configContent').innerHTML = html;
    document.getElementById('configModal').style.display = 'block';
}
function copyText(elementId) {
    const text = document.getElementById(elementId).textContent;
    navigator.clipboard.writeText(text).then(() => {
        alert('کپی شد! ✅');
    }).catch(err => {
        alert('خطا در کپی');
    });
}