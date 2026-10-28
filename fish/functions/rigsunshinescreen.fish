function rigsunshinescreen -d "Switch which screen Sunshine captures on Rig (DP vs HDMI)"
    set target $argv[1]

    set script '
        target="'$target'"
        conf="$HOME/.config/sunshine/sunshine.conf"
        export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock 2>/dev/null)

        if [ -z "$target" ] || [ "$target" = "status" ] || [ "$target" = "current" ]; then
            echo "=== Sunshine Rig Current Setting ==="
            grep "output_name" "$conf" 2>/dev/null || echo "output_name is not set (defaulting to primary/Monitor 0 - DP-1)"
            echo ""
            echo "=== Active Displays in Niri ==="
            niri msg outputs 2>/dev/null | grep -E "(Output|Current mode)" || echo "No Niri session detected"
            echo ""
            echo "=== Detected Monitors in Sunshine Logs ==="
            grep -m 4 "Monitor [0-9]" "$HOME/.config/sunshine/sunshine.log" 2>/dev/null || true
            exit 0
        fi

        case "$(echo "$target" | tr "[:upper:]" "[:lower:]")" in
            dp|displayport|dp-1|0)
                conn="DP-1"
                label="HP 324pv (DP-1 / Monitor 0)"
                ;;
            hdmi|hdmi-a-1|1)
                conn="HDMI-A-1"
                label="MSI MAG 255F (HDMI-A-1 / Monitor 1)"
                ;;
            *)
                conn="$target"
                label="$target"
                ;;
        esac

        mkdir -p "$(dirname "$conf")"
        if grep -q "^output_name" "$conf" 2>/dev/null; then
            sed -i "s/^output_name = .*/output_name = $conn/" "$conf"
        else
            echo "output_name = $conn" >> "$conf"
        fi

        systemctl --user restart sunshine.service
        echo "Sunshine on Rig switched to: $label ($conn)"
    '

    if string match -q "*rig*" (hostname)
        bash -c "$script"
    else
        echo "$script" | ssh rig "bash -s"
    end
end
