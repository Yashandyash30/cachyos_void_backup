function guipc
    set app_cmd $argv[1]
    if test -z "$app_cmd"
        echo "Please specify a tool (e.g., guipc pyraf)"
        return 1
    end
    
    set target_dir (_get_pc_target_dir)
    
    ping -c 1 -W 1 100.117.73.75 > /dev/null
    if test $status -ne 0
        echo "PC is offline. Sending Wake-on-LAN..."
        wakepc; sleep 30
    end
    
    echo "Starting Xpra Graphics Tunnel..."
    # 1. Start a persistent invisible X11 display (:100) on the Host PC
    ssh void@100.117.73.75 "xpra start :100 2>/dev/null"
    
    # 2. Attach the laptop to that display in the background
    # We use GDK_BACKEND=x11 to prevent Niri scaling bugs
    env GDK_BACKEND=x11 xpra attach ssh://void@100.117.73.75/100 >/dev/null 2>&1 &
    set xpra_pid $last_pid
    
    echo "Launching $app_cmd on Host PC at $target_dir..."
    # 3. SSH in interactively, point the graphics to :100, and launch the CLI tool
    ssh -t void@100.117.73.75 "cd '$target_dir' && set -x DISPLAY :100 && exec fish -i -C '$app_cmd'"
    
    # 4. Clean up the background Xpra window grabber when you close the app
    kill $xpra_pid
end
