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

# Change All User Account Passwords and Remove sudo/adm/wheel
changePasswords () {
    echo "[STATUS] Changing User Passwords and Removing Sudo Privs..."
    read -sp "Enter new pass: " new_pass
    enc_pass=$(openssl passwd -6 $new_pass)
    for host in $linux_hosts
    do
        ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "cat /etc/passwd | grep 'sh$' | cut -d ":" -f 1 | tee users.txt" > users.txt
        cat users.txt > users_$host.txt 
        echo ""
        for user in $(cat users.txt)
        do
            echo "Changing Password For: $user"
            ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "echo '$user:$enc_pass' | chpasswd -e"          
        done
        read -p "Change root password for $host (y/n)?: " change_root
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

removeSudo () {
    mkdir $PWD/privs
    echo "[STATUS] Backing-Up Original Privileges..."
    for host in $linux_hosts
    do
        ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "bash clientHardening.sh --enumPrivs"
        scp -i /root/.ssh/.xyz root@$host:/root/user_privs.txt $PWD/privs/user_privs_original_$host.txt
        for user in $(cat users.txt)
        do
            echo "Removing Sudo Privileges For: $user"
            for priv in "adm" "sudo" "wheel"
            do
                ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "gpasswd -d $user $priv 2> /dev/null"
            done
        done
    done      
}

remoteHardening () {
    mkdir $PWD/logins $PWD/network
    for host in $linux_hosts
    do 
        ssh -i /root/.ssh/.xyz -o StrictHostKeyChecking=no root@$host "bash clientHardening.sh --all"
        scp -i /root/.ssh/.xyz root@$host:/root/user_privs.txt $PWD/privs/user_privs_$host.txt
        scp -i /root/.ssh/.xyz root@$host:/root/logins.log $PWD/logins/logins_$host.log
        scp -i /root/.ssh/.xyz root@$host:/root/network.log $PWD/network/network_$host.log

    done
}

updateHardening () {
    for host in $linux_hosts
    do 
        echo "[STATUS] Transfering Hardening File To: $host"
        scp -i /root/.ssh/.xyz $PWD/clientHardening.sh root@$host:/root/clientHardening.sh
        echo "[STATUS] Done."
    done
}


main () {
    #echo '###################'
    #echo ' Initial Hardening '
    #echo '###################'
    disableHistory
    createSSHKeys
    #findLinuxHosts
    linux_hosts=$(cat linuxhosts)
    copyPubKey
    hardenSSH
    updateHardening
    changePasswords
    removeSudo
    addUser
    remoteHardening
}

main
