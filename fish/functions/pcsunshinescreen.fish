function pcsunshinescreen -d "Switch which screen Sunshine captures on Host PC (HDMI vs DP)"
    set target $argv[1]

    set script '
        target="'$target'"
        conf="$HOME/.config/sunshine/sunshine.conf"
        export NIRI_SOCKET=$(echo /run/user/1000/niri.*.sock 2>/dev/null)

        if [ -z "$target" ] || [ "$target" = "status" ] || [ "$target" = "current" ]; then
            echo "=== Sunshine Host PC Current Setting ==="
            grep "output_name" "$conf" 2>/dev/null || echo "output_name is not set (defaulting to primary/Monitor 0)"
            echo ""
            echo "=== Active Displays in Niri ==="
            niri msg outputs 2>/dev/null | grep -E "(Output|Current mode)" || echo "No Niri session detected"
            echo ""
            echo "=== Detected Monitors in Sunshine Logs ==="
            grep -m 4 "Monitor [0-9]" "$HOME/.config/sunshine/sunshine.log" 2>/dev/null || true
            exit 0
        fi

        case "$(echo "$target" | tr "[:upper:]" "[:lower:]")" in
            hdmi)
                conn=$(niri msg outputs 2>/dev/null | grep -o "HDMI-A-[0-9]" | head -n 1)
                [ -z "$conn" ] && conn="HDMI-A-2"
                ;;
            dp|displayport)
                conn=$(niri msg outputs 2>/dev/null | grep -o "DP-[0-9]" | head -n 1)
                [ -z "$conn" ] && conn="DP-1"
                ;;
            hdmi-1|hdmi-a-1) conn="HDMI-A-1" ;;
            hdmi-2|hdmi-a-2) conn="HDMI-A-2" ;;
            dp-1) conn="DP-1" ;;
            dp-2) conn="DP-2" ;;
            0|1|2) conn="$target" ;;
            *) conn="$target" ;;
        esac

        if grep -q "^output_name" "$conf" 2>/dev/null; then
            sed -i "s/^output_name = .*/output_name = $conn/" "$conf"
        else
            echo "output_name = $conn" >> "$conf"
        fi

        systemctl --user restart sunshine.service
        echo "Sunshine on Host PC switched to: $conn"
    '

    if test (hostname) = "void-pc"
        bash -c "$script"
    else
        echo "$script" | ssh void@100.117.73.75 "bash -s"
    end
end
