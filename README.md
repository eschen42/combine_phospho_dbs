# `combine_phospho_dbs` - Aggregate kinase and substrate data

## Purpose

The [**MaxQuant Phosphopeptide Preprocessing**](https://toolshed.g2.bx.psu.edu/repository/display_tool?repository_id=7b866682d0b1d44c&tool_config=%2Fsrv%2Ftoolshed-repos%2Fmain%2F006%2Frepo_6289%2Fmqppep_preproc.xml&changeset_revision=bae3a23461c9&render_repository_actions_for=tool_shed) tool requires the following four files as static inputs:

  - `networkin_cutoff_2.tabular`
  - `pSTY_motifs.tabular`
  - `psp_kinase_substrate_dataset.tabular`
  - `psp_regulatory_sites.tabular`

The scripts in the `combine_phospho_dbs` repository fetch and aggregate
data from:

- NetworKIN
- Phospho.ELM
- PhosphoSitesPlus
- UniProt
- ENZYME

and produce these four tabular files plus an aggregation of these data

```
  combined_phospho_dbs.sqlite
```

By default, human data are retrieved.  See [section "Default settings" below](#default-settings) for alternatives.

## TL;DR

1. Read and conform with [the "Licenses for data fetched by these scripts" section](#licenses-for-data-fetched-by-these-scripts).
2. Run the following commands:

```bash
  conda create -n combophospho -c conda-forge bash bzip2 curl icon make sed sqlite xz
  conda activate combophospho
  make
```
3. Take the following files:

  - `networkin_cutoff_2.tabular`
  - `pSTY_motifs.tabular`
  - `psp_kinase_substrate_dataset.tabular`
  - `psp_regulatory_sites.tabular`

## Results

In addition to the four tabular files, several [SQLite](https://sqlite.org) databases are produced by these scripts.

The aggregated data are written to the
```
  combined_phospho_dbs.sqlite
```
file (about 80 megabytes).

Reference citations are copied from `urls_to_fetch.sh` to the
`citation` table in `combined_phospho_dbs.sqlite`.

At the conclusion of the process, the reference and license information is emitted for the various data sources.

## Licenses for data fetched by these scripts

Data from the first three data sources listed above may be used only upon
acceptance of "academic", non-commercial use licenses.  Please see
```
  urls_to_fetch.example
```
for the licensing terms to which users must adhere.

The scripts depend upon the file
```
  urls_to_fetch.sh
```
which may be obtained by copying or linking `urls_to_fetch.example`;
doing so constitutes acceptance of the license terms.

Note that `urls_to_fetch.sh` performs most of the configuration
for the scripts rather than merely listing URLs

It should not be difficult to rewrite the
```
  fetch_all.sh
```
to omit collection of data not authorized for non-commercial use.

## Default settings

Default settings are set in `fetch_all.sh` using environment variables,
but you can override these settings by setting environment
variables before invoking `fetch_all.sh`.  The defaults are:

| Environment Variable       | Default Value                 |
| :------------------------- | :---------------------------- |
| `TAXID`                    | `9606`                        |
| `SPECIES`                  | `HUMAN_9606`                  |
| `SPECIES_NAME`             | `HUMAN`                       |
| `UNIPROT_PROTEOME`         | `UP000005640_9606`            |
| `UNIPROT_PROTEOME_SQLITE`  | `UP000005640_9606.sqlite`     |
| `PHOSPHO_AGGREGATE_SQLITE` | `combined_phospho_dbs.sqlite` |


## How to use these scripts

### Platform requirements

The scripts vary in their requirements, the union of which are:

- `amd64` (i.e., 64-bit Intel-/AMD-based) Linux
- bash
- bzip2
- curl
- icon 
- make
- sed
- sqlite
- xz

#### Conda meets requirements with minimal effort

The simplest way to satisfy these requirements is to create
a ["Conda"](https://docs.conda.io/en/latest/) environment 
with packages from the conda-forge channel, e.g.:

```bash
  conda create -n combophospho -c conda-forge bash bzip2 curl icon make sed sqlite xz
  conda activate combophospho
```

#### Docker gives greater isolation

Docker can be used to provide greater isolation for reproducible testing.

```bash
# ------------------------------------------------------------------------------
# Make a script to produce a working copy of the files from the repository
#   (1) Create a home for a script to do the copying
if [ ! -d nb ]; then
  mkdir nb
  fi
#   (2) Make a script from the files in the same directory as this README.md;
#       sed is a Swiss Army knife ...
ls -F | grep -v '[/]$' | sed -e \
  's/^/cp /; s/$/ \/root\/src\//; 1 {h; s/.*/mkdir -p \/root\/\src/}; p; d' \
  > nb/root_test.sh

# ------------------------------------------------------------------------------
# Now enter the Docker container, linking this directory as /src
docker run -ti --rm -v `readlink -f .`:/src docker.io/condaforge/miniforge3 bash

# now you are in the Docker container, running as `root`

# Create a conda environment that meets the platform requirements
conda create -n combophospho -c conda-forge bash bzip2 curl icon make sed sqlite xz

# Activate the requirement
conda activate combophospho

# Run the script to produce a working copy of the files from the repository
#   (1) Copy the files that you will run to /root/src
cd /src
bash nb/root_test.sh
#   (2) Move to the working copy
cd /root/src

# Build the artifacts; at a minimum, you will want to keep the resulting
#   combined_phospho_dbs.sqlite
bash fetch_all.sh

# If all has gone well, you may copy the desired artifacts to /src ...
cp combined_phospho_dbs.sqlite /src
# ... but don't forget to change the userid to match the other files there, e.g.:
RSUID=$(ls -na /src | grep ' [.]$' | head -n 1 | sed -e 's/[ ][ ]*/:/g' | cut -f 3 -d ':')
RSGID=$(ls -na /src | grep ' [.]$' | head -n 1 | sed -e 's/[ ][ ]*/:/g' | cut -f 4 -d ':')
cd /src
chown ${RSUID}:${RSGID} combined_phospho_dbs.sqlite
# ------------------------------------------------------------------------------
```

### Procedure

Only if you accept the licensing terms, copy or link
`urls_to_Fetch.example` to `urls_to_Fetch.sh`, e.g.,
```bash
  ln -s `urls_to_Fetch.example` `urls_to_Fetch.sh`
```
and invoke `fetch_all.sh`
```bash
  bash fetch_all.sh
```

## Revising or replacing the `elm_networkin_psp_uniprot_lut` table

Data in the `elm_networkin_psp_uniprot_lut` table
in the `combined_phospho_dbs.sqlite` file
are imported from the file
```
  elm_networkin_psp_uniprot_lut.tabular
```

The `elm_networkin_psp_uniprot_lut` table maps the various kinase names found
in PSP, Phospho.ELM, and NetworKIN to UniProt IDs
(i.e., entry names, not accessions).
Unfortunately, this file is only available for human data at this time.

Should this file need to be reconstructed, the database named as specified
by the `UNIPROT_PROTEOME_SQLITE` environment variable (which is set to its
default value in `fetch_all.sh` may be helpful for discovering assignments
if many new assignments are required (documentation of how to do so may
eventually appear here).

## Logical design diagram

The logical design for the database file specified by `UNIPROT_PROTEOME_SQLITE`
(i.e., the database that has entries parsed from UniProt and ENZYME)
may be viewed (or updated) by opening the `ParsedUniProtKB.dia` file in
[the Dia drawing program](https://en.wikipedia.org/wiki/Dia_(software)).
Here is a (hopefully up-to-date) ![PDF export](ParsedUniProtKB.pdf?raw=true).
