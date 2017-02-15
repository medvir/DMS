#!/bin/bash

### destination directory
dest=$(pwd)

### remove spaces in sample sheet
sed -e "s/ /_/g" < $1 > sample_sheet.tmp

### counters for read 1/2 and samples
r=0
s=0

### read sample sheet line by line
while IFS=',' read col1 col2 col3 col4 col5 col6 col7 col8 col9 col10
do
    if [[ $col1 == \[*] ]]
    then
		section=$col1
    
	### [Header] section
	elif [[ $section == "[Header]" && $col2 ]]
	then
		echo $section $col1 $col2
        declare "$col1=$col2"

	### [Reads] section for read 1
	elif [[ $section == "[Reads]" && $col1 =~ ^[0-9]+$ && $r -eq 0 ]]
	then
		r=1
		echo $section $col1
    	Read1=$col1
	
	### [Reads] section for read 2
	elif [[ $section == "[Reads]" && $col1 =~ ^[0-9]+$ && $r -eq 1 ]]
	then
		r=2
		echo $section $col1
	   	Read2=$col1
	
	### [Data] section headers
	elif [[ $section == "[Data]" && $col2 && $s -eq 0 ]]
	then
		head1=$col1
		head2=$col2
		head3=$col3
		head4=$col4
		head5=$col5
		head6=$col6
		head7=$col7
		head8=$col8
		head9=$col9
		head10=$col10
		echo $section $head1 $head2 $head3 $head4 $head5 $head6 $head7 $head8 $head9 $head10
		((s+=1))
		
	### [Data] section values
	elif [[ $section == "[Data]" && $col2 && $s -gt 0 ]]
	then
		echo $section $col1 $col2 $col3 $col4 $col5 $col6 $col7 $col8 $col9 $col10
		declare "${head1}_${s}=$col1"
		declare "${head2}_${s}=$col2"
		declare "${head3}_${s}=$col3"
		declare "${head4}_${s}=$col4"
		declare "${head5}_${s}=$col5"
		declare "${head6}_${s}=$col6"
		declare "${head7}_${s}=$col7"
		declare "${head8}_${s}=$col8"
		declare "${head9}_${s}=$col9"
		declare "${head10}_${s}=$col10"
		((s+=1))
				
	fi
done < sample_sheet.tmp

### remove temporary file
rm sample_sheet.tmp

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
