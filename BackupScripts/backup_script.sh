#!/bin/bash
SRC=/Volumes/MiSeqi100/MiSeqi100Outputs
DST=/backup/MiSeq
LOG=$HOME/DMS/BackupScripts/backup.log
ERR=$HOME/DMS/BackupScripts/backup.err

echo '' >> $LOG 2>> $ERR
echo '--------------------' >> $LOG 2>> $ERR
date >> $LOG 2>> $ERR
rsync -av --stats --exclude='Thumbnail_Images' --exclude='Logs' $SRC vir26:$DST &>> $LOG 2>> $ERR
echo 'backed up' >> $LOG 2>> $ERR
date >> $LOG 2>> $ERR
echo '--------------------' >> $LOG 2>> $ERR
echo '' >> $LOG 2>> $ERR
