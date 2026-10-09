function jumppcz
    set target_dir (_get_pc_target_dir)
    
    ping -c 1 -W 1 100.117.73.75 > /dev/null
    if test $status -ne 0
        echo "PC is offline. Sending Wake-on-LAN..."
        wakepc
        sleep 30
    end
    
    echo "Jumping to Zellij session on PC at $target_dir..."
    ssh -t void@100.117.73.75 "cd '$target_dir' && exec zellij attach -c astro"
end
