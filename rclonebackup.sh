LOGFILE=/root/scripts/rclonebackup/logs/rclone-$(date "+%Y%m%d").log
echo rclone log $(date) $'\r'$'\r' >> $LOGFILE 2>&1
echo "Starting rclone copy" $'\r'>> $LOGFILE 2>&1

# full local system backup [https://wiki.archlinux.org/index.php/full_system_backup_with_rsync]

rsync -aAXx --info=progress2 --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found","/var/lib/one/datastor$

# reference: rclone copy /media/raidnew/<ShareName>/<FolderName> <RemoteName>:<RemoteFolderName> >> $LOGFILE 2>&1

rclone -v sync /media/raidnew/backups/ drive:/rclone/xxub01/media/raidnew/backups/ >> $LOGFILE 2>&1
