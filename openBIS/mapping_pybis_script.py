#!/usr/bin/env python3
"""Map samples in openBIS following their unique naming scheme."""
import configparser
import io
import logging
import logging.handlers
import os
import shlex
import subprocess
import sys
import tempfile
import time
import glob
import shutil
from pybis import Openbis
from tqdm import tqdm
import PyPDF2

minvar_2_save = ['report.md', 'report.pdf', 'merged_muts_drm_annotated.csv', 'minvar.log', 'cns_max_freq.fasta',
                 'merged_mutations_nt.csv', 'subtype_evidence.csv', 'cns_ambiguous.fasta', 'mutations_nt_pos_ref_aa.csv']
v3seq_2_save = ['v3haplotypes.fasta', 'v3seq.log', 'v3cons.fasta']
runControl_2_save = ['score_report.txt','runko.log']

smaltalign_ref_CMV_dict = {'CMV_UL54':'/home/ubuntu/SmaltAlign/References/CMV_UL54_REF.fasta', 'CMV_UL56':'/home/ubuntu/SmaltAlign/References/CMV_UL56_REF.fasta', 'CMV_UL97':'/home/ubuntu/SmaltAlign/References/CMV_UL97_REF.fasta'}
smaltalign_ref_path_dict = {'SARS-COV2':'/home/ubuntu/SmaltAlign/References/MN908947_REF.fasta', 'CMV':smaltalign_ref_CMV_dict}

smaltalign_exe_path="smaltalign"

analyses_per_run = 20

class TqdmToLogger(io.StringIO):
    """Output stream for tqdm which will output to logger module instead of the STDOUT."""

    logger_l = None
    level = None
    buf = ''

    def __init__(self, logger_l, level=None):
        super(TqdmToLogger, self).__init__()
        self.logger = logger_l
        self.level = level or logging.INFO

    def write(self, buf):
        self.buf = buf.strip('\r\n\t ')

    def flush(self):
        self.logger.log(self.level, self.buf)


def general_mapping(project=None):
    """Create parent-child relationships in a project.

    MISEQ_RUN -> MISEQ_SAMPLE (where -> means "parent of")
    For resistance tests, the full relationship is
    MISEQ_RUN -> MISEQ_SAMPLE -> RESISTANCE_TEST
    """
    logging.info('Mapping called for project %s', project)
    p_code = project.upper()
    valid_projects = ['RESISTANCE', 'METAGENOMICS', 'PLASMIDS', 'OTHER', 'ANTIBODIES', 'RETROSEQ', 'CONSENSUS']
    if p_code not in valid_projects:
        sys.exit('Choose a valid project: %s' % ','.join(valid_projects))

    logging.info('We are here in project %s', p_code)
    # define experiments list
    type_names = ['MISEQ_RUN', 'MISEQ_SAMPLE']
    if p_code == 'RESISTANCE' or p_code == 'RETROSEQ' or p_code == 'CONSENSUS':
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
    for miseq_sample_id in tqdm(samples_dict['MISEQ_SAMPLE'], file=tqdm_out, mininterval=30):
        # e.g.
        # miseq_sample_id = 170623_M02081_0218_000000000-B4CPG-1
        # miseq_run_id = 170623_M02081_0218_000000000-B4CPG
        miseq_run_id = \
            '-'.join(miseq_sample_id.split('-')[:-1]) + '_%s' % p_code
        assert miseq_run_id in samples_dict['MISEQ_RUN'], miseq_run_id

        # extract samples with get_sample (we are using unique identifiers)
        miseq_sample = o.get_sample(miseq_sample_id)
        # assert 'mapped' not in miseq_sample.tags
        # run_sample can be extracted here, but we are using the 'mapped'
        # property only when samples are given a parent, and run_sample
        # only has children
        # run_sample = o.get_sample('/IMV/%s' % miseq_run_id)

        # create the run -> sample link
        logging.debug('mapping sample %s', miseq_sample_id)
        miseq_sample.add_parents(miseq_run_id)
        miseq_sample.props.mapped = True
        miseq_sample.save()

        # for resistance tests there is another relation to create
        if p_code == 'RESISTANCE' or p_code == 'RETROSEQ' :
            #if p_code == 'RESISTANCE':
            resi_sample_id = '%s_RESISTANCE' % miseq_sample_id
            resi_sample = o.get_sample(resi_sample_id)
            #elif p_code == 'RETROSEQ' :
            #    resi_sample_id = '%s_RETROSEQ' % miseq_sample_id
            #    resi_sample = o.get_sample(resi_sample_id)

            if not resi_sample.props.mapped or resi_sample.props.mapped is None:
                resi_sample.add_parents(miseq_sample_id)
                resi_sample.props.mapped = True
                resi_sample.save()
                logging.debug('mapping sample %s', resi_sample_id)
            else:
                logging.warning('sample %s already mapped', resi_sample_id)
        
        elif p_code == 'CONSENSUS':
            cons_sample_id = '%s_CONSENSUS' % miseq_sample_id
            cons_sample = o.get_sample(cons_sample_id)
            if not cons_sample.props.mapped or cons_sample.props.mapped is None:
                cons_sample.add_parents(miseq_sample_id)
                cons_sample.props.mapped = True
                cons_sample.save()
                logging.debug('mapping sample %s', cons_sample_id)
            else:
                logging.warning('sample %s already mapped', cons_sample_id)

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


def run_exe(ds, exe=None, ref=None):
    """Run external program and return a dictionary of output files."""
    if exe == 'minvar':
        files_to_save = minvar_2_save
    elif exe == 'runControl':
        files_to_save = runControl_2_save
    elif exe == 'v3seq':
        files_to_save = v3seq_2_save
    elif exe == 'smaltalign_indel':
        files_to_save = []
        
    rdir = os.getcwd()
    cml_wts=''
    with tempfile.TemporaryDirectory() as tmpdirname:
        logging.info('running %s in %s', exe, tmpdirname)
        os.chdir(tmpdirname)
        #Added for runControl, runControl gets the output of minvar as input and
        # does not need the fastq file from openbis
        if exe == 'runControl':
            runCo_input_full_path = os.path.join(rdir, ds)
            cml = shlex.split('%s -f %s' % (exe, runCo_input_full_path))
        else:
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

            if exe == 'smaltalign_indel':

                if ref != None:
                    smaltalign_ref_path = smaltalign_ref_CMV_dict[ref]
                else:
                    smaltalign_ref_path = smaltalign_ref_path_dict['SARS-COV2']
                shutil.copy(smaltalign_ref_path,tmpdirname)
                cml = shlex.split('%s -r %s -o %s -t 15 -c 1 -d %s' % (smaltalign_exe_path, smaltalign_ref_path, tmpdirname, fastq_file))
                cml_wts = shlex.split('sudo Rscript /home/ubuntu/SmaltAlign/wts.R %s 50 3' %(tmpdirname))
            else:
                cml = shlex.split('%s -f %s' % (exe, fastq_file))
            
        with open('/tmp/%s.err' % exe, 'w') as oh:
            subprocess.call(cml, stdout=oh, stderr=subprocess.STDOUT)
            if cml_wts:
                subprocess.call(cml_wts, stdout=oh, stderr=subprocess.STDOUT)
        try:
            logging.info('%s finished, copying files', exe)
            saved_files = {fn: open(fn, 'rb').read() for fn in files_to_save}
            if cml_wts:
                saved_files.update({fn: open(fn, 'rb').read() for fn in glob.glob('*REF.fasta')})
                saved_files.update({fn: open(fn, 'rb').read() for fn in glob.glob('*15_WTS.fasta')})
                saved_files.update({fn: open(fn, 'rb').read() for fn in glob.glob('*50_WTS.fasta')})
                saved_files.update({fn: open(fn, 'rb').read() for fn in glob.glob('*4_lofreq.vcf') if fn})
                saved_files.update({fn: open(fn, 'rb').read() for fn in glob.glob('*_lofreq_indel_hq.vcf') if fn})
                saved_files.update({fn: open(fn, 'rb').read() for fn in glob.glob('*.csv') if fn})
                saved_files.update({fn: open(fn, 'rb').read() for fn in glob.glob('*1.depth') if fn})
                pdfFileObj = open('coverage.pdf', 'rb')
                saved_files.update({'coverage.pdf': PyPDF2.PdfFileReader(pdfFileObj)}) 
                
        except FileNotFoundError:
            logging.warning('%s finished with an error, saving %s.err', exe, exe)
            saved_files = {'%s.err' % exe: open('/tmp/%s.err' % exe, 'rb').read()}
                
    os.chdir(rdir)
    logging.warning('saved_files: ')
    logging.warning(saved_files)
    return saved_files

def run_minvar(o, samples_to_analyse, tqdm_out, files_to_delete):
    
    global minvar_grandpa 
    upload_analysis_files_grandpa_ls = []
    for sample_id in tqdm(samples_to_analyse, file=tqdm_out):
        sample = o.get_sample(sample_id)
        virus = sample.props.virus
        sample_name = sample.props.sample_name
        parents = sample.get_parents()
        assert len(parents) == 1
        parent = parents[0]  # MISEQ_SAMPLE
        grandparents = parent.get_parents()
        assert len(grandparents) == 1
        global minvar_grandpa
        minvar_grandpa = grandparents[0]  # MISEQ_RUN
        
        try:
            rd = parent.get_datasets()
            logging.info('Datasets found. Sample: %s - virus: %s', sample.code, virus)
        except ValueError:
            logging.warning('No datasets')
            sample.props.analysed = True
            sample.save()
            continue
        ds_code1 = str(rd[0].permId)
        dataset = o.get_dataset(ds_code1)
        upload_analysis_files_ls = []
        #upload_analysis_files_grandpa_ls = []
        # run minvar on dataset, i.e. on the fastq file therein
        minvar_files = run_exe(dataset, 'minvar')
        for filename, v in minvar_files.items():
            fh = open(filename, 'wb')
            fh.write(v)
            fh.close()
            # add molis number into filename
            root, ext = os.path.splitext(filename)
            upload_name  = '%s_%s%s' % (root, sample_name, ext)
            os.rename(filename, upload_name)
            upload_analysis_files_ls.append(upload_name)
            #sample.add_attachment(upload_name)
            
            # add cns_ambiguous_molis_number.fasta as attachment to MISEQ_RUN
            if upload_name.startswith('cns_ambiguous'):
                #grandpa.add_attachment(upload_name)
                #grandpa.save()
                upload_analysis_files_grandpa_ls.append(upload_name)
            
            files_to_delete.append(upload_name)
            
            if (virus == 'HIV-1' and 'runko' in sample_name.lower() and 
                upload_name.startswith('mutations_nt_pos_ref_aa')):
                runCo_input_file = upload_name
        
                #runCo_input_file = "mutations_nt_pos_ref_aa.csv"
                runCo_files = run_exe(runCo_input_file, 'runControl')
                for filename, v in runCo_files.items():
                    fh = open(filename, 'wb')
                    fh.write(v)
                    fh.close()
                    root, ext = os.path.splitext(filename)
                    upload_name  = '%s_%s%s' % (root, sample_name, ext)
                    os.rename(filename, upload_name)
                    #sample.add_attachment(upload_name)
                    upload_analysis_files_ls.append(upload_name)
                    #grandpa.add_attachment(upload_name)
                    #grandpa.save()
                    upload_analysis_files_grandpa_ls.append(upload_name)
                    files_to_delete.append(upload_name)
    
        # on HIV only, run v3seq too
        if virus == 'HIV-1':
            v3seq_files = run_exe(dataset, 'v3seq')
            for filename, v in v3seq_files.items():
                fh = open(filename, 'wb')
                fh.write(v)
                fh.close()
                # add molis number into filename
                root, ext = os.path.splitext(filename)
                upload_name = '%s_%s%s' % (root, sample_name, ext)
                os.rename(filename, upload_name)
                #sample.add_attachment(upload_name)
                upload_analysis_files_ls.append(upload_name)
                files_to_delete.append(upload_name)
        
        ds_new = o.new_dataset(
            #experiment = '/IMV/RESISTANCE/RESISTANCE_TESTS',
            sample = sample,
            type = 'DATAMOVER_SAMPLE_CREATOR',
            files = upload_analysis_files_ls,
            )
        ds_new.save()

        sample.props.analysed = True
        sample.save()

    if upload_analysis_files_grandpa_ls:
        ds_new_grandpa = o.new_dataset(
            #experiment = '/IMV/RESISTANCE/RESISTANCE_TESTS',
            sample = minvar_grandpa,
            type = 'DATAMOVER_SAMPLE_CREATOR',
            files = upload_analysis_files_grandpa_ls,
            )
        ds_new_grandpa.save()
        
    for filename in set(files_to_delete):
        try:
            os.remove(filename)
        except FileNotFoundError:
            continue

def run_smaltalign(o, samples_to_analyse, tqdm_out, files_to_delete):

    global smalt_grandpa  
    upload_analysis_files_grandpa_ls = []
    for sample_id in tqdm(samples_to_analyse, file=tqdm_out):
        sample = o.get_sample(sample_id)
        virus = sample.props.virus
        sample_name = sample.props.sample_name
        parents = sample.get_parents()
        assert len(parents) == 1
        parent = parents[0]  # MISEQ_SAMPLE
        grandparents = parent.get_parents()
        assert len(grandparents) == 1
        global smalt_grandpa
        smalt_grandpa = grandparents[0]
        try:
            rd = parent.get_datasets()
            logging.info('Datasets found. Sample: %s - virus: %s', sample.code, virus)
        except ValueError:
            logging.warning('No datasets')
            sample.props.analysed = True
            sample.save()
            continue
        ds_code1 = str(rd[0].permId)
        dataset = o.get_dataset(ds_code1)
    
        # run smaltalign on dataset, i.e. on the fastq file therein
        # IF virus is CMV then run it three times with different references
        if virus.upper() == 'CMV':
            CMV_ref_dict = smaltalign_ref_path_dict[virus.upper()]
            for ref in CMV_ref_dict:
                #ref = 'CMV_UL54', 'CMV_UL56', 'CMV_UL97'
                smaltalign_files = run_exe(dataset, 'smaltalign_indel',  ref)
                upload_analysis_files_ls = []
                upload_analysis_files_grandpa_ls = []
                for filename, v in smaltalign_files.items():
                    fh = open(filename, 'wb')
                    if (filename == 'coverage.pdf'):
                        pdfWriter = PyPDF2.PdfFileWriter()
                        for pageNum in range(v.numPages):
                            pdfWriter.addPage(v.getPage(pageNum))
                        pdfWriter.write(fh)
                    else:
                        fh.write(v)
                    fh.close()
        
                    # add molis number into filename
                    root, ext = os.path.splitext(filename)
                    #if filename.startswith('reference'):
                        
                    if ('15_WTS' in filename):
                        new_name = '%s_new%s' % (ref, ext)
                        f = open(filename, "r")
                        fw = open(new_name, 'w')
                        f.readline() # and discard
                        replacement_line = '>' + root + '_' + ref + '\n'
                        fw.write(replacement_line)
                        shutil.copyfileobj(f, fw)
                        #filename = upload_name
                        f.close()
                        fw.close()
                        upload_name  = '%s_%s%s' % (root, ref, ext)
                        
                    elif ('50_WTS' in filename):
                        
                        new_name = '%s_new%s' % (ref, ext)
                        f = open(filename, "r")
                        fw = open(new_name, 'w')
                        f.readline() # and discard
                        replacement_line = '>' + root + '_' + ref + '\n'
                        fw.write(replacement_line)
                        shutil.copyfileobj(f, fw)
                        #filename = tmp_name
                        f.close()
                        fw.close()
                        upload_name  = '%s_%s%s' % (root, ref, ext)
                        
                    elif filename.startswith('coverage'):
                        upload_name  = '%s_%s_%s%s' % (sample_name, ref, root, ext)
                    elif 'REF.fasta' in filename:
                        upload_name = '%s_%s' % (root, ext)
                    else:
                        upload_name  = '%s_%s%s' % (root, ref, ext)#filename
                        
                    if '50_WTS' in filename or '15_WTS' in filename:
                        os.rename(new_name, upload_name)
                    else:
                        os.rename(filename, upload_name)
                    
                    upload_analysis_files_ls.append(upload_name)
                    #sample.add_attachment(upload_name)
                    
                    if ('coverage' in upload_name or '15_WTS' in upload_name):
                        #grandpa.add_attachment(upload_name)
                        #grandpa.save()
                        upload_analysis_files_grandpa_ls.append(upload_name)
                    files_to_delete.append(upload_name)
                
                ds_new = o.new_dataset(
                    #experiment = '/IMV/RESISTANCE/RESISTANCE_TESTS',
                    sample = sample,
                    type = 'DATAMOVER_SAMPLE_CREATOR',
                    files = upload_analysis_files_ls,
                    )
                ds_new.save()
                sample.props.analysed = True
                sample.save()

                if upload_analysis_files_grandpa_ls:
                    ds_new_grandpa = o.new_dataset(
                        #experiment = '/IMV/RESISTANCE/RESISTANCE_TESTS',
                        sample = smalt_grandpa,
                        type = 'DATAMOVER_SAMPLE_CREATOR',
                        files = upload_analysis_files_grandpa_ls,
                        )
                    ds_new_grandpa.save()
         
                for filename in set(files_to_delete):
                    try:
                        os.remove(filename)
                    except FileNotFoundError:
                        continue
                    
        else: #elif virus.upper() == 'SARS_COV2':
            # assuming that it is SARS_COV2
            smaltalign_files = run_exe(dataset, 'smaltalign_indel')
            upload_analysis_files_ls = []
            #upload_analysis_files_grandpa_ls = []
            for filename, v in smaltalign_files.items():
                fh = open(filename, 'wb')
                if (filename == 'coverage.pdf'):
                    pdfWriter = PyPDF2.PdfFileWriter()
                    for pageNum in range(v.numPages):
                        pdfWriter.addPage(v.getPage(pageNum))
                    pdfWriter.write(fh)
                else:
                    fh.write(v)
                fh.close()
    
                # add molis number into filename
                root, ext = os.path.splitext(filename)
                if (filename.startswith('coverage') or filename.startswith('reference')):
                    upload_name  = '%s_%s%s' % (sample_name, root, ext)
                else:
                    upload_name  = filename
                    
                os.rename(filename, upload_name)
                upload_analysis_files_ls.append(upload_name)
                #sample.add_attachment(upload_name)
                if ('coverage' in upload_name or '15_WTS' in upload_name):
                    #grandpa.add_attachment(upload_name)
                    #grandpa.save()
                    upload_analysis_files_grandpa_ls.append(upload_name)
                files_to_delete.append(upload_name)
                
            ds_new = o.new_dataset(
                #experiment = '/IMV/RESISTANCE/RESISTANCE_TESTS',
                sample = sample,
                type = 'DATAMOVER_SAMPLE_CREATOR',
                files = upload_analysis_files_ls,
                )
            ds_new.save()
        
            sample.props.analysed = True
            sample.save()    

            if upload_analysis_files_grandpa_ls:
                ds_new_grandpa = o.new_dataset(
                    #experiment = '/IMV/RESISTANCE/RESISTANCE_TESTS',
                    sample = smalt_grandpa,
                    type = 'DATAMOVER_SAMPLE_CREATOR',
                    files = upload_analysis_files_grandpa_ls,
                    )
                ds_new_grandpa.save()
         
            for filename in set(files_to_delete):
                try:
                    os.remove(filename)
                except FileNotFoundError:
                    continue


LOG_FILENAME = 'pybis_script.log'
logging.basicConfig(
    filename=LOG_FILENAME, level=logging.INFO,
    format='%(levelname)s %(asctime)s: %(funcName)s() %(lineno)d: \t%(message)s',
    datefmt='%Y/%m/%d %H:%M:%S')


logger = logging.getLogger()
tqdm_out = TqdmToLogger(logger, level=logging.INFO)

# Add the log message handler to the logger
handler = logging.handlers.RotatingFileHandler(LOG_FILENAME, maxBytes=1E7, backupCount=5)
logger.addHandler(handler)

# open the session first
o = Openbis('https://openbis.virology.uzh.ch/openbis/', verify_certificates=True)
if not o.is_session_active():
    o = Openbis('https://openbis.virology.uzh.ch/openbis/', verify_certificates=False)
    config = configparser.ConfigParser()
    config.read(os.path.expanduser('~/.pybis/cred.ini'))
    username = config['credentials']['username']
    password = config['credentials']['password']
    o.login(username, password, save_token=True)


logging.info('-----------Mapping session starting------------')

for pro in ['antibodies', 'resistance', 'metagenomics', 'plasmids', 'other', 'retroseq', 'consensus']:
    general_mapping(pro)
logging.info('-----------Mapping session finished------------')
logging.info('* * * * * * * * * * * * * * * * * * * * * * * *')
#time.sleep(300)

logging.info('-----------MinVar Analysis session starting-----------')

# Fetch all resistance samples that are mapped
res_test_mapped = o.get_experiment('/IMV/RESISTANCE/RESISTANCE_TESTS').get_samples(mapped=True)
rtm = set(res_test_mapped.df['identifier'])
# All resistance samples that have already been analyzed
try:
    res_test_analysed = o.get_experiment('/IMV/RESISTANCE/RESISTANCE_TESTS').get_samples(mapped=True, analysed=True)
    rta = set(res_test_analysed.df['identifier'])
except ValueError:
    rta = set()
# res_test_samples = [o.get_sample('/IMV/170803_M02081_0226_000000000-BCJY4-1_RESISTANCE')]
logging.info('Found %d mapped samples', len(rtm))
logging.info('Found %d analysed samples', len(rta))
# samples that need to be analyzed, but this script will only do a maximum number of analysis each time it's called
samples_to_analyse = list(rtm - rta)[:analyses_per_run]
logging.info('Analysis will proceed on %d samples', len(samples_to_analyse))

files_to_delete = []  # store files that will be deleted at the end
run_minvar(o, samples_to_analyse, tqdm_out, files_to_delete)
logging.info('-----------MinVar Analysis session finished-----------')

#time.sleep(300)
logging.info('-----------RETROSEQ Analysis session starting-----------')
# Fetch all retroseq samples that are mapped
res_test_mapped = o.get_experiment('/IMV/RETROSEQ/RESISTANCE_TESTS').get_samples(mapped=True)
rtm = set(res_test_mapped.df['identifier'])
# All resistance samples that have already been analyzed
try:
    res_test_analysed = o.get_experiment('/IMV/RETROSEQ/RESISTANCE_TESTS').get_samples(mapped=True, analysed=True)
    rta = set(res_test_analysed.df['identifier'])
except ValueError:
    rta = set()

logging.info('Found %d mapped samples', len(rtm))
logging.info('Found %d analysed samples', len(rta))

samples_to_analyse = list(rtm - rta)[:analyses_per_run]
logging.info('RETROSEQ Analysis will proceed on %d samples', len(samples_to_analyse))

files_to_delete = []  # store files that will be deleted at the end
run_minvar(o, samples_to_analyse, tqdm_out, files_to_delete)
logging.info('-----------RETROSEQ Analysis session finished-----------')

#time.sleep(300)
logging.info('-----------CONSENSUS Analysis session starting-----------')
# Fetch all consensus samples that are mapped
res_test_mapped = o.get_experiment('/IMV/CONSENSUS/CONSENSUS_INFO').get_samples(mapped=True)
rtm = set(res_test_mapped.df['identifier'])
# All consensus samples that have already been analyzed
try:
    res_test_analysed = o.get_experiment('/IMV/CONSENSUS/CONSENSUS_INFO').get_samples(mapped=True, analysed=True)
    rta = set(res_test_analysed.df['identifier'])
except ValueError:
    rta = set()

logging.info('Found %d mapped samples', len(rtm))
logging.info('Found %d analysed samples', len(rta))

samples_to_analyse = list(rtm - rta)[:analyses_per_run]
logging.info('CONSENSUS Analysis will proceed on %d samples', len(samples_to_analyse))

files_to_delete = []  # store files that will be deleted at the end
run_smaltalign(o, samples_to_analyse, tqdm_out, files_to_delete)
logging.info('-----------CONSENSUS Analysis session finished-----------')

o.logout()
