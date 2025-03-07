/*************************************************************************************************
File name:      draw_VennDiagrams-macro.sas
 
Study:          NA
 
SAS version:    9.4
 
Purpose:        draw_VennDiagrams
 
Macros called:
 
Notes:
 
Parameters:
 
Sample:
 
Date started:    27MAY2024
Date completed:  
 
Mod     Date            Name            Description
---     -----------     ------------    -----------------------------------------------
1.0     27MAY2024       Xinwei.Zhong    Created
 
 
************************************ Prepared by hengrui************************************/

****** Check whether the variable exists *********;
%macro varlsexist(data=,varls=);
    %let dsid = %sysfunc(open(&data)); 
	%let _dsn=%eval(%sysfunc(count(&varls.,|))+1);
	%let noexistvar=;
    %if &dsid %then %do; 
	   %do _i_v=1 %to &_dsn.;
	   	   %let _var=%scan(&varls.,&_i_v.,|);
		   %global typ_&_var.;
	       %let varnum = %sysfunc(varnum(&dsid,&_var.));
	       %if &varnum.=0 %then %let noexistvar=%str(&noexistvar. &_var.);
		   	%else %let typ_&_var. = %sysfunc(vartype(&dsid., &varnum.));
	   %end;
	   %let rc = %sysfunc(close(&dsid));
    %end;%else %do;
       %put ERR%str()OR: Dataset[&data.] not exist, please check!!;
       %abort cancel;
    %end;
    %if %length(&noexistvar.)>0 %then %do;
       %put ERR%str()OR: Variable[&noexistvar.] not exist in dataset[&data.], please check!!;
       %abort cancel;
    %end;
%mend varlsexist;

****** deal with attribute default value *********;
%macro split_attrib(attrib_info=,info_ds=);
options noquotelenmax;
%if %length(%nrbquote(&attrib_info.))=0 %then %do;
	%put ERR%str()OR: Parameter[attrib_info] uninitialized, please check!!;
	%abort cancel;
%end;
%if %length(&info_ds.)=0 %then %let info_ds=%str(__split_attrib);
data &info_ds.(drop=_id1 _id2);
	length __info $2000. subcol $500. class attrib $32. attribval $200.;
	__info=tranwrd(tranwrd(tranwrd(tranwrd("%nrbquote(&attrib_info.)",'%/','$#@'),'%\','$##@'),'%|','*#@'),'%=','*##@');
	__info=tranwrd(tranwrd(__info,'%[','$###@'),'%]','$####@');
	if substr(__info,lengthn(__info),1)='|' then __info=substr(__info,1,lengthn(__info)-1);
	do classn=1 to (count(__info,'|')+1);
		_id1=prxparse('/(\w+)=\[([^\[\]]+)\]/');
		subcol=strip(scan(__info,classn,'|'));
		if prxmatch(_id1,subcol) then do;
			class=strip(upcase(prxposn(_id1, 1, subcol)));
			subcol=prxposn(_id1, 2, subcol);
		end; 
		if substr(subcol,lengthn(subcol),1)='/' then subcol=substr(subcol,1,lengthn(subcol)-1);
		start = 1; 
	    finish = length(subcol);
		_id2=prxparse('/(\w+)=([^\/\\]+)/');
	    do ord = 1 by 1 until(start > finish); 
	        call prxnext(_id2, start, finish, subcol, position, length); 
	        if position > 0 then do;
	            attrib = strip(upcase(prxposn(_id2, 1, subcol))); 
	            attribval = prxposn(_id2, 2, subcol); 
				attribval=tranwrd(tranwrd(tranwrd(tranwrd(tranwrd(tranwrd(attribval,'$#@','/'),'$##@','\'),'*#@','|'),'*##@','='),'$###@','['),'$####@',']');
	            output;
	        end;
	        else leave;
	    end;
	end;
run;
%mend split_attrib;

%macro attrib_vmacro(default_attrib=,set_attrib_info=,vmacro_prestr=,debug=);
%if %length(%nrbquote(&default_attrib.))=0 or %length(%nrbquote(&set_attrib_info.))=0 %then %do;
	%put ERR%str()OR: Parameter[default_attrib/set_attrib_info] uninitialized, please check!!;
	%abort cancel;
%end;
%split_attrib(attrib_info=%nrbquote(&default_attrib.),info_ds=%str(__default_attrib));
%split_attrib(attrib_info=%nrbquote(&set_attrib_info.),info_ds=%str(__split_attrib));
%if %length(&debug.)=0 %then %let debug=0;

proc sql undo_policy=none;
	create table __attribval as select a.class,b.class as class0,a.ord,b.ord as ord0
		,a.attrib,b.attrib as attrib0,a.attribval as defaultval,b.attribval
		from __default_attrib as a
		left join __split_attrib as b on a.class=b.class and a.attrib=b.attrib
		order by a.classn,a.class,a.ord;
quit; 
data __attribval;
	set __attribval;
	if attribval='' then do;
		attribval=defaultval; impute=1;
	end;
	length vmacroname $50.;
	vmacroname=cats(class,"_&vmacro_prestr.",attrib);
	if lengthn(vmacroname)>32 then put "ERR" "OR:" vmacroname= "macro variable is too long!";
	call symputx(vmacroname,attribval,'g');
run;
%if "&debug."="0" %then %do;
	proc datasets nolist;
		delete __split_attrib: __default_attrib:;
	quit;
%end;
%mend attrib_vmacro;

****************************;
%macro draw_VennDiagrams(indat= 
					,groupVarls=
					,groupcd=
					,byvar=
					,byvarcd=
					,columns=
					,circlesopts=
					,blocklabelopts=
					,legendopts=
					,bylabelopts=
					,graphicsopts=
					,add_annods=
					,plotyn=
				    ,debug=) / minoperator;

%put NOTE: -------------------- Macro[&SYSMACRONAME.] Start --------------------;
*****parameter control****;
%if %length(&indat.)=0 or %length(&groupVarls.)=0 %then %do;
	%put ERR%str()OR: Parameter[indat/groupVarls] uninitialized, please check!!;
	%return;
%end;
%if %sysfunc(exist(&indat.))=0 %then %do;
	%put ERR%str()OR: DataSet[indat = &indat.] no exist, please check!!;
	%return;
%end;

data _null_;
	length groupVarls $200.;
	groupVarls=tranwrd("&groupVarls.",'#','|');
	if substr(strip(groupVarls),1,1)='|' then groupVarls=substr(strip(groupVarls),2);
	if substr(strip(groupVarls),lengthn(strip(groupVarls)),1)='|' then groupVarls=substr(strip(groupVarls),1,lengthn(strip(groupVarls))-1);
	call symputx('groupVarls',groupVarls);
run;

%let _varls=%str(&groupVarls.);
%if %length(&byvar.)>0 %then %let _varls=%str(&groupVarls.|&byvar.);

%varlsexist(data=%str(&indat.),varls=%str(&_varls.));

************************************************************************;
********** circlesopts ***********;
%attrib_vmacro(vmacro_prestr=%str(cle_),set_attrib_info=%nrbquote(C=[&circlesopts.]),
default_attrib=%nrbquote(C=[display=all/FILLCOLORLS=%str(CXFF0000#CX0000FF#CX00FF00#CXFFFF00)/FILLTRANSPARENCY=0.7
/TRANSPARENCY=0/LINECOLORLS=%str(CXFF0000#CX0000FF#CX00FF00#CXFFFF00)/LINETHICKNESS=1/LINEPATTERN=1]));
data __attribval_all;
	set __attribval(keep=vmacroname attribval);
run;

********** blocklabelopts ***********;
%attrib_vmacro(vmacro_prestr=%str(blk_),set_attrib_info=%nrbquote(B=[&blocklabelopts.]),
default_attrib=%nrbquote(B=[zeroblkdisplay=Y/display=STANDARD/TEXTCOLOR=black/TEXTFONT=Arial%/SimSun/TEXTSIZE=9/TEXTWEIGHT=bold/FSTYLE=NORMAL]));
data __attribval_all;
	set __attribval_all __attribval(keep=vmacroname attribval IMPUTE);
run;

********** legendopts ***********;
%attrib_vmacro(vmacro_prestr=%str(lgd_),set_attrib_info=%nrbquote(L=[&legendopts.]),
default_attrib=%nrbquote(L=[display=Y/X=-1/Y=-1/BORDER=FALSE/WIDTH=20/TEXTCOLOR=black/TEXTFONT=Arial%/SimSun/TEXTSIZE=9/TEXTWEIGHT=bold/FSTYLE=NORMAL]));
data __attribval_all;
	set __attribval_all __attribval(keep=vmacroname attribval IMPUTE);
run;

%if %length(&plotyn.)=0 %then %let plotyn=%str(Y);
%let plotyn=%upcase(%substr(&plotyn.,1,1));
%if %length(&debug.)=0 %then %let debug=%str(0);

**************************************************************************************;
data __indat;
	set &indat.;
	%if %length(&byvar.)>0 %then %do;
	length __&byvar. $200.;
	__&byvar.=strip(vvalue(&byvar.));
	%end;
run;
data __gvar(where=(var>''));
	length var $32. label $200.;
	%do _i=1 %to %eval(%sysfunc(count(&groupVarls.,|))+1);
		var="%scan(&groupVarls.,&_i.,|)"; label="%scan(&groupcd.,&_i.,|)"; 
		if label='' then label=var; output;
	%end;
run;
proc sql noprint;
	select count(*) into: __gvarn trimmed from __gvar;
	select var,label into: __gvar1-:__gvar&__gvarn.,: __glabel1-:__glabel&__gvarn. from __gvar;
quit;
%if &__gvarn.<2 or &__gvarn.>4 %then %do;
	%put ERR%str()OR: The number of variables in parameter[groupVarls] must be between 2 and 4, please check!!;
	%return;
%end;

%if %length(&byvar.)>0 %then %do;
	%if %length(&byvarcd.)>0 %then %do;
		%let _xaxisn=%eval(%sysfunc(countc(&byvarcd.,%str(#| )))+1);
		data __gr(where=(__&byvar.>''));
			length __&byvar. $200.;
			%do _i=1 %to &_xaxisn.;
				__grn=&_i.; __&byvar.="%scan(&byvarcd.,&_i.,#|)"; output;
			%end;
		run;
	%end;%else  %do;
		proc sort data =__indat out = __gr(keep=&byvar.) nodupkey;
			where ^missing(&byvar.);
		    by &byvar.;
		run;
		data __gr;
			set __gr;
			by &byvar.;
			retain __grn 0;
			__grn+1;
			length __&byvar. $200.;
			__&byvar.=strip(vvalue(&byvar.));
		run;
	%end;
	%let __chk_gr=0;
	proc sql undo_policy=none noprint;
		create table __indat as select a.*,b.__grn from __indat as a
			left join __gr as b on strip(a.__&byvar.)=strip(b.__&byvar.);
		create table __chk_gr as select * from __indat where __grn=.;
		select count(*) into: __chk_gr from __chk_gr;
	quit;
	%if &__chk_gr.>0 %then %do;
		%put ERR%str()OR: The [byvar]grouping information does not match. Please check the dataset [__chk_gr]!!!;
		%return;
	%end;

proc sql noprint;
    select count(*) into : _xaxisn trimmed from __gr;
quit;
%end; %else %do;
%let _xaxisn=1;
%let byvar=__dummy_gr;
data __indat;
	set &indat.;
	__dummy_gr='dummy';
	__grn=1;
run;
%end;

%let bylabelyn=N;
********** graphicsopts ***********;
%if %length(&columns.)=0 %then %let columns=%str(&_xaxisn.);
%let rows=%sysfunc(ceil(%sysevalf(&_xaxisn./&columns.)));

%let _height=14;   %let _width =14;
%let _dxaxismax=50; %let _dyaxismax=50;
%let _xaxismax=&_dxaxismax.; %let _yaxismax=&_dyaxismax.;

%if &_xaxisn.>1 %then %do;
	%if &columns.>&rows. %then %do;
		%let _width =%sysevalf(&_width.*&columns.);
		%if &_width.>28 %then %do;
			%let _height=%sysevalf(28/&columns.);
			%let _width =28;
		%end;
		%let _height =%sysevalf(&_height.*&rows.);
	%end; %else %do;
		%let _height =%sysevalf(&_height.*&rows.);
		%if &_height.>28 %then %do;
			%let _width=%sysevalf(28/&rows.);
			%let _height =28;
		%end;
		%let _width =%sysevalf(&_width.*&columns.);
	%end;
	%let bylabelyn=Y;
	%let _xaxismax=%sysevalf(&_xaxismax.*&columns.);
	%let _yaxismax=%sysevalf(&_yaxismax.*&rows.);
%end;
%attrib_vmacro(vmacro_prestr=%str(GRP_),set_attrib_info=%nrbquote(G=[&graphicsopts.]),
default_attrib=%nrbquote(G=[height=&_height.cm/width=&_width.cm/walldisplay=none]));
data __attribval_all;
	set __attribval_all __attribval(keep=vmacroname attribval IMPUTE);
run;

********** bylabelopts ***********;
%attrib_vmacro(vmacro_prestr=%str(BYLB_),set_attrib_info=%nrbquote(P=[&bylabelopts.]),
default_attrib=%nrbquote(P=[display=&bylabelyn./Y=97/BORDER=FALSE/WIDTH=20/TEXTCOLOR=black/TEXTFONT=Arial%/SimSun/TEXTSIZE=9/TEXTWEIGHT=bold/FSTYLE=NORMAL]));
data __attribval_all;
	set __attribval_all __attribval(keep=vmacroname attribval IMPUTE);
run;

***************************************************************************;
proc sql;
%do _i=1 %to &__gvarn.;
	create table __tab&_i. as select __grn,&byvar.,&&__gvar&_i. as make,count(*) as num&_i. 
		from __indat group by __grn,&byvar.,&&__gvar&_i.;
%end;
quit;

data __tab;
	merge __tab1-__tab&__gvarn.;
	by __grn &byvar. make;
	if make>'';
	if n(of num:)>0 then sum=sum(of num:);
run;

%*********************Count the number of people in each block **************************************;
%let __vdblkvarls=;
%macro set_mvar(where=,grn=);
proc sql noprint;
	create table __tab_ as select __grn,&byvar.,count(*) as num from __tab where &where. group by __grn,&byvar.;
quit;
%do _i=1 %to &_xaxisn.; %global _num&grn._&_i.; %let _num&grn._&_i.=0; %let __vdblkvarls=%str(&__vdblkvarls. _num&grn._&_i.); %end;
data _null_;
	set __tab_;
	call symputx(cats("_num&grn._",__grn),put(num,best.));
run;
%mend set_mvar;
%if &__gvarn.=2 %then %do;
%set_mvar(where=%str(num1>. and missing(num2)),grn=1);
%set_mvar(where=%str(missing(num1) and num2>.),grn=2);
%set_mvar(where=%str(num1>. and num2>.),grn=12);
%end;%else %if &__gvarn.=3 %then %do;
%set_mvar(where=%str(num1>. and n(num2,num3)=0),grn=1);
%set_mvar(where=%str(num2>. and n(num1,num3)=0),grn=2);
%set_mvar(where=%str(num3>. and n(num1,num2)=0),grn=3);
%set_mvar(where=%str(missing(num3) and n(num1,num2)=2),grn=12);
%set_mvar(where=%str(missing(num2) and n(num1,num3)=2),grn=13);
%set_mvar(where=%str(missing(num1) and n(num2,num3)=2),grn=23);
%set_mvar(where=%str(n(num1,num2,num3)=3),grn=123);
%end;%else %if &__gvarn.=4 %then %do;
%set_mvar(where=%str(num1>. and n(num2,num3,num4)=0),grn=1);
%set_mvar(where=%str(num2>. and n(num1,num3,num4)=0),grn=2);
%set_mvar(where=%str(num3>. and n(num1,num2,num4)=0),grn=3);
%set_mvar(where=%str(num4>. and n(num1,num2,num3)=0),grn=4);
%set_mvar(where=%str(n(num1,num2)=2 and n(num3,num4)=0),grn=12);
%set_mvar(where=%str(n(num1,num3)=2 and n(num2,num4)=0),grn=13);
%set_mvar(where=%str(n(num1,num4)=2 and n(num2,num3)=0),grn=14);
%set_mvar(where=%str(n(num2,num3)=2 and n(num1,num4)=0),grn=23);
%set_mvar(where=%str(n(num2,num4)=2 and n(num1,num3)=0),grn=24);
%set_mvar(where=%str(n(num3,num4)=2 and n(num1,num2)=0),grn=34);
%set_mvar(where=%str(missing(num4) and n(num1,num2,num3)=3),grn=123);
%set_mvar(where=%str(missing(num3) and n(num1,num2,num4)=3),grn=124);
%set_mvar(where=%str(missing(num2) and n(num1,num3,num4)=3),grn=134);
%set_mvar(where=%str(missing(num1) and n(num2,num3,num4)=3),grn=234);
%set_mvar(where=%str(n(num1,num2,num3,num4)=4),grn=1234);
%end;

%if "&debug."="0" %then %do;
	proc datasets nolist;
		delete __tab: __gvar  __indat;
	quit;
%end;
%let _B_blk_DISPLAY=all;
%if "%upcase(%substr(&B_blk_DISPLAY.,1,1))"="N" %then %do;
	%let B_blk_DISPLAY=none;
%end;%else %do;
	%let _B_blk_DISPLAY=&B_blk_DISPLAY.;
%end;

proc template;
define statgraph draw_circles; 
	begingraph/DESIGNHEIGHT=&G_GRP_HEIGHT. DESIGNWIDTH=&G_GRP_WIDTH. AXISLINEEXTENT=FULL pad=0;
	layout overlay / walldisplay=&G_GRP_WALLDISPLAY.
		xaxisopts=(display=none offsetmin=0 offsetmax=0 linearopts=(viewmin=0 viewmax=&_xaxismax.
					tickvaluesequence=(start=0 end=&_xaxismax. increment=5)) ) 
		yaxisopts=(display=none offsetmin=0 offsetmax=0 linearopts=(viewmin=0 viewmax=&_yaxismax.
					tickvaluesequence=(start=0 end=&_yaxismax. increment=5)) ) 
		;
		annotate / id="myid"; 
		textplot x=x y=y text=text/display=&_B_blk_DISPLAY. textattrs=(color=&B_blk_TEXTCOLOR. 
			family="&B_blk_TEXTFONT." size=&B_blk_TEXTSIZE. style=&B_blk_FSTYLE. weight=&B_blk_TEXTWEIGHT.);
	endlayout;
	endgraph;
end;
run;

%let radius=16;
%if &__gvarn.=2 %then %let radius=16;
%let interval=50;
%let x1=22;
%let y1=25;
%if &__gvarn.=3 %then %let y1=30;
%if &__gvarn.=4 %then %let y1=20;
%let y1=%sysevalf((&rows.-1)*&_dyaxismax.+&y1.);
/*%put &=y1.;*/

data __anno_oval;
	length oval_type function id x1space y1space display widthunit heightunit fillcolor linecolor linepattern $50.;
    function="oval"; id="myid"; x1space="datavalue"; y1space="datavalue";
    LINETHICKNESS=&C_cle_LINETHICKNESS.; display="&C_cle_DISPLAY.";
    width=&radius.*sqrt(3); widthunit="DATA"; height=&radius.*sqrt(3); heightunit="DATA";
    filltransparency=&C_cle_FILLTRANSPARENCY.; linepattern="&C_cle_LINEPATTERN.";
	transparency=&C_cle_TRANSPARENCY.;
******* circles  **********;
	oval_type='circles';
	%let _yadd=0;
	%let _rown=1;
%do _i=1 %to &_xaxisn.;
	_xaxisn=&_i.;
	%let _ii=%sysfunc(mod(&_i.,&columns.));
	%if &_ii.=0 %then %let _ii=&columns.;
	%if &_ii.=1 and &_i.^=1 %then %do; %let _yadd=%sysevalf(&_yadd.+&_dyaxismax.); %let _rown=%eval(&_rown.+1); %end;
	%let interval1=%sysevalf(&interval.*%sysevalf(&_ii.-1));
	rown=&_rown.; coln=&_ii.;
	%if &__gvarn.=2 or &__gvarn.=3 %then %do;
	    circle=1; x1=&radius.+2+&interval1.;   y1=&y1.-&_yadd.; fillcolor="%scan(&C_cle_FILLCOLORLS.,1,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,1,|#)"; output;
	    circle=2; x1=&radius.*2+2+&interval1.; y1=&y1.-&_yadd.; fillcolor="%scan(&C_cle_FILLCOLORLS.,2,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,2,|#)"; output;
		%if &__gvarn.=3 %then %do;
		    circle=3; x1=&radius.+(&radius./2)+2+&interval1.; y1=&y1.-(&radius./2)*sqrt(3)-&_yadd.; 
				fillcolor="%scan(&C_cle_FILLCOLORLS.,3,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,3,|#)"; output;
		%end;
	%end; %else %do;
		width=13;height=32;
		circle=1; x1=(&x1.-6)+&interval1.; y1=&y1.-&_yadd.; fillcolor="%scan(&C_cle_FILLCOLORLS.,1,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,1,|#)"; ROTATE=45; output;
		circle=2; x1=(&x1.)+&interval1.; y1=&y1.+5-&_yadd.; fillcolor="%scan(&C_cle_FILLCOLORLS.,2,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,2,|#)"; ROTATE= 25; output;
		circle=3; x1=(&x1.+5)+&interval1.; y1=&y1.+5-&_yadd.; fillcolor="%scan(&C_cle_FILLCOLORLS.,3,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,3,|#)"; ROTATE=335; output;
		circle=4; x1=(&x1.+11)+&interval1.; y1=&y1.-&_yadd.; fillcolor="%scan(&C_cle_FILLCOLORLS.,4,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,4,|#)"; ROTATE= 315; output;
	%end;
%end;

********** legend circles *************;
%if "%upcase(%substr(&L_lgd_DISPLAY.,1,1))"="Y" %then %do;
	oval_type='legend'; rown=.; coln=.; _xaxisn=.;
	%if &L_lgd_X.>0 %then %let _legend_X=%str(&L_lgd_X.);
		%else %do;
			%let _legend_X=%sysevalf(&radius.*2+8.5+&interval1.);
			%if &_xaxisn.>1 and &interval1.>0 %then %let _legend_X=%sysevalf(&_legend_X.-&interval.);
		%end;
	%if &L_lgd_y.>0 %then %let _legend_y=%str(&L_lgd_y.);
		%else %do;
			%let _legend_y=7; 
			%if &__gvarn.=3 %then %let _legend_y=7;
			%if &__gvarn.=4 %then %let _legend_y=9.5;
		%end;
	%if &__gvarn.=2 or &__gvarn.=3 %then %do;
		%let lgd_multiple=0.07;
		%if &__gvarn.=2 %then %let lgd_multiple=0.07;
		width=&radius.*sqrt(3)*&lgd_multiple.;height=&radius.*sqrt(3)*&lgd_multiple.; LINETHICKNESS=&C_cle_LINETHICKNESS.&0.6;
		call symputx('lgd_width',put(max(width),10.7));
		circle=1; x1=&_legend_X.; y1=%sysevalf(&_legend_y.); fillcolor="%scan(&C_cle_FILLCOLORLS.,1,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,1,|#)"; output;
		circle=2; x1=&_legend_X.; y1=%sysevalf(&_legend_y.-2.5); fillcolor="%scan(&C_cle_FILLCOLORLS.,2,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,2,|#)"; output;
		%if &__gvarn.=3 %then %do;
			circle=3; x1=&_legend_X.; y1=%sysevalf(&_legend_y.-5); fillcolor="%scan(&C_cle_FILLCOLORLS.,3,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,3,|#)"; output;
		%end;
	%end;
	%if &__gvarn.=4 %then %do;
		width=width*0.06;height=height*0.06; LINETHICKNESS=&C_cle_LINETHICKNESS.&0.6;
		call symputx('lgd_width',put(max(width),10.7));
		circle=1; x1=&_legend_X.; y1=%sysevalf(&_legend_y.); ROTATE= 45; fillcolor="%scan(&C_cle_FILLCOLORLS.,1,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,1,|#)"; output;
		circle=2; x1=&_legend_X.; y1=%sysevalf(&_legend_y.-2.5); ROTATE= 25; fillcolor="%scan(&C_cle_FILLCOLORLS.,2,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,2,|#)"; output;
		circle=3; x1=&_legend_X.; y1=%sysevalf(&_legend_y.-5); ROTATE= 335; fillcolor="%scan(&C_cle_FILLCOLORLS.,3,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,3,|#)"; output;
		circle=4; x1=&_legend_X.; y1=%sysevalf(&_legend_y.-7.5); ROTATE= 315; fillcolor="%scan(&C_cle_FILLCOLORLS.,4,|#)"; linecolor="%scan(&C_cle_LINECOLORLS.,4,|#)"; output;
	%end;
%end;
run;
data __anno_text;
	_xaxisn=0;
run;
%if "%upcase(%substr(&P_BYLB_DISPLAY.,1,1))"="Y" %then %do;
%let bylabely=&P_BYLB_Y.;
data __anno_text;
	set __gr;
	length oval_type function id x1space y1space ANCHOR BORDER TEXTCOLOR TEXTFONT TEXTSTYLE TEXTWEIGHT label $50.;
    function="text"; id="myid"; x1space="wallpercent"; y1space="wallpercent";
    ANCHOR="center"; BORDER="&P_BYLB_BORDER."; WIDTH=&P_BYLB_WIDTH.;
	TEXTCOLOR="&P_BYLB_TEXTCOLOR."; TEXTSIZE=&P_BYLB_TEXTSIZE.;
	TEXTFONT="&P_BYLB_TEXTFONT."; TEXTSTYLE="&P_BYLB_FSTYLE."; TEXTWEIGHT="&P_BYLB_TEXTWEIGHT.";
	oval_type='bylabel'; label=strip(vvalue(__group));
	_xaxisn=__grn; 
	coln=mod(__grn,&columns.);
	if coln=0 then coln=&columns.;
	rown=ceil(__grn/&columns.);
	y1=&bylabely.-(100/&rows.)*(ceil(__grn/&columns.)-1);
	x1=(100/&columns.)*(coln-1)+(100/&columns.)/2; 
run;
%end;
%if "%upcase(%substr(&L_lgd_DISPLAY.,1,1))"="Y" %then %do;
data __anno_lgd_text;
	length oval_type function id x1space y1space ANCHOR BORDER TEXTCOLOR TEXTFONT TEXTSTYLE TEXTWEIGHT label $50.;
    function="text"; id="myid"; x1space="datavalue"; y1space="datavalue";
    ANCHOR="left"; BORDER="&L_lgd_BORDER."; WIDTH=&L_lgd_WIDTH.;
	TEXTCOLOR="&L_lgd_TEXTCOLOR."; TEXTSIZE=&L_lgd_TEXTSIZE.;
	TEXTFONT="&L_lgd_TEXTFONT."; TEXTSTYLE="&L_lgd_FSTYLE."; TEXTWEIGHT="&L_lgd_TEXTWEIGHT.";
	oval_type='legend_text';
	circle=1; x1=&_legend_X.+ceil(&lgd_width./2)+1; y1=%sysevalf(&_legend_y.); label="&__glabel1."; output;
	circle=2; x1=&_legend_X.+ceil(&lgd_width./2)+1; y1=%sysevalf(&_legend_y.-2.5); label="&__glabel2."; output;
	%if &__gvarn.=3 or &__gvarn.=4 %then %do;
		circle=3; x1=&_legend_X.+ceil(&lgd_width./2)+1; y1=%sysevalf(&_legend_y.-5); label="&__glabel3."; output;
	%end;
	%if &__gvarn.=4 %then %do;
		circle=4; x1=&_legend_X.+ceil(&lgd_width./2)+1; y1=%sysevalf(&_legend_y.-7.5); label="&__glabel4."; output;
	%end;
run;
%end;
data __anno_text;
	set __anno_text %if "%upcase(%substr(&L_lgd_DISPLAY.,1,1))"="Y" %then %do;
		__anno_lgd_text
	%end;;
run;
data __final;
	length block $50.;
%if "%upcase(&B_blk_DISPLAY.)"^="NONE" %then %do;
	%let _yadd=0; %let _rown=1;
	%do _i=1 %to &_xaxisn.;
		_xaxisn=&_i.;
		%let _ii=%sysfunc(mod(&_i.,&columns.));
		%if &_ii.=0 %then %let _ii=&columns.;
		%if &_ii.=1 and &_i.^=1 %then %do; %let _yadd=%sysevalf(&_yadd.+&_dyaxismax.); %let _rown=%eval(&_rown.+1); %end;
		%let interval1=%sysevalf(&interval.*%sysevalf(&_ii.-1));
		rown=&_rown.; coln=&_ii.;
/*		%put &=_yadd.;*/
		%if &__gvarn.=2 or &__gvarn.=3 %then %do;
			%let yadd=0;
			%if &__gvarn.=3 %then %let yadd=2;
			block='1';  x=&radius.-4+&interval1.; y=&y1.+&yadd.-&_yadd.; num=&&_num1_&_i..; output;
			block='2';  x=&radius.*2+6+&interval1.; y=&y1.+&yadd.-&_yadd.; num=&&_num2_&_i..; output;
			block='12'; x=&radius.+(&radius./2)+2+&interval1.; y=&y1.+&yadd.*2-&_yadd.; num=&&_num12_&_i..; output;
		%end;
		%if &__gvarn.=3 %then %do;
			block='3';   x=&radius.+(&radius./2)+2+&interval1.; y=&y1.-(&radius./2)*sqrt(3)-&yadd.*2-&_yadd.; num=&&_num3_&_i..; output;
			block='13';  x=&radius.+2+&interval1.; y=&y1.-&yadd.*4.5-&_yadd.; num=&&_num13_&_i..; output;
			block='23';  x=&radius.*2+2+&interval1.; y=&y1.-&yadd.*4.5-&_yadd.; num=&&_num23_&_i..; output;
			block='123'; x=&radius.+(&radius./2)+2+&interval1.; y=&y1.-&yadd.*2.5-&_yadd.; num=&&_num123_&_i..; output;
		%end;
		%if &__gvarn.=4 %then %do; %let yadd=0;
			block='1'; x=(&x1.-6)-6+&interval1.; y=(&y1.)+4-&_yadd.; num=&&_num1_&_i..; output;
			block='2'; x=(&x1.)-4+&interval1.; y=(&y1.+5)+8-&_yadd.; num=&&_num2_&_i..; output;
			block='3'; x=(&x1.+5)+3+&interval1.; y=(&y1.+5)+8-&_yadd.; num=&&_num3_&_i..; output;
			block='4'; x=(&x1.+11)+5+&interval1.; y=(&y1.)+4-&_yadd.; num=&&_num4_&_i..; output;

			block='12'; x=(&x1.-6)+1+&interval1.; y=(&y1.)+5-&_yadd.; num=&&_num12_&_i..; output;
			block='13'; x=(&x1.)-2.5+&interval1.; y=(&y1.)-6-&_yadd.; num=&&_num13_&_i..; output;
			block='14'; x=(&x1.+5)-3+&interval1.; y=(&y1.)-11-&_yadd.; num=&&_num14_&_i..; output;
			block='23'; x=(&x1.+5)-1.5+&interval1.; y=(&y1.)+6-&_yadd.; num=&&_num23_&_i..; output;
			block='24'; x=(&x1.+5)+2.5+&interval1.; y=(&y1.)-6-&_yadd.; num=&&_num24_&_i..; output;
			block='34'; x=(&x1.+5)+4.5+&interval1.; y=(&y1.)+5-&_yadd.; num=&&_num34_&_i..; output;

			block='123'; x=(&x1.)-1+&interval1.; y=(&y1.)-&_yadd.; num=&&_num123_&_i..; output;
			block='124'; x=(&x1.+5)-0.2+&interval1.; y=(&y1.)-8.5-&_yadd.; num=&&_num124_&_i..; output;
			block='134'; x=(&x1.+5)-4.8+&interval1.; y=(&y1.)-8.4-&_yadd.; num=&&_num134_&_i..; output;
			block='234'; x=(&x1.+5)+1+&interval1.; y=(&y1.)-&_yadd.; num=&&_num234_&_i..; output;

			block='1234'; x=(&x1.+5)-2.5+&interval1.; y=(&y1.)-5.5-&_yadd.; num=&&_num1234_&_i..; output;
		%end;
	%end;
%end;%else %do;
	_xaxisn=0; block='0'; x=-50; y=-50; num=99; output;
%end;
run;
data plot_final;
	retain rown coln _xaxisn block;
	set __final;
	length text $200.;
	text=strip(vvalue(num)); 
	%if "%upcase(%substr(&B_blk_ZEROBLKDISPLAY.,1,1))"^="Y" %then %do;
		if num=0 then delete;
	%end;
run;

data plot_anno;
	retain rown coln _xaxisn circle;
	set __anno_oval(in=a) __anno_text &add_annods.;
	if a then do;
		if fillcolor='' then do;
			fillcolor='CX000000'; linecolor=fillcolor;
		end;
	end;
run;

%if "&plotyn."="Y" or "&plotyn."="1" %then %do;
ods graphics/height=&G_GRP_HEIGHT. width=&G_GRP_WIDTH.;
proc sgrender data=plot_final template=draw_circles sganno=plot_anno;
run;
%end;

********* delete global macro varibale *********;
proc sql noprint;
	select strip(vmacroname) into : _drpmvarls separated by ' ' from __attribval_all;
quit;

%symdel &_drpmvarls. &__vdblkvarls.;

%if "&debug."="0" %then %do;
	proc datasets nolist;
		delete __final: __anno: __gr __attribval: __chk_gr;
	quit;
%end;
%put NOTE: -------------------- Macro[&SYSMACRONAME.] End --------------------;
%mend draw_VennDiagrams;
