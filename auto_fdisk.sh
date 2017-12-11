#!/bin/bash
# Author:  白开水 <mengzq@sinoage.com>
# QQ: 719975531  
#
# Notes: LoveOpenSource for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+
#
#
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
clear
printf "
#######################################################################
#       LoveOpenSource for CentOS/RadHat 5+ Debian 6+ and Ubuntu 12+  #
#                             Auto fdisk                              #
#       For more information please contact with me                   #
#######################################################################
"
echo=echo
for cmd in echo /bin/echo; do
        $cmd >/dev/null 2>&1 || continue
        if ! $cmsk -e  "" | grep -qE '^-e'; then
                echo=$cmd
                break        
fi
done
CSI=$($echo -e "\033[")
CEND="${CSI}0m"
CDGREEN="${CSI}32m"
CRED="${CSI}1;31m"
CGREEN="${CSI}1;32m"
CYELLOW="${CSI}1;33m"
CBLUE="${CSI}1;34m"
CMAGENTA="${CSI}1;35m"
CCYAN="${CSI}1;36m"
CSUCCESS="$CDGREEN"
CFAILURE="$CRED"
CQUESTION="$CMAGENTA"
CWARNING="$CYELLOW"
CMSG="$CCYAN"
# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }
#UUID=$(blkid /dev/md127|awk '{print $2}')
#UUID=$(blkid /dev/sda1|awk '{print $2}')
#o=$(fdisk -l | grep "fd" |wc -l)
#p=$(fdisk -l | grep "fd" | grep "/dev"|awk  '{print $1}')
#p=$(fdisk -l | grep "fd" | grep "/dev"|awk  '{print $1}'|  sed -n '1h;1!H;${g;s/\n/ /g;p;}')
#raid_level=$(0)
#q=$(/dev/md127)
#MOUNT_DIR=$(blkid|grep /dev/md127|awk '{print $2}')
MOUNT_DIR=/data
FSTAB_FILE=/etc/fstab
count=0
TMP1=/tmp/.tmp1
TMP2=/tmp/.tmp2
TMP3=/tmp/.tmp3
> $TMP1
> $TMP2
# check lock file, one time only let the script run one time 
LOCKfile=/tmp/.$(basename $0)
if [ -f "$LOCKfile" ];then
    echo
    echo "${CWARNING}The script is already exist, please next time to run this script${CEND}"
    echo
    exit
else
    echo
    echo "${CMSG}Step 1.No lock file, begin to create lock file and continue${CEND}"
    echo
    touch $LOCKfile
fi
# check disk partition
check_disk() {
    > $LOCKfile
    for i in `fdisk -l | grep "Disk" | grep "/dev" | awk '{print $2}' | awk -F: '{print $1}' | grep "sd"`
    do
        DEVICE_COUNT=$(fdisk -l $i | grep "$i" | awk '{print $2}' | awk -F: '{print $1}' | wc -l)
        NEW_MOUNT=$(df -h)
        if [ $DEVICE_COUNT -lt 2 ];then
            if [ -n "$(echo $NEW_MOUNT | grep -w "$i")" -o "$(grep -v '^#' $FSTAB_FILE | grep -v ^$ | awk '{print $1,$2,$3}' | grep -w "$i" | awk '{print $2}')" == '/' -o "$(grep -v '^#' $FSTAB_FILE | grep -v ^$ | awk '{print $1,$2,$3}' | grep -w "$i" | awk '{print $3}')" == 'swap' ];then
                echo "${CWARNING}The $i disk is mounted${CEND}"
            else
                echo $i >> $LOCKfile
                echo "You have a free disk, Now will fdisk it and mount it"
            fi
        fi
    done
    DISK_LIST=$(cat $LOCKfile)
    if [ "X$DISK_LIST" == "X" ];then
        echo
        echo "${CWARNING}No free disk need to be fdisk. Exit script${CEND}"
        echo
        rm -rf $LOCKfile
        exit 0
    else
        echo "${CMSG}This system have free disk :${CEND}"
        for i in `echo $DISK_LIST`
        do
            echo "$i"
            count=$((count+1))
        done
#        [ $count -gt 1 ] && { echo "${CWARNING}This system has at least two free disk, You must manually mount it${CEND}"; exit 0; }
    fi
}
# check os
check_os() {
    os_release=$(grep "CentOS release 6.5 (Final)" /etc/issue 2>/dev/null)
    os_release_2=$(grep "CentOS release 6.5 (Final)" /etc/redhat-release 2>/dev/null)
    if [ "$os_release" ] && [ "$os_release_2" ];then
        if echo "$os_release" | grep "CentOS release 6.5 (Final)" >/dev/null 2>&1;then
            os_release="CentOS release 6.5 (Final)"
           modify_env
        fi
    fi
}
# install ext4
# install mdadm
modify_env() {
#    modprobe ext4
    yum -y install mdadm
}
# fdisk ,formating and create the file system
fdisk_fun() {
fdisk -S 56 $i << EOF
n
p
1


t
fd
w
EOF
sleep 5
#mkfs.ext4 ${i}1
}
adm() {
o=$(fdisk -l | grep "fd" |wc -l)
p=$(fdisk -l | grep "fd" | grep "/dev"|awk  '{print $1}'|  sed -n '1h;1!H;${g;s/\n/ /g;p;}')
mdadm --create /dev/md127 --level "0" --raid-devices $o $p 
sleep 5
}
fs() {
mkfs.ext4  -T largefile /dev/md127
sleep 20
}

#UUID=$(blkid /dev/md127|awk '{print $2}')

UUID_data() {
UUID=$(blkid /dev/md127|awk '{print $2}')
echo "$UUID" >> $TMP2
}
# make directory
make_dir() {
    echo "${CMSG}Step 4.Begin to make directory${CEND}"
    [ -d "$MOUNT_DIR" ] && mv ${MOUNT_DIR}{,_bk}
#UUID=$(blkid /dev/md127|awk '{print $2}')
    mkdir -p $MOUNT_DIR
    echo "$MOUNT_DIR" >> $TMP1
}
# config /etc/fstab and mount device
main() {
    for i in `echo $DISK_LIST`
    do
        echo
        echo "${CMSG}Step 3.Begin to fdisk free disk${CEND}"
        [ -n "`df -h | grep ${i}1`" ] && { echo "${CFAILURE}The ${i}1 already mount${CEND}"; echo; exit 0; }
#	dev=$([`df -h | grep ${i}1`] && { echo "${CFAILURE}The ${i}1 already mount${CEND}"; echo; exit 0; })
        fdisk_fun $i > /dev/null 2>&1
        echo
#        echo "${i}1" >> $TMP3
#	echo "$UUID" >> $TMP2	
    done
    adm
    fs
    make_dir
    UUID_data
    > $LOCKfile
    paste $TMP2 $TMP1 > $LOCKfile
    echo
    echo "${CMSG}Step 5.Begin to write configuration to /etc/fstab and mount device${CEND}"
    while read a b
    do
        [ -z "`grep ^${a} $FSTAB_FILE`" -a -z "`grep ${b} $FSTAB_FILE`" ] && echo "${a} $b      ext4    defaults      0 2" >> $FSTAB_FILE
    done < $LOCKfile
    mount -a
    echo
}
# start script
echo "${CMSG}Step 2.Begin to check free disk${CEND}"
#service mysqld stop
#mv /data /root
check_os
check_disk
main
df -h
fdisk -l|grep /dev/md127
printf="Congratulations! SUCCESS!!"
#mv /root/data/* /data
#service mysqld start
rm -rf $LOCKfile $TMP1 $TMP2 
