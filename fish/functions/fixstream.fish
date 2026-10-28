function fixstream -d "Wake monitors and restart Sunshine on Rig"
    if string match -q "*rig*" (hostname)
        echo "Waking monitor (Display 1 - MSI MAG 255F)..."
        ddcutil -d 1 setvcp 0xd6 0x01 2>/dev/null || true
        echo "Restarting Sunshine..."
        systemctl --user restart sunshine.service
    else
        echo "Waking monitor on Rig..."
        ssh rig "ddcutil -d 1 setvcp 0xd6 0x01 2>/dev/null || true; systemctl --user restart sunshine.service"
    end
    echo "Recovery complete."
end
