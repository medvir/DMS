#!/bin/bash
SRC=/Volumes/MiSeqi100/MiSeqi100Outputs
DST=/backup/MiSeq
LOG=/Users/gsm_net/DMS/BackupScripts/backup.log
ERR=/Users/gsm_net/DMS/BackupScripts/backup.err
SERVER_IP=$(grep "^SERVER_IP" "/Users/gsm_net/.pybis/uzhsrv.ini" | cut -d "=" -f2)

# Check if the MiSeqi100 volume is mounted
if [ ! -d "/Volumes/MiSeqi100" ]; then
    echo "SMB share not found. Attempting to mount..." >> $LOG
    
    osascript -e 'mount volume "smb://SERVER_IP/MiSeqi100"'
    
    # Wait to give it time to mount
    sleep 5
fi

# Double check that it actually mounted before running rsync
if [ ! -d "/Volumes/MiSeqi100" ]; then
    echo "ERROR: Failed to mount SMB share. Aborting backup." >> $ERR
    exit 1
fi

echo '' >> $LOG 2>> $ERR
echo '--------------------' >> $LOG 2>> $ERR
date >> $LOG 2>> $ERR
rsync -av --stats --exclude='Thumbnail_Images' --exclude='Logs' $SRC vir26:$DST &>> $LOG 2>> $ERR
echo 'backed up' >> $LOG 2>> $ERR
date >> $LOG 2>> $ERR
echo '--------------------' >> $LOG 2>> $ERR
echo '' >> $LOG 2>> $ERR
