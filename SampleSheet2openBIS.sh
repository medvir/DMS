#!/bin/bash

incomingdir=/cygdrive/D/Illumina/MiSeqOutput
incomingdir=/Users/ozagordi/openBIS
bufferdir=/cygdrive/D/BufferDir
bufferdir=/tmp/parse_samples/

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
openbis='n'

# global variable to allow a function return it
ismolis='undefined'

test_molis(){
    if [[ $1 =~ ^100[0-9]{7} ]]; then
        ismolis=true
        return
    else
        ismolis=false
        return
    fi
}

write_miseq_run(){
    # input: run_name space
    # space is Diagnostics or Research
    runname=$1
    dest=$bufferdir/$runname
    if [[ -d $dest ]];then
        echo "Directory $dest exists! It should not."
        exit 1
    fi
    mkdir $dest
    prop_file=${dest}/dataset.properties

    datenum=${runname:0:6}
    YYYY=20${datenum:0:2}
    MM=${datenum:2:2}
    DD=${datenum:4:2}

    ### sample_type MISEQ_RUN

    printf "space=$2\n" > $prop_file
    printf "IEMFileVersion=$IEMFileVersion\n" >> $prop_file
    printf "investigator_name=$Investigator_Name\n" >> $prop_file
    printf "experiment_name=$Experiment_Name\n" >> $prop_file
    printf "date=${YYYY}-${MM}-${DD}\n" >> $prop_file
    printf "miseq_workflow=$Workflow\n" >> $prop_file
    printf "Application=$Application\n" >> $prop_file
    printf "Assay=$Assay\n" >> $prop_file
    printf "Chemistry=$Chemistry\n" >> $prop_file
    printf "Read1=$Read1\n" >> $prop_file
    printf "Read2=$Read2\n" >> $prop_file
    printf "PhiX=$PhiX" >> $prop_file
    printf "RGT_Box_1=$RGT_Box_1\n" >> $prop_file
    printf "RGT_Box_2=$RGT_Box_2\n" >> $prop_file

}

write_miseq_sample(){
    # input is a line in section [Data] of the samples sheet
    # copy fastq file into $bufferdir/$rundir/S.../ and write dataset.properties

    declare -a sample_line=("${!1}")

    #echo "    " "${sample_line[@]}"

    ### move fastq file into folder
    sample_number=${sample_line[0]}
    sample_name=${sample_line[1]}
    sample_plate=${sample_line[2]}
    sample_well=${sample_line[3]}
    I7_index_id=${sample_line[4]}
    index=${sample_line[5]}
    I5_index_id=${sample_line[6]}
    index2=${sample_line[7]}

    ### create folder S.. in $dest
    dest=$bufferdir/${rundir}_S${sample_number}
    if [[ -d $dest ]];then
        echo "Directory $dest exists! It should not."
        exit 1
    fi
    mkdir $dest

    fastq_file=$rundir/${sample_name}_S${sample_number}_L001_R1_001.fastq.gz
    if [ -e $fastq_file ]; then
        mv $fastq_file ${dest}/
    fi

    ### write properties file
    prop_file=${dest}/dataset.properties

    ### space and project

    # space is Diagnostics if sample_name is a MOLIS number
    test_molis $sample_name
    if [[ "$ismolis" = true ]];then
        Space='Diagnostics'
    else
        Space='Research'
    fi
    ismolis='undefined'

    # Project from Sample_Project column
    Project=${sample_line[8]}

    ### sample_type MISEQ_SAMPLE
    printf "Space=$Space\n" > $prop_file
    printf "Project=$Project\n" >> $prop_file

    printf "Sample_ID=${sample_number}\n" >> $prop_file

    Sample_Name_i=$(eval echo "\$Sample_Name_${i}")
    printf "Sample_Name=${sample_name}\n" >> $prop_file

    Sample_Plate_i=$(eval echo "\$Sample_Plate_${i}")
    printf "Sample_Plate=${Sample_Plate_i}\n" >> $prop_file

    Sample_Well_i=$(eval echo "\$Sample_Well_${i}")
    printf "Sample_Well=${Sample_Well_i}\n" >> $prop_file

    I7_Index_ID_i=$(eval echo "\$I7_Index_ID_${i}")
    printf "I7_Index_ID=${I7_Index_ID_i}\n" >> $prop_file

    index_i=$(eval echo "\$index_${i}")
    printf "INDEX1=${index_i}\n" >> $prop_file

    I5_Index_ID_i=$(eval echo "\$I5_Index_ID_${i}")
    printf "I5_Index_ID=${I5_Index_ID_i}\n" >> $prop_file

    index2_i=$(eval echo "\$index2_${i}")
    printf "INDEX2=${index2_i}\n" >> $prop_file

    Description_i=$(eval echo "\$Description_${i}")
    printf "DESCRIPTION=${Description_i}\n" >> $prop_file

}

write_resistance_test(){

    declare -a sample_line=("${!1}")

    sample_number=${sample_line[0]}
    sample_name=${sample_line[1]}
    sample_project=${sample_line[8]}
    Description=${sample_line[9]}
    virus=${sample_line[10]}
    genotype=${sample_line[11]}
    target=${sample_line[12]}
    viral_load=${sample_line[13]}

    ### create folder S.. in $dest
    dest=$bufferdir/RESTEST_${rundir}_S${sample_number}
    if [[ -d $dest ]];then
        echo "Directory $dest exists! It should not."
        exit 1
    fi
    mkdir $dest

    ### write properties file
    prop_file=${dest}/dataset.properties
    touch $prop_file

    printf "SAMPLE_NAME=$sample_name\n" >> $prop_file
    printf "VIRUS=$virus\n" >> $prop_file
    printf "TARGET_TYPE=$target\n" >> $prop_file
    printf "GENOTYPE=$genotype\n" >> $prop_file
    printf "VIRAL_LOAD=$viral_load\n" >> $prop_file

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
    sed -e "s/ /_/g" < $incomingdir/$rundir/Data/Intensities/BaseCalls/SampleSheet.csv > sample_sheet.tmp

    ### counters for read 1/2 and samples
    r=0
    s=0
    diag_sample=false
    res_sample=false
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
            echo -e '  Headers found:' ${headers[@]}
            ((s+=1))

        ### [Data] section values
        elif [[ $section == "[Data]" && ${line[1]} && $s -gt 0 ]]
        then
            # echo "Before: " "$ismolis"
            echo "    " "${line[@]}"
            test_molis ${line[1]}
            if [ "$ismolis" = true ]; then
                diag_sample=true
            else
                res_sample=true
            fi
            #echo "After: " "$ismolis"
            ismolis='undefined'
            write_miseq_sample line[@]
            if [[ "${line[8]}" == "Resistance" ]]; then
                write_resistance_test line[@]
            fi
            ((s+=1))
        fi
    done < sample_sheet.tmp

    ### remove temporary file
    rm sample_sheet.tmp

    # if any sample was "diagnostics" then write diagnostic run
    if [ "$diag_sample" = true ]; then
        echo "WRITING DIAGNOSTICS"
        write_miseq_run ${rundir}_DIA Diagnostics
    fi
    # if any sample was "research" then write research run
    if [ "$res_sample" = true ]; then
        echo "WRITING RESEARCH"
        write_miseq_run ${rundir}_RES Research
    fi

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
    openbis='n'

    touch $rundir/.UPLOADED_RUN

}

echo 'GO!'
### main loop over all dirs in $incomingdir starting with "1"
#for run in $(find $incomingdir -type d -name "1*" -depth 1); do
for rundir in $(ls $incomingdir); do
    if [[ -d $incomingdir/$rundir ]]
    then
        echo -e "\033[1;31m================================================================================\033[0m"
        echo 'Now syncing:' $rundir
        process_runs $rundir
    fi
done
