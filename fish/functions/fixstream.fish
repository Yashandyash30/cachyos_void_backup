function fixstream
    echo "Waking monitors..."
    ssh void@100.117.73.75 "ddcutil -d 1 setvcp 0xd6 0x01; ddcutil -d 2 setvcp 0xd6 0x01"
    echo "Restarting Sunshine..."
    ssh void@100.117.73.75 "systemctl --user restart sunshine"
    echo "Recovery complete."
end
