#!/bin/sh

. /opt/pwn.college/data/config.env

if [ ! "$(ls -A /opt/pwn.college/data/dojos /opt/pwn.college/data/challenges)" ]; then
    echo "Warning: initializing dojo for the first time and no data included, auto populating with data_example"
    cp -r /opt/pwn.college/data_example/* /opt/pwn.college/data
fi

if [ ! -f /opt/pwn.college/data/homes/homefs ]; then
    mkdir -p /opt/pwn.college/data/homes
    mkdir -p /opt/pwn.college/data/homes/data
    mkdir -p /opt/pwn.college/data/homes/nosuid
    dd if=/dev/zero of=/opt/pwn.college/data/homes/homefs bs=1M count=0 seek=1000
    mkfs.ext4 -O ^has_journal /opt/pwn.college/data/homes/homefs
    mount /opt/pwn.college/data/homes/homefs -o X-mount.mkdir /opt/pwn.college/data/homes/homefs_mount
    rm -rf /opt/pwn.college/data/homes/homefs_mount/lost+found/
    cp -a /etc/skel/. /opt/pwn.college/data/homes/homefs_mount
    chown -R hacker:hacker /opt/pwn.college/data/homes/homefs_mount
    umount /opt/pwn.college/data/homes/homefs_mount
    rm -rf /opt/pwn.college/data/homes/homefs_mount
fi

for i in $(seq 1 4096); do
    if [ -e /dev/loop$i ]; then
        continue
    fi
    mknod /dev/loop$i b 7 $i
    chown --reference=/dev/loop0 /dev/loop$i
    chmod --reference=/dev/loop0 /dev/loop$i
done


if [ ! -d /opt/pwn.college/data/ssh_host_keys ]; then
    mkdir -p /opt/pwn.college/data/ssh_host_keys
    rm /etc/ssh/ssh_host_*_key*
    ssh-keygen -A
    for key in $(ls /etc/ssh/ssh_host_*_key*); do
        cp -a $key /opt/pwn.college/data/ssh_host_keys
    done
else
    for key in $(ls /opt/pwn.college/data/ssh_host_keys/ssh_host_*_key*); do
        cp -a $key /etc/ssh
    done
fi

mkdir -p /opt/pwn.college/data/dms/config \
         /opt/pwn.college/data/dms/mail-data \
         /opt/pwn.college/data/dms/mail-state \
         /opt/pwn.college/data/dms/mail-logs
echo "hacker@${DOJO_HOST}|{SHA512-CRYPT}$(openssl passwd -6 hacker)" > /opt/pwn.college/data/dms/config/postfix-accounts.cf

mkdir -p /opt/pwn.college/data/logging

sysctl -w kernel.pty.max=1048576
echo core > /proc/sys/kernel/core_pattern

iptables -N DOCKER-USER
iptables -I DOCKER-USER -i user_firewall -j DROP
for host in $(cat /opt/pwn.college/user_firewall.allowed); do
    iptables -I DOCKER-USER -i user_firewall -d $(host $host | awk '{print $NF; exit}') -j ACCEPT
done

exec /usr/bin/systemd
