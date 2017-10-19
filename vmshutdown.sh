echo Shutting down VMs...
echo

mapfile -t onenumbers < <(onevm list | grep runn | egrep -o "(\s(\S+ one))" | cut -d " " -f 2 | xargs -L1 echo)

mapfile -t onenames < <(onevm list | grep runn | egrep -o "(\s(x\S+))" | cut -d " " -f 2 | xargs -L1 echo)

echo "${onenames[@]}" #debug

for i in "${onenames[@]}"

        do

	# Lookup vm ip [must be 192.168.1.11x (old raidset servers) or be 192.168.1.50]

	#debug

	echo $(/usr/bin/nslookup $i.example.org 127.0.0.1)
	echo $(/usr/bin/nslookup $i.example.org 127.0.0.1 | egrep -o "(\s(192.168.1.11)\S+|\s(192.168.1.50))")
	echo $(/usr/bin/nslookup $i.example.org 127.0.0.1 | egrep -o "(\s(192.168.1.11)\S+|\s(192.168.1.50))" | sed -e 's/^[ \t]*//')

	# /debug

	vmip=$(/usr/bin/nslookup $i.example.org 127.0.0.1 | egrep -o "(\s(192.168.1.11)\S+|\s(192.168.1.50))" | sed -e 's/^[ \t]*//')

	echo $vmip #debug

        if [ ! -z $vmip ]; then

                echo Returned ip for $i: $vmip
                echo

		ssh -tt -o IdentityFile=/root/.ssh/id_rsa root@$vmip 'sudo shutdown -h now'

	fi

done

for i in "${onenames[@]}"

	do

	# Lookup vm ip [must be 192.168.1.12x (new raidset servers)]

        vmip=$(/usr/bin/nslookup $i.example.org 127.0.0.1 | egrep -o "(\s(192.168.1.12)\S+)" | sed -e 's/^[ \t]*//')

        if [ ! -z $vmip ]; then

                echo Returned ip for $i: $vmip
                echo

                ssh -tt -o IdentityFile=/root/.ssh/xxub01_id_rsa root@$vmip 'sudo shutdown -h now'

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
		echo Waiting 15 seconds for virtual machines shutdown...
		echo

		sleep 15

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

echo All vms [${onenumbers[@]}] [${onenames[@]}] powered off: Done.
echo
