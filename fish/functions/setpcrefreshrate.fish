function setpcrefreshrate
    set hz $argv[1]
    if test -z "$hz"
        set hz 60
    end
    ssh void@100.117.73.75 "export NIRI_SOCKET=\$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-2 mode 1920x1080@$hz.000"
    echo "PC HDMI-A-2 mode set to $hz Hz"
end
