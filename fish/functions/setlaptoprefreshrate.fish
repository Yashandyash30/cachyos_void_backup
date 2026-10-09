function setlaptoprefreshrate -d "Change refresh rate on Laptop's external monitor (HDMI-A-1)"
    set hz $argv[1]
    if test -z "$hz"
        set hz 120
    end

    if test (hostname) = "void-pc"
        ssh void@100.70.236.70 "export NIRI_SOCKET=\$(echo /run/user/1000/niri.*.sock); niri msg output HDMI-A-1 mode 1920x1080@$hz.000"
    else
        set -gx NIRI_SOCKET (echo /run/user/1000/niri.*.sock)
        niri msg output HDMI-A-1 mode 1920x1080@$hz.000
    end
    echo "Laptop HDMI-A-1 (MSI MAG 255F) set to $hz Hz"
end
