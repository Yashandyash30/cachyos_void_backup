function phonepic
    echo "📸 Snapping photo from voidphone front camera..."
    
    # Wake the screen up (even if locked) to bypass background camera restrictions
    ssh -p 8022 u0_a183@100.103.187.97 "sudo input keyevent 224; sleep 1"
    
    # Take the photo and save it temporarily on the phone
    ssh -p 8022 u0_a183@100.103.187.97 "termux-camera-photo -c 1 ~/latest_pic.jpg"
    set photo_status $status
    
    # Immediately put the screen back to sleep
    ssh -p 8022 u0_a183@100.103.187.97 "sudo input keyevent 223"
    
    if test $photo_status -eq 0
        # Generate a timestamped filename
        set filename "voidphone_pic_"(date +%Y%m%d_%H%M%S)".jpg"
        
        echo "📥 Downloading to $PWD/$filename..."
        scp -q -P 8022 u0_a183@100.103.187.97:~/latest_pic.jpg ./$filename
        
        echo "✅ Done!"
    else
        echo "❌ Failed to take photo. Make sure permissions are granted."
    end
end
