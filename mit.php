<?php
require_once 'functions.php';

#-----------------------------#
function mit_get_config($panel_name) {
    $panel = select("marzban_panel", "*", "name_panel", $panel_name, "select");
    if (!$panel || empty($panel['mit_config'])) {
        return null;
    }
    $config = json_decode($panel['mit_config'], true);
    if (!$config || empty($config['mit_url'])) {
        return null;
    }
    return $config;
}

#-----------------------------#
function mit_login($panel_name) {
    $config = mit_get_config($panel_name);
    if (!$config) {
        return ['success' => false, 'token' => null, 'error' => 'Panel config not found'];
    }

    $url = rtrim($config['mit_url'], '/') . '/login';
    $data = http_build_query([
        'username' => $config['mit_admin_user'],
        'password' => $config['mit_admin_pass'],
    ]);

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT_MS, 8000);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Content-Type: application/x-www-form-urlencoded',
        'Accept: application/json',
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $data);

    $response = curl_exec($ch);
    $error = curl_error($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($error) {
        return ['success' => false, 'token' => null, 'error' => 'cURL error: ' . $error];
    }

    $body = json_decode($response, true);
    if ($http_code === 200 && isset($body['data']['access_token'])) {
        return ['success' => true, 'token' => $body['data']['access_token'], 'error' => null];
    }

    $msg = $body['detail'] ?? $body['message'] ?? 'Login failed (HTTP ' . $http_code . ')';
    return ['success' => false, 'token' => null, 'error' => $msg];
}

#-----------------------------#
function mit_get_all_admins($jwt_token, $panel_name) {
    $config = mit_get_config($panel_name);
    if (!$config) {
        return false;
    }

    $url = rtrim($config['mit_url'], '/') . '/superadmin/admins';

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_HTTPGET, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT_MS, 8000);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Accept: application/json',
        'Authorization: Bearer ' . $jwt_token,
    ]);

    $output = curl_exec($ch);
    $error = curl_error($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($error || $http_code !== 200) {
        return false;
    }

    $body = json_decode($output, true);
    return $body['data'] ?? false;
}

#-----------------------------#
function mit_find_admin($jwt_token, $panel_name, $admin_username) {
    $admins = mit_get_all_admins($jwt_token, $panel_name);
    if (!is_array($admins)) {
        return null;
    }

    foreach ($admins as $admin) {
        if (isset($admin['username']) && $admin['username'] === $admin_username) {
            return $admin;
        }
    }

    return null;
}

#-----------------------------#
function mit_get_admin_traffic($panel_name, $admin_username) {
    $login = mit_login($panel_name);
    if (!$login['success']) {
        return ['success' => false, 'traffic' => null, 'admin_id' => null, 'error' => $login['error']];
    }

    $admin = mit_find_admin($login['token'], $panel_name, $admin_username);
    if (!$admin) {
        return ['success' => false, 'traffic' => null, 'admin_id' => null, 'error' => 'Admin not found'];
    }

    $traffic = $admin['traffic'] ?? 0;
    return ['success' => true, 'traffic' => intval($traffic), 'admin_id' => intval($admin['id']), 'error' => null];
}

#-----------------------------#
function mit_deduct_traffic($panel_name, $admin_username, $traffic_bytes) {
    $login = mit_login($panel_name);
    if (!$login['success']) {
        return ['success' => false, 'remaining' => null, 'error' => $login['error']];
    }

    $admin = mit_find_admin($login['token'], $panel_name, $admin_username);
    if (!$admin) {
        return ['success' => false, 'remaining' => null, 'error' => 'Admin not found'];
    }

    $admin_id = $admin['id'];
    $current_limit = intval($admin['traffic'] ?? 0);
    $new_limit = max(0, $current_limit - intval($traffic_bytes));

    $config = mit_get_config($panel_name);
    $url = rtrim($config['mit_url'], '/') . '/superadmin/admin/' . $admin_id;

    $payload = json_encode(['traffic' => $new_limit]);

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, 'PUT');
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT_MS, 8000);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Accept: application/json',
        'Content-Type: application/json',
        'Authorization: Bearer ' . $login['token'],
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);

    $response = curl_exec($ch);
    $error = curl_error($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($error) {
        return ['success' => false, 'remaining' => null, 'error' => 'cURL error: ' . $error];
    }

    if ($http_code >= 200 && $http_code < 300) {
        return ['success' => true, 'remaining' => $new_limit, 'error' => null];
    }

    $body = json_decode($response, true);
    $msg = $body['detail'] ?? $body['message'] ?? 'Failed to update traffic (HTTP ' . $http_code . ')';
    return ['success' => false, 'remaining' => null, 'error' => $msg];
}

#-----------------------------#
function mit_test_connection($panel_name) {
    $config = mit_get_config($panel_name);
    if (!$config) {
        return ['success' => false, 'error' => 'Panel config not found'];
    }

    $url = rtrim($config['mit_url'], '/');

    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_HTTPGET, true);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT_MS, 6000);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Accept: application/json',
    ]);

    $response = curl_exec($ch);
    $error = curl_error($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($error) {
        return ['success' => false, 'error' => 'cURL error: ' . $error];
    }

    if ($http_code >= 200 && $http_code < 400) {
        return ['success' => true, 'error' => null];
    }

    return ['success' => false, 'error' => 'HTTP ' . $http_code];
}

#-----------------------------#
function mit_check_traffic($panel_name, $admin_username, $required_bytes) {
    $result = mit_get_admin_traffic($panel_name, $admin_username);
    if (!$result['success']) {
        return ['sufficient' => false, 'remaining' => null, 'error' => $result['error']];
    }

    $remaining = $result['traffic'];
    return [
        'sufficient' => $remaining >= intval($required_bytes),
        'remaining' => $remaining,
        'error' => null,
    ];
}

#-----------------------------#
function mit_get_target_admin($panel_name) {
    $config = mit_get_config($panel_name);
    if (!$config || empty($config['mit_target_admin'])) {
        return null;
    }
    return $config['mit_target_admin'];
}

#-----------------------------#
function mit_send_low_volume_alert($admin_id, $panel_name, $remaining_gb) {
    global $sendmessage;
    $admin_ids = select("admin", "id_admin", null, null, "FETCH_COLUMN");
    if (!$admin_ids) return;

    $text = "⚠️ Low traffic alert!\n"
          . "Panel: {$panel_name}\n"
          . "Admin ID: {$admin_id}\n"
          . "Remaining: {$remaining_gb} GB";

    foreach ($admin_ids as $admin_id_chat) {
        sendmessage($admin_id_chat, $text, null, 'HTML');
    }
}
