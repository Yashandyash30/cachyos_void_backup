function _get_tab_ip
    # 1. Test last known local LAN IP
    if nc -z -w 1 172.21.3.148 8022 2>/dev/null
        echo "172.21.3.148"
        return
    end

    # 2. Check ARP table for tablet MAC (2e:b9:53:fd:2f:81) if DHCP IP changed
    set lan_ip (ip neigh 2>/dev/null | grep -i "2e:b9:53:fd:2f:81" | awk '{print $1}')
    if test -n "$lan_ip"
        if nc -z -w 1 $lan_ip 8022 2>/dev/null
            echo "$lan_ip"
            return
        end
    end

    # 3. Fallback to Tailscale IP
    echo "100.78.165.3"
end
