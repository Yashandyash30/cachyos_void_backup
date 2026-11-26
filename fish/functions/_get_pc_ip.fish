function _get_pc_ip
    # Check if PC is reachable on local network (172.21.1.25) with a 1s timeout
    if nc -z -w 1 172.21.1.25 22 2>/dev/null
        echo "172.21.1.25"
    else
        echo "100.117.73.75"
    end
end
