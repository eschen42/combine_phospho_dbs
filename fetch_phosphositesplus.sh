#!/bin/env bash
############################################################################
#
# File: fetch_phosphositesplus.sh
#
# Subject: fetch_phosphositesplus.sh - Fetch NetworKin patterns for kinases and domains
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
#    NetworKin, http://pegasus.biochem.mpg.de/phosphositesplus/help/motifs.aspx
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
#   conda create -n fetch_phosphositesplus -c conda-forge bash curl sed sqlite xz
#   conda activate fetch_phosphositesplus
#
############################################################################
#
# This file is in the public domain. Art Eschenlauer has waived all
# copyright and related or neighboring rights to:
#   fetch_phosphositesplus.sh - Fetch NetworKin patterns for kinases and domains
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

printenv | grep 'LICENSE_AGREED_PHOSPHOSITESPLUS=YES' || DISCARD=${LICENSE_AGREED_PHOSPHOSITESPLUS:?'
You must agree to the noncommercial use terms at
  https://www.phosphosite.org/staticDownloads
and then set the
  LICENSE_AGREED_PHOSPHOSITESPLUS
environment variable to YES in urls_to_fetch.sh.
'}

DISCARD=${URL_PSP_KINASE_SUBSTRATE:?'
You must set the
  URL_PSP_KINASE_SUBSTRATE
environment variable to the address of the PSP Kinase-Substrate URL, e.g.,
  https://web.archive.org/web/20210625175218/https://www.phosphosite.org/downloads/Kinase_Substrate_Dataset.gz
'}

DISCARD=${URL_PSP_REGULATORY_SITES:?'
You must set the
  URL_PSP_REGULATORY_SITES
environment variable to the address of the PSP Regulatory Sites URL, e.g.,
  https://web.archive.org/web/20150918235046/http://www.phosphosite.org/downloads/Regulatory_sites.gz
'}

if [ ! -e psp_kinase_substrate_dataset.gz ]; then
  curl -o psp_kinase_substrate_dataset.gz  ${URL_PSP_KINASE_SUBSTRATE}
  fi

if [ ! -e psp_regulatory_sites.gz ]; then
  curl -o psp_regulatory_sites.gz  ${URL_PSP_REGULATORY_SITES}
  fi

FILTER_PATTERN_PSP_KS=${FILTER_PATTERN_PSP_KS:-'.*'}
if [ "$SPECIES" = 'HUMAN_9606' ]; then
  FILTER_PATTERN_PSP_KS='\thuman\t.*\thuman\t'
  fi
gzip -c -d psp_kinase_substrate_dataset.gz | LC_ALL=C sed -e '
  1,3 d;
  s/[^[:print:]\r\t]/-/g;
  4 { p; d; };
  /'"${FILTER_PATTERN_PSP_KS}"'/! d;
  ' > psp_kinase_substrate_dataset.tabular

FILTER_PATTERN_PSP_REG=${FILTER_PATTERN_PSP_REG:-'.*'}
if [ "$SPECIES" = 'HUMAN_9606' ]; then
  FILTER_PATTERN_PSP_REG='\thuman\t'
  fi
gzip -c -d psp_regulatory_sites.gz | LC_ALL=C sed -e '
  1,3 d;
  s/[^[:print:]\r\t]/-/g;
  4 { p; d; };
  /'"${FILTER_PATTERN_PSP_REG}"'/! d;
  ' > psp_regulatory_sites.tabular

