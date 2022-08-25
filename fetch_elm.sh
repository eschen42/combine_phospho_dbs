#!/bin/env bash
############################################################################
#
# File: fetch_elm.sh
#
# Subject: fetch_elm.sh - Fetch data for noncommercial use from Phospho.ELM
#
# Author: Arthur Eschenlauer (https://orcid.org/0000-0002-2882-0508)
#
# Date: 5 May 2022
#
# URL: [if available, e.g. https://gist.github.com/eschen42/a223f6aeee93797a720c559a666ec069]
#
############################################################################
#
#  This file downloads the Phospho.ELM datasets for kinase and binding
#    domains of phosphopeptides and produces a SQLite database, exporting
#    into tabular format.
#
#  It also downloads and transforms kinase and domain metadata and
#    ELM classes (which have binding site patterns) into tabular format.
#
############################################################################
#
# Requires:
#   - bash
#   - curl
#   - sed
#   - sqlite3 (command line shell for SQLite: https://sqlite.org/cli.html)
#
# For example, these requirements may be met using conda, e.g.:
#   conda create -n fetch_elm bash curl sed sqlite
#   conda activate fetch_elm
#
############################################################################
#
#  Terms of use:
#    This script downloads datasets from Phospho.ELM.
#    Those datasets (but not this script) are subject to the terms of use
#      and attribution presented at http://phospho.elm.eu.org/dataset.html
#    You must read and agree to those terms before using those datasets.
#
#  From http://phospho.elm.eu.org/dataset.html
#    "The data in phospho.ELM should not be used or shared for any
#    commercial purposes and should not be distributed to a third party
#    without prior consent.  Please read the full Phospho.ELM academic
#    license agreement."
#
############################################################################
#
# This file is in the public domain. Art Eschenlauer has waived all
# copyright and related or neighboring rights to:
#   fetch_elm.sh - Fetch data for noncommercial use from Phospho.ELM
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
source urls_to_fetch.sh
printenv | grep 'LICENSE_AGREED_ELM=YES' || DISCARD=${LICENCE_AGREED_ELM:?'
You must agree to the academic license at
  http://phospho.elm.eu.org/dataset.html
and then set the
  LICENCE_AGREED_ELM
environment variable to YES in urls_to_fetch.sh.
'}
DISCARD=${URL_PHOSPHO_ELM_SWITCHES:?' You must define this variable in urls_to_fetch.sh'}
DISCARD=${URL_PHOSPHO_ELM_KINASES:?' You must define this variable in urls_to_fetch.sh'}
DISCARD=${URL_PHOSPHO_ELM_DOMAINS:?' You must define this variable in urls_to_fetch.sh'}
DISCARD=${URL_PHOSPHO_ELM_API:?' You must define this variable in urls_to_fetch.sh'}
DISCARD=${URL_ELM_CLASSES:?' You must define this variable in urls_to_fetch.sh'}
DISCARD=${URL_PHOSPHO_ELM_DUMP_VERTEBRATES:?' You must define this variable in urls_to_fetch.sh'}
#ACE DISCARD=${URL_ELM_INTERACTIONS:?' You must define this variable in urls_to_fetch.sh'}


  PHOSPHOELM_IMP_SQL=phosphoelm_kin_bind.sql
  PHOSPHOELM_TABULAR=phosphoelm_kin_bind_detail.tabular
   PHOSPHOELM_SQLITE=${PHOSPHOELM_SQLITE:-phosphoelm_kin_bind.sqlite}
   PHOSPHOELM_DETAIL=phosphoelm_kin_bind.detail
     PHOSPHOELM_TASK=phosphoelm_kin_bind.task
         ELM_CLASSES=elm_phospho_classes.tsv
  PHOSPHOELM_KINASES=phospho_elm_kinases
  PHOSPHOELM_DOMAINS=phospho_elm_domains
PHOSPHOELM_KINDETAIL=phosphoelm_kinase_upid_desc.lut
#ACE  ELM_INTERACTIONS=elm_interactions.tsv

############################################################################

# Fetch ELM phosphorylation-applicable classes 
if [ ! -e ${ELM_CLASSES} ]; then
  # Fetch all ELM classes, since it is not clear how to choose fewer
  curl -o temp_${ELM_CLASSES}  ${URL_ELM_CLASSES}
  # Extract the phosphorylation-applicable rows
  grep -i -E \
    '(SH2)|([Pp]hospho[pr])|([Pp]hosphatase)|([Kk]inase)|(Accession)' \
    temp_${ELM_CLASSES} \
    | LC_ALL=C sed -e '
    s/^"//;
    s/".$//;
    s/"\t"/\t/g;
    1 s/#//g;
    /\tTRG_/d;
    /\tDEG_/d;
    s/[^[:print:]\r\t]/-/g
    ' > ${ELM_CLASSES}
  # Clean up
  rm temp_${ELM_CLASSES}
  fi

# you can fetch ELM switches if desired:
#curl -o switches.fetch  ${URL_PHOSPHO_ELM_KINASES}

############################################################################

cat > ${PHOSPHOELM_IMP_SQL} << END_SQL
.mode tabs
.import --skip 1 kinases.fetch kinase
.import --skip 1 domains.fetch domain
.mode table
select 'kinase' as 'record type', count(*) as count from kinase
union
select 'domain', count(*) from domain;
END_SQL

# If database does not exist, create and populate it.
#   Note well: Please remove the database if you want to update it from Phospho.ELM
if [ ! -e ${PHOSPHOELM_SQLITE} ]; then
  # Ensure that stray files don't exist before attempting to create them.
  if [ -e ${PHOSPHOELM_DETAIL} ]; then
    rm ${PHOSPHOELM_DETAIL}
  fi
  if [ -e ${PHOSPHOELM_TASK} ]; then
    rm ${PHOSPHOELM_TASK}
  fi

  # Get the lists of kinases and phospho-domains
  curl -o kinases.fetch ${URL_PHOSPHO_ELM_KINASES}
  curl -o domains.fetch ${URL_PHOSPHO_ELM_DOMAINS}

  # Scrape the kinase or domain IDs from the downloaded web page.
  sed -i -e '
    1,/thead/ d; /thead/,/tbody/ d; /tbody/,$ d;
    s/^[ ][ ]*//;
    s/^[<]tr[^>]*[>] //; s/ [<][/]tr[>]$//;
    s/[<][/]th[>][ ]*[<]th[^>]*[>][ ]*/\t/g;
    s/[<][/]td[>][ ]*[<]td[^>]*[>][ ]*/\t/g;
    s/\([<][^>]\+[>][ ]*\)\+//g;
    s/^\t//;
    /^$/d;
    /^Name/ {
      s/[&]nbsp;/_/g;
      s/\t[#]/\t/;
      s/.*/\L&/;
      }
    ' kinases.fetch domains.fetch


  #   reference for the following: http://phospho.elm.eu.org/help.html
  #   Accession:       UniProt ID
  #                      Note that this may be used to get all the records
  #                      for the accession,
  #                      e.g., http://phospho.elm.eu.org/byAccession/P12931.csv
  #   Res.:            Phosphorylated residue (S/T/Y)
  #   Pos.:            Position of the S/T/Y phosphorylation site within the
  #                      UniPROT/TrEMBL sequence. (NB. position may differ from
  #                      that given in literature due to differences
  #                      in sequence entry).
  #   Sequence:        Amino acid sequence of region flanking the modified
  #                      residue (+/- 10 amino acids).
  #   Kinase:          List of kinases which modify the given residue.
  #                      e.g., http://phospho.elm.eu.org/kinases.html#AAK1
  #   PMID:            Link to PubMed entry(s) for publications reporting
  #                      the evidence from which the data was collected,
  #                      e.g., https://pubmed.ncbi.nlm.nih.gov/18657069/
  #                      (NB. Site position quoted in literature may differ
  #                      from that given in Phospho.ELM due to differences
  #                      in sequence entry and annotation).
  #   Src:             High Throughput Data (HTP) != 1;
  #                      Low Throughput Data (LTP) = 1
  #   Cons:            The Conservation Score (http://conscore.embl.de/)
  #                      quantifies the conservation of each phospho-site.
  #                      Values range between 0 and 1, where 1 indicates
  #                      the highest conservation.
  #   ELM:             Link to ELM server (http://elm.eu.org/) entry
  #                      for the given phosphorylation and/or binding motif.
  #   Binding Domain:  The phosphorylation of the given residue creates
  #                      a binding motif for a domain involved in signaling
  #                      (e.g. SH2, 14-3-3, PTB).
  #   SMART/Pfam:      Note of any protein family or SMART domain predictions
  #                      (http://smart.embl-heidelberg.de/)
  #                      in which the phosphorylation instance resides.
  #   IUPRED score:    Prediction of protein disorder by IUPRED
  #                      (http://iupred.enzim.hu/).
  #                      Score ranges from 0 to 1; a score above 0.5 is
  #                      considered as disordered.
  #   PDB: i           Link to a macromolecular structure database PDBe
  #                      (http://www.ebi.ac.uk/pdbe/)
  #                      entry containing a relevant structure covering
  #                      the phosphorylated site.
  #   P3D Acc.:        Surface accessibility score calculated by Phospho3D
  #                      (http://arianna.bio.uniroma1.it/phospho3d),
  #                      which is a database of three-dimensional structures
  #                      of protein phosphorylation sites.
  #                      A link to the Phospho3D entry is provided
  #                      for each calculated value.
  #                      The accessibility data should always be interpreted
  #                      in the context of the structure!
  #


  # Create rudimentary schema
  echo "
  CREATE TABLE IF NOT EXISTS kinase(
    name           TEXT,
    instances      INT,
    uniprot        TEXT,
    hugo_id        TEXT,
    classification TEXT,
    description    TEXT
  );

  CREATE TABLE IF NOT EXISTS domain(
    name           TEXT,
    instances      INT
  );

  CREATE TABLE IF NOT EXISTS kin_detail(
    uniprot_id     TEXT NOT NULL ON CONFLICT IGNORE,
    residue        TEXT NOT NULL ON CONFLICT IGNORE,
    position       INT NOT NULL ON CONFLICT IGNORE,
    context        TEXT NOT NULL ON CONFLICT IGNORE,
    kinase         TEXT,
    pubmed_id      TEXT NOT NULL ON CONFLICT IGNORE,
    source         INT,
    conscore       REAL,
    elm            TEXT,
    binding_domain TEXT,
    smart_pfam     TEXT,
    iupred_score   REAL,
    pdb            TEXT,
    p3d_acc        REAL,
    UNIQUE(
      uniprot_id,
      residue,
      position,
      context,
      kinase,
      pubmed_id,
      source,
      binding_domain
      )
  );
  " | sqlite3 -batch ${PHOSPHOELM_SQLITE}

  # Scrape the binding domain IDs from the web page
  cat ${PHOSPHOELM_IMP_SQL} | sqlite3 -batch ${PHOSPHOELM_SQLITE}

  # Prime the task file
  echo 'set -xe' > ${PHOSPHOELM_TASK}

  # Add to the task file tasks to fetch each kinase detail
  echo "select 'curl -o - ${URL_PHOSPHO_ELM_API}/byKinase/' || replace(name, ' ', '%20') || '.csv | sed -e ''/^\$/d; s/;\$//; s/; /;/g;'' > ${PHOSPHOELM_DETAIL} && sqlite3 -batch -separator '';'' ${PHOSPHOELM_SQLITE} ''.import -skip 1 ${PHOSPHOELM_DETAIL} kin_detail'' && rm ${PHOSPHOELM_DETAIL}' from kinase;" | sqlite3 -batch ${PHOSPHOELM_SQLITE} >> ${PHOSPHOELM_TASK}

  # Add to the task file tasks to fetch each substrate detail
  echo "select 'curl -o - ${URL_PHOSPHO_ELM_API}/byDomain/' || replace(name, ' ', '_') || '.csv | sed -e ''/^\$/d; s/;\$//; s/; /;/g;'' > ${PHOSPHOELM_DETAIL} && sqlite3 -batch -separator '';'' ${PHOSPHOELM_SQLITE} ''.import -skip 1 ${PHOSPHOELM_DETAIL} kin_detail'' && rm ${PHOSPHOELM_DETAIL}' from domain;" | sqlite3 -batch ${PHOSPHOELM_SQLITE} >> ${PHOSPHOELM_TASK}

  # Execute the humongous task file
  set +e  # ignore exit code since warnings give nonzero exit code
  bash ${PHOSPHOELM_TASK}
  set -e

  sqlite3 -tabs -header -batch ${PHOSPHOELM_SQLITE} "DROP TABLE IF EXISTS phospho_elm_classes;"
  sqlite3 -tabs -header -batch ${PHOSPHOELM_SQLITE} ".import ${ELM_CLASSES} phospho_elm_classes"

  # Clean up
  rm ${PHOSPHOELM_TASK}
fi

# Clean up
rm ${PHOSPHOELM_IMP_SQL}

# Clean up kinase column
echo "
UPDATE kin_detail
  SET kinase = '-'
  WHERE kinase = 'none';
" | sqlite3 -batch ${PHOSPHOELM_SQLITE}

# Create view to split the binding_domain column on ', '
echo "
DROP VIEW IF EXISTS v_kin_bind_detail;
CREATE VIEW v_kin_bind_detail
  AS
  WITH RECURSIVE split(eid, label, str) AS (
      SELECT
        rowid,
        '',
        binding_domain || ', '
      FROM kin_detail
      UNION ALL
      SELECT
        eid,
        substr(str,  0,                    instr(str, ', ')),
        substr(str,  instr(str, ', ') + 2                  )
      FROM split
      WHERE
        NOT str = ''
  ) SELECT
      uniprot_id,
      residue,
      position,
      context,
      kinase,
      pubmed_id,
      source,
      conscore,
      elm,
      label AS binding_domain,
      smart_pfam,
      iupred_score,
      pdb,
      p3d_acc
    FROM split, kin_detail
    WHERE
      split.eid = kin_detail.rowid
    AND
      NOT label = ''
    ORDER BY eid, label
  ;
DROP TABLE IF EXISTS kin_bind_detail;
CREATE TABLE kin_bind_detail
  AS
  SELECT * FROM v_kin_bind_detail
  ;
" | sqlite3 -batch ${PHOSPHOELM_SQLITE}

# Prepare to export v_kin_bind_detail to ${PHOSPHOELM_TABULAR}
echo "
.mode tabs
.header on
.once ${PHOSPHOELM_TABULAR}
select * from v_kin_bind_detail;
.quit
" > ${PHOSPHOELM_TASK}

# Export v_kin_bind_detail to ${PHOSPHOELM_TABULAR}
if [ -e ${PHOSPHOELM_SQLITE} ]; then
  if [ -e  ${PHOSPHOELM_TABULAR} ]; then
    rm ${PHOSPHOELM_TABULAR}
  fi
  cat ${PHOSPHOELM_TASK} | sqlite3 -batch ${PHOSPHOELM_SQLITE}
fi

# Clean up
rm ${PHOSPHOELM_TASK}

############################################################################

#ACE # Fetch ELM interaction classes 
#ACE if [ ! -e ${ELM_INTERACTIONS} ]; then
#ACE   # Fetch all ELM classes, since it is not clear how to choose fewer
#ACE   if [ ! -e temp_${ELM_INTERACTIONS} ]; then
#ACE     curl -o temp_${ELM_INTERACTIONS}  "${URL_ELM_INTERACTIONS}"
#ACE     fi
#ACE   # Extract the phosphorylation-applicable rows
#ACE   set -x
#ACE   grep -i -E \
#ACE     "(\"$TAXID\"[(].*\"${TAXID}\"[(])|(taxonomyElm.taxonomyDomain)" \
#ACE     temp_${ELM_INTERACTIONS} \
#ACE     | grep -E -v '(^TRG)|(^DEG)' > ${ELM_INTERACTIONS}
#ACE   set +x
#ACE   # Clean up
#ACE   #RESTOREME rm temp_${ELM_INTERACTIONS}
#ACE   fi

############################################################################

# Fetch Phospho.ELM kinass or domains if needed and transform to tabular format
if [ ! -e ${PHOSPHOELM_KINASES}.html ]; then
  curl -o ${PHOSPHOELM_KINASES}.html ${URL_PHOSPHO_ELM_KINASES}
  fi

if [ ! -e ${PHOSPHOELM_DOMAINS}.html ]; then
  curl -o ${PHOSPHOELM_DOMAINS}.html ${URL_PHOSPHO_ELM_KINASES}
  fi

# Function to scrape metadata from kinase HTML and format as tabular
xform_kinases ()
{
  cp $1 $2
  sed -i -e '
    1 {
      h;
      s/.*/name\tinstances\tuniprot_id\thugo_id\tclassification\tdescription\tdetail_url\tsource/;
      p; x;
    };
    /byKinase/ ! d;
    s/^[ ]*//;
    s/.tr. .td style="text-align:left;"..a name="[^"]*"...a..a href="\(.byKinase.[^"]*.html\)".\([^<]*\)..a...td. .td.\([1-9][0-9]*\)..td. .td..a href="http:..www.uniprot.org.uniprot.[^"]*" target="_blank".\([^<]*\)..a...td. .td..a href="http:..www.genenames.org.data.hgnc_data.php?hgnc_id=[1-9][0-9]*" target="_blank".\([1-9][0-9]*\)..a...td. .td.\([^<]*\)..td. .td style="text-align:left;".\([^<]*\)..td. ..tr./\2\t\3\t\4\t\5\t\6\t\7\t'"${URL_PHOSPHO_ELM_API}"'\1/;
    s/.tr. .td style="text-align:left;"..a name="[^"]*"...a..a href="\(.byKinase.[^"]*.html\)".\([^<]*\)..a...td. .td.\([1-9][0-9]*\)..td. .td..a href="http:..www.uniprot.org.uniprot.[^"]*" target="_blank".\([^<]*\)..a...td. .td.\([^<]*\)..td. .td.\([^<]*\)..td. .td style="text-align:left;".\([^<]*\)..td. ..tr./\2\t\3\t\4\t\5\t\6\t\7\t'"${URL_PHOSPHO_ELM_API}"'\1/;
    s/.tr. .td style="text-align:left;"..a name="[^"]*"...a..a href="\(.byKinase.[^"]*.html\)".\([^<]*\)..a...td. .td.\([1-9][0-9]*\)..td. .td.\([^<]*\)..td. .td.\([^<]*\)..td. .td.\([^<]*\)..td. .td style="text-align:left;".\([^<]*\)..td. ..tr./\2\t\3\t\4\t\5\t\6\t\7\t'"${URL_PHOSPHO_ELM_API}"'\1/;
    s/[ ]*$//;
    s/$/\tPhoshpo.ELM/;
    ' $2
}

# Function to scrape metadata from domain HTML and format as tabular
xform_domains ()
{
  cp $1 $2
  sed -i -e '
    1 {
      h;
      s/.*/name\tinstances\tdetail_url\tsource/;
      p; x;
    };
    /byDomain/ ! d;
    s/^[ ]*//;
    s/.tr. .td style="text-align:left;"..a name="[^"]*"...a..a href="\(.byDomain.[^"]*.html\)".\([^<]*\)..a...td..td.\([1-9][0-9]*\)..td. ..tr./\2\t\3\t'"${URL_PHOSPHO_ELM_API}"'\1\tPhospho.ELM/;
    s/[ ]*$//;
    ' $2
  foo='
.tr. .td style="text-align:left;"..a name="[^"]*"../a..a href="\(/byDomain/[^"]*.html\)".\([^<]*\)./a../td..td.5./td. ./tr.
<tr> <td style="text-align:left;"><a name="SH2D1A SH2"></a><a href="/byDomain/SH2D1A_SH2.html">SH2D1A SH2</a></td><td>5</td> </tr>
  '
}

# Format as tabular
xform_kinases ${PHOSPHOELM_KINASES}.html ${PHOSPHOELM_KINASES}.tabular
xform_domains ${PHOSPHOELM_DOMAINS}.html ${PHOSPHOELM_DOMAINS}.tabular

cut -f 1,3,6 ${PHOSPHOELM_KINASES}.tabular | sed -e '1 s/^/kinase_/;' > ${PHOSPHOELM_KINDETAIL}

# Don't run the next curl command unless you have submitted your agreement
# to the "academic" (i.e., non-commercial use) license at:
#   http://phospho.elm.eu.org/dataset.html
#
# curl -o phosphoELM_vertebrate_latest.dump.tgz ${URL_PHOSPHO_ELM_DUMP_VERTEBRATES}
#
# This will give a gzipped file with fields:
#   acc, sequence, position, code, pmids, kinases, source, species, entry_date
# Note that:
#   - this is *not* the same format as what is fetched below, and
#   - this only provides kinase sites, not matches to ELM patterns (binding sites, modules)
#
# To create a normalized version of this file, remove '#bash' from the following lines and run in the bash shell:
#bash
#bash  if [ -e phosphoELM_vertebrate.sqlite ]; then rm phosphoELM_vertebrate.sqlite; fi
#bash
#bash  tar -x --gzip --to-stdout -f phosphoELM_vertebrate_latest.dump.tgz \
#bash    | sqlite3 -tabs -header phosphoELM_vertebrate.sqlite '.import /dev/stdin phospho_elm'
#bash
#bash  (cat - | sqlite3 -tabs -header phosphoELM_vertebrate.sqlite) << END_SQL
#bash       DROP VIEW  IF EXISTS v_phospho_elm;
#bash       DROP TABLE IF EXISTS phospho_elm_accession;
#bash       DROP TABLE IF EXISTS phospho_elm_sequence;
#bash       DROP TABLE IF EXISTS phospho_elm_kinase;
#bash       DROP TABLE IF EXISTS phospho_elm_thrghpt_spcs_ntr;
#bash       DROP TABLE IF EXISTS phospho_elm_pubmed;
#bash 
#bash       CREATE TABLE phospho_elm_accession (
#bash         id INTEGER PRIMARY KEY, accession TEXT UNIQUE ON CONFLICT IGNORE
#bash         );
#bash        INSERT INTO phospho_elm_accession(accession)
#bash          SELECT DISTINCT acc FROM phospho_elm;
#bash 
#bash       CREATE TABLE phospho_elm_sequence (
#bash         id INTEGER PRIMARY KEY, sequence TEXT UNIQUE ON CONFLICT IGNORE
#bash         );
#bash        INSERT INTO phospho_elm_sequence(sequence)
#bash          SELECT DISTINCT sequence FROM phospho_elm;
#bash 
#bash       CREATE TABLE phospho_elm_kinase (
#bash         id INTEGER PRIMARY KEY, kinase TEXT UNIQUE ON CONFLICT IGNORE
#bash         );
#bash        INSERT INTO phospho_elm_kinase(kinase)
#bash          SELECT DISTINCT kinases FROM phospho_elm;
#bash 
#bash       CREATE TABLE phospho_elm_thrghpt_spcs_ntr (
#bash         id INTEGER PRIMARY KEY, throughput, species, entry_date,
#bash         UNIQUE(throughput, species, entry_date) ON CONFLICT IGNORE);
#bash        INSERT INTO phospho_elm_thrghpt_spcs_ntr(throughput, species, entry_date)
#bash          SELECT DISTINCT source, species, entry_date FROM phospho_elm;
#bash 
#bash       CREATE TABLE phospho_elm_pubmed (
#bash         id INTEGER PRIMARY KEY,
#bash         accession_id                    INTEGER REFERENCES phospho_elm_accession(id)        ON UPDATE CASCADE ON DELETE CASCADE,
#bash         sequence_id                     INTEGER REFERENCES phospho_elm_sequence(id)         ON UPDATE CASCADE ON DELETE CASCADE,
#bash         position                        INTEGER,
#bash         residue                         TEXT,
#bash         pmid                            INTEGER,
#bash         kinase_id                       INTEGER REFERENCES phospho_elm_kinase(id)           ON UPDATE CASCADE ON DELETE CASCADE,
#bash         phospho_elm_thrghpt_spcs_ntr_id INTEGER REFERENCES phospho_elm_thrghpt_spcs_ntr(id) ON UPDATE CASCADE ON DELETE CASCADE,
#bash         UNIQUE(accession_id, sequence_id, position, residue, pmid, kinase_id, phospho_elm_thrghpt_spcs_ntr_id) ON CONFLICT IGNORE
#bash         );
#bash        INSERT INTO phospho_elm_pubmed(
#bash          accession_id,
#bash          sequence_id,
#bash          position,
#bash          residue,
#bash          pmid,
#bash          kinase_id,
#bash          phospho_elm_thrghpt_spcs_ntr_id
#bash          )
#bash          SELECT DISTINCT
#bash            a.id,
#bash            s.id,
#bash            e.position,
#bash            e.code,
#bash            e.pmids,
#bash            k.id,
#bash            t.id
#bash          FROM
#bash            phospho_elm_accession        a,
#bash            phospho_elm_sequence         s,
#bash            phospho_elm_thrghpt_spcs_ntr t,
#bash            phospho_elm                  e
#bash              LEFT JOIN
#bash                phospho_elm_kinase       k
#bash              ON e.kinases    = k.kinase
#bash           WHERE e.acc        = a.accession
#bash             AND e.sequence   = s.sequence
#bash             AND e.source     = t.throughput
#bash             AND e.species    = t.species
#bash             AND e.entry_date = t.entry_date
#bash          ;
#bash 
#bash        CREATE VIEW v_phospho_elm(
#bash            id,
#bash            accession,
#bash            sequence,
#bash            position,
#bash            residue,
#bash            pmid,
#bash            kinase,
#bash            throughput,
#bash            species,
#bash            entry_date
#bash          )
#bash        AS
#bash          SELECT
#bash            p.id,
#bash            a.accession,
#bash            s.sequence,
#bash            p.position,
#bash            p.residue,
#bash            p.pmid,
#bash            k.kinase,
#bash            t.throughput,
#bash            t.species,
#bash            t.entry_date
#bash          FROM
#bash            phospho_elm_accession        a,
#bash            phospho_elm_sequence         s,
#bash            phospho_elm_thrghpt_spcs_ntr t,
#bash            phospho_elm_pubmed           p
#bash              LEFT JOIN
#bash                phospho_elm_kinase       k
#bash              ON p.kinase_id = k.id
#bash           WHERE p.accession_id                    = a.id
#bash             AND p.sequence_id                     = s.id
#bash             AND p.phospho_elm_thrghpt_spcs_ntr_id = t.id
#bash        ;
#bash 
#bash      DROP TABLE phospho_elm;
#bash  END_SQL
