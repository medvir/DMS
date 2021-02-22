#!/bin/bash

#set -x  # uncomment for debugging
incomingdir=/cygdrive/D/Illumina/MiSeqOutput
timavoDST=/data/MiSeq
datamoverDST=data/outgoing
samplesheetdir=/cygdrive/I/MiSeq/MiSeqSampleSheets
logdir=/cygdrive/c/Users/sbsuser/DMS/openBIS

# define these globally so no need to pass it as a function parameter
headers='undefined'
rundir='undefined'
# IEMFileVersion='undefined'
Account=''
Investigator_Name='undefined'
Experiment_Name='undefined'
#Date='undefined'
Workflow='undefined'
Application='undefined'
Assay='undefined'
#Description='undefined'
Chemistry='undefined'
Read1=''
Read2=''
PhiX='undefined'
RGT_box1='undefined'
RGT_box2='undefined'
openbis='n'
timavo='n'

write_miseq_run(){
    # input: run_name space
    # space is Diagnostics or Research
    run_name_here=$1

    datenum=${run_name_here:0:6}
    YYYY=20${datenum:0:2}
    MM=${datenum:2:2}
    DD=${datenum:4:2}

    echo "Writing properties files for MISEQ_RUN:$1 PROJECT:$2"
    prop_file=sample.properties
    {
        printf "INVESTIGATOR_NAME = %s\n" "$Investigator_Name"
        printf "EXPERIMENT_NAME = %s\n" "$Experiment_Name"
        printf "SAMPLE_SHEET_NAME = %s\n" "$Sample_Sheet"
        printf "ACCOUNT = %s\n" "$Account"
        printf "DATE = %s-%s-%s\n" "${YYYY}" "${MM}" "${DD}"
        printf "MISEQ_WORKFLOW = %s\n" "$Workflow"
        printf "APPLICATION = %s\n" "$Application"
        printf "ASSAY = %s\n" "$Assay"
        printf "CHEMISTRY = %s\n" "$Chemistry"
        printf "READ_1 = %s\n" "$Read1"
        printf "READ_2 = %s\n" "$Read2"
        printf "PHIX_CONCENTRATION = %s\n" "$PhiX"
        printf "RGT_Box_1 = %s\n" "$RGT_box1"
        printf "RGT_Box_2 = %s\n" "$RGT_box2"
    } > "$prop_file"

    dst="${datamoverDST}/${run_name_here}"
    rsync -a --rsync-path="mkdir -p $dst && rsync" "$prop_file" "ozagor@datamover:$dst"
    # save rsync exit status, if 0 then success
    rsync1=$?

    ### sample_type MISEQ_RUN
    project_to_write=$2

    prop_file=dataset.properties
    {
        printf "SPACE = IMV\n"
        printf "PROJECT = %s\n" "$project_to_write"
        printf "EXPERIMENT = MISEQ_RUNS\n"
        printf "SAMPLE = %s\n" "$run_name_here"
        printf "SAMPLE_TYPE = MISEQ_RUN\n"
        printf "DATASET_TYPE = DATAMOVER_SAMPLE_CREATOR\n"
    } > "$prop_file"

    rsync -a "$prop_file" "ozagor@datamover:$dst"
    rsync2=$?
    if [ "$rsync1" -eq "0" ] && [ "$rsync2" -eq "0" ]; then
        ssh ozagor@datamover touch "$datamoverDST/.MARKER_is_finished_${run_name_here}" </dev/null
    else
        echo -e "WATCH OUT: touching the void! $rsync1 $rsync2"
    fi

}


write_miseq_sample_zero(){

    sample_number=0
    sample_name='Undetermined'
    run_name="$(basename $rundir)"

    fastq_file=$incomingdir/$run_name/Data/Intensities/BaseCalls/${sample_name}_S${sample_number}_L001_R1_001.fastq.gz
    fastq_file_2=$incomingdir/$run_name/Data/Intensities/BaseCalls/${sample_name}_S${sample_number}_L001_R2_001.fastq.gz
    index_file=$incomingdir/$run_name/Data/Intensities/BaseCalls/${sample_name}_S${sample_number}_L001_I1_001.fastq.gz
    index_file_2=$incomingdir/$run_name/Data/Intensities/BaseCalls/${sample_name}_S${sample_number}_L001_I2_001.fastq.gz

    echo "Syncing to TIMAVO"
    DST2="${timavoDST}/MiSeqOutput/${run_name}/Data/Intensities/BaseCalls/"
    rsync -a --chmod=ug+rwx,o+r --rsync-path="mkdir -p $DST2 && rsync" "$fastq_file" "timavo:$DST2"
    if [ -e "$fastq_file_2" ]; then
        rsync --chmod=ug+rwx,o+r "$fastq_file_2" "timavo:$DST2"
    fi
    if [ -e "$index_file" ]; then
        rsync "$index_file" "timavo:$DST2"
    fi
    if [ -e "$index_file_2" ]; then
        rsync "$index_file_2" "timavo:$DST2"
    fi

    ### write properties file
    ### sample_type MISEQ_SAMPLE
    echo "Writing properties files for MISEQ_SAMPLE ID:${sample_number} NAME:${sample_name}"
    prop_file=sample.properties
    {
        printf "SAMPLE_ID=0\n"
        printf "SAMPLE_NAME=Undetermined\n"
        printf "SAMPLE_PLATE=\n"
        printf "SAMPLE_WELL=\n"
        printf "I7_INDEX_ID=\n"
        printf "INDEX_1=\n"
        printf "I5_INDEX_ID=\n"
        printf "INDEX_2=\n"
        printf "DESCRIPTION=\n"
    } > "$prop_file"

    dst="${datamoverDST}/${run_name}-${sample_number}"
    rsync -a --rsync-path="mkdir -p $dst && rsync" "$prop_file" "ozagor@datamover:$dst"
    # save rsync exit status, if 0 then success
    rsync1=$?

    prop_file=dataset.properties
    {
        printf "SPACE = IMV\n"
        printf "PROJECT = METAGENOMICS\n"
        printf "EXPERIMENT = MISEQ_SAMPLES\n"
        printf "SAMPLE = %s-%s\n" "${run_name}" "${sample_number}"
        printf "SAMPLE_TYPE = MISEQ_SAMPLE\n"
        printf "DATASET_TYPE = FASTQ\n"
    } > "$prop_file"

    rsync -a "$prop_file" "ozagor@datamover:$dst"
    rsync2=$?

    rsync3=0
    if [ -e "$fastq_file" ]; then
        rsync -a "$fastq_file" "ozagor@datamover:$dst"
        rsync3=$?
        # echo "R1 file exists, rsync returns $rsync3"
    else
        echo "R1 file does not exist"
    fi

    rsync4=0
    if [ -e "$fastq_file_2" ]; then
        rsync -a "$fastq_file_2" "ozagor@datamover:$dst"
        rsync4=$?
        echo "R2 file exists, rsync returns $rsync4"
    # else
    #     echo "R2 file does not exist"
    fi

    if [ "$rsync1" -eq "0" ] && [ "$rsync2" -eq "0" ] && [ "$rsync3" -eq "0" ] && [ "$rsync4" -eq "0" ]; then
        ssh ozagor@datamover touch "$datamoverDST/.MARKER_is_finished_${run_name}-${sample_number}" </dev/null
    else
        echo -e "WATCH OUT: touching the void! $rsync1 $rsync2 $rsync3 $rsync4"
    fi

}


write_miseq_sample(){
    # input is a line in section [Data] of the samples sheet
    # copy fastq file into $bufferdir/$rundir/S.../ and write dataset.properties
    # if timavo == y, sync fastq file on timavo too

    declare -a sample_line=("${!1}")

    ### move fastq file into folder

    sample_number=${sample_line[0]}
    # this should mimic the behaviour of MiSeq Reporter on sample names with
    # spaces and punctuations:
    # - remove leadin and trailing whitespaces (first sed)
    # - replace punctuation characters and internal spaces with dashes
    sample_name=$(echo ${sample_line[1]} | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s '[:punct:] ' '-')
    sample_plate=${sample_line[2]}
    sample_well=${sample_line[3]}
    I7_index_id=${sample_line[4]}
    index_1=${sample_line[5]}
    I5_index_id=${sample_line[6]}
    index_2=${sample_line[7]}
    description=${sample_line[9]}
    timavo=${sample_line[14]}

    run_name="$(basename $rundir)"

    fastq_file=$incomingdir/$run_name/Data/Intensities/BaseCalls/${sample_name}_S${sample_number}_L001_R1_001.fastq.gz
    fastq_file_2=$incomingdir/$run_name/Data/Intensities/BaseCalls/${sample_name}_S${sample_number}_L001_R2_001.fastq.gz
    index_file=$incomingdir/$run_name/Data/Intensities/BaseCalls/${sample_name}_S${sample_number}_L001_I1_001.fastq.gz
    index_file_2=$incomingdir/$run_name/Data/Intensities/BaseCalls/${sample_name}_S${sample_number}_L001_I2_001.fastq.gz

    if [[ $timavo == *"y"* ]]; then
        echo "Syncing to TIMAVO"
        DST2="${timavoDST}/MiSeqOutput/${run_name}/Data/Intensities/BaseCalls/"
        rsync -a --chmod=ug+rwx,o+r --rsync-path="mkdir -p $DST2 && rsync" "$fastq_file" "timavo:$DST2"
        if [ -e "$fastq_file_2" ]; then
            rsync --chmod=ug+rwx,o+r "$fastq_file_2" "timavo:$DST2"
        fi
        if [ -e "$index_file" ]; then
            rsync "$index_file" "timavo:$DST2"
        fi
        if [ -e "$index_file_2" ]; then
            rsync "$index_file_2" "timavo:$DST2"
        fi

      else
        echo "Not syncing to TIMAVO"
    fi

    ### write properties file

    ### sample_type MISEQ_SAMPLE
    echo "Writing properties files for MISEQ_SAMPLE ID:${sample_number} NAME:${sample_name}"
    prop_file=sample.properties
    {
        printf "SAMPLE_ID=%s\n" "${sample_number}"
        printf "SAMPLE_NAME=%s\n" "${sample_name}"
        printf "SAMPLE_PLATE=%s\n" "${sample_plate}"
        printf "SAMPLE_WELL=%s\n" "$sample_well"
        printf "I7_INDEX_ID=%s\n" "$I7_index_id"
        printf "INDEX_1=%s\n" "$index_1"
        printf "I5_INDEX_ID=%s\n" "$I5_index_id"
        printf "INDEX_2=%s\n" "$index_2"
        printf "DESCRIPTION=%s\n" "$description"
    } > "$prop_file"

    dst="${datamoverDST}/${run_name}-${sample_number}"
    rsync -a --rsync-path="mkdir -p $dst && rsync" "$prop_file" "ozagor@datamover:$dst"
    # save rsync exit status, if 0 then success
    rsync1=$?

    Project=${sample_line[8]}

    prop_file=dataset.properties
    {
        printf "SPACE = IMV\n"
        printf "PROJECT = %s\n" "$Project"
        printf "EXPERIMENT = MISEQ_SAMPLES\n"
        printf "SAMPLE = %s-%s\n" "${run_name}" "${sample_number}"
        printf "SAMPLE_TYPE = MISEQ_SAMPLE\n"
        printf "DATASET_TYPE = FASTQ\n"
    } > "$prop_file"

    rsync -a "$prop_file" "ozagor@datamover:$dst"
    rsync2=$?

    rsync3=0
    if [ -e "$fastq_file" ]; then
        rsync -a "$fastq_file" "ozagor@datamover:$dst"
        rsync3=$?
        # echo "R1 file exists, rsync returns $rsync3"
    else
        echo "R1 file does not exist"
    fi

    rsync4=0
    if [ -e "$fastq_file_2" ]; then
        rsync -a "$fastq_file_2" "ozagor@datamover:$dst"
        rsync4=$?
        echo "R2 file exists, rsync returns $rsync4"
    # else
    #     echo "R2 file does not exist"
    fi

    if [ "$rsync1" -eq "0" ] && [ "$rsync2" -eq "0" ] && [ "$rsync3" -eq "0" ] && [ "$rsync4" -eq "0" ]; then
        ssh ozagor@datamover touch "$datamoverDST/.MARKER_is_finished_${run_name}-${sample_number}" </dev/null
    else
        echo -e "WATCH OUT: touching the void! $rsync1 $rsync2 $rsync3 $rsync4"
    fi

}

write_resistance_test(){

    declare -a sample_line=("${!1}")

    sample_number=${sample_line[0]}
    sample_name=${sample_line[1]}
    #sample_project=${sample_line[8]}
    #Description=${sample_line[9]}
    virus=${sample_line[10]}
    genotype=${sample_line[11]}
    target=${sample_line[12]}
    viral_load=${sample_line[13]}
    apl=${sample_line[15]}

    run_name=$(basename "$rundir")

    ## change the following line for retroseq

    echo "Writing properties files for RESISTANCE_TEST RUN:${run_name} SAMPLE:${sample_name}"

    ### write properties file
    prop_file=sample.properties
    {
        printf "SAMPLE_NAME=%s\n" "$sample_name"
        printf "VIRUS=%s\n" "$virus"
        printf "TARGET_REGION=%s\n" "$target"
        printf "GENOTYPE=%s\n" "$genotype"
        printf "VIRAL_LOAD=%s\n" "$viral_load"
        printf "APL=%s\n" "$apl"
    } > "$prop_file"

    dst="${datamoverDST}/${run_name}-${sample_number}_RESISTANCE"
    rsync -a --rsync-path="mkdir -p $dst && rsync" "$prop_file" "ozagor@datamover:$dst"
    # save rsync exit status, if 0 then success
    rsync1=$?

    prop_file=dataset.properties
    {
        printf "SPACE = IMV\n"
        printf "PROJECT = RESISTANCE\n"
        printf "EXPERIMENT = RESISTANCE_TESTS\n"
        printf "SAMPLE = %s-%s_RESISTANCE\n" "${run_name}" "${sample_number}"
        printf "SAMPLE_TYPE = RESISTANCE_TEST\n"
        printf "DATASET_TYPE = DATAMOVER_SAMPLE_CREATOR\n"
    } > "$prop_file"

    rsync -a "$prop_file" "ozagor@datamover:$dst"
    rsync2=$?

    if [ "$rsync1" -eq "0" ] && [ "$rsync2" -eq "0" ]; then
        ssh ozagor@datamover touch "$datamoverDST/.MARKER_is_finished_${run_name}-${sample_number}_RESISTANCE" </dev/null
    else
        echo -e "WATCH OUT: touching the void! $rsync1 $rsync2"
    fi

}

write_retroseq_resistance_test(){

    declare -a sample_line=("${!1}")

    sample_number=${sample_line[0]}
    sample_name=${sample_line[1]}
    #sample_project=${sample_line[8]}
    #Description=${sample_line[9]}
    virus=${sample_line[10]}
    genotype=${sample_line[11]}
    target=${sample_line[12]}
    viral_load=${sample_line[13]}
    apl=${sample_line[15]}

    run_name=$(basename "$rundir")

    ## change the following line for retroseq

    echo "Writing properties files for RESISTANCE_TEST RUN:${run_name} SAMPLE:${sample_name}"

    ### write properties file
    prop_file=sample.properties
    {
        printf "SAMPLE_NAME=%s\n" "$sample_name"
        printf "VIRUS=%s\n" "$virus"
        printf "TARGET_REGION=%s\n" "$target"
        printf "GENOTYPE=%s\n" "$genotype"
        printf "VIRAL_LOAD=%s\n" "$viral_load"
        printf "APL=%s\n" "$apl"
    } > "$prop_file"

    ## Change HERE
    dst="${datamoverDST}/${run_name}-${sample_number}_RESISTANCE"
    rsync -a --rsync-path="mkdir -p $dst && rsync" "$prop_file" "ozagor@datamover:$dst"
    # save rsync exit status, if 0 then success
    rsync1=$?

    ## Change HERE
    prop_file=dataset.properties
    {
        printf "SPACE = IMV\n"
        ## Change HERE
        printf "PROJECT = RETROSEQ\n"
        printf "EXPERIMENT = RESISTANCE_TESTS\n"
        ## Change HERE
        printf "SAMPLE = %s-%s_RESISTANCE\n" "${run_name}" "${sample_number}"
        printf "SAMPLE_TYPE = RESISTANCE_TEST\n"
        printf "DATASET_TYPE = DATAMOVER_SAMPLE_CREATOR\n"
    } > "$prop_file"

    rsync -a "$prop_file" "ozagor@datamover:$dst"
    rsync2=$?

    if [ "$rsync1" -eq "0" ] && [ "$rsync2" -eq "0" ]; then
        ## Change HERE
        ssh ozagor@datamover touch "$datamoverDST/.MARKER_is_finished_${run_name}-${sample_number}_RESISTANCE" </dev/null
    else
        echo -e "WATCH OUT: touching the void! $rsync1 $rsync2"
    fi

}

write_consensus_info(){

    declare -a sample_line=("${!1}")

    sample_number=${sample_line[0]}
    sample_name=${sample_line[1]}
    #sample_project=${sample_line[8]}
    #Description=${sample_line[9]}
    virus=${sample_line[10]}
    genotype=${sample_line[11]}
    target=${sample_line[12]}
    viral_load=${sample_line[13]}
    apl=${sample_line[15]}

    run_name=$(basename "$rundir")

    ## change the following line for retroseq

    echo "Writing properties files for CONSENSUS_INFO RUN:${run_name} SAMPLE:${sample_name}"

    ### write properties file
    prop_file=sample.properties
    {
        printf "SAMPLE_NAME=%s\n" "$sample_name"
        printf "VIRUS=%s\n" "$virus"
        printf "TARGET_REGION=%s\n" "$target"
        printf "GENOTYPE=%s\n" "$genotype"
        printf "VIRAL_LOAD=%s\n" "$viral_load"
        printf "APL=%s\n" "$apl"
    } > "$prop_file"

    ## Change HERE
    dst="${datamoverDST}/${run_name}-${sample_number}_CONSENSUS"
    rsync -a --rsync-path="mkdir -p $dst && rsync" "$prop_file" "ozagor@datamover:$dst"
    # save rsync exit status, if 0 then success
    rsync1=$?

    ## Change HERE
    prop_file=dataset.properties
    {
        printf "SPACE = IMV\n"
        ## Change HERE
        printf "PROJECT = CONSENSUS\n"
        printf "EXPERIMENT = CONSENSUS_INFO\n"
        ## Change HERE
        printf "SAMPLE = %s-%s_CONSENSUS\n" "${run_name}" "${sample_number}"
        printf "SAMPLE_TYPE = RESISTANCE_TEST\n"
        printf "DATASET_TYPE = DATAMOVER_SAMPLE_CREATOR\n"
    } > "$prop_file"

    rsync -a "$prop_file" "ozagor@datamover:$dst"
    rsync2=$?

    if [ "$rsync1" -eq "0" ] && [ "$rsync2" -eq "0" ]; then
        ## Change HERE
        ssh ozagor@datamover touch "$datamoverDST/.MARKER_is_finished_${run_name}-${sample_number}_CONSENSUS" </dev/null
    else
        echo -e "WATCH OUT: touching the void! $rsync1 $rsync2"
    fi

}

process_runs(){
    # read the samples sheet,
    # save info found in [Header] and [Reads] in global variables
    # call process_sample on all lines in [Data] section

    rundir=$1
    if [[ -e $rundir/.UPLOADED_RUN ]]; then
        echo "Run $rundir already uploaded"
        return
    fi

    # reset headers
    headers='undefined'

    ### remove spaces in sample sheet
    #sed -e "s/ /_/g" < "$rundir/Data/Intensities/BaseCalls/SampleSheet.csv" > sample_sheet.tmp
    # sample sheets are now created with Stefan's template: no need to remove them anymore
    cp "$rundir/SampleSheet.csv" sample_sheet.tmp
    # count_openbis=$(grep -c openbis sample_sheet.tmp)
    ### counters for read 1/2 and samples
    r=0
    s=0
    res_sample=false
    retro_sample=false
    consensus_sample=false
    meta_sample=false
    plasm_sample=false
    anti_sample=false
    other_sample=false

    ### read sample sheet line by line splitting on commas
    ### || [[ -n "$line"]] allow reading last line also if file does not end
    ### with a newline
    while IFS=',' read -r -a line || [[ -n "$line" ]]
    do
        # if [[ "$count_openbis" == 0 ]]
        # then
        #     break
        # fi
        if [[ ${line[0]} =~ ^\[[[:alpha:]]*\] ]]
        then
            section=${line[0]}

        ### [Header] section
        elif [[ $section == "[Header]" && ${line[1]} ]]
        then
            declare "${line[0]}=${line[1]}"

        ### [Reads] section for read 1
        elif [[ $section == "[Reads]" && ${line[0]} =~ ^[0-9]+$ && $r -eq 0 ]]
        then
            # [Header] has now been parsed, if openbis != y then stop parsing
            # this run and go to next
            if [[ "$openbis" == "n" ]]; then
                break
            fi
            r=1
            # echo $section ${line[0]}
            Read1=${line[0]}

        ### [Reads] section for read 2
        elif [[ $section == "[Reads]" && ${line[0]} =~ ^[0-9]+$ && $r -eq 1 ]]
        then
            r=2
            # echo $section ${line[0]}
            Read2=${line[0]}

        ### [Data] section headers
        elif [[ $section == "[Data]" && ${line[1]} && $s -eq 0 ]]
        then
            headers=( "${line[@]}" )
            echo -e "  Headers found:" "${headers[@]}"
            ((s+=1))

        ### [Data] section values
        ## HERE ADD RETROSEQ and write_retroseq_resistance_test
        elif [[ $section == "[Data]" && ${line[1]} && $s -gt 0 ]]
        then

            write_miseq_sample line[@]

            case ${line[8]} in
              Antibodies)
                anti_sample=true
                ;;
              Metagenomics)
                meta_sample=true
                ;;
              Other)
                other_sample=true
                ;;
              Plasmids)
                plasm_sample=true
                ;;
              Resistance)
                res_sample=true
                write_resistance_test line[@]
                ;;
              Retroseq)
                retro_sample=true
                write_retroseq_resistance_test line[@]
                ;;
              Consensus)
                consensus_sample=true
                write_consensus_info line[@]
              esac
            ((s+=1))
        fi

    done < sample_sheet.tmp

    echo "Syncing SampleSheet to timavo"
    run_name=$(basename "$rundir")
    smpshdst="${timavoDST}/MiSeqOutput/${run_name}/Data/Intensities/BaseCalls/"
    rsync -av --chmod=ug+rwx --rsync-path="mkdir -p $smpshdst && rsync" sample_sheet.tmp "timavo:$smpshdst/SampleSheet.csv"
    rm sample_sheet.tmp

    # get sample sheet name from runParameter.xml file and save runParameter.xml file with the sample sheet name
    Sample_Sheet=$(grep -A 1 ReagentKitRFIDTag "$rundir/runParameters.xml" | grep SerialNumber | sed 's/^.*<SerialNumber>//' | sed 's/<\/SerialNumber>//')
    rsync -av --stats --chmod=ug+rwx -p "$rundir/runParameters.xml" "timavo:$timavoDST/MiSeqRunParameters/${Sample_Sheet}.xml"

    # if any sample was X then write Miseq run sample with PROJECT = X
    if [ "$anti_sample" = true ]; then
        echo "WRITING ANTIBODIES RUN"
        write_miseq_run "${run_name}_ANTIBODIES" Antibodies
    fi
    if [ "$meta_sample" = true ]; then
        echo "WRITING UNDETERMINED READS"
        write_miseq_sample_zero
        echo "WRITING METAGENOMICS RUN"
        write_miseq_run "${run_name}_METAGENOMICS" Metagenomics
    fi
    if [ "$other_sample" = true ]; then
        echo "WRITING OTHER RUN"
        write_miseq_run "${run_name}_OTHER" Other
    fi
    if [ "$plasm_sample" = true ]; then
        echo "WRITING PLASMIDS RUN"
        write_miseq_run "${run_name}_PLASMIDS" Plasmids
    fi
    if [ "$res_sample" = true ]; then
        echo "WRITING RESISTANCE RUN"
        write_miseq_run "${run_name}_RESISTANCE" Resistance
    fi
    ## HERE
    if [ "$retro_sample" = true ]; then
        echo "WRITING RETROSEQ RUN"
        write_miseq_run "${run_name}_RETROSEQ" Retroseq
    fi
    ## HERE
    if [ "$consensus_sample" = true ]; then
        echo "WRITING CONSENSUS RUN"
        write_miseq_run "${run_name}_CONSENSUS" Consensus
    fi

    # reset [Header] and [Reads] information
    Investigator_Name='undefined'
    Experiment_Name='undefined'
    Sample_Sheet='undefined'
    # Date='undefined'
    Workflow='undefined'
    Application='undefined'
    Assay='undefined'
    # Description='undefined'
    Chemistry='undefined'
    Read1=''
    Read2=''
    PhiX='undefined'
    RGT_box1='undefined'
    RGT_box2='undefined'
    openbis='n'

    touch "$rundir/.UPLOADED_RUN"

}

echo 'GO!' >> "$logdir"/backup2timavo.log 2>> "$logdir"/backup2timavo.err
### main loop over all dirs in $incomingdir starting with "1"
#for rundir in $(find $incomingdir -type d -name "1*" -depth 1)
#for rundir in $(ls $incomingdir)
for rundir in "$incomingdir"/*; do
    [[ -d "$rundir" ]] || continue
    echo -e "\033[1;31m================================================================================\033[0m"
    echo "Now syncing:" "$rundir"
    process_runs "$rundir"
done >> "$logdir"/backup2timavo.log 2>> "$logdir"/backup2timavo.err

# copy SampleSheets
rsync -avO --stats --no-perms $samplesheetdir "timavo:$timavoDST" >> "$logdir"/backup2timavo.log 2>> "$logdir"/backup2timavo.err
