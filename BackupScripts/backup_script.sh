#!/bin/bash
SRC=/Volumes/MiSeqi100/MiSeqi100Outputs
DST=/backup/MiSeq
LOG=/Users/gsm_net/DMS/BackupScripts/backup.log
ERR=/Users/gsm_net/DMS/BackupScripts/backup.err

echo '' >> $LOG 2>> $ERR
echo '--------------------' >> $LOG 2>> $ERR
date >> $LOG 2>> $ERR
rsync -av --stats --exclude='Thumbnail_Images' --exclude='Logs' $SRC sbsuser@virologysrv10.uzh.ch:$DST &>> $LOG 2>> $ERR
echo 'backed up' >> $LOG 2>> $ERR
date >> $LOG 2>> $ERR
echo '--------------------' >> $LOG 2>> $ERR
echo '' >> $LOG 2>> $ERR
