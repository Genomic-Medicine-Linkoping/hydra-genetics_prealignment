# vim: syntax=python tabstop=4 expandtab
# coding: utf-8

__author__ = "Patrik Smeds"
__copyright__ = "Copyright 2021, Patrik Smeds"
__email__ = "patrik.smeds@scilifelab.uu.se"
__license__ = "GPL-3"


import pandas
import yaml
from snakemake.utils import validate
from snakemake.utils import min_version

from hydra_genetics.utils.resources import load_resources
from hydra_genetics.utils.samples import *
from hydra_genetics.utils.units import *

min_version("6.8.0")

### Set and validate config file


configfile: "config.yaml"
    
    
validate(config, schema="../schemas/config.schema.yaml")
config = load_resources(config, config["resources"])
validate(config, schema="../schemas/resources.schema.yaml")


### Read and validate samples file

samples = pandas.read_table(config["samples"], dtype=str).set_index("sample", drop=False)
validate(samples, schema="../schemas/samples.schema.yaml")

### Read and validate units file

units = pandas.read_table(config["units"], dtype=str).set_index(["sample", "type", "run", "lane"], drop=False)
validate(units, schema="../schemas/units.schema.yaml")


### Set wildcard constraints
wildcard_constraints:
    sample="|".join(get_samples(samples)),
    unit="N|T|R",
    read="fastq[1|2]",


if config.get("trimmer_software", None) == "fastp":
    merged_input = lambda wildcards: expand(
        "prealignment/fastp_pe/{{sample}}_{run_lane}_{{type}}_{{read}}.fastq.gz",
        run_lane=["{}_{}".format(unit.run, unit.lane) for unit in get_units(units, wildcards, wildcards.type)],
    )
else:
    merged_input = lambda wildcards: get_fastq_files(units, wildcards)


def compile_output_list(wildcards: snakemake.io.Wildcards):
    return [
        "prealignment/merged/{}_{}_{}.fastq.gz".format(sample, t, read)
        for sample in get_samples(samples)
        for read in ["fastq1", "fastq2"]
        for t in get_unit_types(units, sample)
    ]
