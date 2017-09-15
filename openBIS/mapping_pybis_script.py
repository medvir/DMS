#!/usr/bin/env python
'''Map samples in openBIS following their unique naming scheme'''
import os
import sys
import getpass
import logging
import logging.handlers
import tempfile
import subprocess
from pybis import Openbis

logging.basicConfig(
    filename='pybis_script.log', level=logging.DEBUG,
    format='%(levelname)s %(asctime)s %(filename)s: %(funcName)s() %(lineno)d: \t%(message)s',
    datefmt='%Y/%m/%d %H:%M:%S')

def general_mapping(project=None):
    '''Create parent-child relationships in a project, like
    MISEQ_RUN -> MISEQ_SAMPLE (where -> means "parent of")
    For resistance tests, the full relationship is
    MISEQ_RUN -> MISEQ_SAMPLE -> RESISTANCE_TEST
    '''
    logging.debug('Mapping called for project %s', project)
    p_code = project.upper()
    valid_projects = ['RESISTANCE', 'METAGENOMICS', 'PLASMIDS', 'OTHER',
                      'ANTIBODIES']
    if p_code not in valid_projects:
        sys.exit('Choose a valid project: %s' % ','.join(valid_projects))

    proj = o.get_projects(space='IMV', code=p_code)[0]
    logging.debug('We are here in project %s', proj.code)

    # dict with a list of samples from each experiment in this project
    samples_dict = {}
    for xp in proj.get_experiments():
        xp_name = str(xp.type)
        codes_here = [smp.code for smp in xp.get_samples()]
        samples_dict[xp_name] = codes_here

    for miseq_sample_id in samples_dict['MISEQ_SAMPLES']:
        # e.g.
        # miseq_sample_id = 170623_M02081_0218_000000000-B4CPG-1
        # miseq_run_id = 170623_M02081_0218_000000000-B4CPG
        miseq_run_id = \
            '-'.join(miseq_sample_id.split('-')[:-1]) + '_%s' % p_code
        assert miseq_run_id in samples_dict['MISEQ_RUNS'], miseq_run_id

        # extract samples with get_sample (we are using unique identifiers)
        miseq_sample = o.get_sample('/IMV/%s' % miseq_sample_id)

        # run_sample can be extracted here, but we are using the 'mapped'
        # tag only when samples are given a parent, and run_sample
        # only has children
        # run_sample = o.get_sample('/IMV/%s' % miseq_run_id)

        # create the run -> sample link
        if 'mapped' not in miseq_sample.tags:
            miseq_sample.add_parents('/IMV/%s' % miseq_run_id)
            miseq_sample.add_tags('mapped')
            miseq_sample.save()
        else:
            logging.debug('sample %s already mapped', miseq_sample_id)

        # for resistance tests there is another relation to create
        if p_code == 'RESISTANCE':
            resi_sample_id = '%s_RESISTANCE' % miseq_sample_id
            resi_sample = o.get_sample('/IMV/%s' % resi_sample_id)

            if 'mapped' not in resi_sample.tags:
                resi_sample.add_parents('/IMV/%s' % miseq_sample_id)
                resi_sample.add_tags('mapped')
                resi_sample.save()
            else:
                logging.debug('sample %s already mapped', resi_sample_id)


def run_child(cmd):
    '''use subrocess.check_output to run an external program with arguments'''
    import shlex
    cml = shlex.split(cmd)
    logging.debug('Running instance of %s', cml[0])
    try:
        output = subprocess.check_output(
            cml, universal_newlines=True, stderr=subprocess.STDOUT)
        logging.debug('Completed')
    except subprocess.CalledProcessError as ee:
        logging.error(
            "Execution of %s failed with returncode %d: %s",
            cmd, ee.returncode, ee.output)
        logging.error(cmd)
        output = None
    return output


def run_minvar(fastq_file):
    files_to_save = ['report.md', 'annotated_DRM.csv']
    with tempfile.TemporaryDirectory() as tmpdirname:
        print('going to temporary directory', tmpdirname)
        os.chdir(tmpdirname)
        run_child('minvar -f %s &> /tmp/minvar.log' % fastq_file)
        print('minvar finished, copying files')
        saved_files = {fn: open(fn).readlines() for fn in files_to_save}
    return saved_files


# open the session first
o = Openbis('https://s3itdata.uzh.ch', verify_certificates=True)
if not o.is_session_active():
    o = Openbis('https://s3itdata.uzh.ch', verify_certificates=False)
    password = getpass.getpass()
    # saves token in ~/.pybis/example.com.token
    o.login('ozagor', password, save_token=True)


logging.info('Mapping session starting')
# map samples in each project
for project in ['resistance', 'metagenomics', 'antibodies', 'plasmids', 'other']:
    general_mapping(project)
logging.info('Mapping session finished')

logging.info('Analysis session starting')
# iterate through resistance samples to run minvar
res_test_samples = o.get_experiment('/IMV/RESISTANCE/RESISTANCE_TESTS').get_samples(tags=['mapped'])

for sample in res_test_samples:
    virus = sample.props.virus
    if virus != 'HIV-1':
        logging.debug('Virus is not HIV')
        continue
    if 'analysed' in sample.tags:
        logging.debug('Sample already analysed')
        continue
    logging.info('Found resistance sample: %s' % sample.code)
    parents = sample.get_parents()
    assert len(parents) == 1
    parent = parents[0]
    logging.info('Parent: %s' % parent.code)
    continue
    try:
        rd = parent.get_datasets()[0]
        logging.debug('Datasets found')
    except ValueError:
        logging.warning('No datasets')
        continue

    minvar_files = get_minvar_files('/IMV/%s' % parent.code)
    for k, v in minvar_files.items():
        fh = open(k, 'wb')
        fh.write(v)
        fh.close()
    break
