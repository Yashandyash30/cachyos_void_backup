function sshpc
    # Ping the PC's Tailscale IP once to see if it is online
        ping -c 1 -W 1 100.117.73.75 > /dev/null
        
        if test $status -ne 0
                echo "PC is offline. Sending Wake-on-LAN via voidphone..."
                wakepc
                echo "Waiting 30 seconds for PC to boot and connect to Tailscale..."
                sleep 30
        end
        
        echo "Connecting to PC..."
        ssh void@100.117.73.75
end
