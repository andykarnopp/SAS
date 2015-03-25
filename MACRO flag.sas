/*
MACRO flag

Generalized Flagging Macro - SAS Global Forum 2015 session 1340
Using SAS® Macros to Flag Claims Based on Medical Codes
Andy Karnopp

This macro brings together the code from all the examples. 
It assumes you have a code list named CODES with variables code, codetype, codefrom, codeto, and flagtype. 
It uses dedicated macro variables, one for each code, up to 999 codes. 
An argument named flagset is used for the dataset name.

Usage: %flag(icd9px, 3, Chemo, CLAIMS)
*/

%macro flag(codetype, codecount, flagtype, flagset);

*load codes and valid dates for this flag type and code type;

proc sql noprint;
 select code, codefrom, codeto into 
  :code1-:code999,
  :from1-:from999,
  :to1-:to999
 from CODES
 where flagtype="&flagtype" and codetype="&codetype";
quit;

*only load the claims if codes were returned;
%if &sqlObs > 0 %then %do;	
%put ***** Checking claims using a list of &sqlObs &codetype &flagtype codes;

*load the claims;
data &flagset (compress=yes drop=codecounter claimcounter _claimcounter);
  set &flagset end=end;

  retain codecounter;	   *keep track of the number of codes that match;	
  retain claimcounter;   *keep track of the number of claims that match;	
  _claimcounter = 0; 	   *flag used by the claimcounter;

  *loop through each code and each variable;	
  *check if the code matches, and if it has time-dependency;
  *if the code matches flag the claim and update the counters;	
   %do j= 1 %to &codecount;
     %do k= 1 %to &sqlObs;
        if (
               (&codetype&j = "&&code&k") and 
               (	
               ("&&from&k."d eq .) or 
               (("&&from&k."d ne .) and 
				("&&from&k."d <= claimdate <= "&&to&k."d))
               )	
          )
          then do;
               _&flagtype=1;					
               if _claimcounter = 0 then _claimcounter = 1;
               if codecounter eq . then codecounter = 1;
                  else codecounter=codecounter+1; 
          end;
   %end;
  %end;
  
*increment the claim counter before loading the next observation;  
if _claimcounter = 1 then do;
   if claimcounter eq . then claimcounter=1; 
   else claimcounter=claimcounter+1;
end;

*write the number of claims and codes to the log if this observation is the last;
if end=1 then do;
   if codecounter ne . then 
    put "***** " codecounter "&codetype &flagtype codes found"; 
    else put "WARNING: No &codetype &flagtype codes were found in the claims"; 
   if claimcounter ne . then 
    put "***** " claimcounter "&codetype &flagtype claims flagged";
end;

run;	
	
*this ends the loop if codes were returned from the code list;
*if no codes were in the code list, log a warning;

%end;

%else %put WARNING: No &codetype &flagtype codes are in the code list; 

*log a final count of the claims flagged;

proc sql noprint;
  select count(*) into :claimsum from &flagset where _&flagtype=1;
  %put ***** %cmpres(&claimsum) claims are currently flagged for &flagtype;
quit;

%mend flag;
