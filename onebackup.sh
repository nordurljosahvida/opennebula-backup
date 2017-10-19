#!/usr/bin/env bash

# vars

now=$(date "+%Y-%m-%d_%H-%M-%S")
today=$(date +"%u")
fullbackupday=0 # monday is 1, sunday is 7
datastoresrootdir=/var/lib/one/datastores/ # include trailing slash!
backupsrootdir=/media/externaldrive/backups/ # include trailing slash!
logbasedir=/root/scripts/logs/fullbackup/ # include trailing slash!
logbasename=fullbackup-$now.log
duplicitykey=XXXXXXXX
servername=ubuntu
domain=example.net
sshkeyvm01=/root/.ssh/vm-01_id_rsa
sshkeyvm02=/root/.ssh/vm-02_id_rsa
excludefilelocal=/root/scripts/fullbackup/exclude-local.txt
excludefilevm01=/root/scripts/fullbackup/exclude-vm-01.txt
excludefilevm02=/root/scripts/fullbackup/exclude2.txt

# /vars

vmbackupdir="$backupsrootdir"vms/ # include trailing slash!
logbasename=fullbackup-$now.log
logfile="$logbasedir""$logbasename"

rm "$logbasedir"latest.log
ln -s "$logfile" "$logbasedir"latest.log

exec >  >(tee -a $logfile)
exec 2> >(tee -a $logfile >&2)

echo
echo "Starting fullbackup on $now"
echo

# full local system backup [https://wiki.archlinux.org/index.php/full_system_backup_with_rsync]

echo Backing up local root
echo

mkdir -p "$backupsrootdir"local/slash/

. /root/.gpgpp && export PASSPHRASE && duplicity --encrypt-key "$duplicitykey" --exclude-globbing-filelist="$excludefilelocal" / file://"$backupsrootdir"local/slash/

# List running vms [name of vms must start with "x"]

echo "Backing up virtual machines' roots"
echo

mapfile -t onenames < <(onevm list | grep runn | egrep -o "(\s(x\S+))" | cut -d " " -f 2 | xargs -L1 echo)

# sed -e 's/$/."$domain"/' | sed -e 's/^/root@/'

mkdir -p "$vmbackupdir"

for i in "${onenames[@]}"

	do

	# Lookup vm ip [must be 192.168.1.11x (old raidset servers) or be 192.168.1.50 (xynx01)]

	vmip=$(/usr/bin/nslookup $i."$domain" 127.0.0.1 | egrep -o "(\s(192.168.1.11)\S+|\s(192.168.1.50))" | sed -e 's/^[ \t]*//')

	if [ ! -z $vmip ]; then

	        echo Returned ip for $i: $vmip
        	echo

		mkdir -p /mnt/sshfs-$i

		sshfs -o IdentityFile="$sshkeyvm01" root@$vmip:/ /mnt/sshfs-$i

		. /root/.gpgpp && export PASSPHRASE && duplicity --encrypt-key "$duplicitykey" --exclude-globbing-filelist="$excludefilevm01" \
 /mnt/sshfs-$i file://"$vmbackupdir"$i

	fi

done

for i in "${onenames[@]}"

	do

	# Lookup vm ip [must be 192.168.1.12x (new raidset servers)]

	vmip=$(/usr/bin/nslookup $i."$domain" 127.0.0.1 | egrep -o "(\s(192.168.1.12)\S+)" | sed -e 's/^[ \t]*//')

	if [ ! -z $vmip ]; then

		echo Returned ip for $i: $vmip
        	echo

		mkdir -p /mnt/sshfs-$i

		sshfs -o IdentityFile="$sshkeyvm02" root@$vmip:/ /mnt/sshfs-$i

		. /root/.gpgpp && export PASSPHRASE && duplicity --encrypt-key "$duplicitykey" --exclude-globbing-filelist="$excludefilevm02" \
/mnt/sshfs-$i file://"$vmbackupdir"$i

	fi

done

# clean up

umount /mnt/sshfs-*
rm -r /mnt/sshfs-*

# poweroff vms and backup datastores on fullbackupday

if [ "$(date +"%u")" -eq $fullbackupday ];  then

echo "Full backup day [$fullbackupday] of week detected: powering off virtual machines and backing up datastores"
echo
echo Shutting down VMs...
echo

mapfile -t onenumbers < <(onevm list | grep runn | egrep -o "(\s(\S+ one))" | cut -d " " -f 2 | xargs -L1 echo)

mapfile -t onenames < <(onevm list | grep runn | egrep -o "(\s(x\S+))" | cut -d " " -f 2 | xargs -L1 echo)

echo "${onenames[@]}" #debug

for i in "${onenames[@]}"

        do

	# Lookup vm ip [must be 192.168.1.11x (old raidset servers) or be 192.168.1.50]

	#debug

	echo $(/usr/bin/nslookup $i."$domain" 127.0.0.1)
	echo $(/usr/bin/nslookup $i."$domain" 127.0.0.1 | egrep -o "(\s(192.168.1.11)\S+|\s(192.168.1.50))")
	echo $(/usr/bin/nslookup $i."$domain" 127.0.0.1 | egrep -o "(\s(192.168.1.11)\S+|\s(192.168.1.50))" | sed -e 's/^[ \t]*//')

	# /debug

	vmip=$(/usr/bin/nslookup $i."$domain" 127.0.0.1 | egrep -o "(\s(192.168.1.11)\S+|\s(192.168.1.50))" | sed -e 's/^[ \t]*//')

	echo $vmip #debug

        if [ ! -z $vmip ]; then

                echo Returned ip for $i: $vmip
                echo

		ssh -tt -o IdentityFile="$sshkeyvm01" root@$vmip 'sudo shutdown -h now'

	fi

done

for i in "${onenames[@]}"

	do

	# Lookup vm ip [must be 192.168.1.12x (new raidset servers)]

        vmip=$(/usr/bin/nslookup $i."$domain" 127.0.0.1 | egrep -o "(\s(192.168.1.12)\S+)" | sed -e 's/^[ \t]*//')

        if [ ! -z $vmip ]; then

                echo Returned ip for $i: $vmip
                echo

                ssh -tt -o IdentityFile="$sshkeyvm02" root@$vmip 'sudo shutdown -h now'

        fi

done

runningvmcount="$(onevm list | grep -o 'runn' | wc -l)"

runcheckiteration=0

while [[ $runningvmcount -gt 0 ]]

do
	echo iter $runcheckiteration

	if [[ $runcheckiteration -lt 42 ]];

	then	echo $runningvmcount virtual machines still running.
		echo
		echo Waiting 1 minute for virtual machines shutdown...
		echo

		sleep 60

		runcheckiteration=$[$runcheckiteration+1]

		echo iter $runcheckiteration

		runningvmcount="$(onevm list | grep -o 'runn' | wc -l)"

	else	echo "Virtual machines still running: Aborting."
		echo

		echo "Starting all VMs back up..."
		echo

		onevm resume $(echo ${onenumbers[@]} | tr ' ' ',')

		exit

	fi

done

echo All vms powered off: Proceeding...
echo

# Initiate duplicity backup

. /root/.gpgpp && export PASSPHRASE && duplicity --encrypt-key "$duplicitykey" "$datastoresrootdir" file://"$backupsrootdir"local/"$datastoresrootdir"

echo "Starting all VMs back up..."
echo

onevm resume $(echo ${onenumbers[@]} | tr ' ' ',')

fi

# check lockfile for rclone activity

if [ -f /tmp/rclonelockfile ];

then	echo "RClone sync already running from another script: Aborting."
	echo

	exit

else	echo "Uploading backups to google drive"
	echo

	touch /tmp/rclonelockfile

	echo rclone iter 1
	echo

	/root/go/bin/rclone sync "$backupsrootdir" drive:/rclone/"$servername""$backupsrootdir"
	sleep 45

	echo rclone iter 2
	echo

	/root/go/bin/rclone sync "$backupsrootdir" drive:/rclone/"$servername""$backupsrootdir"
	sleep 45

	echo rclone iter 3
	echo

	/root/go/bin/rclone sync "$backupsrootdir" drive:/rclone/"$servername""$backupsrootdir"

	rm /tmp/rclonelockfile

fi

echo "Done!"
echo
