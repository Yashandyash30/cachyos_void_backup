function stopsunshine -d "Stop Sunshine streaming daemon"
    if string match -q "*rig*" (hostname)
        systemctl --user stop sunshine.service
    else
        ssh rig "systemctl --user stop sunshine.service"
    end
    echo "Sunshine stopped."
end
