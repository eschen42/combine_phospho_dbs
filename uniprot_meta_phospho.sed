#extract ID, AC, phosphosites, interactions, and GO from uniprot .dat file

s/ECO:[0-9|]\+//g;
s/ {PubMed:[0-9]\+, }//g;
s/ {}//g;

/^ID/ {
  h;
  s/.*Reviewed.*/DB sp/;
  s/.*Unreviewed.*/DB tr/;
  x;
  G;
  p;
  s/.*//;
  h;
  d;
  }

/^AC/ {
  H;
  d;
  }

/^DT/ {
  g;
  /^$/d;
  s/\nAC  //g;
  s/^/AC  /;
  p;
  s/.*//;
  h;
  d;
  }

/^DE/ {
  s/ {.*}//;
  p;
  d;
  }

/^GN/ {
  s/ {.*}//;
  x;
  G;
  s/^\n//;
  s/\nGN  //;
  x;
  d;
  }

/^OS/ {
  x;
  p;
  s/.*//;
  x;
  p;
  d;
  }

/^OX/ {
  p;
  d;
  }

/^DR   GO;/ {
  p;
  d;
  }

/^DR   Ensembl;/ {
  p;
  d;
  }

/^FT    / {
  x;
  /^$/ {
    x;
    d;
    }
  x;
  H;
  g;
  /^FT   MOD_RES.*[/]note="Phospho.*[/]evidence=".*"/ {
    s/\nFT [ ]*/ /g;
    s/"/'/g;
    p;
    s/.*//;
    h;
    }
  d;
  };
/^FT   MOD_RES/ {
  x;
  s/.*//;
  x;
  N;
  /[/]note="Phospho/{
    h;
    d;
    }
  d;
  };

/^CC   -/ {
  s/:/: /;
  s/:  /: /;
  x;
  /^$/! {
    /-!- ALTERNATIVE PRODUCTS:/ {
      s/\([^;]\)\nCC [ ]*/\1 /g;
      s/;\nCC         IsoId=/; IsoId=/g;
      s/CC       [ ]*/CC       /g;
      };
    /-!- INTERACTION:/! {
      /-!- ALTERNATIVE PRODUCTS:/! s/\nCC [ ]*/ /g;
      };
    s/"/'/g;
    s/[.][.]/./g;
    p;
    }
  s/.*//;
  x;
  /^CC   ---/ {
    N; N; N;
    d;
    };
  h;
  d;
  };

/^CC/ {
  H;
  d;
  };

/^SQ/ {
  p;
  s/.*//;
  h;
  }

/^  / {
  s/ //g;
  H;
  }
/^[/][/]/ {
  x;
  s/\n//g;
  p;
  x;
  p;
  s/.*//;
  h;
  d;
  }

d;
