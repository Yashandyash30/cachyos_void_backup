function jumppc
    set target_dir (_get_pc_target_dir)
    
    ping -c 1 -W 1 100.117.73.75 > /dev/null
    if test $status -ne 0
        echo "PC is offline. Sending Wake-on-LAN via voidphone..."
        wakepc
        echo "Waiting 30 seconds for PC to boot..."
        sleep 30
    end
    
    echo "Jumping to PC at $target_dir..."
    ssh -t void@100.117.73.75 "cd '$target_dir' && exec fish"
end
