#!/usr/bin/env python3
"""Map samples in openBIS following their unique naming scheme."""
import configparser
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

files_to_save = ['report.md', 'report.pdf', 'merged_muts_drm_annotated.csv', 'minvar.log', 'cns_max_freq.fasta',
                 'merged_mutations_nt.csv']


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
    type_names = ['MISEQ_RUN', 'MISEQ_SAMPLE']
    if p_code == 'RESISTANCE':
        type_names.append('RESISTANCE_TEST')

    # dict with a list of samples from each experiment in this project
    samples_dict = {}
    for type_name in type_names:
        logging.debug('Saving samples in experiment %s', type_name)
        # xp_full_name = '/IMV/%s/%s' % (p_code, xp_name)
        # samples = o.get_experiment(xp_full_name).get_samples()
        samples = o.get_samples(space='IMV', type=type_name)
        all_df = samples.df
        all_df['project'] = all_df.apply(lambda row: row['experiment'].split('/')[2], axis=1)
        all_df = all_df[all_df['project'] == p_code]
        all_codes = set(all_df['identifier'])
        try:
            # mapped_samples = o.get_experiment(xp_full_name).get_samples(tags=['mapped'])
            mapped_samples = o.get_samples(space='IMV', type=type_name, mapped=True)
            mapped_df = mapped_samples.df
            mapped_df['project'] = mapped_df.apply(lambda row: row['experiment'].split('/')[2], axis=1)
            mapped_df = mapped_df[mapped_df['project'] == p_code]
            mapped_codes = set(mapped_df['identifier'])
        except ValueError:
            mapped_codes = set()
        unmapped_codes = all_codes - mapped_codes
        samples_dict[type_name] = unmapped_codes

    logging.info('Found %d unmapped MISEQ samples in project %s', len(samples_dict['MISEQ_SAMPLE']), p_code)
    print('Found %d unmapped MISEQ samples', len(samples_dict['MISEQ_SAMPLE']), p_code)

    for miseq_sample_id in samples_dict['MISEQ_SAMPLE']:
        # e.g.
        # miseq_sample_id = 170623_M02081_0218_000000000-B4CPG-1
        # miseq_run_id = 170623_M02081_0218_000000000-B4CPG
        miseq_run_id = \
            '-'.join(miseq_sample_id.split('-')[:-1]) + '_%s' % p_code
        assert miseq_run_id in samples_dict['MISEQ_RUN'], miseq_run_id

        # extract samples with get_sample (we are using unique identifiers)
        miseq_sample = o.get_sample(miseq_sample_id)
        print(miseq_sample)
        # assert 'mapped' not in miseq_sample.tags
        # run_sample can be extracted here, but we are using the 'mapped'
        # property only when samples are given a parent, and run_sample
        # only has children
        # run_sample = o.get_sample('/IMV/%s' % miseq_run_id)

        # create the run -> sample link
        logging.info('mapping sample %s', miseq_sample_id)
        miseq_sample.add_parents(miseq_run_id)
        miseq_sample.props.mapped = True  # add_tags('mapped')
        miseq_sample.save()

        # for resistance tests there is another relation to create
        if p_code == 'RESISTANCE':
            resi_sample_id = '%s_RESISTANCE' % miseq_sample_id
            resi_sample = o.get_sample(resi_sample_id)

            if not resi_sample.props.mapped or resi_sample.props.mapped is None:
                resi_sample.add_parents(miseq_sample_id)
                resi_sample.props.mapped = True  # add_tags('mapped')
                resi_sample.save()
                logging.info('mapping sample %s', resi_sample_id)
            else:
                logging.warning('sample %s already mapped', resi_sample_id)
        break


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
    config = configparser.ConfigParser()
    config.read(os.path.expanduser('~/.pybis/cred.ini'))
    username = config['credentials']['username']
    password = config['credentials']['password']
    o.login(username, password, save_token=True)



# sample = o.get_sample('/IMV/170803_M02081_0226_000000000-BCJY4-1_RESISTANCE')
# print('Before, mapped is', sample.props.mapped)
# sample.props.mapped = True
# sample.save()
# print('After, mapped is', sample.props.mapped)
#
# smp = o.get_samples(space='IMV', mapped=True)
# all_smp = o.get_samples(space='IMV', type='RESISTANCE_TEST')
# df = all_smp.df
# df['project'] = df.apply(lambda row: row['experiment'].split('/')[2], axis=1)
# print(df)
# sys.exit()
# sas = set(all_smp.df['identifier'].tolist())
# sam = set(smp.df['identifier'].tolist())
# print(sam & sas)
#
# o.logout()
# sys.exit()


logging.info('-----------Mapping session starting------------')
for pro in ['antibodies', 'resistance', 'metagenomics', 'plasmids', 'other']:
    general_mapping(pro)
    break
o.logout()
sys.exit()
logging.info('-----------Mapping session finished------------')
logging.info('* * * * * * * * * * * * * * * * * * * * * * * *')
logging.info('-----------Analysis session starting-----------')
# Fetch resistance samples where minvar must be run
res_test_mapped = o.get_experiment('/IMV/RESISTANCE/RESISTANCE_TESTS').get_samples(tags=['mapped'])
rtm = set(res_test_mapped.df['identifier'])
res_test_analysed = o.get_experiment('/IMV/RESISTANCE/RESISTANCE_TESTS').get_samples(tags=['analysed'])
rta = set(res_test_analysed.df['identifier'])
# res_test_samples = [o.get_sample('/IMV/170803_M02081_0226_000000000-BCJY4-1_RESISTANCE')]
logging.info('Found %d mapped samples', len(rtm))
logging.info('Found %d analysed samples', len(rta))
samples_to_analyse = rtm - rta
logging.info('Analysis will proceed on %d samples', len(samples_to_analyse))

c = 0
files_to_delete = []
for sample_id in samples_to_analyse:
    sample = o.get_sample(sample_id)
    virus = sample.props.virus
    sample_name = sample.props.sample_name
    if 'analysed' in sample.tags:
        logging.warning('Sample already analysed: should not be here!')
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
logging.info('-----------Analysis session finished-----------')
o.logout()
