#!/bin/env bash
############################################################################
#
# File: fetch_networkin.sh
#
# Subject: fetch_networkin.sh - Fetch NetworKin patterns for kinases and domains
#
# Author: Arthur Eschenlauer (https://orcid.org/0000-0002-2882-0508)
#
# Date: 23 May 2022
#
# URL: [if available, e.g. https://gist.github.com/eschen42/a223f6aeee93797a720c559a666ec069]
#
############################################################################
#
#  This file:
#  - downloads the catalog of pS/pT/pY sites and binding domains from
#    NetworKin, http://pegasus.biochem.mpg.de/networkin/help/motifs.aspx
#  - translates patterns from the latter into PERL-compatible regular
#      expressions
#
############################################################################
#
# Requires:
# - bash
# - curl
# - sed
# - sqlite3 (command line shell for SQLite: https://sqlite.org/cli.html)
# - xz
#
# For example, these requirements may be met using conda, e.g.:
#   conda create -n fetch_networkin -c conda-forge bash curl sed sqlite xz
#   conda activate fetch_networkin
#
############################################################################
#
# This file is in the public domain. Art Eschenlauer has waived all
# copyright and related or neighboring rights to:
#   fetch_networkin.sh - Fetch NetworKin patterns for kinases and domains
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
NETWORKIN_SQLITE=${NETWORKIN_SQLITE:-networkin.sqlite}
printenv | grep 'LICENSE_AGREED_NETWORKIN=YES' || DISCARD=${LICENCE_AGREED_NETWORKIN:?'
You must agree to the noncommercial use terms at
  http://networkin.science/contact.shtml
and then set the
  LICENCE_AGREED_NETWORKIN
environment variable to YES in urls_to_fetch.sh.
'}
DISCARD=${URL_NETWORKIN_HUMAN_PREDICTIONS_3_1:?'
You must set the
  URL_NETWORKIN_HUMAN_PREDICTIONS_3_1
environment variable to the address of the NetworKIN
predictions URL that is found at:
  http://networkin.science/download.shtml
e.g.,
  http://networkin.science/download/networkin_human_predictions_3.1.tsv.xz
'}

if [ ! -e networkin.tsv.xz ]; then
  # fetch NetworKIN version 3.1 that was posted before 4 October 2017
  curl -o networkin.tsv.xz  ${URL_NETWORKIN_HUMAN_PREDICTIONS_3_1}
  fi

sqlite3 -tabs -header ${NETWORKIN_SQLITE} '
  DROP TABLE if exists networkin_cutoff_2;
  DROP TABLE if exists networkin;
  DROP TABLE if exists networkin_kinase_netphorest_lut;
  DROP TABLE if exists networkin_to_phospho_elm_kinase_lut;
  DROP TABLE if exists kinase_lut;
  DROP TABLE if exists z;
  '

unxz -c networkin.tsv.xz \
  | sqlite3 -tabs -header ${NETWORKIN_SQLITE} ".import /dev/stdin networkin"

(
  echo '.import networkin_to_phospho_elm_kinase_lut.tabular perm_networkin_to_phospho_elm_kinase_lut';

  echo 'CREATE TABLE networkin_to_phospho_elm_kinase_lut
          AS SELECT * FROM perm_networkin_to_phospho_elm_kinase_lut;
    ';

  echo 'DROP TABLE  perm_networkin_to_phospho_elm_kinase_lut;';

  echo "CREATE TABLE kinase_lut
          AS
            SELECT distinct
              id,
              '|'||id||'|' AS qid,
              id||' (NetworKIN)' AS kinase
            FROM
              networkin;
    ";

  echo "CREATE TABLE z
          AS
            SELECT id, phospho_elm_kinase
            FROM
              kinase_lut x,
              networkin_to_phospho_elm_kinase_lut y
            WHERE 0 < instr(y.networkin_kinase, x.qid);
    ";

  echo "UPDATE kinase_lut
          SET kinase = phospho_elm_kinase
          FROM z
          WHERE kinase_lut.id = z.id;
    ";

  echo "INSERT INTO kinase_lut(id, qid, kinase)
          SELECT phospho_elm_kinase, networkin_kinase, phospho_elm_kinase
            FROM networkin_to_phospho_elm_kinase_lut
            WHERE networkin_kinase NOT IN (SELECT qid FROM kinase_lut)
          ;
    ";

  echo 'CREATE TABLE networkin_cutoff_2
          AS SELECT * FROM networkin WHERE networkin_score > 2.0;
    ';

  echo 'CREATE TABLE networkin_kinase_netphorest_lut
          AS
            SELECT distinct id AS networkin_id, id AS kinase, netphorest_group
              FROM networkin
          ;
    ';

  echo "UPDATE networkin_kinase_netphorest_lut
          SET kinase = kl.kinase
          FROM (SELECT DISTINCT id, kinase FROM kinase_lut) kl
          WHERE kl.id = networkin_kinase_netphorest_lut.networkin_id
          ;
    ";

  echo 'INSERT INTO networkin_kinase_netphorest_lut (
          networkin_id, kinase, netphorest_group
          )
          SELECT phospho_elm_kinase, phospho_elm_kinase, '"''"'
            FROM networkin_to_phospho_elm_kinase_lut
           WHERE phospho_elm_kinase NOT IN (
             SELECT kinase
               FROM networkin_kinase_netphorest_lut
             )
        ;
    ';

  echo 'CREATE index networkin_kinase_netphorest_lut_idx
          ON networkin_kinase_netphorest_lut(networkin_id);
    ';

  ) | sqlite3 -tabs -header ${NETWORKIN_SQLITE} 

(
  echo '.once networkin_cutoff_2.tabular';
  echo 'SELECT * FROM networkin_cutoff_2;';

  echo '.once networkin_kinase_netphorest_lut.tabular';
  echo 'SELECT DISTINCT * FROM networkin_kinase_netphorest_lut';
  ) | sqlite3 -tabs -header ${NETWORKIN_SQLITE} 
