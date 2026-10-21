function sshpc
    set pc_ip (_get_pc_ip)

    if not nc -z -w 1 $pc_ip 22 2>/dev/null
        echo "PC is offline at $pc_ip. Sending Wake-on-LAN via voidphone..."
        wakepc
        echo "Waiting 30 seconds for PC to boot and connect..."
        sleep 30
    end

    echo "Connecting to PC ($pc_ip)..."
    ssh void@$pc_ip
end
