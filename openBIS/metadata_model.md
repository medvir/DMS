## Spaces/Projects

- IMV
  - ANTIBODIES
  - METAGENOMICS
  - OTHER
  - RESISTANCE_TESTING

---

## Experiments

The following entities are experiments:

- `MISEQ_RUNS`
- `MISEQ_SAMPLES`
- `RESISTANCE_TESTS`

In order to be defined they only need:

  - Code
  - Project
  - List of samples

---

## Samples

Here below are listed sample types, together with their needed properties

- **Sample Type `MISEQ_RUN`**
  - Investigator_Name
  - Experiment_Name
  - Run name (170303_M01274_0174_000000000-AT5N6)
  - Account
  - Date (YYYY-MMM-DD)
  - MiSeq Workflow
  - Application
  - Assay
  - Description
  - Chemistry
  - Read_1
  - Read_2
  - PhiX_Concentration (%)
  - RGT_Box_1
  - RGT_Box_2


- **Sample Type `MISEQ_SAMPLE`**: child of `MISEQ_RUN`
  - Sample_ID (int)
  - Sample Name
  - Sample Plate
  - Sample Well
  - Index_1
  - Index_2
  - I7_Index_ID
  - I5_Index_ID
  - Description


- **Sample Type `RESISTANCE_TEST`**: child of `MISEQ_SAMPLE`
  - Sample_Name
  - Virus
  - Target
  - Genotype
  - Viral_load (per mL)
