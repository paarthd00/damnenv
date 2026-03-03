#!/usr/bin/env sh

set -u

has() {
    command -v "$1" >/dev/null 2>&1
}

run_bg() {
    "$@" >/dev/null 2>&1 &
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

wifi_state() {
    if ! has nmcli; then
        printf 'unavailable'
        return
    fi
    state="$(nmcli -t -f WIFI g 2>/dev/null | head -n1 || true)"
    if [ -n "$state" ]; then
        printf '%s' "$state"
    else
        printf 'unavailable'
    fi
}

wifi_ssid() {
    if ! has nmcli; then
        return
    fi
    nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1=="yes"{print $2; exit}'
}

active_vpn_name() {
    if ! has nmcli; then
        return
    fi
    nmcli -t -f NAME,TYPE connection show --active 2>/dev/null \
        | awk -F: '$2=="vpn" || $2=="wireguard"{print $1; exit}'
}

configured_vpn_name() {
    if ! has nmcli; then
        return
    fi
    nmcli -t -f NAME,TYPE connection show 2>/dev/null \
        | awk -F: '$2=="vpn" || $2=="wireguard"{print $1; exit}'
}

bluetooth_powered() {
    if ! has bluetoothctl; then
        printf 'unavailable'
        return
    fi
    if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
        printf 'yes'
    else
        printf 'no'
    fi
}

bluetooth_connected_count() {
    if ! has bluetoothctl; then
        printf '0'
        return
    fi
    bluetoothctl devices Connected 2>/dev/null | wc -l | tr -d ' '
}

audio_status() {
    if ! has pactl; then
        printf 'Unavailable'
        return
    fi

    muted="$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')"
    volume="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null \
        | awk 'NR==1{for(i=1;i<=NF;i++) if($i ~ /%$/){print $i; exit}}')"

    if [ "${muted:-no}" = "yes" ]; then
        printf 'Muted'
    elif [ -n "${volume:-}" ]; then
        printf '%s' "$volume"
    else
        printf 'Unavailable'
    fi
}

status_json() {
    wifi="$(wifi_state)"
    ssid="$(wifi_ssid)"
    vpn="$(active_vpn_name)"
    bt="$(bluetooth_powered)"
    bt_count="$(bluetooth_connected_count)"
    audio="$(audio_status)"

    wifi_label="Off"
    wifi_token=""
    if [ "$wifi" = "enabled" ]; then
        wifi_token="WiFi"
        if [ -n "$ssid" ]; then
            wifi_label="On ($ssid)"
        else
            wifi_label="On"
        fi
    elif [ "$wifi" = "unavailable" ]; then
        wifi_label="Unavailable"
    fi

    vpn_label="Off"
    vpn_token=""
    if [ -n "$vpn" ]; then
        vpn_label="On ($vpn)"
        vpn_token="VPN"
    fi

    bt_label="Off"
    bt_token=""
    if [ "$bt" = "yes" ]; then
        bt_token="BT"
        if [ "${bt_count:-0}" -gt 0 ] 2>/dev/null; then
            bt_label="On ($bt_count connected)"
        else
            bt_label="On"
        fi
    elif [ "$bt" = "unavailable" ]; then
        bt_label="Unavailable"
    fi

    text="$wifi_token"
    if [ -n "$vpn_token" ]; then
        if [ -n "$text" ]; then
            text="$text $vpn_token"
        else
            text="$vpn_token"
        fi
    fi
    if [ -n "$bt_token" ]; then
        if [ -n "$text" ]; then
            text="$text $bt_token"
        else
            text="$bt_token"
        fi
    fi
    if [ -z "$text" ]; then
        text="Quick"
    fi

    tooltip="$(printf 'WiFi: %s\\nVPN: %s\\nBluetooth: %s\\nAudio: %s' "$wifi_label" "$vpn_label" "$bt_label" "$audio")"

    printf '{"text":"%s","tooltip":"%s"}\n' "$(json_escape "$text")" "$(json_escape "$tooltip")"
}

wifi_toggle() {
    has nmcli || exit 0
    state="$(wifi_state)"
    if [ "$state" = "enabled" ]; then
        nmcli radio wifi off >/dev/null 2>&1 || true
    elif [ "$state" = "disabled" ]; then
        nmcli radio wifi on >/dev/null 2>&1 || true
    fi
}

vpn_toggle() {
    has nmcli || exit 0
    active="$(active_vpn_name)"
    if [ -n "$active" ]; then
        nmcli connection down id "$active" >/dev/null 2>&1 || true
        return
    fi

    target="$(configured_vpn_name)"
    if [ -n "$target" ]; then
        nmcli connection up id "$target" >/dev/null 2>&1 || true
    fi
}

bluetooth_toggle() {
    has bluetoothctl || exit 0
    if [ "$(bluetooth_powered)" = "yes" ]; then
        bluetoothctl power off >/dev/null 2>&1 || true
    else
        bluetoothctl power on >/dev/null 2>&1 || true
    fi
}

audio_toggle_mute() {
    has pactl || exit 0
    pactl set-sink-mute @DEFAULT_SINK@ toggle >/dev/null 2>&1 || true
}

open_network_settings() {
    if has nm-connection-editor; then
        run_bg nm-connection-editor
    elif has gnome-control-center; then
        run_bg gnome-control-center network
    fi
}

open_vpn_settings() {
    if has nm-connection-editor; then
        run_bg nm-connection-editor
    elif has gnome-control-center; then
        run_bg gnome-control-center network
    fi
}

open_bluetooth_settings() {
    if has gnome-control-center; then
        run_bg gnome-control-center bluetooth
    elif has blueman-manager; then
        run_bg blueman-manager
    fi
}

open_audio_settings() {
    if has pavucontrol; then
        run_bg pavucontrol
    elif has gnome-control-center; then
        run_bg gnome-control-center sound
    fi
}

open_power_settings() {
    if has gnome-control-center; then
        run_bg gnome-control-center power
    fi
}

action="${1:-status}"
case "$action" in
    status)
        status_json
        ;;
    wifi-toggle)
        wifi_toggle
        ;;
    vpn-toggle)
        vpn_toggle
        ;;
    bluetooth-toggle)
        bluetooth_toggle
        ;;
    audio-toggle-mute)
        audio_toggle_mute
        ;;
    open-network-settings)
        open_network_settings
        ;;
    open-vpn-settings)
        open_vpn_settings
        ;;
    open-bluetooth-settings)
        open_bluetooth_settings
        ;;
    open-audio-settings)
        open_audio_settings
        ;;
    open-power-settings)
        open_power_settings
        ;;
    *)
        printf 'Unknown action: %s\n' "$action" >&2
        exit 1
        ;;
esac
