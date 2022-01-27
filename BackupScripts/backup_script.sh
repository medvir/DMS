#!/bin/bash
SRC=/cygdrive/D/Illumina/MiSeqOutput/
DST=/backup/MiSeq
LOG=/cygdrive/c/Users/sbsUser/DMS/BackupScripts/backup.log
ERR=/cygdrive/c/Users/sbsUser/DMS/BackupScripts/backup.err

echo '' >> $LOG 2>> $ERR
echo '--------------------' >> $LOG 2>> $ERR
date >> $LOG 2>> $ERR
rsync -av --stats --exclude='Images*' $SRC sbsuser@virologysrv10.uzh.ch:$DST &>> $LOG 2>> $ERR
echo 'backed up' >> $LOG 2>> $ERR
date >> $LOG 2>> $ERR
echo '--------------------' >> $LOG 2>> $ERR
echo '' >> $LOG 2>> $ERR
