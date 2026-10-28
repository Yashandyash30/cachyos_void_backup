function restartsunshine -d "Restart Sunshine streaming service"
    if string match -q "*rig*" (hostname)
        echo "Restarting Sunshine locally on Rig..."
        systemctl --user restart sunshine.service
    else
        echo "Restarting Sunshine on Rig..."
        ssh rig "systemctl --user restart sunshine.service"
    end
    echo "Sunshine restarted."
end
