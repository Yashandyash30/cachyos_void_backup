function sshtab
    set tab_ip (_get_tab_ip)
    echo "Connecting to Tablet ($tab_ip:8022)..."
    ssh -p 8022 u0_a484@$tab_ip $argv
end
