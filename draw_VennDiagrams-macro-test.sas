
Options notes nomprint nosymbolgen nomlogic nofmterr nosource nosource2 missing=' ' noquotelenmax linesize=max noBYLINE;
dm "output;clear;log;clear;odsresult;clear;";
proc delete data=_all_; run;
%macro rootpath;
%global program_path program_name;
%if %symexist(_SASPROGRAMFILE) %then %let _fpath=%qsysfunc(compress(&_SASPROGRAMFILE,"'"));
	%else %let _fpath=%sysget(SAS_EXECFILEPATH);
%let program_path=%sysfunc(prxchange(s/(.*)\\.*/\1/,-1,%upcase(&_fpath.)));
%let program_name=%scan(&_fpath., -2, .\);
%put NOTE: ----[program_path = &program_path.]----;
%put NOTE: ----[program_name = &program_name.]----;
%mend rootpath;
%rootpath;

%inc "&program_path.\draw_VennDiagrams-macro.sas";
/*Output styles settings*/
options nodate nonumber nobyline;
ods path work.testtemp(update) sasuser.templat(update) sashelp.tmplmst(read);

Proc template;
  define style trial;
    parent=styles.rtf;
    style table from output /
    background=_undef_
    rules=groups
    frame=void
    cellpadding=1pt;
  style header from header /
    background=_undef_
    protectspecialchars=off;
  style rowheader from rowheader /
    background=_undef_;

  replace fonts /
    'titlefont5' = ("courier new",9pt)
    'titlefont4' = ("courier new",9pt)
    'titlefont3' = ("courier new",9pt)
    'titlefont2' = ("courier new",9pt)
    'titlefont'  = ("courier new",9pt)
    'strongfont' = ("courier new",9pt)
    'emphasisfont' = ("courier new",9pt)
    'fixedemphasisfont' = ("courier new",9pt)
    'fixedstrongfont' = ("courier new",9pt)
    'fixedheadingfont' = ("courier new",9pt)
    'batchfixedfont' = ("courier new",9pt)
    'fixedfont' = ("courier new",9pt)
    'headingemphasisfont' = ("courier new",9pt)
    'headingfont' = ("courier new",9pt)
    'docfont' = ("courier new",9pt);

  style body from body /
    leftmargin=0.3in
    rightmargin=0.3in
    topmargin=0.3in
    bottommargin=0.3in;

  class graphwalls / 
            frameborder=off;
   end;
run;

******************************************************;
options source source2;

data venndata;
 infile datalines dsd truncover;
 input group:$50. group1:$50. makeA:$50. makeB:$50. makeC:$50. makeD:$50.;
datalines4;
BaseLine,BaseLine,,Ferrari2BCD,Ferrari2BCD,Ferrari2BCD
BaseLine,BaseLine,,Ferrari3BCD,Ferrari3BCD,Ferrari3BCD
BaseLine,BaseLine,,FerrariBCD,FerrariBCD,FerrariBCD
BaseLine,BaseLine,Acura,Acura2,Acura3,Acura4
BaseLine,BaseLine,Audi,Audi,Audi,Audi
BaseLine,BaseLine,BaseLine,BMW,BMW,BMW,BMW
BaseLine,BaseLine,Buick,Buick,Buick,Buick
BaseLine,BaseLine,Cadillac,Cadillac,Cadillac,Cadillac
BaseLine,BaseLine,Chevrolet,Chevrolet,Chevrolet,Chevrolet
BaseLine,BaseLine,Chrysler,Chrysler,Chrysler,Chrysler
BaseLine,BaseLine,Dodge,Dodge,Dodge,Dodge
BaseLine,BaseLine,Ferrari2ABD,Ferrari2ABD,,Ferrari2ABD
Vist 01,Vist 01,FerrariAB,FerrariAB,,
Vist 01,Vist 01,FerrariABC,FerrariABC,FerrariABC,
Vist 01,Vist 01,FerrariABD,FerrariABD,,FerrariABD
Vist 01,Vist 01,Ford,Ford,Ford,Ford
Vist 01,Vist 01,GMC,GMC,GMC,GMC
Vist 01,Vist 01,Honda,Honda,Honda,Honda
Vist 01,Vist 01,Hummer,Hummer,Hummer,Hummer
Vist 01,Vist 01,Hyundai,Hyundai,Hyundai,Hyundai
Vist 01,Vist 01,Infiniti,Infiniti,Infiniti,Infiniti
Vist 01,Vist 01,Isuzu,Isuzu,Isuzu,Isuzu
Vist 01,Vist 01,Jaguar,Jaguar,Jaguar,Jaguar
Vist 01,Vist 01,Jeep,Jeep,Jeep,Jeep
Vist 01,Vist 01,Kia,Kia,Kia,Kia
Vist 01,Vist 01,Land Rover,Land Rover,Land Rover,Land Rover
Vist 02,Vist 02,Lexus,Lexus,Lexus,Lexus
Vist 02,Vist 02,Lincoln,Lincoln,Lincoln,Lincoln
Vist 02,Vist 02,MINI,MINI,MINI,MINI
Vist 02,Vist 02,Mazda,Mazda,Mazda,Mazda
Vist 02,Vist 02,Mercedes-Benz,Mercedes-Benz,Mercedes-Benz,Mercedes-Benz
Vist 02,Vist 02,Mercury,Mercury,Mercury,Mercury
Vist 02,Vist 02,Mitsubishi,Mitsubishi,Mitsubishi,Mitsubishi
Vist 02,Vist 02,Nissan,Nissan,Nissan,Nissan
Vist 02,Vist 02,Oldsmobile,Oldsmobile,Oldsmobile,Oldsmobile
Vist 02,Vist 02,Pontiac,Pontiac,Pontiac,Pontiac
Vist 02,Vist 02,Porsche,,,Porsche
Vist 02,Vist 02,Porsche,Porsche,Porsche,Porsche
Vist 02,Vist 02,Saab,Saab,Saab,Saab
Vist 03,Vist 02,Saturn,Saturn,Saturn,Saturn
Vist 03,Vist 02,Scion,Scion,Scion,Scion
Vist 03,Vist 02,Subaru,Subaru,Subaru,Subaru
Vist 03,Vist 02,Suzuki,Suzuki,Suzuki,Suzuki
Vist 03,Vist 02,Toyota,Toyota,Toyota,Toyota
Vist 03,Vist 02,Volkswagen,Volkswagen,Volkswagen,Volkswagen
Vist 03,Vist 02,Volvo,Volvo,Volvo,Volvo
;;;;;
run;

************************;
%let _pageof=%str(Page (*ESC*){thispage} of (*ESC*){lastpage});
/*%let _pageof=%sysfunc(unicode(\u7B2C(*ESC*){thispage}\u9875 \u5171(*ESC*){lastpage}\u9875));*/
ods _all_ close;
title;footnote;
goption device=pdf;
options topmargin=0.3in bottommargin=0.3in leftmargin=0.3in rightmargin=0.3in;
options orientation=landscape nodate nonumber;
ods pdf file="&program_path.\draw_VennDiagrams-macro.pdf"  style=trial nogtitle nogfoot dpi=300;

ods graphics on; 
ods graphics /reset  noborder maxlegendarea=55  outputfmt =pdf height = 7 in width = 12in  attrpriority=none;
ods escapechar='^';
title1 height=9 pt j=l "draw_VennDiagrams" height=9 pt j=r "&_pageof.";

************ circle 2 ******************;
%draw_VennDiagrams(indat= venndata
					,groupVarls=  %str(makeA|makeB)
					,groupcd= %str(Group 01|Group 02)
					,byvar=group
					,byvarcd=
					,columns=3
					,bylabelopts=
					,circlesopts=
					,blocklabelopts=%str(ZEROBLKDISPLAY=Y/DISPLAY=STANDARD)
					,legendopts=
					,graphicsopts=%str(walldisplay=all)
					,add_annods=
				    ,debug=1) ;

************ circle 3 ******************;
%draw_VennDiagrams(indat= venndata
					,groupVarls=  %str(makeA|makeB|makec)
					,groupcd= %str(Group 01|Group 02|Group 03|Group 04)
					,byvar=group
					,byvarcd=
					,columns=3
					,bylabelopts=
					,circlesopts=
					,blocklabelopts=%str(ZEROBLKDISPLAY=Y/DISPLAY=STANDARD)
					,legendopts=
					,graphicsopts=%str(walldisplay=all)
					,add_annods=
				    ,debug=1) ;

************ circle 4 ******************;
%draw_VennDiagrams(indat= venndata
					,groupVarls=  %str(makeA|makeB|makec|maked)
					,groupcd= %str(Group 01|Group 02|Group 03|Group 04)
					,byvar=group
					,byvarcd=
					,columns=3
					,bylabelopts=
					,circlesopts=%STR(linecolorLS=CX000000)
					,blocklabelopts=%str(ZEROBLKDISPLAY=Y/DISPLAY=STANDARD)
					,legendopts=
					,graphicsopts=%str(walldisplay=all)
					,add_annods=
				    ,debug=1) ;

ods pdf close;
ods listing;
