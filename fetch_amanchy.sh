#!/bin/env bash
############################################################################
#
# File: fetch_amanchy.sh
#
# Subject: fetch_amanchy.sh - Fetch Amanchy patterns for kinases and domains
#
# Author: Arthur Eschenlauer (https://orcid.org/0000-0002-2882-0508)
#
# Date: 12 May 2022
#
# URL: [if available, e.g. https://gist.github.com/eschen42/a223f6aeee93797a720c559a666ec069]
#
############################################################################
#
#  This file:
#  - downloads the catalog of pS/pT/pY sites and binding domains from
#    HPRD, originating from the supplementary material of
#      Amanchy et al. (2007) A compendium of curated phosphorylation-based
#      substrate and binding motifs. Nature Biotechnology. 25, 285-286.
#      PMID: 17344875  DOI: 10.1038/nbt0307-285
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
#
# For example, these requirements may be met using conda, e.g.:
#   conda create -n fetch_amanchy bash curl sed sqlite
#   conda activate fetch_amanchy
#
############################################################################
#
# This file is in the public domain. Art Eschenlauer has waived all
# copyright and related or neighboring rights to:
#   fetch_amanchy.sh - Fetch Amanchy patterns for kinases and domains
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
DISCARD=${URL_HPRD_SERINE_MOTIFS:?'
You must set the
  URL_HPRD_SERINE_MOTIFS
environment variable to the address of the Amanchy pST motifs web page, e.g.,
  http://hprd.org/serine_motifs
'}
DISCARD=${URL_HPRD_TYROSINE_MOTIFS:?'
You must set the
  URL_HPRD_TYROSINE_MOTIFS
environment variable to the address of the Amanchy pST motifs web page, e.g.,
  http://hprd.org/tyrosine_motifs
'}


if [ ! -e hprd_tyrosine_motifs.html ]; then
  curl -o hprd_tyrosine_motifs.html ${URL_HPRD_TYROSINE_MOTIFS}
  fi
if [ ! -e hprd_serine_motifs.html ]; then
  curl -o hprd_serine_motifs.html   ${URL_HPRD_SERINE_MOTIFS}
  fi


xform_hprd_motifs ()
{
  cp $1 $2
  # note:  s/#/-- inline comments are formatted as no-ops/;
  sed -i -e '
    1 {
      h;
      s/.*/counter\tpcre\tsymbol\tdescription\tpubmed_id\tclassification\tsource/;
      p; x;
    };
    /pdf/ d;
    /color:red/ ! d;
    s/\([<][/]\?t[dr][^>]*[>]\)\+/\t/g;
    s/[<][/]\?span[^>]*[>]//g;
    s/[>][<]img border.*//;
    s/[<]a href=//;
    s/\t[&]nbsp;[&]nbsp;//;
    s/[&]nbsp;[&]nbsp;//;
    s/[*]//g;
    s/http:.*list_uids=//;
    s/^[ ]\+//;

    h; s/^\([^\t]*\t\)\{2\}//;
    x; s/\(\t[^\t]*\)\{2\}$//;
    s/[[]/(/g;
    s/[]]/)/g;
    s/[/]/|/g;
    s/X/./g;
    s/B/[^P]/g;
    G; s/\n/\t/;
    s/\t[^\t]*$//;
    G; s/\n/\t/;

    s/\t\([^\t]\+\)$/\thttps:\/\/pubmed.ncbi.nlm.nih.gov\/?term=\1/;

    s/ [Kk]inase motif/ kinase substrate motif/g;
    /[kK]inase substrate motif/ {
      s/ [Kk]inase substrate motif//;
      s/$/\tkinase substrate/;
    };
    / substrate motif[ ]*\t/ {
      s/ substrate motif[ ]*//;
      s/$/\tkinase substrate/;
    };
    s/kinase substrate\tkinase substrate/kinase substrate/;
    / substrate sequence[ ]*\t/ {
      s/ substrate sequence[ ]*//;
      s/$/\tkinase substrate/;
    };
    / phosphatase / {
      s/kinase substrate/phosphatase substrate/;
    };
    /domain[s]\? binding motif/ {
      s/ domain[s]\? binding motif//;
    s/$/\tdomain binding/;
    };
    s/[ ]\+\t/\t/g;

    s/#/-- rename pS|pT kinases or domains/;

    s/Aurora-/Aurora /;
    s/Calmodulin-dependent protein kinase II alpha\t/CaM-KII_alpha\t/;
    s/Calmodulin-dependent protein kinase II\t/CaM-KII_group\t/;
    s/CaMK2 alpha/CaM-KII_alpha/;
    s/Calmodulin-dependent protein kinase IV\t/CaM-KIV\t/;
    s/Calmodulin-dependent protein kinase I\t/CaM-KI_group\t/;
    s/Casein [kK]inase I delta\t/CK1_delta|CK1_group\t/;
    s/Casein [kK]inase I gamma\t/CK1_group|CK1_gamma Q9HCP0\t/;
    s/Casein [kK]inase II\t/CK2_group\t/;
    s/Casein [kK]inase I\t/CK1_group\t/;
    s/Cdc2 like protein/CDK1/;
    s/Cdc2\t/CDK1\t/;
    s/CDK1,2, 4, 6/CDK1|CDK2|CDK4|CDK6/;
    s/CDK\t/CDK_group\t/;
    s/Chk1\t/CHK1\t/;

    s/#/-- hack, because there is no CLK2 on Phospho.ELM/;
    s/CLK2\t/CLK1\t/;
    s/CLK1,2\t/CLK1\t/;
    s/DOA[/]CDC-like kinase 2\t/CLK1\t/;
    s/#/-- end hack, because there is no CLK2 on Phospho.ELM/;

    s/DMPK1\t/DMPK_group\t/;
    s/DMPK1,2\t/DMPK_group\t/;
    s/DNA dependent Protein/DNA-PK/;
    s/Doublecortin kinase-1/DCAMKL1/;
    s/elF2 alpha/HRI|PKR|PERK/;

    s/GSK3, Erk1, Erk2 and CDK5\t/GSK-3 (HPRD)|MAP2K1|MAP2K2|MAP2K_group|CDK5\t/;
    s/GSK-3, ERK1, ERK2, CDK5\t/GSK-3 (HPRD)|MAP2K1|MAP2K2|MAP2K_group|CDK5\t/;

    s/\tERK2\t/\tMAP2K1|MAP2K_group\t/;
    s/PKR/EIF2AK2/;
    s/PERK/EIF2AK3/;
    s/ERK1\t/MAP2K1|MAP2K2|MAP2K_group\t/;
    s/ERK1,2\t/MAP2K1|MAP2K2|MAP2K_group\t/;
    s/ERK1, ERK2\t/MAP2K1|MAP2K2|MAP2K_group\t/;
    s/ERK1, ERK2, SAPK, CDK5 and GSK3\t/MAP2K1|MAP2K2|MAP2K_group|CDK5|GSK-3 (HPRD)\t/;
    s/MAPK 11,13,14\t/MAPK11|MAPK13|MAPK14\t/;
    s/\tMEKK\t/\tMEKK (HPRD)\t/;

    s/#/-- There is no reference to in vivo specificity for MEKK from PMID 7874496/;

    s/\tGSK3\t/\tGSK-3 (HPRD)\t/;
    s/G protein-coupled receptor kinase 1/GRK-1/;
    /(pS|pT)P(K|R)/ {
      s/Growth associated histone HI/CDK2|MOD_CDK_SPK_2/;
      s/\tkinase substrate$/\tkinase substrate|ELM/;
      };
    /(pS|pT)P.(K|R)/ {
      s/Growth associated histone HI/CDK2|MOD_CDK_SPxK_1/;
      s/\tkinase substrate$/\tkinase substrate|ELM/;
      };
    /(K|R)(pS|pT)P/ {
      s/Growth associated histone HI/GSK-3 (HPRD)|MAP2K1|MAP2K2|MAP2K_group|CDK5|MOD_ProDKin_1/;
      s/\tkinase substrate$/\tkinase substrate|ELM/;
      };
    s/AMP-activated protein/AMPK_group/;
    s/AMPK kinase 2/AMPK_group/;
    s/Branched chain alpha-ketoacid dehydrogenase/BCKDK/;
    s/b-Adrenergic Receptor/GRK-2/;
    s/CLK1,2/CLK1|CLK2/;
    /RRA(pS|pT)VA/ {
      s/PP2A, PP2C/PKA_group|MOD_PKA_1/;
      s/\tkinase substrate$/\tkinase substrate|ELM/;
      };
    s/DMPK1,2/DMPK1|DMPK2/;
    s/p70 Ribosomal S6/p70S6K/;
    s/PKC alpha/PKC_alpha/;
    s/PKC beta/PKC_beta/;
    s/PKC delta/PKC_delta/;
    s/PKC epsilon/PKC_epsilon/;
    s/PKC eta/PKC_eta/;
    s/PKC mu/PKC_mu/;
    s/PKC theta/PKC_theta/;
    s/PKC zeta/PKC_zeta/;
    s/PKC family/PKC_group/;
    s/Plk1/PLK1/;
    s/Plk1 PDB/PLK1 PDB/;
    /R(R|K).(pS|pT)[[]^P[]]/ {
      /\tPKA, PKG\t/ {
        s/PKA, PKG/PKA_alpha|MOD_PKA_1/;
        s/\tkinase substrate$/\tkinase substrate|ELM/;
        }
      /\tPKG\t/ {
        s/PKG/PKA_group|MOD_PKA_1/;
        s/\tkinase substrate$/\tkinase substrate|ELM/;
        }
      };
    s/Pyruvate dehydrogenase/PDHK1/;

    s/#/-- These patterns in HPRD do not match the sequences or patterns in ELM/;
    s/TGF beta receptor/TGF-beta (HPRD)/;
    s/Dual specificity protein phosphatase 1/DUSP1 P28562/;
    s/Dual specificity protein phosphatase 6/DUSP6 Q16828/;
    s/Phosphorylase/PHK_group/;

    s/#/-- LIG_BRCT_BRCA1_1 is only slightly different:  .pS..F /;
    /pS(F|Y|H)(V|F|Y)(F|Y)/ {
      s/BRCA1 BRCT/LIG_BRCT_BRCA1_1/;
      s/domain binding$/domain binding|ELM/;
      }
    /\tWW\t/ {
      s/\tWW\t/\tDOC_WW_Pin1_4\t/;
      s/domain binding$/domain binding|ELM/;
      }
    s/#/-- FHA in phosphoELM match [GTWPQ][SGAV][AESPC]T[QP][GREVT][ASTLC]/;
    /\tFHA\t/ s/\tFHA\t/\tFHA (HPRD)\t/;
    /Chk2 FHA/ {
      s/Chk2 FHA/LIG_FHA_1/;
      s/domain binding$/domain binding|ELM/;
      }
    /R[.](Y|F)[.]pS[.]P/ {
      s/\t14-3-3\t/\tLIG_14-3-3_CanoR_1\t/;
      s/domain binding$/domain binding|ELM/;
      }
    s/\t14-3-3\t/\t14-3-3 (HPRD)\t/;
    s/\tAMPK_group kinase 2\t/\tAMPK_group\t/;
    s/Beta-TrCP1/BTRC WD40/;
    s/CDC4 WD40/hCDC4 Q969H0/;
    s/BARD1 BRCT/BARD1 Q99728/;
    /(R|K)[.]R[.][.]pS/ s/\tMAPKAPK1\t/\tRSK-1|RSK-2|RSK_group\t/;
    /RRR[.]pS/ s/\tMAPKAPK1\t/\tRSK_group\t/;
    /(L|F|I)...R(Q|S|T)L((pS|pT)(M|L|I|V)/ s/((/(/;
    s/\tMDC1 BRCT\t/\tMDC1 FHA\t/;
    s/\tMLCK\t/\tMLCK_group\t/;
    s/\(F..F(pS|pT)(F|Y)\t\)PDK1\t/\1PDK-1\t/;
    s/\tNek 2\t/\tNEK2\t/;
    s/\tPKC\t/\tPKC_group\t/;
    s/\tPKC_mu\t/\tPKD1\t/;
    s/\tPKA\t/\tPKA_group\t/;
    s/\tAkt\t/\tPKB_group\t/;
    s/\tZIP\t/\tDAPK3\t/;
    s/\tFRIP PTB\t/\tFRS2 PTB\t/;
    s/\tRasGAP SH2\t/\tRASA_group SH2\t/;
    s/\t\(Pim[12]\) kinase\t/\t\1 (HPRD)\t/;
    s/\t\(RAD9 BRCT\)\t/\t\1 (HPRD)\t/;
    s/\t\(NIMA\)\t/\t\1 (HPRD)\t/;
    s/#/-- missing from ELM or indeterminate: 14-3-3; BARD1 Q99728; CK1_gamma Q9HCP0; DUSP1 P28562; DUSP6 Q16828; FRIP PTB; FGFR; GSK-3; HCP SH2; JNK1; NEKK; NIMA (NEKn); PKC_mu; PTPRH SH2; PTPRJ SH2; RasGAP SH2; hCDC4 Q969H0;  /;


    s/#/-- rename pY kinases or domains/;
    s/#/-- fix broken pattern found with regex "[0-9]\+"."[^("]*|/;
    s/\tE|P(M|L|I|V|F)pY(G|A).(M|L|I|V|F|Y)A\t/\t(E|P)(M|L|I|V|F)pY(G|A).(M|L|I|V|F|Y)A\t/;

    s/#/-- patterns in HPRD not matching corresponding sequences or patterns in ELM/;
    s/\tAbl\t/\tAbl\t/;

    s/#/-- corrected errata for domains/;
    s/pY..YY\tALK\t/pY...YY\tALK|PLCG1 SH2\t/;
    s/KKKSPGEpYVNIEFG\tIGF1 receptor\t/KSPGEpYVNIEFG\tIGF1R|INSR\t/;
    s/\tInsulin receptor\t/\tINSR\t/;
    s/\tPDGFR\t/\tPDGFR_group\t/;
    s/\tSrc family\t/\tSRC_group\t/;
    s/\tSrc\t/\tSRC\t/;
    s/\tSyk\t/\tSYK\t/;
    s/\t3BP2 SH2\t/\tSH3BP2 SH2\t/;
    s/\tSrc and Abl SH2\t/\tPIK3R1 SH2|Src SH2\t/;
    s/\tSrc, Fyn, Lck, Fgr, Abl, Crk, Nck SH2\t/\tSrc SH2|Fyn SH2|Lck SH2|FGR SH2|ABL1 SH2|CRK SH2|NCK SH2\t/;
    s/\tSrc, Fyn,Csk, Nck and SHC SH2\t/\tSrc SH2|Fyn SH2|Lck SH2|Csk SH2|NCK SH2|SHC1 SH2\t/;
    s/\tSHC SH2\t/\tSHC_group SH2|SHC1 SH2|SHC2 SH2\t/;
    s/\tSrc,Lck and Fyn SH2\t/\tSrc SH2|Fyn SH2|Lck SH2\t/;
    /pY(M|L|E)EP/ s/\tSyk [CN]-terminal SH2\t/\tSYK SH2\t/;
    /pYESP/ s/\tVav SH2\t/\tVAV1 SH2|VAV2 SH2|VAV_group SH2\t/;
    s/\tCbl PTB\t/\tCBL PTB\t/;
    s/N.LpY\tDok1 PTB/N.LpY\tDOK_group PTB/;
    s/NP[.]pY\tShc PTB/NP.pY\tSHC1 PTB/;
    s/Shb PTB/SHB SH2/;
    s/Shb SH2/SHB SH2/;
    s/\tPTP1B, TC-PTP phosphatase\t/\tPTPN6 SH2|PTPN11 SH2\t/;
    
    s/#/-- The proteins dephosphorylated by PTP1B (PTN1_HUMAN) are:                                  /;
    s/#/--   O60674 P00519 P03372 P05556 P06213 P08581 P08922 P11274 P12931 P19235 P25963            /;
    s/#/--   P35568 P40763 P42229 P49841 P56945 Q9H1D0                                               /;
    s/#/-- as deduced by querying:                                                                   /;
    s/#/--   http:@@www.ebi.ac.uk@Tools@webservices@psicquic@mint@webservices@current@search@query@  /;
    s/#/-- for:                                                                                      /;
    s/#/--   id:P18031 AND taxidA:9606 AND taxidB:9606 AND type:"dephosphorylation reaction"         /;
    s/#/-- (i.e., convert @ signs to slashes and paste the query after the final slash)              /;
    s/#/-- However, the Amanchy patterns from HPRD for the PTP1B substes only match the phospho.ELM  /;
    s/#/-- sites of those proteins for:                                                              /;
    s/#/--    O60674 (JAK2_HUMAN)  Tyrosine-protein kinase JAK2 (Y-1007 and Y-1008)                  /;
    s/#/--    P06213 (INSR_HUMAN)  Insulin receptor (Y-1189 and Y-1190)                              /;
    s/#/--    P56945 (BCAR1_HUMAN) Breast cancer anti-estrogen resistance protein 1 (Y-664)          /;
    s/#/--    P08581 (MET_HUMAN)   Hepatocyte growth factor receptor (Y-1235)                        /;
    s/#/-- Therefore, I have decided to put this site into its own group, PTP1B (HPRD)               /;
    s/\tPTP1B phosphatase\t/\tPTP1B (HPRD)\t/;

    s/#/-- PP2B|Calcineurin|CaN (PP2BA_HUMAN) Q08209 is missing from phospho.ELM.  See the UniProt   /;
    s/#/--   entry and also PMIDs 19154138 and 3511054                                               /;
    s/\tPP2B\t/\tCalcineurin (HPRD)\t/;

    s/#/-- PMID  15807522 supports dephosphorylation of pT.pY that is essential for MAPK14           /;
    s/\tPP2C delta\t/\tWip1 O15297\t/;

    s/\tGRB2, 3BP2, Csk, Fes, Syk C-terminal SH2\t/\tFES SH2|SH3BP2 SH2|Csk SH2|GRB2 SH2|SYK SH2\t/;
    s/\tGRB7, GRB10 SH2\t/\tGRB7 SH2|GRB10 SH2\t/;
    s/\tSHP1, SHP2 SH2\t/\tSHP1 SH2|SHP2 SH2\t/;
    s/\tPLCgamma C and N-terminal SH2\t/\tPLCG1 SH2|SHP2 SH2\t/;
    s/\tSHP2, PLCgamma SH2s\t/\tPLCG1 SH2|SHP2 SH2\t/;
    s/Syk, ZAP-70, Shc, Lyn SH2/SYK SH2|SHC_group SH2|Lyn SH2|ZAP70/;
    s/\tSyk [CN]-terminal SH2\t/\tSYK SH2\t/;
    s/ [CN]-terminal SH2\t/ SH2\t/;
    s/\tVav SH2\t/\tVAV1 SH2|VAV2 SH2|VAV_group SH2\t/;
    s/\tTensin SH2\t/\tFES SH2|SH3BP2 SH2\t/;
    /pY(L|V)N(V|P)/ s/\tSem5 SH2\t/\tGRB2 SH2|STAT3 SH2\t/;
    s/\tLck and Src SH2\t/\tLck SH2|Src SH2\t/;
    s/\tNck SH2\t/\tNCK SH2\t/;
    s/\tItk SH2\t/\tITK SH2\t/;
    s/\tGrb2 SH2\t/\tGRB2 SH2\t/;
    s/\tSrc SH2\t/\tSrc SH2\t/;
    s/pYENP\tAbl SH2/pYENP\tABL1 SH2/;
    s/\tPI3 Kinase p85 SH2\t/\tPIK3R1 SH2\t/;
    s/\tCrk SH2\t/\tCRK SH2\t/g;
    s/\tFes SH2\t/\tFES SH2\t/g;
    s/\tFgr SH2\t/\tFGR SH2\t/g;
    s/\tCSK\t/\tCsk\t/g;
    s/\tHCP  SH2\t/\tHCP SH2\t/g;
    s/\tJNK\t/\tMAP2K7|MAP2K6\t/g;
    s/\tJNK1\t/\tJNK_group\t/g;
    s/\tSAP and EAT2 SH2\t/\tSH2D1A SH2|SH2D1B SH2\t/g;
    s/SHP1/PTPN6/;
    s/SHP2/PTPN11/;
    s/PTPN11 phosphatase/PTPN11 SH2/;
    s/PTPN11 CSH2/PTPN11 SH2/;
    s/PTPN6 phosphatase/PTPN6 SH2/;
    s/\tHCP SH2\t/\tPTPN6 SH2\t/;
    s/ phosphatase\([\t|]\)/ SH2\1/;
    s/\tSHIP2 SH2\t/\tPTPN11 SH2|PTPN6 SH2\t/;
    s/\t\(PTPR[HJ] SH2\)\t/\t\1 (HPRD)\t/;
    s/\t\(FGFR\)\t/\t\1 (HPRD)\t/;
    s/\tRasGAP SH2\t/\tRASA_group SH2\t/;
    s/\tTC-PTP SH2\t/\tTC-PTP SH2 (HPRD)\t/;

    s/$/\tHPRD/;
    ' $2
  foo='
    /Src,Lck and Fyn SH2/p;
    /pYESP/p;

  '
}

xform_hprd_motifs hprd_tyrosine_motifs.html         pY_amanchy.tabular
xform_hprd_motifs hprd_serine_motifs.html           pST_amanchy.tabular
sed -i -e 's/^/"/; s/$/"/; s/\t/"\t"/g;' pST_amanchy.tabular pY_amanchy.tabular

if [ ! -e phosphoelm_kin_bind_detail.tabular ]; then
  cut -f 3  pY_amanchy.tabular pST_amanchy.tabular | sed -e 's/"//g; s/[|]/\n/g' | sort | uniq > terms.grep
  cat \
    <(cut -f  5 phosphoelm_kin_bind_detail.tabular | sed -e '/^-$/ d') \
    <(cut -f 10 phosphoelm_kin_bind_detail.tabular | sed -e '/^-$/ d') \
    | sort | uniq > space.grep
  fi
