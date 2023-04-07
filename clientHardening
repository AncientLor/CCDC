checkNmap() {
    if [ ! $(command -v nmap) ]
    then
        echo "Installing nmap..."
        apt update && apt install nmap -y

    else
        echo "nmap already installed."

    fi
}
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

enumPrivs () {
    echo "" > user_privs.txt
    for user in $(cat /etc/passwd | cut -d ":" -f 1)
    do
        id $user >> user_privs.txt
    done
}

enumLogins () {
    echo "$hostname" >> logins.log
    date >> logins.log
    echo "[who]" >> logins.log
    who >> logins.log
    echo "[lastlog]" >> logins.log
    lastlog >> logins.log
    echo "[last]" >> logins.log
    last >> logins.log
    echo "[lastb]" >> logins.log
    lastb >> logins.log
    echo "[END]" >> logins.log
    echo ""
}

enumNetwork () {
    echo "$hostname" >> network.log
    date >> network.log
    echo "[netstat]" >> network.log
    netstat -tulnep >> network.log
    echo "[hosts]" >> network.log
    cat /etc/hosts >> network.log
    echo "[resolv]" >> network.log
    cat /etc/resolv.conf >> network.log
    echo "[nmap]" >> network.log
    nmap -sCV -v localhost >> network.log
    echo ""
}

show_help () {
    echo "Usage: ./remote_hardening.sh [--disableHistory] [--enumPrivs]"
    echo "--disableHistory  Link History Files to Null"
    echo "--enumPrivs       Enumerate User Privileges"
}

args=$1
main () {
    if [ ! $args ]
    then
        echo "Please specify a parameter."
        show_help
    elif [ $args == '--disableHistory' ]
    then
        disableHistory
    elif [ $args == '--enumPrivs' ]
    then
        enumPrivs
    elif [ $args == '--all' ]
    then
        disableHistory
        enumPrivs
        enumLogins
        checkNmap
        enumNetwork
    fi
}



main
