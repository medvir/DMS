#!/bin/bash
SRC=/cygdrive/D/Illumina/MiSeqOutput/
DST=/backup/MiSeq

echo '' >> backup.log
echo '--------------------' >> backup.log
date >> backup.log
rsync -av --stats --exclude='Images*' --exclude='Alignment*' $SRC virologysrv10
.uzh.ch:$DST &>> backup.log
echo 'backed up' >> backup.log
date >> backup.log
echo '--------------------' >> backup.log
echo '' >> backup.log
