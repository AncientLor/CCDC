#!/bin/bash

# Check Sudo Permissions
if [ $(echo $UID) -ne 0 ]
then
    echo "[ERROR] Please run as root."
    exit
fi

# Check For sshpass
if [ ! command -v sshpass &> /dev/null ]
then
    echo "[STATUS] Installing sshpass..."
    apt install sshpass -y
fi

# Disable History Files
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

# Create SSH Keys
createSSHKeys () {
    echo "[STATUS] Creating SSH Keys..."
    ssh-keygen -f /root/.ssh/.xyz -N ''
    chmod 600 /root/.ssh/.xyz
    echo "[STATUS] Done."
}

# Find Linux Hosts
findLinuxHosts () {
    echo "[STATUS] Checking for nmap..."
    if [ ! command -v nmap &> /dev/null ]
    then
        echo "[STATUS] Installing nmap..."
        apt install nmap -y
    else
        echo "[STATUS] Nmap already installed"
    fi
    read -p "Enter host range: " host_range
    echo "[STATUS] Finding Linux Hosts..."
    nmap -sn --reason $host_range --disable-arp-ping | grep "ttl 64" -B 1 | grep -E '[0-9].[0-9].[0-9].[0-9]' | cut -d " " -f 5 > linuxhosts
    echo "[STATUS] Done."
}

# Copy Pubkey to Hosts 
copyPubKey () {
    read -sp "Enter ssh pass: " pw
    echo "[STATUS] Copying SSH PubKey to Hosts..."
    for host in $linux_hosts
    do
        sshpass -p $pw ssh-copy-id -i /root/.ssh/.xyz.pub root@$host
        #sshpass -p $pw ssh root@$host -o StrictHostKeyChecking=no "echo hello > hello.txt"
    done
    echo "[STATUS] Done."
}


# Create New Sudo User on Hosts
addUser () {
    echo "[STATUS] Adding New User to Hosts..."
    read -p "Enter new username: " new_user
    read -sp "Enter user pass: " user_pass
    enc_pass=$(openssl passwd -6 $user_pass)
    for host in $linux_hosts
    do
        ssh -i /root/.ssh/.xyz root@$host -o StrictHostKeyChecking=no "useradd $new_user -p $enc_pass -m && usermod -aG sudo $new_user && mkdir /home/$new_user/.ssh && cp /root/.ssh/authorized_keys /home/$new_user/.ssh/authorized_keys && chown -R $new_user:$new_user /home/$new_user/.ssh && chmod 600 /home/$new_user/.ssh/authorized_keys && systemctl restart sshd"
    done
}

# Copy Hardened SSH Config File // Disable Password Login
hardenSSH () {
    echo "[STATUS] Hardening SSH..."
    for host in $linux_hosts
    do
        scp -i /root/.ssh/.xyz -o StrictHostKeyChecking=no /etc/ssh/sshd_config root@$host:/etc/ssh/sshd_config 
        ssh -i /root/.ssh/.xyz root@$host -o StrictHostKeyChecking=no "systemctl restart sshd"
    done
}

# Change All User Account Passwords
changePasswords () {
    echo "[STATUS] Changing User Passwords..."
    read -sp "Enter new pass: " new_pass
    enc_pass=$(openssl passwd -6 $new_pass)
    for host in $linux_hosts
    do
        ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "cat /etc/passwd | grep 'sh$' | cut -d ":" -f 1 | tee users.txt" > users.txt
        echo ""
        for user in $(cat users.txt)
        do
            echo "Changing Password For: $user"
            ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "echo '$user:$enc_pass' | chpasswd -e"
        done
        read -p "Change root password (y/n)?: " change_root
        if [ $change_root == "y" ]
        then
            read -sp "Enter new root password: " root_pass
            enc_root=$(openssl passwd -6 $root_pass)
            ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "echo 'root:$enc_root' | chpasswd -e"
            echo ""
            echo "Changing Password For: root"
        fi
    done
    echo "[STATUS] Done."
}

disableHistoryRemote () {
    for host in $linux_hosts
    do 
        scp -i /root/.ssh/.xyz /root/disablehist.sh root@$host:/root
        ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "bash disablehist.sh"
    done
}



main () {
    echo '###################'
    echo ' Initial Hardening '
    echo '###################'
    disableHistory
    createSSHKeys
    findLinuxHosts
    linux_hosts=$(cat linuxhosts)
    copyPubKey
    addUser
    hardenSSH
    changePasswords
    disableHistoryRemote
}

main
