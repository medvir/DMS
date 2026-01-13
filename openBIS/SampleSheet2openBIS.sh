#!/bin/bash

# set -x  # uncomment for debugging

incomingdir=/Volumes/MiSeqi100/MiSeqi100Outputs
timavoDST=/data/MiSeq
samplesheetdir=/Volumes/MiSeqSampleSheets
logdir=$HOME/DMS/openBIS

# define these globally so no need to pass it as a function parameter
headers='undefined'
rundir='undefined'
Account=''
Operator='undefined'
Experiment_Name='undefined'
#Date='undefined'
Workflow='undefined'
Application='undefined'
Assay='undefined'
#Description='undefined'
Chemistry='undefined'
Read1=''
Read2=''
PhiX=''
RGT_box1='undefined'
RGT_box2='undefined'
openbis='n'
timavo='n'

write_miseq_run(){
    run_name_here=$1
    project_to_write=$2
    datenum=${run_name_here:0:8}
    formatted_date="${datenum:0:4}-${datenum:4:2}-${datenum:6:2}"

    payload=$(cat <<EOF
    {
        "space": "IMV",
        "project": "$project_to_write",
        "experiment": "MISEQ_RUNS",
        "sample_code": "${run_name_here#20}",
        "sample_type": "MISEQ_RUN",
        "properties": {
            "INVESTIGATOR_NAME": "$Operator",
            "EXPERIMENT_NAME": "$Experiment_Name",
            "SAMPLE_SHEET_NAME": "$Sample_Sheet",
            "ACCOUNT": "$Account",
            "DATE": "$formatted_date",
            "MISEQ_WORKFLOW": "$Workflow",
            "APPLICATION": "$Application",
            "ASSAY": "$Assay",
            "CHEMISTRY": "$Chemistry",
            "READ_1": "$Read1",
            "READ_2": "$Read2",
            "PHIX_CONCENTRATION": "$PhiX",
            "RGT_Box_1": "$Reagent1",
            "RGT_Box_2": "$Reagent2"
        }
    }
EOF
    )
    python3 openbis_uploader.py "$payload"
}


write_miseq_sample_zero(){

    sample_number=0
    sample_name='Undetermined'
    run_name="$(basename $rundir)"
    last_alignment_dir="$(ls -td ${incomingdir}/${run_name}/Analysis/* | head -1 | awk -F/ '{print $NF}')"
    fastq_dir="$(ls -td ${incomingdir}/${run_name}/Analysis/${last_alignment_dir}/Data/BCLConvert/)"

    fastq_file=${fastq_dir}/fastq/${sample_name}_S${sample_number}_L001_R1_001.fastq.gz  
    fastq_file_2=${fastq_dir}/fastq/${sample_name}_S${sample_number}_L001_R2_001.fastq.gz
    index_file=${fastq_dir}/fastq/${sample_name}_S${sample_number}_L001_I1_001.fastq.gz
    index_file_2=${fastq_dir}/fastq/${sample_name}_S${sample_number}_L001_I2_001.fastq.gz

    echo "in write_miseq_sample_zero, run name: $run_name, alignment dir: ${last_alignment_dir}, fastq dir: ${fastq_dir}"

    echo "Syncing to TIMAVO"
    DST2="${timavoDST}/MiSeqOutput/${run_name}/"
    rsync -a --chmod=ug+rwx,o+r --rsync-path="mkdir -p $DST2 && rsync" "$fastq_file" "timavo:$DST2"

    if [ -e "$index_file" ]; then
        rsync "$index_file" "timavo:$DST2"
    fi

    ### To OpenBis
    sample_code="${run_name#20}-${sample_number}"

    payload=$(cat <<EOF
    {
        "space": "IMV",
        "project": "METAGENOMICS",
        "experiment": "MISEQ_SAMPLES",
        "sample_code": "$sample_code",
        "sample_type": "MISEQ_SAMPLE",
        "parent_sample": "${run_name}_METAGENOMICS",
        "dataset_type": "FASTQ",
        "files": ["$fastq_file"],
        "properties": {
            "SAMPLE_ID": "$sample_number",
            "SAMPLE_NAME": "$sample_name"
        }
    }
EOF
    )
    python3 openbis_uploader.py "$payload"
}


write_miseq_sample(){

    declare -a sample_line=("$@")

    ### move fastq file into folder

    sample_number=${sample_line[0]}
    # this should mimic the behaviour of MiSeq Reporter on sample names with
    # spaces and punctuations:
    # - remove leadin and trailing whitespaces (first sed)
    # - replace punctuation characters and internal spaces with dashes
    sample_name=$(echo ${sample_line[1]} | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -s '[:punct:] ' '-')
    I7_index_id=${sample_line[2]}
    index_1=${sample_line[3]}
    index_2=${sample_line[4]}
    timavo=${sample_line[9]}

    run_name="$(basename $rundir)"
    last_alignment_dir="$(ls -td ${incomingdir}/${run_name}/Analysis/* | head -1 | awk -F/ '{print $NF}')"
    fastq_dir="$(ls -td ${incomingdir}/${run_name}/Analysis/${last_alignment_dir}/Data/BCLConvert/)"

    fastq_file=${fastq_dir}/fastq/${sample_name}_S${sample_number}_L001_R1_001.fastq.gz    
    fastq_file_2=${fastq_dir}/fastq/${sample_name}_S${sample_number}_L001_R2_001.fastq.gz
    index_file=${fastq_dir}/fastq/${sample_name}_S${sample_number}_L001_I1_001.fastq.gz
    index_file_2=${fastq_dir}/fastq/${sample_name}_S${sample_number}_L001_I2_001.fastq.gz

    echo "in write_miseq_sample, run name: $run_name, alignment dir: ${last_alignment_dir}, fastq dir: ${fastq_dir}"

    if [[ $timavo == *"y"* ]]; then
        echo "Syncing to TIMAVO"
        DST2="${timavoDST}/MiSeqOutput/${run_name}/"
        rsync -a --chmod=ug+rwx,o+r --rsync-path="mkdir -p $DST2 && rsync" "$fastq_file" "timavo:$DST2"

        if [ -e "$index_file" ]; then
            rsync "$index_file" "timavo:$DST2"
        fi
    else
        echo "Not syncing to TIMAVO"
    fi

    ### To OpenBis
    sample_code="${run_name#20}-${sample_number}"
    project="${sample_line[5]}"

    # Link with the parent
    project_up=$(echo "$project" | tr '[:lower:]' '[:upper:]')
    parent_link="${run_name}_${project_up}"

    payload=$(cat <<EOF
    {
        "space": "IMV",
        "project": "$project",
        "experiment": "MISEQ_SAMPLES",
        "sample_code": "$sample_code",
        "sample_type": "MISEQ_SAMPLE",
        "parent_sample": "$parent_link",
        "dataset_type": "FASTQ",
        "files": ["$fastq_file"],
        "properties": {
            "SAMPLE_ID": "$sample_number",
            "SAMPLE_NAME": "$sample_name",
            "SAMPLE_PLATE": "$sample_plate",
            "SAMPLE_WELL": "$sample_well",
            "I7_INDEX_ID": "$I7_index_id",
            "INDEX_1": "$index_1",
            "INDEX_2": "$index_2",
            "DESCRIPTION": "$description"
        }
    }
EOF
    )
    python3 openbis_uploader.py "$payload"
}

write_experiment_generic(){
    declare -a sample_line=("$@")
    local project_name=$1
    local exp_name=$2
    local sample_suffix=$3
    
    run_name=$(basename "$rundir")
    sample_number=${sample_line[0]}

    sequencing_sample="${run_name#20}-${sample_number}"
    test_sample="${sequencing_sample}_${sample_suffix}"

    payload=$(cat <<EOF
    {
        "space": "IMV",
        "project": "$project_name",
        "experiment": "${exp_name}",
        "sample_code": "$test_sample",
        "sample_type": "RESISTANCE_TEST",
        "parent_sample": "$sequencing_sample",
        "properties": {
            "SAMPLE_NAME": "${sample_line[1]}",
            "VIRUS": "${sample_line[6]}",
            "TARGET_REGION": "${sample_line[7]}",
            "APL": "${sample_line[8]}"
        }
    }
EOF
    )
    python3 openbis_uploader.py "$payload"
}

write_resistance_test() { 
    write_experiment_generic "RESISTANCE" "RESISTANCE_TESTS" "RESISTANCE" "${@}"; 
}

write_retroseq_resistance_test() { 
    write_experiment_generic "RETROSEQ" "RESISTANCE_TESTS" "RESISTANCE" "${@}"; 
}

write_consensus_info() { 
    write_experiment_generic "CONSENSUS" "CONSENSUS_INFO" "CONSENSUS" "${@}"; 
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

    # get sample sheet name
    Sample_Sheet_tmp=$(cat "$rundir/SampleSheet.csv" | grep InputContainerIdentifier | sed 's/InputContainerIdentifier,//')
    Sample_Sheet=`echo $Sample_Sheet_tmp | sed 's/\\r//g'`
    cp "$samplesheetdir/$Sample_Sheet.csv" sample_sheet.tmp
    chmod 777 sample_sheet.tmp
    echo "In process_runs, sample sheet: ${Sample_Sheet} "
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
        if [[ ${line[0]} =~ ^\[[[:alpha:]_]*\] ]]; then 
            section=${line[0]}
        fi

        ### [Header] section
        if [[ $section == "[Header]" && ${line[1]} ]]; then
            header_value=$(echo "${line[1]}" | tr -d '\r')
            if [[ "${line[0]}" == "RunName" ]]; then
                Experiment_Name=${header_value}
                echo "Experiment_Name line: $Experiment_Name , 0: ${line[0]}, 1: ${line[1]}"
            else
                declare "${line[0]}=${header_value}"
            fi
        ### [Reads] section
        elif [[ $section == "[Reads]" ]]; then 
            # Check for openbis=n flag *before* processing any reads info
            if [[ "$openbis" == "n" ]]; then
                break
            fi
            
            ### [Reads] section for read 1
            if [[ ${line[0]} == "Read1Cycles" && $r -eq 0 && ${line[1]} =~ ^[0-9]+$ ]]; then
                r=1
                Read1=${line[1]}
            
            # [Reads] section for read 2
            elif [[ ${line[0]} == "Read2Cycles" && $r -eq 1 && ${line[1]} =~ ^[0-9]+$ ]]; then
                r=2
                Read2=${line[1]}
            fi

        ### [BCLConvert_Data] section headers
        elif [[ $section == "[BCLConvert_Data]" && ${line[0]} == "Sample_ID" && $s -eq 0 ]]; then
            headers=( "${line[@]}" )
            echo -e "  Headers found:" "${headers[@]}"
            ((s+=1))

        ### [BCLConvert_Data] section values
        ## HERE ADD RETROSEQ and write_retroseq_resistance_test
        elif [[ $section == "[BCLConvert_Data]" && ${line[0]} =~ ^[0-9]+$ && $s -gt 0 ]]; then
            write_miseq_sample "${line[@]}"

            case ${line[5]} in
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
                write_resistance_test "${line[@]}"
                ;;
              Retroseq)
                retro_sample=true
                write_retroseq_resistance_test "${line[@]}"
                ;;
              Consensus)
                consensus_sample=true
                write_consensus_info "${line[@]}"
              esac
            ((s+=1))
        fi
    done < sample_sheet.tmp

    echo "Syncing SampleSheet to timavo"
    run_name=$(basename "$rundir")
    smpshdst="${timavoDST}/MiSeqOutput/${run_name}/"
    rsync -av --chmod=ug+rwx --rsync-path="mkdir -p $smpshdst && rsync" sample_sheet.tmp "timavo:$smpshdst/SampleSheet.csv"
    rm sample_sheet.tmp

    # get sample sheet name from runParameter.xml file and save runParameter.xml file with the sample sheet name
    rsync -av --stats --chmod=ug+rwx -p "$rundir/RunParameters.xml" "timavo:$timavoDST/MiSeqRunParameters/${Sample_Sheet}.xml"

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
    Operator='undefined'
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
    PhiX=''
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
