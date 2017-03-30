# Spaces/Projects
- DIAGNOSTICS
  - RESISTANCE_TEST
  - METAGENOMICS
- RESEARCH
  - ANTIBODIES
  - OTHER

***

### Exp.Type. > MISEQ_RUNS
### Sam.Type. > MISEQ_RUN
Properties:
- Run Name (170303_M01274_0174_000000000-AT5N6)
- Investigator_Name
- Experiment_Name
- Date (mm/dd/yyyy)
- Workflow
- Application
- Assay
- Description
- Chemistry
- Read_1
- Read_2
- PhiX_Concentration (%)
- RGT_Box_1
- RGT_Box_2

***

### Exp.Type. > MISEQ_SAMPLES
### Sam.Type. > MISEQ_SAMPLE
`Child of:	MISEQ_RUN`

Properties:	
- Sample_ID (int)
- Sample_Name
- Sample_Plate
- Sample_Well
- I7_Index_ID
- Index
- I5_Index_ID
- Index2
- Description

***

### Exp.Type > RESISTANCE_TESTS
### Sam.Type.> RESISTANCE_TEST
`Child of:	MISEQ_SAMPLE`

Properties:
- Sample_Name
- Virus
- Target
- Genotype
- Viral_load (per mL)