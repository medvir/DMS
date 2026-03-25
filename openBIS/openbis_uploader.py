#!/usr/bin/env python3

import configparser
import os
import sys
import json
from pybis import Openbis

# Configuration
OPENBIS_URL = 'https://openbis.virology.uzh.ch/openbis/'
config = configparser.ConfigParser()
config.read(os.path.expanduser('~/.pybis/cred.ini'))
USER = config['credentials']['username']
PASSWORD = config['credentials']['password']
    
def upload_to_openbis(data):
    o = Openbis(OPENBIS_URL, verify_certificates=True)
    o.login(USER, PASSWORD, save_token=True)

    # Standardize inputs to uppercase
    space = data.get('space', 'IMV').upper()
    project_code = data.get('project', '').upper()
    experiment_code = data.get('experiment', '').upper()
    sample_code = data.get('sample_code', '').upper()
    sample_type = data.get('sample_type', '').upper()
    parent_code = data.get('parent_sample', '').upper()
    
    properties = data.get('properties', {})
    files = data.get('files', [])

    project_id = f"/{space}/{project_code}"
    exp_id = f"{project_id}/{experiment_code}"
    
    # 1. Ensure Experiment exists or create it
    try:
        exp = o.get_experiment(exp_id)
    except Exception:
        print(f"Creating missing Experiment: {experiment_code} in {project_id}")
        exp = o.new_experiment(type='MISEQ_RUNS', code=experiment_code, project=project_id)
        exp.save()

    # 2. Handle Sample (Find or Create)
    sample_path = f"/{space}/{project_code}/{sample_code}"
    sample_exists = False

    try:
        sample = o.get_sample(sample_path)
        sample_exists = True
        print(f"NOTICE: Sample {sample_code} already exists. Updating and/or overwriting...")

    except Exception:
        print(f"Creating Sample: {sample_code}")
        try:
            sample = o.new_sample(
                type=sample_type,
                code=sample_code,
                space=space,
                project=project_id,
                experiment=exp.identifier
            )
            sample.save()
        except Exception as e:
            print(f"FAILED to create {sample_code}: {e}")
            return
    
    # 3. Apply Cleaned Properties (Remove undefined samples and transform int to Integers)
    clean_props = {}
    for k, v in properties.items():
        if v is not None and str(v).lower() != 'undefined' and str(v).strip() != '':
            key = k.strip().lower()
            val_str = str(v).strip()
            
            # If it's a number, send it as an Integer to satisfy openBIS
            if key in ['viral_load', 'read_1', 'read_2', 'sample_id']:
                try:
                    clean_props[key] = int(val_str)
                except ValueError:
                    print(f"Warning: {key} value '{val_str}' is not an integer. Sending as text.")
                    clean_props[key] = val_str

            elif key == 'phix_concentration':
                try:
                    clean_props[key] = float(val_str)
                except ValueError:
                    print(f"Warning: {key} value '{val_str}' is not a number. Sending as text.")
                    clean_props[key] = val_str

            else:
                clean_props[key] = val_str
    
    sample.set_props(clean_props)
    sample.save()

    # 4. Parent Linking
    if parent_code:
        parent_id = f"/{space}/{project_code}/{parent_code}"
        try:
            parent_obj = o.get_sample(parent_id)
            
            try:
                sample.parents = parent_obj
                sample.save()
                print(f"Linked to: {parent_id}")
            except Exception as e:
                print(f"Link failed: {e}")
                
        except Exception:
            print(f"Note: Parent {parent_code} not found. Skipping link.")

    # 5. Dataset Upload
    if files:
        # Check if the sample already has datasets to avoid duplication
        existing_datasets = sample.get_datasets() if sample_exists else []

        if len(existing_datasets) > 0:
            print(f"Note: Sample already has {len(existing_datasets)} dataset(s). Skipping FASTQ upload to prevent duplicates.")
        else:
            valid_files = [f for f in files if os.path.exists(f)]
            if valid_files:
                ds = o.new_dataset(type=data.get('dataset_type', 'FASTQ'), sample=sample, files=valid_files)
                ds.save()
                print(f"Uploaded {len(valid_files)} files.")

    o.logout()

if __name__ == "__main__":
    try:
        input_data = json.loads(sys.argv[1])
        upload_to_openbis(input_data)
    except Exception as e:
        print(f"ERROR: {str(e)}", file=sys.stderr)
        sys.exit(1)