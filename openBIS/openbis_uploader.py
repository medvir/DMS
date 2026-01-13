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
    try:
        sample = o.get_sample(f"/{space}/{sample_code}")
        print(f"Updating Sample: {sample_code}")
    except Exception:
        print(f"Creating Sample: {sample_code}")
        sample = o.new_sample(
            type=sample_type,
            code=sample_code,
            space=space,
            project=project_id,
            experiment=exp.identifier
        )
    
    # 3. Apply Cleaned Properties (Remove undefined samples and transform int to Integers)
    clean_props = {}
    for k, v in properties.items():
        if v is not None and str(v).lower() != 'undefined' and str(v).strip() != '':
            key = k.lower()
            val_str = str(v).strip()
            
            # If it's a number, send it as an Integer to satisfy openBIS
            if val_str.isdigit():
                clean_props[key] = int(val_str)
            else:
                clean_props[key] = val_str
    
    sample.set_props(clean_props)

    # 4. Parent Linking
    if parent_code:
        try:
            parent_sample = o.get_sample(f"/{space}/{parent_code}")
            if parent_sample:
                sample.parents = [parent_sample.identifier]
        except:
            print(f"Note: Parent {parent_code} not found yet.")
    
    sample.save()

    # 5. Dataset Upload
    if files:
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