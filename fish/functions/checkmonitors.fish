function checkmonitors -d "Check monitor power states"
    if string match -q "*rig*" (hostname)
        echo "Querying physical monitor power states locally on Rig..."
        ddcutil -d 1 getvcp d6 2>/dev/null || true
    else
        echo "Querying physical monitor power states on Rig..."
        ssh rig "ddcutil -d 1 getvcp d6 2>/dev/null || true"
    end
end
