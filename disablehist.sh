disableHistory () {
    users=$(ls /home)
    for user in $users
    do
        hist=$(ls -a /home/$user | grep history)
        for h in $hist
        do
            echo "[STATUS] Removing $user History Files: $h"
            rm -rf /home/$user/$h && ln -s /dev/null /home/$user/$h
            echo "[STATUS] Done."
        done
    done
    root_hist=$(ls -a /root | grep history)
    for h in $root_hist
    do
        echo "[STATUS] Removing Root History Files: $h"
        rm -rf /root/$h && ln -s /dev/null /root/$h
        echo "[STATUS] Done."
    done
}

disableHistory
