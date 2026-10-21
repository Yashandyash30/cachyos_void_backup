function guipcz
    set target_dir (_get_pc_target_dir)
    set pc_ip (_get_pc_ip)

    if not nc -z -w 1 $pc_ip 22 2>/dev/null
        echo "PC is offline at $pc_ip. Sending Wake-on-LAN..."
        wakepc; sleep 30
    end

    echo "Starting Xpra Graphics Tunnel ($pc_ip)..."
    ssh void@$pc_ip "xpra start :100 2>/dev/null"

    env GDK_BACKEND=x11 xpra attach ssh://void@$pc_ip/100 >/dev/null 2>&1 &
    set xpra_pid $last_pid

    echo "Jumping to Zellij (GUI-enabled) session on PC ($pc_ip) at $target_dir..."
    ssh -t void@$pc_ip "cd '$target_dir' && set -x DISPLAY :100 && exec zellij attach -c astro_gui"

    kill $xpra_pid
end
