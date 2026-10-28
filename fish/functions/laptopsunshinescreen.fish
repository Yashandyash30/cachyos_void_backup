function laptopsunshinescreen --description 'Switch which screen Sunshine captures on Laptop (external vs internal)'
    set target $argv[1]
    switch "$target"
        case internal inbuilt edp edp-1 0
            set val 0
            set label "Laptop Inbuilt Screen (eDP-1 / Monitor 0)"
        case external hdmi hdmi-a-1 1
            set val 1
            set label "External Monitor (HDMI-A-1 / Monitor 1)"
        case status current ""
            if test (hostname) = "void"
                cat ~/.config/sunshine/sunshine.conf 2>/dev/null | grep output_name
                echo "--- Detected Monitors in Sunshine ---"
                grep -m 2 'Monitor [01]' ~/.config/sunshine/sunshine.log 2>/dev/null
            else
                ssh void@100.70.236.70 "cat ~/.config/sunshine/sunshine.conf 2>/dev/null | grep output_name; echo '--- Detected Monitors in Sunshine ---'; grep -m 2 'Monitor [01]' ~/.config/sunshine/sunshine.log 2>/dev/null"
            end
            return
        case "*"
            echo "Usage: laptopsunshinescreen [external | internal | status]"
            echo "  external -> captures MSI MAG 255F (HDMI-A-1 / output_name = 1)"
            echo "  internal -> captures Inbuilt Screen (eDP-1 / output_name = 0)"
            return 1
    end

    if test (hostname) = "void"
        sed -i "s/^output_name = .*/output_name = $val/" ~/.config/sunshine/sunshine.conf
        systemctl --user restart sunshine.service
    else
        ssh void@100.70.236.70 "sed -i 's/^output_name = .*/output_name = $val/' ~/.config/sunshine/sunshine.conf && systemctl --user restart sunshine.service"
    end
    echo "Sunshine on Laptop switched to: $label"
end
