#!/bin/env bash
############################################################################
#
# File: fetch_phosida.sh
#
# Subject: fetch_phosida.sh - Fetch Phosida patterns for kinases and domains
#
# Author: Arthur Eschenlauer (https://orcid.org/0000-0002-2882-0508)
#
# Date: 23 May 2022
#
# URL: [if available, e.g. https://gist.github.com/eschen42/a223f6aeee93797a720c559a666ec069]
#
############################################################################
#
# This file:
# - downloads the catalog of pS/pT/pY sites and binding domains from
#   Phosida, http://pegasus.biochem.mpg.de/phosida/help/motifs.aspx
# - translates patterns from the latter into PERL-compatible regular
#     expressions
#
############################################################################
#
# Requires:
# - bash
# - curl
# - sed
# - sqlite3 (command line shell for SQLite: https://sqlite.org/cli.html)
#
# For example, these requirements may be met using conda, e.g.:
#   conda create -n fetch_phosida bash curl sed sqlite
#   conda activate fetch_phosida
#
############################################################################
#
# No license requirements are posted anywhere at the Phosida site
#
############################################################################
#
# This file is in the public domain. Art Eschenlauer has waived all
# copyright and related or neighboring rights to:
#   fetch_phosida.sh - Fetch Phosida patterns for kinases and domains
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
SQ=${SQ:-'sqlite3 -tabs -header'}

source urls_to_fetch.sh
PHOSIDA_SQLITE=${PHOSIDA_SQLITE:-phosida_motifs.sqlite}

DB=${PHOSIDA_SQLITE}

DISCARD=${URL_PHOSIDA:?'
You must set the
  URL_PHOSIDA
environment variable to the address of the phosida motifs web page, e.g.,
  http://pegasus.biochem.mpg.de/phosida/help/motifs.aspx
'}

if [ ! -e phosida_motifs.html ]; then
  curl -o phosida_motifs.html ${URL_PHOSIDA}
  fi

${SQ} ${DB} "drop table if exists phosida;"
${SQ} ${DB} "drop table if exists citation;"
${SQ} ${DB} "${CITTBL_CREATE}"
${SQ} ${DB} "
  ${CITTBL_INSERT_TBL_URL_ATTRB}
    (
      'phosida',
      '${LICENSE_URL_PHOSIDA}',
      '${LICENSE_ATTRIBUTION_PHOSIDA}',
      '${LICENSE_TERMS_PHOSIDA}',
      '"${CITTBL_DERIVED_YES}"'
      );
  "

xform_phosida_motifs ()
{
  cat $1 | sed -n -e '
    /\r/ s/.$//g;
    1 {
      h;
      s/.*/symbol\tdescription\tpcre\tpubmed_id\tclassification\tsource/;
      p; d;
      };
    # note:  s/#/-- inline comments are formatted as no-ops/;
    2,/kinases.motifs/d;
    /<!--REFERENCES-->/,$ d;
    /<!--.*-->/ d;
    /jpg/ d;
    /td align="left" width="100"/ {
      s/.*<td align="left" width="100" height="22">\(..*\)<[/]td>/\1/;
      /td/ d;
      s/\(.*\)/\1@\1/;
      s/PKA@/PKA_group@/;
      s/CK1@/CK1_group@/;
      s/CK2@/CK2_group@/;
      s/GSK-3@/GSK-3 (HPRD)@/;
      s/CDK1|CDK2|CDK4|CDK6@/CDK2@/;
      s/CAMK2@/CaM-KII_group@/;
      s/ERK[/]MAPK@/MAP2K_group@/;
      s/PKB[/]AKT@/PKB_group@/;
      s/PKC@/PKC_group@/;
      s/LCK@/Lck@/;
      s/ABL@/ABL1@/;
      s/SRC@/SRC_group@/;
      s/AURORA-A@/Aurora A@/;
      s/AURORA@/Aurora A@/;
      s/PLK1@/PLK@/;
      s/PLK1@/PLK@/;
      s/CHK1[/]2@/CHK1@/;
      h;
      };
    /td align="left" width="545" height="22"/ {
      s/<td align="left" width="545" height="22">\(..*\)<sup>\([1-9][0-9]*\)<[/]sup><[/]td>/\1\t\2/;
      s/<td align="left" width="545" height="22">\(..*\)<[/]td>/\1\t17/;
      /<td.*><[/]td>/d;
      /<td.*td>/d;
      s/<b>S<.b>[/]<b>T<.b>/(pS\|pT)/g;
      s/<b>S.T<.b>/(pS\|pT)/g;
      s/.b.S..b./pS/g;
      s/.b.T..b./pT/g;
      s/.b.Y..b./pY/g;
      s/X/./g;
      s/\([A-Z/]\{2,\}\)/(\1)/g;
      s/[/]/|/g;
      s/-//g;
      s/\t1$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/1956339/;
      s/\t2$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/2156841/;
      s/\t3$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/8325833/;
      s/\t4$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/15789031/;
      s/\t5$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/15782149/;
      s/\t6$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/7845468/;
      s/\t7$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/16273072/;
      s/\t8$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/16381900/;
      s/\t9$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/12408861/;
      s/\t10$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/16083426/;
      s/\t11$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/12738781/;
      s/\t12$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/12023960/;
      s/\t13$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/12501191/;
      s/\t14$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/17464182/;
      s/\t15$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/10648819/;
      s/\t16$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/8887677/;
      s/\t17$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/11516946/;
      s/^[ ]*//;
      x;
      G;
      s/\n/\t/g;
      s/\r/\t/g;
      s/\t\t\t\t\t/\t/g;
      s/@/\t/;
      s/$/\tkinase substrate\tPhosida/;
      p;
      s/\t/@/;
      s/\t.*//;
      h;
      };
    d;
    '
  foo='
  '
}

xform_phosida_motifs phosida_motifs.html |  ${SQ} ${DB} ".import /dev/stdin phosida"

${SQ} ${DB} "
  select
    rowid AS counter,
    pcre,
    symbol,
    description,
    pubmed_id,
    classification,
    source
  from phosida;
  " | sed -e 's/\t/"\t"/g; s/^/"/; s/$/"/;' > pSTY_phosida.tabular
