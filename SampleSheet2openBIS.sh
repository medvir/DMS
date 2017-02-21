#!/bin/bash

incomingdir=/cygdrive/D/Illumina/MiSeqOutput
incomingdir=$(pwd)
bufferdir=/cygdrive/D/BufferDir
bufferdir=/tmp

# define these globally so no need to pass it as a function parameter
headers='undefined'
rundir='undefined'
Investigator_Name='undefined'
Experiment_Name='undefined'
Date='undefined'
Workflow='undefined'
Application='undefined'
Assay='undefined'
Description='undefined'
Chemistry='undefined'
Read1='undefined'
Read2='undefined'
PhiX='undefined'
RGT_Box_1='undefined'
RGT_Box_2='undefined'

write_miseq_run(){

    dest=$bufferdir/$1
    mkdir -p $dest
    prop_file=${dest}/dataset.properties
    touch $prop_file
    printf "Space=$2" >> $prop_file
    printf "Investigator_Name=$Investigator_Name" >> $prop_file
    printf "Experiment_Name=$Experiment_Name" >> $prop_file
    printf "Date=$Date" >> $prop_file
    printf "Workflow=$Workflow" >> $prop_file
    printf "Application=$Application" >> $prop_file
    printf "Assay=$Assay" >> $prop_file
    printf "Chemistry=$Chemistry\n" >> $prop_file
    printf "Read1=$Read1\n" >> $prop_file
    printf "Read2=$Read2\n" >> $prop_file
    printf "PhiX=$PhiX" >> $prop_file
    printf "RGT_Box_1=$RGT_Box_1" >> $prop_file
    printf "RGT_Box_2=$RGT_Box_2" >> $prop_file


}

process_sample(){
    # input is a line in section [Data] of the samples sheet
    # copy fastq file into $bufferdir/$rundir/S.../ and write file dataset.properties

    declare -a sample_line=("${!1}")

    echo "    " "${sample_line[@]}"

    ### move fastq file into folder
    sample_number=${sample_line[0]}
    sample_name=${sample_line[1]}

    ### create folder S.. in $dest
    dest=$bufferdir/${rundir}_S${sample_number}
    mkdir -p $dest

    fastq_file=$rundir/${sample_name}_S${sample_number}_L001_R1_001.fastq.gz
    if [ -e $fastq_file ]; then
        mv $fastq_file ${dest}/
    fi

    ### write properties file
    prop_file=${dest}/dataset.properties
    touch $prop_file

    ### space and project
    printf "Space=Routine\n" >> $prop_file
    printf "Project=Resistance_Testing\n" >> $prop_file

    ### sample_type MISEQ_RUN
    printf "IEMFileVersion=$IEMFileVersion\n" >> $prop_file
    printf "Investigator_Name=$Investigator_Name\n" >> $prop_file
    printf "Experiment_Name=$Experiment_Name\n" >> $prop_file
    printf "Date=$Date\n" >> $prop_file
    printf "Workflow=$Workflow\n" >> $prop_file
    printf "Application=$Application\n" >> $prop_file
    printf "Assay=$Assay\n">> $prop_file
    printf "Description=$Description\n" >> $prop_file
    printf "Chemistry=$Chemistry\n" >> $prop_file
    printf "Read1=$Read1\n" >> $prop_file
    printf "Read2=$Read2\n" >> $prop_file

    ### sample_type MISEQ_SAMPLE
    printf "Sample_ID=${i}\n" >> $prop_file

    Sample_Name_i=$(eval echo "\$Sample_Name_${i}")
    printf "Sample_Name=${Sample_Name_i}\n" >> $prop_file

    Sample_Plate_i=$(eval echo "\$Sample_Plate_${i}")
    printf "Sample_Plate=${Sample_Plate_i}\n" >> $prop_file

    Sample_Well_i=$(eval echo "\$Sample_Well_${i}")
    printf "Sample_Well=${Sample_Well_i}\n" >> $prop_file

    I7_Index_ID_i=$(eval echo "\$I7_Index_ID_${i}")
    printf "I7_Index_ID=${I7_Index_ID_i}\n" >> $prop_file

    index_i=$(eval echo "\$index_${i}")
    printf "index=${index_i}\n" >> $prop_file

    I5_Index_ID_i=$(eval echo "\$I5_Index_ID_${i}")
    printf "I5_Index_ID=${I5_Index_ID_i}\n" >> $prop_file

    index2_i=$(eval echo "\$index2_${i}")
    printf "index2=${index2_i}\n" >> $prop_file

    Sample_Project_i=$(eval echo "\$Sample_Project_${i}")
    printf "Sample_Project=${Sample_Project_i}\n" >> $prop_file

    Description_i=$(eval echo "\$Description_${i}")
    printf "Description=${Description_i}\n" >> $prop_file

}

process_runs(){
    # read the samples sheet,
    # save info found in [Header] and [Reads] in global variables
    # call process_sample on all lines in [Data] section

    rundir=$1

    # reset headers
    headers='undefined'

    ### remove spaces in sample sheet
    sed -e "s/ /_/g" < $rundir/Data/Intensities/BaseCalls/SampleSheet.csv > sample_sheet.tmp

    ### counters for read 1/2 and samples
    r=0
    s=0

    ### read sample sheet line by line
    while IFS=',' read -a line
    do

        if [[ ${line[0]} == \[*] ]]
        then
            section=${line[0]}

        ### [Header] section
        elif [[ $section == "[Header]" && ${line[1]} ]]
        then
            declare "${line[0]}=${line[1]}"

        ### [Reads] section for read 1
        elif [[ $section == "[Reads]" && ${line[0]} =~ ^[0-9]+$ && $r -eq 0 ]]
        then
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
            echo -e '  Found headers' ${headers[@]}
            ((s+=1))

        ### [Data] section values
        elif [[ $section == "[Data]" && ${line[1]} && $s -gt 0 ]]
        then
            process_sample line[@]
            ((s+=1))
        fi
    done < sample_sheet.tmp

    if [[ $Description == 'Mixed' ]]; then
        write_miseq_run ${rundir}_DIA Diagnostics
        write_miseq_run ${rundir}_RES Research
    elif [[ $Description == 'Diagnostics' ]]; then
        write_miseq_run ${rundir}_DIA Diagnostics
    elif [[ $Description == 'Research' ]]; then
        write_miseq_run ${rundir}_RES Research

    # reset [Header] and [Reads] information
    Investigator_Name='undefined'
    Experiment_Name='undefined'
    Date='undefined'
    Workflow='undefined'
    Application='undefined'
    Assay='undefined'
    Description='undefined'
    Chemistry='undefined'
    Read1='undefined'
    Read2='undefined'
    PhiX='undefined'
    RGT_Box_1='undefined'
    RGT_Box_2='undefined'

    ### remove temporary file
    rm sample_sheet.tmp
}

### main loop over all runs in $incomingdir
for run in $(ls $incomingdir); do
    if [[ -d $run ]]
    then
        echo -e "\033[1;31m================================================================================\033[0m"
        echo 'Now syncing:' $run
        rundir=$run
        process_runs $rundir
    fi
done
