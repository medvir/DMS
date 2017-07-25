#!/usr/bin/env python
'''Map samples in openBIS following their unique naming scheme'''
import os
import sys
import glob
import codecs
import getpass
import logging
import logging.handlers
import tempfile
import subprocess
from pybis import Openbis

logging.basicConfig(filename='/home/ubuntu/pybis_script.log', level=logging.INFO,
                    format='%(levelname)s %(asctime)s %(filename)s: %(funcName)s() %(lineno)d: \t%(message)s',
                    datefmt='%Y/%m/%d %H:%M:%S')


def run_child(cmd, exe='/bin/bash'):
    '''use subrocess.check_output to run an external program with arguments'''
    logging.debug('Running instance of %s' % cmd.split()[0])
    try:
        output = subprocess.check_output(cmd, universal_newlines=True,
        shell=True,
#        executable=exe,
        stderr=subprocess.STDOUT)
        logging.debug('Completed')
    except subprocess.CalledProcessError as ee:
        logging.error("Execution of %s failed with returncode %d: %s" % (cmd, ee.returncode, ee.output))
        logging.error(cmd)
        output = None
    return output


def general_mapping(project=None):
    '''Create parent-child relationships in a project, like
    MISEQ_RUN -> MISEQ_SAMPLE (where -> means "parent of")
    For resistance tests, the full relationship is
    MISEQ_RUN -> MISEQ_SAMPLE -> RESISTANCE_TEST
    '''
    logging.info('Mapping called for project %s' % project)
    p_code = project.upper()
    valid_projects = ['RESISTANCE', 'METAGENOMICS', 'PLASMIDS', 'OTHER',
                      'ANTIBODIES']
    if p_code not in valid_projects:
        sys.exit('Choose a valid project: %s' % ','.join(valid_projects))

    proj = o.get_projects(space='IMV', code=p_code)[0]
    logging.debug('We are here in project %s' % proj.code)

    # dict with a list of samples from each experiment in this project
    samples_dict = {}
    for xp in proj.get_experiments():
        xp_name = str(xp.type)
        try:
            codes_here = [smp.code for smp in xp.get_samples()]
        except ValueError as ee:
            logging.error('No samples here?')
            logging.error(str(ee))
            codes_here = []
        samples_dict[xp_name] = codes_here

    logging.info('Found %d miseq samples' % len(samples_dict['MISEQ_SAMPLES']))

    for miseq_sample_id in samples_dict['MISEQ_SAMPLES']:
        # e.g.
        # miseq_sample_id = 170623_M02081_0218_000000000-B4CPG-1
        # miseq_run_id = 170623_M02081_0218_000000000-B4CPG
        miseq_run_id = '-'.join(miseq_sample_id.split('-')[:-1]) + '_%s' % p_code
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
            logging.info('sample %s mapped' % miseq_sample_id)
        else:
            logging.debug('sample %s already mapped' % miseq_sample_id)

        # for resistance tests there is another relation to create
        if p_code == 'RESISTANCE':
            resi_sample_id = '%s_RESISTANCE' % miseq_sample_id
            resi_sample = o.get_sample('/IMV/%s' % resi_sample_id)

            if 'mapped' not in resi_sample.tags:
                resi_sample.add_parents('/IMV/%s' % miseq_sample_id)
                resi_sample.add_tags('mapped')
                resi_sample.save()
            else:
                logging.debug('sample %s already mapped' % resi_sample_id)


def run_minvar(fastq_file):
    '''Run minvar on the input file in a tmp directory and returns some output
    files
    '''
    files_to_save = ['report.md', 'annotated_DRM.csv', 'minvar.err', 'minvar.log', 'report.pdf']
    cwd = os.getcwd()
    with tempfile.TemporaryDirectory() as tmpdirname:
        logging.debug('going to temporary directory %s' % tmpdirname)
        os.chdir(tmpdirname)
        run_child('minvar -f %s &> minvar.err' % fastq_file)
        saved_files = {}
        for fn in files_to_save:
            try:
                print('Reading', fn)
                saved_files[fn] = open(fn, "rb").read()
                logging.debug('Written %d bytes to %s' % (len(saved_files[fn]), fn))
            except FileNotFoundError as err:
                logging.error(str(err))
                saved_files[fn] = b'File not found\n'
        print(saved_files.keys())
    os.chdir(cwd)
    return saved_files


def get_minvar_files(smp_code):
    '''
    '''
    smp = o.get_sample(smp_code)
    for rd in smp.get_datasets(type='FASTQ'):
        od = rd.download(destination='/tmp', wait_until_finished=True)
        for file_path in rd.file_list:
            # build full path of downloaded files
            full_path = '/tmp/%s/%s' % (rd.permId, file_path)
            assert os.path.exists(full_path), full_path
            if 'fastq' in os.path.basename(file_path) or 'fq' in os.path.basename(file_path):
                fastq_path = full_path
        logging.info('Running minvar on %s' % fastq_path)
        minvar_output = run_minvar(fastq_path)
        return minvar_output

# open the session first
o = Openbis('https://s3itdata.uzh.ch', verify_certificates=True)
if not o.is_session_active():
    o = Openbis('https://s3itdata.uzh.ch', verify_certificates=False)
    password = getpass.getpass()
    # saves token in ~/.pybis/example.com.token
    o.login('ozagor', password, save_token=True)

logging.info('Mapping session starting')
# map samples in each project
for project in ['metagenomics', 'resistance', 'antibodies', 'plasmids', 'other']:
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
        sample.add_attachment(k)
        os.remove(k)
    sample.add_tags('analysed')
    sample.save()
    print('-----------')
logging.info('Analysis session finished')
