#!/bin/bash

incomingdir=/cygdrive/D/Illumina/MiSeqOutput
incomingdir=$(pwd)
bufferdir=/cygdrive/D/BufferDir
bufferdir=/tmp

# define these globally so no need to pass it as a function parameter
headers='undefined'
rundir='undefined'

process_sample(){
    # this copies a fastq file into $dest and writes file dataset.properties

    declare -a sample_line=("${!1}")

    echo $rundir
    echo "${headers[@]}"
    echo "${sample_line[@]}"

    ### move fastq file into folder
    sample_number=${sample_line[0]}
    sample_name=${sample_line[1]}

    ### create folder S.. in $dest
    dest=$bufferdir/$rundir/S${sample_number}
    mkdir -p $dest

    #mv $rundir/${sample_name}_S${sample_number}_L001_R1_001.fastq.gz ${dest}/

    ### write properties file
    prop_file=${dest}/openBIS.properties
    #> $prop_file

    ### space and project
    printf "Space=Routine\n" >> $prop_file
    printf "Project=Resistance_Testing\n" >> $prop_file
    exit
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
    rundir=$1
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
            echo $section ${line[0]} ${line[1]}
            declare "${line[0]}=${line[1]}"

        ### [Reads] section for read 1
        elif [[ $section == "[Reads]" && ${line[0]} =~ ^[0-9]+$ && $r -eq 0 ]]
        then
            r=1
            echo $section ${line[0]}
            Read1=${line[0]}

        ### [Reads] section for read 2
        elif [[ $section == "[Reads]" && ${line[0]} =~ ^[0-9]+$ && $r -eq 1 ]]
        then
            r=2
            echo $section ${line[0]}
            Read2=${line[0]}

        ### [Data] section headers
        elif [[ $section == "[Data]" && ${line[1]} && $s -eq 0 ]]
        then
            headers=( "${line[@]}" )
            echo ${!headers}
            ((s+=1))

        ### [Data] section values
        elif [[ $section == "[Data]" && ${line[1]} && $s -gt 0 ]]
        then
            process_sample line[@]
            ((s+=1))
        fi
    done < sample_sheet.tmp

    ### remove temporary file
    rm sample_sheet.tmp
}

for run in $(ls $incomingdir); do
    if [[ -d $run ]]
    then
        echo $run
        rundir=$run
        process_runs $rundir
    fi
done

exit

### loop over every sample f
for i in $(seq 1 1 $s); do

   ### create folder S.. in $dest
   mkdir -p S${i}

   ### move fastq file into folder
   sample_name_i=$(eval echo "\$Sample_Name_${i}")
   mv ${sample_name_i}_S${i}_L001_R1_001.fastq.gz ${dest}/S${i}

   ### write properties file
   prop_file=${dest}/S${i}/openBIS.properties
   > $prop_file

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
done
