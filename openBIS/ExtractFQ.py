#!/usr/bin/env python3

import configparser
import glob
import os
import shutil
import numpy as np
import pandas as pd

from datetime import datetime
from pybis import Openbis

# Set Configuration and Details
config = configparser.ConfigParser()
config.read(os.path.expanduser('~/.pybis/cred.ini'))
OPENBIS_URL = 'https://openbis.virology.uzh.ch/openbis/'
USERNAME = config['credentials']['username']
PASSWORD = config['credentials']['password']
DOWNLOAD_DIR = os.path.expanduser('~/IMV2OpenBis/tmp_downloads')
OUTPUT_DIR = os.path.expanduser(
    f'~/IMV2OpenBis/fastq_downloads_{datetime.today().strftime("%Y-%m-%d")}'
    )
SAMPLE_FILE = os.path.expanduser('~/IMV2OpenBis/IMV2OpenBis.txt')

# Connect to OpenBIS
o = Openbis(OPENBIS_URL, verify_certificates=True)
o.login(USERNAME, PASSWORD, save_token=True)

# Ensure download directory exists
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

# Read all target sample names from file
df = pd.read_csv(SAMPLE_FILE, sep='\t')
target_sample_names = df['anforderungsnr'].dropna().astype(str).tolist()

# Get all samples with a sample_name property
samples = o.get_samples(props={"sample_name": "*"})

# Create a list to store fastq filenames per row
fastq_files_column = []

# Loop over each target sample name
for TARGET_SAMPLE_NAME in target_sample_names:

    # Find the one that exactly matches the sample_name value
    found_samples = [
        s for s in samples if s.props.get("sample_name") == TARGET_SAMPLE_NAME 
        ]

    # Store FASTQ files for this sample
    sample_fastq_files = []

    if found_samples:
        # Get the last sample (assuming this will be the correct one)
        # Note: > 1 sample is found if there are errors with the 1st sample
        # Note2: there are always 2 folders per sample (FASTQ and outputs)
        # FASTQs are in the first folder, that's why we take the 1st
        try:
            matching_sample = found_samples[-2]
        except:
            matching_sample = found_samples[-1] 
        print(f"Searching for sample_name = {TARGET_SAMPLE_NAME} ...")

        datasets = matching_sample.get_datasets()
        if datasets:
            for dataset in datasets:
                files = dataset.get_files()
                for _, file_row in files.iterrows():
                    file_path = file_row['pathInDataSet']
                    if file_path.lower().endswith(('.fastq', '.fastq.gz')):
                        print(f"Downloading {file_path}")
                        dataset.download(
                            files=file_path, 
                            destination=DOWNLOAD_DIR
                            )
                        sample_fastq_files.append(os.path.basename(file_path))
            if sample_fastq_files:
                print("All FASTQ files downloaded.")
            else:
                print("No FASTQ files found in datasets.")
        else:
            print("No datasets found for this sample.")
    
    # Append result for this sample (comma-separated or NA)
    if sample_fastq_files:
        fastq_files_column.append(','.join(sorted(set(sample_fastq_files))))
    else:
        fastq_files_column.append(np.nan)

# Add fastq_files column and save updated file
df['fastq_files'] = fastq_files_column
df.dropna(subset=['fastq_files'], inplace = True)
df.to_csv(
    os.path.expanduser('~/IMV2OpenBis/IDs_with_fastq.txt'), 
    sep='\t', 
    index=False
    )
print("Updated sample file saved as 'IDs_with_fastq.txt'")

# Add files to output directory and remove the temporal folder
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Recursively find all files in DOWNLOAD_DIR
file_paths = glob.glob(
    os.path.join(DOWNLOAD_DIR, '**', '*.*'), recursive=True
    )

for file_path in file_paths:
    if os.path.isfile(file_path):
        filename = os.path.basename(file_path)
        dest_path = os.path.join(OUTPUT_DIR, filename)

        shutil.move(file_path, dest_path)
        print(f"Moved {file_path} to {dest_path}")

# Remove the original DOWNLOAD_DIR entirely
shutil.rmtree(DOWNLOAD_DIR)
print(f"All files moved to {OUTPUT_DIR} and {DOWNLOAD_DIR} has been deleted.")