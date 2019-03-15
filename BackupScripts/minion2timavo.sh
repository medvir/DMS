#!/bin/bash

# target:
# C:\cygwin64\bin\mintty.exe -e /bin/sh -l -c '/cygdrive/c/data/DMS/BackupScripts/minion2timavo.sh &>> /home/minion/minion2timavo.log'

incomingdir=/cygdrive/c/data
timavoDST=/data/MinION

run_list=$(ls -d $incomingdir/*guppy*)

for rundir in $run_list; do

  # extract run name
  run_name=$(echo "$rundir" | cut -f 5 -d "/")

  if [[ -e $rundir/.UPLOADED_RUN ]]; then
      echo "Run $run_name already uploaded"
      return
  fi

  echo "Syncing run $run_name to TIMAVO"
  DST="${timavoDST}/MinIONOutput/${run_name}/"
  rsync -arv --stats --chmod=ug+rwx --rsync-path="mkdir -p $DST && rsync" "$rundir"/* "timavo:$DST"

  touch "$rundir/.UPLOADED_RUN"

done
