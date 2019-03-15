#!/bin/bash
# copy only fastq files, sample sheets and config files
SRC=/cygdrive/D/Illumina/MiSeqOutput
SRC2=/cygdrive/i/MiSeqSampleSheets
SRC3=/cygdrive/d/Illumina/MiSeqRunParameters
DST=virologysrv04.uzh.ch:/data/MiSeq

LIST=$(ls $SRC)
for i in $LIST; do
    # get sample sheet name from runParameter.xml file and save runParameter.xml file with the sample sheet name in SRC3
    SAMPLESHEET=$(grep -A 1 ReagentKitRFIDTag "${SRC}/${i}/runParameters.xml" | grep SerialNumber | sed 's/^.*<SerialNumber>//' | sed 's/<\/SerialNumber>//')
    cp "${SRC}/${i}/runParameters.xml ${SRC3}/${SAMPLESHEET}.xml"
done

echo 'syncing fastq files'
{
    echo ''
    echo '--------------------'
    date
    rsync -av --stats --chmod=ug+rwx -p --include="*/" --include="*/Data/Intensities/BaseCalls/*" --include="*.config.xml" --exclude="*" -m $SRC $DST
}  &>> backup_fq.log

echo 'synced'

echo 'syncing sample sheets'
{
    rsync -av --stats --chmod=ug+rwx -p $SRC2 $DST
    echo 'backed up'
    date
    echo '--------------------'
    echo ''
} &>> backup_fq.log

echo 'syncing run parameters'
{
    rsync -av --stats --chmod=ug+rwx -p $SRC3 $DST
    echo 'backed up'
    date
    echo '--------------------'
    echo ''
} &>> backup_fq.log
