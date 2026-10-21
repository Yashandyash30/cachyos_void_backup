function jumppc
    set target_dir (_get_pc_target_dir)
    set pc_ip (_get_pc_ip)

    if not nc -z -w 1 $pc_ip 22 2>/dev/null
        echo "PC is offline at $pc_ip. Sending Wake-on-LAN via voidphone..."
        wakepc
        echo "Waiting 30 seconds for PC to boot..."
        sleep 30
    end

    echo "Jumping to PC ($pc_ip) at $target_dir..."
    ssh -t void@$pc_ip "cd '$target_dir' && exec fish"
end
