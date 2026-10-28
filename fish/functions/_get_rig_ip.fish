function _get_rig_ip
    # Check if Rig is reachable on local network (172.21.2.49) with a 1s timeout
    if nc -z -w 1 172.21.2.49 22 2>/dev/null
        echo "172.21.2.49"
    else
        echo "100.106.197.11"
    end
end
