# opennebula-backup
A one-shot script to backup all of your opennebula host and virtual machines

# Functionality
onebackup is a backup solution for servers running opennebula. It takes a full local system backup using duplicity, then sshes automatically into the vms, takes a full system duplicity backup for each and every one, and uploads everything to an external location using rclone. And once a week, on a specified day at a specified time, it cleanly shuts down the running vms, takes a full backup of the datastores, switches those and only those vms back on, and uploads this too to the external location.
