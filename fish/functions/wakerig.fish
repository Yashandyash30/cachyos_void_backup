function wakerig
    echo "Sending Wake-on-LAN to Rig (30:56:0f:85:de:b2)..."
    wol 30:56:0f:85:de:b2 2>/dev/null
    wol -i 172.21.3.255 30:56:0f:85:de:b2 2>/dev/null
    ssh -o ConnectTimeout=2 -o BatchMode=yes -p 8022 u0_a183@100.103.187.97 "wol 30:56:0f:85:de:b2; wol -i 172.21.3.255 30:56:0f:85:de:b2 2>/dev/null" 2>/dev/null
    echo "Done."
end
