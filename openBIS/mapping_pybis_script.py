#!/usr/bin/env python3
"""Map samples in openBIS following their unique naming scheme."""
import getpass
import logging
import logging.handlers
import os
import shlex
import subprocess
import sys
import tempfile

from pybis import Openbis

logging.basicConfig(
    filename='pybis_script.log', level=logging.INFO,
    format='%(levelname)s %(asctime)s %(filename)s: %(funcName)s() %(lineno)d: \t%(message)s',
    datefmt='%Y/%m/%d %H:%M:%S')

files_to_save = ['report.md', 'report.pdf', 'merged_muts_drm_annotated.csv', 'minvar.log', 'cns_max_freq.fasta']


def general_mapping(project=None):
    """Create parent-child relationships in a project.

    MISEQ_RUN -> MISEQ_SAMPLE (where -> means "parent of")
    For resistance tests, the full relationship is
    MISEQ_RUN -> MISEQ_SAMPLE -> RESISTANCE_TEST
    """
    logging.info('Mapping called for project %s', project)
    p_code = project.upper()
    valid_projects = ['RESISTANCE', 'METAGENOMICS', 'PLASMIDS', 'OTHER', 'ANTIBODIES']
    if p_code not in valid_projects:
        sys.exit('Choose a valid project: %s' % ','.join(valid_projects))

    logging.info('We are here in project %s', p_code)
    # define experiments list
    exp_names = ['MISEQ_RUNS', 'MISEQ_SAMPLES']
    if p_code == 'RESISTANCE':
        exp_names.append('RESISTANCE_TESTS')

    # dict with a list of samples from each experiment in this project
    samples_dict = {}
    for xp_name in exp_names:
        logging.info('Saving samples in experiment %s', xp_name)

        xp_full_name = '/IMV/%s/%s' % (p_code, xp_name)
        all_codes = set([smp.code for smp in o.get_experiment(xp_full_name).get_samples()])
        try:
            mapped_codes = set([smp.code for smp in o.get_experiment(xp_full_name).get_samples(tags=['mapped'])])
        except ValueError:
            mapped_codes = set()
        unmapped_codes = all_codes - mapped_codes
        samples_dict[xp_name] = unmapped_codes

    logging.info('Found %d MISEQ samples, start mapping', len(samples_dict['MISEQ_SAMPLES']))

    for miseq_sample_id in samples_dict['MISEQ_SAMPLES']:
        # e.g.
        # miseq_sample_id = 170623_M02081_0218_000000000-B4CPG-1
        # miseq_run_id = 170623_M02081_0218_000000000-B4CPG
        miseq_run_id = \
            '-'.join(miseq_sample_id.split('-')[:-1]) + '_%s' % p_code
        assert miseq_run_id in samples_dict['MISEQ_RUNS'], miseq_run_id

        # extract samples with get_sample (we are using unique identifiers)
        miseq_sample = o.get_sample('/IMV/%s' % miseq_sample_id)
        assert 'mapped' not in miseq_sample.tags
        # run_sample can be extracted here, but we are using the 'mapped'
        # tag only when samples are given a parent, and run_sample
        # only has children
        # run_sample = o.get_sample('/IMV/%s' % miseq_run_id)

        # create the run -> sample link
        logging.info('mapping sample %s', miseq_sample_id)
        miseq_sample.add_parents('/IMV/%s' % miseq_run_id)
        miseq_sample.add_tags('mapped')
        miseq_sample.save()

        # for resistance tests there is another relation to create
        if p_code == 'RESISTANCE':
            resi_sample_id = '%s_RESISTANCE' % miseq_sample_id
            resi_sample = o.get_sample('/IMV/%s' % resi_sample_id)

            if 'mapped' not in resi_sample.tags:
                resi_sample.add_parents('/IMV/%s' % miseq_sample_id)
                resi_sample.add_tags('mapped')
                resi_sample.save()
                logging.info('mapping sample %s', resi_sample_id)
            else:
                logging.warning('sample %s already mapped', resi_sample_id)


def run_child(cmd):
    """Use subrocess.check_output to run an external program with arguments."""
    cml = shlex.split(cmd)
    logging.info('Running instance of %s', cml[0])
    try:
        output = subprocess.check_output(
            cml, universal_newlines=True, stderr=subprocess.STDOUT)
        logging.info('Completed')
    except subprocess.CalledProcessError as ee:
        logging.error(
            "Execution of %s failed with returncode %d: %s",
            cmd, ee.returncode, ee.output)
        logging.error(cmd)
        output = None
    return output


def run_minvar(ds):
    """Run minvar and return a dictionary of output files."""
    rdir = os.getcwd()
    with tempfile.TemporaryDirectory() as tmpdirname:
        logging.info('running minvar in %s', tmpdirname)
        os.chdir(tmpdirname)
        for f in list(ds.file_list):
            if not f.endswith('properties'):
                fastq_name = f
        ds.download(destination='.')
        try:
            fastq_file = os.path.join(tmpdirname, ds.permId, fastq_name)
        except UnboundLocalError:  # sometimes fastq files are not present
            os.chdir(rdir)
            return {}
        assert os.path.exists(fastq_file), ' '.join(os.listdir())
        cml = shlex.split('minvar -f %s' % fastq_file)
        with open('/tmp/minvar.err', 'w') as oh:
            subprocess.call(cml, stdout=oh, stderr=subprocess.STDOUT)
        try:
            logging.info('minvar finished, copying files')
            saved_files = {fn: open(fn, 'rb').read() for fn in files_to_save}
        except FileNotFoundError:
            logging.warning('minvar finished with an error, saving minvar.err')
            saved_files = {'minvar.err': open('/tmp/minvar.err', 'rb').read()}
    os.chdir(rdir)
    return saved_files


# open the session first
o = Openbis('https://s3itdata.uzh.ch', verify_certificates=True)
if not o.is_session_active():
    o = Openbis('https://s3itdata.uzh.ch', verify_certificates=False)
    password = getpass.getpass()
    # saves token in ~/.pybis/example.com.token
    o.login('ozagor', password, save_token=True)

logging.info('Mapping session starting')
for pro in ['resistance', 'metagenomics', 'antibodies', 'plasmids', 'other']:
    general_mapping(pro)
logging.info('Mapping session finished')

logging.info('Analysis session starting')
# iterate through resistance samples to run minvar
res_test_samples = o.get_experiment('/IMV/RESISTANCE/RESISTANCE_TESTS').get_samples(tags=['mapped'])
# res_test_samples = [o.get_sample('/IMV/170803_M02081_0226_000000000-BCJY4-1_RESISTANCE')]
logging.info('Found %d samples', len(res_test_samples))

c = 0
files_to_delete = []
for sample in res_test_samples:
    virus = sample.props.virus
    sample_name = sample.props.sample_name
    if 'analysed' in sample.tags:
        logging.debug('Sample already analysed')
        continue
    parents = sample.get_parents()
    assert len(parents) == 1
    parent = parents[0]
    try:
        rd = parent.get_datasets()
        logging.info('Datasets found. Sample: %s - virus: %s', sample.code, virus)
    except ValueError:
        logging.warning('No datasets')
        sample.add_tags('analysed')
        sample.save()
        continue
    ds_code1 = str(rd[0].permId)
    dataset = o.get_dataset(ds_code1)
    minvar_files = run_minvar(dataset)
    for filename, v in minvar_files.items():
        fh = open(filename, 'wb')
        fh.write(v)
        fh.close()
        # add molis number into filename
        if filename == 'report.pdf':
            upload_name = 'report_%s.pdf' % sample_name
            os.rename(filename, upload_name)
        else:
            upload_name = filename
        sample.add_attachment(upload_name)
        files_to_delete.append(upload_name)
    sample.add_tags('analysed')
    sample.save()

    c += 1
    if c == 20:
        break

for filename in set(files_to_delete):
    try:
        os.remove(filename)
    except FileNotFoundError:
        continue
