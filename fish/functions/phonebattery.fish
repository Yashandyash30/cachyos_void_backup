function phonebattery
    echo "Querying voidphone..."
    ssh -p 8022 u0_a183@100.103.187.97 "termux-battery-status" | jq -r '"Battery Level: \(.percentage)%\nStatus: \(.status)"'
end
