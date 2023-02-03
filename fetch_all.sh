#!/bin/env bash
############################################################################
#
# File: fetch_all.sh
#
# Subject: fetch_all.sh - Fetch kinase and substrate data
#
# Author: Arthur Eschenlauer (https://orcid.org/0000-0002-2882-0508)
#
# Date: 15 June 2022
#
# URL: [if available, e.g. https://gist.github.com/eschen42/a223f6aeee93797a720c559a666ec069]
#
############################################################################
#
#  This file:
#  - invokes other scripts to fetch data as specified in ursl_to_fetch.sh
#  - compiles the data into a small-ish SQLite database.
#
############################################################################
#
# Requires:
# - bash
# - curl
# - bzip2
# - sed
# - sqlite3 (command line shell for SQLite: https://sqlite.org/cli.html)
#
# Client files also require:
# - icon
# For example, these requirements may be met using conda, e.g.:
#   mamba create -n fetch_all bash curl sed sqlite bzip2 icon
#   mamba activate fetch_all
#
############################################################################
#
# This file is in the public domain. Art Eschenlauer has waived all
# copyright and related or neighboring rights to:
#   fetch_all.sh - Fetch kinase and substrate data
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

TAXID=${TAXID:-'9606'}
SPECIES_NAME=${SPECIES_NAME:-'HUMAN'}
SPECIES=${SPECIES:-"${SPECIES_NAME}_${TAXID}"}
UNIPROT_PROTEOME=${UNIPROT_PROTEOME:-'UP000005640_9606'}

SQ=${SQ:-'sqlite3 -tabs -header'}
SQR=${SQR:-'sqlite3 -tabs -header -readonly'}

BZ=${BZ:-bzip2 -9 --force}
BZCAT=${BZCAT:-bzip2 -dc}

# The following exports may be overridden before calling this script;
#   when not exported here or overridden, they will be set by urls_to_fetch.sh.
export                     PHOSPHOELM_SQLITE=${PHOSPHOELM_SQLITE:-phosphoelm_kin_bind.sqlite}
export                      NETWORKIN_SQLITE=${NETWORKIN_SQLITE:-networkin.sqlite}
export                        PHOSIDA_SQLITE=${PHOSIDA_SQLITE:-phosida_motifs.sqlite}
export                   UNIPROT_XREF_SQLITE=${UNIPROT_XREF_SQLITE:-${SPECIES}_uniprot_xref.sqlite}
export               UNIPROT_PROTEOME_SQLITE=${UNIPROT_PROTEOME_SQLITE:-${UNIPROT_PROTEOME}.sqlite}
export              PHOSPHO_AGGREGATE_SQLITE=${PHOSPHO_AGGREGATE_SQLITE:-combined_phospho_dbs.sqlite}
export PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT=${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT:-elm_networkin_psp_uniprot_lut}
export                 ENSEMBL_UNIPROT_TABLE=${ENSEMBL_UNIPROT_TABLE:-ensembl_pro_uniprot_lut}
export                   ENSEMBL_UNIPROT_LUT=${ENSEMBL_UNIPROT_LUT:-${SPECIES}_${ENSEMBL_UNIPROT_TABLE}}
export                    UNIPROT_ATTR_TABLE=${UNIPROT_ATTR_TABLE:-uniprot_attrib_lut}
export                      UNIPROT_ATTR_LUT=${UNIPROT_ATTR_LUT:-${SPECIES}_uniprot_GN_DB_DE_ID_AC_MOD_lut}
export                     UNIPROT_ATTR_LIST=${UNIPROT_ATTR_LIST:-"'GN', 'DB', 'DE', 'ID', 'AC', 'MOD_RES', 'PTM'"}
export               KINASE_NAME_UNIPROT_LUT=${KINASE_NAME_UNIPROT_LUT:-kinase_name_uniprot_lut}
export        KINASE_UNIPROT_DESCRIPTION_LUT=${KINASE_UNIPROT_DESCRIPTION_LUT:-kinase_uniprot_description_lut}

source urls_to_fetch.sh

PHOSPHO_AGGREGATE_INCLUDE_SEQUENCES=${PHOSPHO_AGGREGATE_INCLUDE_SEQUENCES:-1}

if [ -e ${PHOSPHO_AGGREGATE_SQLITE} ]; then
  rm ${PHOSPHO_AGGREGATE_SQLITE}
  fi

echo ''
echo fetch PhosphoSitePlus datasets
bash fetch_phosphositesplus.sh

echo ''
echo fetch phospho.ELM
bash fetch_elm.sh
echo '  created SQLite tables:'
${SQ} ${PHOSPHOELM_SQLITE} '.tables' | sed -e 's/^/    /';

# fetch_amanchy relies upon phosphoelm_kin_bind_detail.tabular produced by fetch_elm
echo ''
echo fetch Amanchy patterns
bash fetch_amanchy.sh

echo ''
echo fetch NetworKIN
bash fetch_networkin.sh
echo '  created SQLite tables:'
${SQ} ${NETWORKIN_SQLITE} '.tables' | sed -e 's/^/    /';

echo ''
echo fetch Phosida
bash fetch_phosida.sh
echo '  created SQLite tables:'
${SQ} ${PHOSIDA_SQLITE} '.tables' | sed -e 's/^/    /';

echo ''
echo combining Phosida and NetworKIN to pSTY_motifs.tabular
cat pST_amanchy.tabular > pSTY_motifs.tabular
sed -e '1 d' pY_amanchy.tabular >> pSTY_motifs.tabular
sed -e '1 d' pSTY_phosida.tabular >> pSTY_motifs.tabular

echo ''
echo fetch UniProt Knowledgebase idmapping
bash fetch_uniprot_human_xref.sh

echo ''
echo "fetches completed; constructing ${PHOSPHO_AGGREGATE_SQLITE}"

echo ''
( set -e;
  ${SQR} ${PHOSPHOELM_SQLITE} \
    '.dump domain kinase kin_bind_detail phospho_elm_classes';
  echo 'ALTER TABLE domain          RENAME TO phospho_elm_domain;';
  echo 'ALTER TABLE kinase          RENAME TO phospho_elm_kinase;';
  echo 'ALTER TABLE kin_bind_detail RENAME TO phospho_elm_kin_bind_detail;';
  ${SQR} ${PHOSIDA_SQLITE}   '.dump phosida';
  ${SQR} ${NETWORKIN_SQLITE} '.dump networkin_kinase_netphorest_lut';
  ${SQR} ${NETWORKIN_SQLITE} '.dump networkin_cutoff_2';
  echo '.import pSTY_motifs.tabular raw_psty_motifs';

  echo ".import ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}.tabular ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}";
  ) | ${SQ} ${PHOSPHO_AGGREGATE_SQLITE}

${BZCAT} ${ENSEMBL_UNIPROT_LUT}.sql.bz2 | ${SQ} ${PHOSPHO_AGGREGATE_SQLITE};

echo ".import ${UNIPROT_ATTR_LUT}.tabular ${UNIPROT_ATTR_TABLE}" | \
  ${SQ} ${PHOSPHO_AGGREGATE_SQLITE}

set -e;

cat > up_descr.txt << .
CREATE TEMP TABLE up_descr(uniprot_id,descriptions)
;
INSERT INTO up_descr
  SELECT uniprotid, group_concat(value, ';')
  FROM ${UNIPROT_ATTR_TABLE}
  WHERE value NOT LIKE 'EC %' AND attribute = 'DE'
  GROUP BY uniprotid
;
CREATE INDEX up_descr_uniprotid_ix
  ON up_descr(uniprot_id)
;
UPDATE ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}
  SET descriptions = (
    SELECT up_descr.descriptions
    FROM up_descr
    WHERE up_descr.descriptions IS NOT NULL
    AND length(up_descr.descriptions) > 0
    AND up_descr.uniprot_id = ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}.uniprotid
  )
  WHERE uniprotid in (SELECT uniprot_id FROM up_descr)
;

DROP TABLE IF EXISTS ${KINASE_UNIPROT_DESCRIPTION_LUT};
CREATE TABLE ${KINASE_UNIPROT_DESCRIPTION_LUT}(
  UniProtID TEXT PRIMARY KEY,
  Descriptions TEXT
);
CREATE INDEX ${KINASE_UNIPROT_DESCRIPTION_LUT}_uniprotid_ix
  ON ${KINASE_UNIPROT_DESCRIPTION_LUT}(UniProtID)
;
INSERT INTO
  ${KINASE_UNIPROT_DESCRIPTION_LUT}(UniProtID, Descriptions)
SELECT DISTINCT UniProtID, Descriptions
  FROM ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}
;


DROP TABLE IF EXISTS ${KINASE_NAME_UNIPROT_LUT};
CREATE TABLE ${KINASE_NAME_UNIPROT_LUT}(
  kinase TEXT,
  UniProtID TEXT,
  FOREIGN KEY (UniProtID)
    REFERENCES ${KINASE_UNIPROT_DESCRIPTION_LUT}(UniProtID)
);
CREATE INDEX ${KINASE_NAME_UNIPROT_LUT}_kinase_ix
  ON ${KINASE_NAME_UNIPROT_LUT}(kinase)
;
INSERT INTO
  ${KINASE_NAME_UNIPROT_LUT}(kinase, UniProtID)
SELECT DISTINCT
    CASE
      WHEN kinase LIKE '% (PSP)'
        THEN substr(kinase, 1, -1 + instr(kinase, ' (PSP)'))
      WHEN kinase LIKE '% (NetworKIN)'
        THEN substr(kinase, 1, -1 + instr(kinase, ' (NetworKIN)'))
        ELSE kinase
      END
      AS kinase,
    UniProtID -- , source AS original
  FROM (
    SELECT DISTINCT
        UniProtID AS kinase,
        UniProtID,
        UniProtID as source
      FROM ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}
      WHERE instr(UniProtID, '_')
    UNION
    SELECT DISTINCT
        CASE
          WHEN instr(UniProtID, '_')
          THEN substr(UniProtID, 1, -1 + instr(UniProtID, '_'))
          ELSE UniProtID
        END AS kinase,
        UniProtID,
        UniProtID as source
      FROM ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}
      WHERE substr(UniProtID, 1, -1 + instr(UniProtID, '_')) NOT IN (
        SELECT kinase FROM ${KINASE_UNIPROT_DESCRIPTION_LUT}
      )
    UNION
    SELECT DISTINCT kinase, UniProtID, kinase
      FROM ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}
      WHERE length(kinase) > 0
    UNION
    SELECT DISTINCT networkin_id AS kinase, UniProtID, networkin_id
      FROM ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}
      WHERE length(networkin_id) > 0
    UNION
    SELECT DISTINCT psp_id AS kinase, UniProtID, psp_id
      FROM ${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}
      WHERE length(psp_id) > 0
  )
;
.

cat up_descr.txt | ${SQ} ${PHOSPHO_AGGREGATE_SQLITE}

( set -e;

  echo 'CREATE TABLE hprd_phosida_psty_motifs
          AS
            SELECT symbol, description, pcre, pubmed_id,
                   classification, source
            FROM raw_psty_motifs;
            DROP TABLE raw_psty_motifs;
    ';
  echo '.import psp_kinase_substrate_dataset.tabular psp_kinase_substrate';
  echo '.import psp_regulatory_sites.tabular         psp_regulatory_sites';
  ) | tee import.txt | ${SQ} ${PHOSPHO_AGGREGATE_SQLITE}

${SQ} ${PHOSPHO_AGGREGATE_SQLITE} "${CITTBL_CREATE}"
cat > citetbl.insert << .
${SQ} ${PHOSPHO_AGGREGATE_SQLITE} "
  ${CITTBL_INSERT} \
    ('uniprot_sequence', '${LICENSE_URL_UNIPROT}', '${LICENSE_ATTRIBUTION_UNIPROT}', '${LICENSE_TERMS_UNIPROT}', '"${CITTBL_DERIVED_YES}"')
  , ('uniprot_accession', '${LICENSE_URL_UNIPROT}', '${LICENSE_ATTRIBUTION_UNIPROT}', '${LICENSE_TERMS_UNIPROT}', '"${CITTBL_DERIVED_YES}"')
  , ('uprt_upacc_v', '${LICENSE_URL_UNIPROT}', '${LICENSE_ATTRIBUTION_UNIPROT}', '${LICENSE_TERMS_UNIPROT}', '"${CITTBL_DERIVED_YES}"')
  , ('${ENSEMBL_UNIPROT_TABLE}', '${LICENSE_URL_UNIPROT}', '${LICENSE_ATTRIBUTION_UNIPROT}', '${LICENSE_TERMS_UNIPROT}', '"${CITTBL_DERIVED_YES}"')
  , ('hprd_phosida_psty_motifs', '${LICENSE_URL_HPRD}', '${LICENSE_ATTRIBUTION_HPRD}', '${LICENSE_TERMS_HPRD}', '"${CITTBL_DERIVED_YES}"')
  , ('hprd_phosida_psty_motifs', '${LICENSE_URL_PHOSIDA}', '${LICENSE_ATTRIBUTION_PHOSIDA}', '${LICENSE_TERMS_PHOSIDA}', '"${CITTBL_DERIVED_YES}"')
  , ('networkin_cutoff_2', '${LICENSE_URL_NETWORKIN}', '${LICENSE_ATTRIBUTION_NETWORKIN}', '${LICENSE_TERMS_NETWORKIN}', '"${CITTBL_DERIVED_NO}"')
  , ('phosida', '${LICENSE_URL_PHOSIDA}', '${LICENSE_ATTRIBUTION_PHOSIDA}', '${LICENSE_TERMS_PHOSIDA}', '"${CITTBL_DERIVED_YES}"')
  , ('phospho_elm_classes', '${LICENSE_URL_ELM}', '${LICENSE_ATTRIBUTION_ELM}', '${LICENSE_TERMS_ELM}', '"${CITTBL_DERIVED_NO}"')
  , ('phospho_elm_domain', '${LICENSE_URL_ELM}', '${LICENSE_ATTRIBUTION_ELM}', '${LICENSE_TERMS_ELM}', '"${CITTBL_DERIVED_NO}"')
  , ('phospho_elm_kin_bind_detail', '${LICENSE_URL_ELM}', '${LICENSE_ATTRIBUTION_ELM}', '${LICENSE_TERMS_ELM}', '"${CITTBL_DERIVED_YES}"')
  , ('phospho_elm_kinase', '${LICENSE_URL_ELM}', '${LICENSE_ATTRIBUTION_ELM}', '${LICENSE_TERMS_ELM}', '"${CITTBL_DERIVED_NO}"')
  , ('psp_kinase_substrate', '${LICENSE_URL_PHOSPHOSITESPLUS}', '${LICENSE_ATTRIBUTION_PHOSPHOSITESPLUS}', '${LICENSE_TERMS_PHOSPHOSITESPLUS}', '"${CITTBL_DERIVED_NO}"')
  , ('psp_regulatory_sites', '${LICENSE_URL_PHOSPHOSITESPLUS}', '${LICENSE_ATTRIBUTION_PHOSPHOSITESPLUS}', '${LICENSE_TERMS_PHOSPHOSITESPLUS}', '"${CITTBL_DERIVED_NO}"')
  , ('${PHOSPHO_ELM_NETWORKIN_PSP_UNIPROT_LUT}', '${LICENSE_URL_PHOSPHO_AGGREGATE_SQLITE}'
    , '${LICENSE_ATTRIBUTION_PHOSPHO_AGGREGATE_SQLITE}', '${LICENSE_TERMS_ELM_NETWORKIN_PSP_UNIPROT_LUT}',  '"${CITTBL_DERIVED_NO}"'
    )
  , ( '${KINASE_NAME_UNIPROT_LUT}',               '${LICENSE_URL_PHOSPHO_AGGREGATE_SQLITE}'
    , '${LICENSE_ATTRIBUTION_PHOSPHO_AGGREGATE_SQLITE}', '${LICENSE_TERMS_KINASE_NAME_UNIPROT_LUT}',        '"${CITTBL_DERIVED_NO}"'
    )
  , ( '${KINASE_UNIPROT_DESCRIPTION_LUT}',        '${LICENSE_URL_PHOSPHO_AGGREGATE_SQLITE}'
    , '${LICENSE_ATTRIBUTION_PHOSPHO_AGGREGATE_SQLITE}', '${LICENSE_TERMS_KINASE_UNIPROT_DESCRIPTION_LUT}', '"${CITTBL_DERIVED_NO}"'
    )
  , ( '${UNIPROT_ATTR_TABLE}',                    '${LICENSE_URL_PHOSPHO_AGGREGATE_SQLITE}'
    , '${LICENSE_ATTRIBUTION_PHOSPHO_AGGREGATE_SQLITE}', '${LICENSE_TERMS_UNIPROT_ATTR_TABLE}',             '"${CITTBL_DERIVED_NO}"'
    )
  ;"
.

. citetbl.insert && rm citetbl.insert

${SQ} ${PHOSPHO_AGGREGATE_SQLITE} "update psp_kinase_substrate set kin_acc_id = 'P06748' where  kin_acc_id = 'AAA58698'";

if [ -e ${UNIPROT_PROTEOME_SQLITE} -a "${PHOSPHO_AGGREGATE_INCLUDE_SEQUENCES}" = "1" ]; then
  ${SQ} -batch ${UNIPROT_PROTEOME_SQLITE} \
    'select accession, uniprotid, db from uprt_upacc_v;' \
    > uprt_upacc.tabular
  ${SQ} -batch ${UNIPROT_PROTEOME_SQLITE} \
    'SELECT id AS UniProtID, db, os, ox, sq AS stats, sequence FROM uprt_v;' \
    > uprt_sequence.tabular
  ${SQ} -batch ${PHOSPHO_AGGREGATE_SQLITE} << .
-- NB: This adds about 62 Mbytes to the DB
--     which is substantial because it starts at about 17 Mbytes
DROP TABLE IF EXISTS uniprot_accession
  ;
DROP TABLE IF EXISTS uniprot_sequence
  ;
CREATE TABLE IF NOT EXISTS uniprot_sequence(
  UniProtID TEXT PRIMARY KEY,
  db        TEXT,
  os        TEXT,
  ox        INTEGER,
  stats     TEXT,
  sequence  TEXT
  );
CREATE INDEX uniprot_sequence_id_ix ON uniprot_sequence(UniProtID)
  ;
CREATE TABLE IF NOT EXISTS uniprot_accession(
  Accession TEXT,
  UniProtID TEXT REFERENCES uniprot_sequence(UniProtID),
  db TEXT,
  UNIQUE(Accession, UniProtID)
  );
CREATE INDEX uniprot_accession_id_ix ON uniprot_accession(UniProtID)
  ;
CREATE INDEX uniprot_accession_acc_ix ON uniprot_accession(Accession)
  ;
DROP VIEW IF EXISTS uprt_upacc_v;
CREATE VIEW uprt_upacc_v
AS
  SELECT a.accession, u.*
  FROM uniprot_accession a
    LEFT JOIN uniprot_sequence u
      ON a.uniprotid = u.uniprotid
  ;
.import uprt_sequence.tabular uniprot_sequence
.import uprt_upacc.tabular    uniprot_accession
VACUUM
  ;
.
  fi

echo ''
echo '+------------------------------------------------+'
echo '|    SUMMARY:  RESULTING DATABASES AND TABLES    |'
echo '+------------------------------------------------+'
echo ''

. <(
  ls *.sqlite \
  | sed -e '$ {g; p; d}; /combined_phospho_dbs/ {h; d}; p; d' \
  | sed -e 's/\(.*\)/(echo ""); (echo Tables within \1:); (echo ""); '"${SQR}"' \1 .tables | sed -e "s@^@  @"/'
)

let ONECOL="-1 + $COLUMNS / 5"
export ONECOL
(
  echo ".mode table --wrap ${ONECOL} --wordwrap on --noquote";
  echo "SELECT * FROM citation ORDER BY table_name, derivation";
) | ${SQR} ${PHOSPHO_AGGREGATE_SQLITE}

set -x
(
  echo ".once ${KINASE_NAME_UNIPROT_LUT}.tabular";
  echo "SELECT * FROM ${KINASE_NAME_UNIPROT_LUT};";
  echo ".once ${KINASE_UNIPROT_DESCRIPTION_LUT}.tabular";
  echo "SELECT * FROM ${KINASE_UNIPROT_DESCRIPTION_LUT};";
  ) | ${SQR} ${PHOSPHO_AGGREGATE_SQLITE} && \
    sleep 1 &&  \
    ${BZ} "${KINASE_UNIPROT_DESCRIPTION_LUT}.tabular" && \
    ${BZ} "${KINASE_NAME_UNIPROT_LUT}.tabular"
