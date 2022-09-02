#!/bin/env bash
############################################################################
#
# File: fetch_uniprot_human_xref.sh
#
# Subject: fetch_uniprot_xref.sh - Fetch uniprot cross-reference for human
#
# Author: Arthur Eschenlauer (https://orcid.org/0000-0002-2882-0508)
#
# Date: 26 May 2022
#
# URL: [if available, e.g. https://gist.github.com/eschen42/a223f6aeee93797a720c559a666ec069]
#
############################################################################
#
#  This file:
#  - downloads the uniprot knowledgebase for Homo sapiens (organism id 9606)
#    from https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/
#  - imports the data into a SQLite database
#
############################################################################
#
# Requires:
# - bash
# - curl
# - sqlite3 (command line shell for SQLite: https://sqlite.org/cli.html)
# - gzip
# - icon
# - bzip2
#
# For example, these requirements may be met using conda, e.g.:
#   conda create -n fetch_uniprot_xref -c conda-forge bash curl sqlite \
#     bzip2 gzip icon
#   conda activate fetch_uniprot_xref
#
############################################################################
#
# This file is in the public domain. Art Eschenlauer has waived all
# copyright and related or neighboring rights to:
#   fetch_uniprot_human_xref.sh - Fetch uniprot cross-reference for human
# For details, see:
#   https://creativecommons.org/publicdomain/zero/1.0/
#
# If you require a specific license and public domain status is not suffi-
# cient for your needs, please apply the MIT license (below), bearing
# in mind that the copyright "claim" is solely to meet your requirements
# and does not imply any restriction on use or copying by the author:
#
#   Copyright (c) 2022, Arthur Eschenlauer
#
#   Permission is hereby granted, free of charge, to any person obtaining
#   a copy of this software and associated documentation files (the
#   "Software"), to deal in the Software without restriction, including
#   without limitation the rights to use, copy, modify, merge, publish,
#   distribute, sublicense, and/or sell copies of the Software, and to
#   permit persons to whom the Software is furnished to do so, subject
#   to the following conditions:
#
#   The above copyright notice and this permission notice shall be
#   included in all copies or substantial portions of the Software.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
#   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
#   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
#   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
#   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#   SOFTWARE.
#
############################################################################

set -e 

SPECIES=${SPECIES:-HUMAN_9606}
UNIPROT_PROTEOME=${UNIPROT_PROTEOME:-UP000005640_9606}
SQ=${SQ:-sqlite3 -tabs -header}
SQR=${SQR:-'sqlite3 -tabs -header -readonly'}
BZ=${BZ:-bzip2 -9 --force}

source urls_to_fetch.sh

UNIPROT_XREF_SQLITE=${UNIPROT_XREF_SQLITE:-${SPECIES}_uniprot_xref.sqlite}
DB=${UNIPROT_XREF_SQLITE}
UNIPROT_PROTEOME_SQLITE=${UNIPROT_PROTEOME_SQLITE:-${UNIPROT_PROTEOME}.sqlite}
ENSEMBL_UNIPROT_TABLE=${ENSEMBL_UNIPROT_TABLE:-ensembl_pro_uniprot_lut}
ENSEMBL_UNIPROT_LUT=${ENSEMBL_UNIPROT_LUT:-${SPECIES}_${ENSEMBL_UNIPROT_TABLE}}
UNIPROT_ATTR_LUT=${UNIPROT_ATTR_LUT:-${SPECIES}_uniprot_GN_DB_DE_ID_AC_MOD_lut}
UNIPROT_ATTR_LIST=${UNIPROT_ATTR_LIST:-"\'GN\', \'DB\', \'DE\', \'ID\', \'AC\', \'MOD_RES\', \'PTM\'"}

EC_SQL=${EC_SQL:-enzyme.sql}


DISCARD=${URL_UNIPROT_IDMAPPING_SELECTED:?'
You must set the
  URL_UNIPROT_IDMAPPING_SELECTED
environment variable to the address of the "UniProt idmapping selected" URL, e.g.,
  https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/'"${SPECIES}"'_idmapping_selected.tab.gz
'}

DISCARD=${URL_UNIPROT_IDMAPPING:?'
You must set the
  URL_UNIPROT_IDMAPPING
environment variable to the address of the "UniProt idmapping" URL, e.g.,
  https://ftp.uniprot.org/pub/databases/uniprot/current_release/knowledgebase/idmapping/by_organism/'"${SPECIES}"'_idmapping.dat.gz
'}

if [ ! -e ${SPECIES}_idmapping_selected.tab.gz ]; then
  curl -o ${SPECIES}_idmapping_selected.tab.gz ${URL_UNIPROT_IDMAPPING_SELECTED}
  fi
if [ ! -e ${SPECIES}_idmapping.dat.gz ]; then
  curl -o ${SPECIES}_idmapping.dat.gz ${URL_UNIPROT_IDMAPPING}
  fi


if [ ! -z "${URL_UNIPROT_FASTA}" -a ! -e ${UNIPROT_PROTEOME}.fasta.gz ]; then
  echo "curl -o ${UNIPROT_PROTEOME}.fasta.gz ${URL_UNIPROT_FASTA}"
  curl -o ${UNIPROT_PROTEOME}.fasta.gz ${URL_UNIPROT_FASTA}
  fi
if [ ! -z "${URL_UNIPROT_FASTA_ADDITIONAL}" -a ! -e ${UNIPROT_PROTEOME}_additional.fasta.gz ]; then
  echo "curl -o ${UNIPROT_PROTEOME}_additional.fasta.gz ${URL_UNIPROT_FASTA_ADDITIONAL}"
  curl -o ${UNIPROT_PROTEOME}_additional.fasta.gz ${URL_UNIPROT_FASTA_ADDITIONAL}
  fi


if [ ! -z "${URL_UNIPROT_METADATA}" -a ! -e ${UNIPROT_PROTEOME}.phospho.dat.gz ]; then
  echo "curl -o ${UNIPROT_PROTEOME}.phospho.dat.gz ${URL_UNIPROT_METADATA}"
  curl -o ${UNIPROT_PROTEOME}.phospho.dat.gz ${URL_UNIPROT_METADATA}
  fi
if [ ! -z "${URL_UNIPROT_METADATA_ADDITIONAL}" -a ! -e ${UNIPROT_PROTEOME}_additional.phospho.dat.gz ]; then
  echo "curl -o ${UNIPROT_PROTEOME}_additional.phospho.dat.gz ${URL_UNIPROT_METADATA_ADDITIONAL}"
  curl -o ${UNIPROT_PROTEOME}_additional.phospho.dat.gz ${URL_UNIPROT_METADATA_ADDITIONAL}
  fi

if [ ! -e parse_uniprot_dat ]; then
  icont -u parse_uniprot_dat.icn
elif [ parse_uniprot_dat.icn -nt parse_uniprot_dat ]; then
  icont -u parse_uniprot_dat.icn
  fi

if [ -e ${UNIPROT_PROTEOME}.phospho.dat.gz -a \
     -e ${UNIPROT_PROTEOME}_additional.phospho.dat.gz  -a \
     ! -e ${UNIPROT_PROTEOME}.sql ]
then
  echo "decompressing  ${UNIPROT_PROTEOME}.phospho.dat.gz ${UNIPROT_PROTEOME}_additional.phospho.dat.gz and parsing into SQL statements"
  gzip -c -d ${UNIPROT_PROTEOME}.phospho.dat.gz ${UNIPROT_PROTEOME}_additional.phospho.dat.gz | \
    sed -f uniprot_meta_phospho.sed | \
    ./parse_uniprot_dat -f sql -i - > ${UNIPROT_PROTEOME}.sql
  if [ $SPECIES = "HUMAN_9606" -a ${UNIPROT_PROTEOME}="UP000005640_9606" ]; then
    # fetch a few accessions that are not part of proteome UP000005640_9606 
    if [ ! -e Q15300.dat ]; then
      curl -o Q15300.dat https://www.uniprot.org/uniprot/A9UF07.txt
      fi
    if [ ! -e A9UF07.dat ]; then
      curl -o A9UF07.dat https://www.uniprot.org/uniprot/A9UF07.txt
      fi
    if [ ! -e Q7Z370.dat ]; then
      curl -o Q7Z370.dat https://www.uniprot.org/uniprot/Q7Z370.txt
      fi
    cat Q15300.dat A9UF07.dat Q7Z370.dat | \
      sed -f uniprot_meta_phospho.sed | \
      ./parse_uniprot_dat -f sql -i - -n >> ${UNIPROT_PROTEOME}.sql
    fi
  fi

# set path to enzyme.sql if necessary

# see above for: EC_SQL=${EC_SQL:-enzyme.sql}
EC_ARGS='-f sql'
if [ ! -z "${SPECIES_NAME}" ]; then
  EC_SQL=${SPECIES_NAME}_${EC_SQL}
  EC_ARGS="-s ${SPECIES_NAME}"
  fi

# build the uniprot database
if [ ! -e ${UNIPROT_PROTEOME_SQLITE} ]; then
  if [ -e ${UNIPROT_PROTEOME}.sql ]; then
    echo "building SQLite database ${UNIPROT_PROTEOME_SQLITE} from SQL statements"
    ${SQ} ${UNIPROT_PROTEOME_SQLITE} -init ${UNIPROT_PROTEOME}.sql '.quit'
    echo "imported uniprot data into SQLite database ${UNIPROT_PROTEOME_SQLITE}"
    # be sure that extant ENZYME.sql file will be loaded
    if [ -e ${EC_SQL} ]; then
      touch ${EC_SQL}
      fi
    fi
  fi

# build or update the ENZYME parsing program if needed;
#   `make` would be a better option \_("/)_/

if [ ! -e parse_ec_enzyme_dat ]; then
  icont -u parse_ec_enzyme_dat.icn
elif [ parse_ec_enzyme_dat.icn -nt parse_ec_enzyme_dat ]; then
  icont -u parse_ec_enzyme_dat.icn
  fi

# fetch the ENZYME (EC) database; again, make would be nice...

if [ ! -z "${URL_EC_DAT}" -a ! -e enzyme.dat ]; then
  echo "curl -o enzyme.dat ${URL_EC_DAT}"
  curl -o enzyme.dat ${URL_EC_DAT}
  fi

if [ ! -e enzyme.dat ]; then
  echo enzyme.dat does not exist
fi

if [ ! -e enzyme.dat ]; then
  echo "warning: enzyme.dat was not fetched"
elif [ ! -e ${EC_SQL} ]; then
  EC_SQL=${SPECIES_NAME}_enzyme.sql
  echo "parsing enzyme database to  ${EC_SQL}"
  cat enzyme.dat | ./parse_ec_enzyme_dat  ${EC_ARGS} -i - > ${EC_SQL}
elif [ enzyme.dat -nt ${EC_SQL} ]; then
  EC_SQL=${SPECIES_NAME}_enzyme.sql
  echo "parsing enzyme database to  ${EC_SQL}"
  cat enzyme.dat | ./parse_ec_enzyme_dat  ${EC_ARGS} -i - > ${EC_SQL}
  fi

if [ -e ${EC_SQL} -a ${EC_SQL} -nt ${UNIPROT_PROTEOME_SQLITE} ]; then
  echo "importing ENZYME (EC) data into SQLite database ${UNIPROT_PROTEOME_SQLITE} from SQL statements"
  ${SQ} ${UNIPROT_PROTEOME_SQLITE} -init ${EC_SQL} '.quit'
  echo "imported ENZYME (EC) data into SQLite database ${UNIPROT_PROTEOME_SQLITE}"
  touch ${UNIPROT_PROTEOME_SQLITE}
elif [ ! -e ${EC_SQL} ]; then
  echo "file  ${EC_SQL} not found"
  fi

if [ ! -e ${DB} ]; then
  echo "creating ${DB}"
  (
    cat << end_SQL
      DROP TABLE IF EXISTS uniprot_multi_idmap;

      CREATE TABLE uniprot_multi_idmap (
        UniprotAccession TEXT PRIMARY KEY,
        UniProtKB_ID TEXT,
        GeneID TEXT,
        RefSeq TEXT,
        GI TEXT,
        PDB TEXT,
        GeneOntology TEXT,
        UniRef100 TEXT,
        UniRef90 TEXT,
        UniRef50 TEXT,
        UniParc TEXT,
        PIR TEXT,
        NCBI_TaxID TEXT,
        MIM TEXT,
        not_used TEXT,
        PubMedID TEXT,
        EMBL TEXT,
        EMBL_CDS TEXT,
        Ensembl TEXT,
        Ensembl_TRS TEXT,
        Ensembl_PRO TEXT,
        PubMed_additional TEXT
        );

      DROP TABLE IF EXISTS uniprot_simple_idmap;

      CREATE TABLE uniprot_simple_idmap (
        UniprotAccession TEXT,
        RefClass TEXT,
        Reference TEXT
        );

      CREATE INDEX uniprot_simple_idmap_ix
        ON uniprot_simple_idmap(
             UniprotAccession,
             RefClass
             );
end_SQL
    ) | ${SQ} ${DB}
  echo "importing ${SPECIES}_idmapping_selected.tab.gz"
  gzip -c -d ${SPECIES}_idmapping_selected.tab.gz | ${SQ} ${DB} '.import /dev/stdin uniprot_multi_map'
  ${SQ} ${DB} '
    INSERT INTO uniprot_multi_idmap
      SELECT * FROM uniprot_multi_map;
    DROP TABLE uniprot_multi_map;
    '
  echo "importing ${SPECIES}_idmapping.dat.gz"
  gzip -c -d ${SPECIES}_idmapping.dat.gz          | ${SQ} ${DB} '.import /dev/stdin uniprot_simple_map'
  ${SQ} ${DB} '
    INSERT INTO uniprot_simple_idmap
      SELECT * FROM uniprot_simple_map;
    DROP TABLE uniprot_simple_map;
    '
  echo "creating table ${ENSEMBL_UNIPROT_TABLE}"

  ${SQ} ${DB} "
    DROP TABLE IF EXISTS ${ENSEMBL_UNIPROT_TABLE}
    ;
    CREATE TABLE ${ENSEMBL_UNIPROT_TABLE} (
      ensembl_acc TEXT,
      uniprot_acc TEXT
    )
    ;
    CREATE INDEX ${ENSEMBL_UNIPROT_TABLE}_ix
        ON ${ENSEMBL_UNIPROT_TABLE}(ensembl_acc)
    ;
    INSERT INTO ${ENSEMBL_UNIPROT_TABLE}
      SELECT DISTINCT 
        CASE
          WHEN instr(Reference,'.') > 0
            THEN substr(Reference,1,instr(Reference,'.') - 1)
            ELSE Reference
        END AS ensembl_acc,
        s.uniprot_acc
      FROM
        (
          SELECT Reference, UniprotAccession AS uniprot_acc
          FROM uniprot_simple_idmap
          WHERE Reference LIKE 'ENSP%'
        ) s,
        uniprot_multi_idmap  m
      WHERE s.uniprot_acc = m.UniprotAccession
      ORDER BY ensembl_acc
      ;
    "
  
  echo "'vacuuming' ${DB}"
  ${SQ} ${DB} 'VACUUM;'
  fi

${SQ} ${DB} "${CITTBL_CREATE}"
${SQ} ${DB} "
  ${CITTBL_INSERT} \
  ('uniprot_multi_idmap',  '${LICENSE_URL_UNIPROT}', '${LICENSE_ATTRIBUTION_UNIPROT}', '${LICENSE_TERMS_UNIPROT}', '"${CITTBL_DERIVED_NO}"'),
  ('uniprot_simple_idmap', '${LICENSE_URL_UNIPROT}', '${LICENSE_ATTRIBUTION_UNIPROT}', '${LICENSE_TERMS_UNIPROT}', '"${CITTBL_DERIVED_NO}"'),
  ('${ENSEMBL_UNIPROT_TABLE}',  '${LICENSE_URL_UNIPROT}', '${LICENSE_ATTRIBUTION_UNIPROT}', '${LICENSE_TERMS_UNIPROT}', '"${CITTBL_DERIVED_YES}"')
  ;"

echo "exporting ${ENSEMBL_UNIPROT_LUT}.sql.bz2"

${SQR} ${DB} ".dump ${ENSEMBL_UNIPROT_TABLE}" | ${BZ} -c > ${ENSEMBL_UNIPROT_LUT}.sql.bz2

echo "exporting ${UNIPROT_ATTR_LUT}.tabular"
${SQR} ${UNIPROT_PROTEOME_SQLITE} 'select * from upatr_uplst_v where attribute in ('"${UNIPROT_ATTR_LIST}"')' > ${UNIPROT_ATTR_LUT}.tabular

${BZ} --keep ${UNIPROT_ATTR_LUT}.tabular
