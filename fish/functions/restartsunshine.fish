function restartsunshine
    echo "restarting sunshine..."
    ssh void@100.117.73.75 "systemctl --user restart sunshine"
    echo "sunshine restarted."
end
