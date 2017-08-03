# Registering Samples and Materials - General Batch Import
General Batch Import makes it possible to simultaneously import samples and materials. There are many situations in which this function is useful. Some examples include the following:
1. Importing a library of assays provided by a third party into openBIS
2. Importing data stored outside of openBIS (e.g., in another database or in MS Excel)

General Batch Import supports the same data format as the Import Materials and Import Samples. Templates for these formats can be obtained from Import -> Samples and Import -> Materials, respectively, as shown in the Sample Registration session above.
When using General Batch Import, the metadata for the samples and materials must be specified in a particular way on a specific sheet of an Excel file. If the format is that for one particular sample type or material type, the sheet should have the name sample-[Sample Type] or material-[Material Type]. If a sheet contains data for multiple sample or material types (the multiple option in the Batch Import form), then the sheet should have the name sample or material.
How to refer to samples in the imported Excel file:

### Samples without container, using column "Identifier":
- Define both space and code of the sample. Example: /MY_SPACE/MY_CODE
- Define only code of the sample; example: MY_CODE. Space of the sample is defined to be the DEFAULT_SPACE of the import file. If the default space is not defined, then space is defined to be the home space of the user doing the import.

### Samples with container, using only column "Identifier":
- Define space, code and subcode of the sample. Example: /MY_SPACE/CONTAINER_CODE:COMPONENT_CODE. Note: using this syntax means that the component is in same space than the container.

### Samples with container, using columns "Identifier" and "CURRENT_CONTAINER":
- Define space and code of the component sample in the "Identifier" column". Define space and code of the container sample in the "CURRENT_CONTAINER" column.
- Define only code of the component sample in the "Identifier" column" Define space and code of the container sample in the "CURRENT_CONTAINER" column. Space of the component sample is defined to be the same than its container's.
- Define only code of the component sample in the "Identifier" column" Define only code of the container sample in the "CURRENT_CONTAINER" column. Space of both container and component sample is defined to be the DEFAULT_SPACE of the import file. If the default space is not defined, then the space is defined to be the home space of the user doing the import.
 
Note: General batch import does not support automatic generation of sample codes, even if the "Generate Codes Automatically" attribute of the sample type is set.
