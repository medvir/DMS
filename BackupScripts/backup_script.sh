#!/bin/bash
SRC=/cygdrive/D/Illumina/MiSeqOutput/
DST=/backup/MiSeq
LOG=/cygdrive/c/Users/sbsuser/DMS/BackupScripts/backup.log

echo '' >> $LOG
echo '--------------------' >> $LOG
date >> $LOG
rsync -av --stats --exclude='Images*' --exclude='Alignment*' $SRC virologysrv10.uzh.ch:$DST &>> $LOG
echo 'backed up' >> $LOG
date >> $LOG
echo '--------------------' >> $LOG
echo '' >> $LOG
