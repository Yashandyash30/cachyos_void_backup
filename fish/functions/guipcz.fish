function guipcz
    set target_dir (_get_pc_target_dir)
    
    ping -c 1 -W 1 100.117.73.75 > /dev/null
    if test $status -ne 0
        echo "PC is offline. Sending Wake-on-LAN..."
        wakepc; sleep 30
    end
    
    echo "Starting Xpra Graphics Tunnel..."
    ssh void@100.117.73.75 "xpra start :100 2>/dev/null"
    
    env GDK_BACKEND=x11 xpra attach ssh://void@100.117.73.75/100 >/dev/null 2>&1 &
    set xpra_pid $last_pid
    
    echo "Jumping to Zellij (GUI-enabled) session on PC at $target_dir..."
    ssh -t void@100.117.73.75 "cd '$target_dir' && set -x DISPLAY :100 && exec zellij attach -c astro_gui"
    
    kill $xpra_pid
end
