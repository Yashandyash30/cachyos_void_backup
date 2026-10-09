function phone
    if test "$argv[1]" = "wifi"
        # Connect wirelessly via Tailscale Static IP
        ssh u0_a183@100.103.187.97 -p 8022
    else
        # Connect via USB / ADB
        adb forward tcp:8022 tcp:8022 2>/dev/null
        ssh u0_a183@127.0.0.1 -p 8022
    end
end
