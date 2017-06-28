#!/usr/bin/env python
import sys
import getpass
from pybis import Openbis


def general_mapping(project = None):
    '''Create parent-child relationships in a project, like
    MISEQ_RUN -> MISEQ_SAMPLE (where -> means "parent of")
    For resistance tests, the full relationship is
    MISEQ_RUN -> MISEQ_SAMPLE -> RESISTANCE_TEST
    '''
    print('Mapping called for project', project)
    p_code = project.upper()
    valid_projects = ['RESISTANCE', 'METAGENOMICS', 'PLASMIDS', 'OTHER', 'ANTIBODIES']
    if p_code not in valid_projects:
        sys.exit('Choose a valid project: %s' % ','.join(valid_projects))

    proj = [p for p in o.get_projects(space='IMV') if p.code == p_code][0]
    print('We are here in project', proj.code)

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
        miseq_run_id = '-'.join(miseq_sample_id.split('-')[:-1]) + '_%s' % p_code
        assert miseq_run_id in samples_dict['MISEQ_RUNS'], miseq_run_id

        # extract all samples
        # I would like here a method to check that only one sample is returned
        # as we are using identifiers that should be unique
        run_sample =  proj.get_samples(
            space='IMV',
            code = miseq_run_id
        )[0]
        miseq_sample = proj.get_samples(
            space='IMV',
            code = miseq_sample_id
        )[0]

        # create the run -> sample link
        if 'mapped' not in miseq_sample.tags:
            miseq_sample.add_parents('/IMV/%s' % miseq_run_id)
            miseq_sample.add_tags('mapped')
            miseq_sample.save()
        else:
            print('sample %s already mapped' % miseq_sample_id)

        # for resistance tests there is another relation to create
        if p_code == 'RESISTANCE':
            resi_sample_id = '%s_RESISTANCE' % miseq_sample_id
            resi_sample = proj.get_samples(
                space='IMV',
                code = resi_sample_id
            )[0]
            if 'mapped' not in resi_sample.tags:
                resi_sample.add_parents('/IMV/%s' % miseq_sample_id)
                resi_sample.add_tags('mapped')
                resi_sample.save()
            else:
                print('sample %s already mapped' % resi_sample_id)

o = Openbis('https://s3itdata.uzh.ch', verify_certificates=True)
if not o.is_session_active():
    o = Openbis('https://s3itdata.uzh.ch', verify_certificates=False)
    password = getpass.getpass()
    o.login('ozagor', password, save_token=True)  # saves the session token in ~/.pybis/example.com.token

general_mapping('metagenomics')
general_mapping('resistance')
