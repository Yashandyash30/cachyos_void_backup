function setrigrefreshrate -d "Change refresh rate on Rig's displays (DP-1 or HDMI-A-1)"
    set hz $argv[1]
    set target_output $argv[2]

    if test -z "$hz"
        set hz 60
    end

    if test -z "$target_output"
        set conf "$HOME/.config/sunshine/sunshine.conf"
        if test -f "$conf"
            set val (grep -E "^output_name" "$conf" 2>/dev/null | awk -F'=' '{print $2}' | tr -d ' ')
            switch "$val"
                case 0 dp DP-1
                    set target_output "DP-1"
                case 1 hdmi HDMI-A-1
                    set target_output "HDMI-A-1"
                case "*"
                    set target_output "DP-1"
            end
        else
            set target_output "DP-1"
        end
    else
        switch (string lower "$target_output")
            case dp dp-1 0
                set target_output "DP-1"
            case hdmi hdmi-a-1 1
                set target_output "HDMI-A-1"
        end
    end

    if string match -q "*rig*" (hostname)
        set -gx NIRI_SOCKET (echo /run/user/1000/niri.*.sock)
        niri msg output $target_output mode 1920x1080@$hz.000
    else
        ssh rig "export NIRI_SOCKET=\$(echo /run/user/1000/niri.*.sock); niri msg output $target_output mode 1920x1080@$hz.000"
    end
    echo "Rig $target_output mode set to $hz Hz"
end
