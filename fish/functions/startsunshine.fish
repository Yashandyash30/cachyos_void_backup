function startsunshine -d "Start Sunshine streaming daemon"
    if string match -q "*rig*" (hostname)
        systemctl --user start sunshine.service
    else
        ssh rig "systemctl --user start sunshine.service"
    end
    echo "Sunshine started."
end
