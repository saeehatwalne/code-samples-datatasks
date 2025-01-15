*Saee Hatwalne
*hatwalne.saee@gmail.com
*Coding sample
*Uses the NSS-61 data

global pathin = "/Users/saeehatwalne/Desktop/NSS 61/data"
global pathout = "/Users/saeehatwalne/Desktop/output"
global pathtemp = "/Users/saeehatwalne/Desktop/temp"

clear all

********************************************************************************
*        Getting the multipliers and svyset
********************************************************************************
clear all
use "$pathin/level01.dta"

*destring required variables
destring multiplier nss nsc, replace
recast long nss nsc

*combined multiplier: referred to documentation
gen pweight = multiplier/100 if nss == nsc
replace pweight = multiplier/200 if nss != nsc

*first stage strata variable
gen first_stage_strata = state_region + sector + stratum_number + sub_stratum
lab var first_stage_strata "first stage strata"

*survey information
svyset lot_fsu_number [pw = pweight], strata(first_stage_strata) singleunit(centered)
//reference about this first stage strata variable mentioned in the writeup

********************************************************************************
*        Q1 (i): Avg. monthly per capita expenditure
********************************************************************************

*destring requried variables
destring common_id hh_size, replace
destring mpce_30_days, gen(mpce)
recast long hh_size

//state_region has subregions within a state as well
//so preparing one separate state variable, with only states (not regions)
//referred to state codes document
gen temp = substr(state_region, 1, strlen(state_region) - 1)
encode temp, gen(statecode)
drop temp

//checking anomalous entries
preserve
*monthly per capita expenditure in a household
drop if mpce == 99999999 //there was a random high value in the data (Mizoram) - must be a mistake
gen hh_mpce = mpce/hh_size //per capita expenditure
svy: mean hh_mpce if statecode == 15 //mean of Mizoram 1040.99
restore

//imputation
replace mpce = 1040.99 if mpce == 99999999
gen hh_mpce = mpce/hh_size //monthly per capita consumption

svy: mean hh_mpce //mean

/*outreg2 using "$pathout/hhmpce.tex", replace label ///
    title("Mean per capita consumption expenditure of in a household") ctitle("Mean") dec(4)
*/

mean hh_mpce [pw = pweight] //mean

*for same point estimate, one can use just [pw = pw] also

preserve
collapse (mean) hh_mpce [pw = pweight], by(statecode)
gsort -hh_mpce //descending order
keep if _n <= 5 //keeping top 5 states
outsheet using "$pathout/top5_states.tex", replace
restore

preserve
collapse (mean) hh_mpce [pw = pweight], by(statecode)
drop if inlist(statecode, 35, 31, 26, 25, 34, 04, 07) //without union territories
gsort -hh_mpce //descending order
keep if _n <= 5 //keeping top 5 states
outsheet using "$pathout/top5_states_noUT.tex", replace
restore

********************************************************************************
*        Q1 (ii): Deciles of MPCE
********************************************************************************

*Survey characteristics other than pweights affect standard error estimation
*Therefore, point estimation of deciles can still be done using just [pw = pweight]

*creating separate variable for decile
xtile decile = hh_mpce [pw = pweight], nq(10) //creating decile as a categorical variable

//saving the prepared level 01 data
save "$pathtemp/templevel01.dta", replace

*Cutoff values for deciles and tabulating them
_pctile hh_mpce [pw = pweight], p(10 20 30 40 50 60 70 80 90)
return list

matrix scalars = (r(r1) \ r(r2) \ r(r3) \ r(r4) \ r(r5) \ r(r6) \ r(r7) \ r(r8) \ r(r9))
matrix rownames scalars = pct_10 pct_20 pct_30 pct_40 pct_50 pct_60 pct_70 pct_80 pct_90
esttab matrix(scalars) using "$pathout/decilecutoffs.tex", collabels(none) compress booktabs title("Scalar values") nonumbers replace

********************************************************************************
*     Preparing and merging all datasets required for Q1(iii) through Q1(vii)
********************************************************************************

//preparing level 03 for merging
use "$pathin/level03.dta", clear
destring common_id, replace
destring person_srl_no, replace
recast long person_srl_no
save "$pathtemp/templevel03.dta", replace

//merging level 01 and level 03
use "$pathtemp/templevel01.dta", clear
merge  1:m common_id using "$pathtemp/templevel03.dta"
drop _merge
save "$pathtemp/templevel0103.dta", replace

//preparing level 04 for merging
use "$pathin/level04.dta", clear
destring person_srl_no, replace
recast long person_srl_no
destring common_id, replace
save "$pathtemp/templevel04.dta", replace

//merging level 01, 03 and 04
use "$pathtemp/templevel0103.dta", clear
merge 1:1 common_id person_srl_no using "$pathtemp/templevel04.dta"
drop _merge
save "$pathtemp/templevel010304.dta", replace

//preparing level 06 for merging
use "$pathin/level06.dta", clear
destring common_id, replace
destring person_srl_no, replace
duplicates drop common_id person_srl_no, force
recast long person_srl_no
save "$pathtemp/templevel06.dta", replace

//merging previously created dataset with level 06
use "$pathtemp/templevel010304.dta", clear
merge 1:1 common_id person_srl_no using "$pathtemp/templevel06.dta"
save "$pathtemp/templevel01030406.dta", replace

erase "$pathtemp/templevel010304.dta"
erase "$pathtemp/templevel0103.dta"
erase "$pathtemp/templevel06.dta"
erase "$pathtemp/templevel03.dta"
erase "$pathtemp/templevel04.dta"
erase "$pathtemp/templevel01.dta"
********************************************************************************
*        Q1 (iii): Employed by Principal Activity Status
********************************************************************************

use "$pathtemp/templevel01030406.dta", clear
destring age, replace
keep if age > 14 & age < 60 //435342 observations remaining now
destring pri_activity_status, replace
destring sex, gen(female)
recode female (1=0)(2=1)
lab def female 0"male" 1"female", replace
lab val female female

//currently employed by principal status
gen curremployed = 0
replace curremployed = 1 if pri_activity_status >= 11 & pri_activity_status <= 51
lab def curremployed 0"currently unemployed" 1"currently employed"
lab val curremployed curremployed
svy: mean curremployed
estpost tabulate curremployed
esttab using "$pathout/tabcurremployed.tex", ///
cells("b(label(freq)) pct(fmt(2)) cumpct(fmt(2))") ///
varlabels(, blist(Total)) nonumber nomtitle noobs replace

//females currently employed by principal status
gen femalecurremployed = .
replace femalecurremployed = 0 if female == 1 & curremployed == 0
replace femalecurremployed = 1 if female == 1 & curremployed == 1
lab def femalecurremployed 0"female unemployed" 1"female employed"
lab val femalecurremployed femalecurremployed
svy: mean femalecurremployed
estpost tabulate femalecurremployed
esttab using "$pathout/tabfemalecurremployed.tex", ///
cells("b(label(freq)) pct(fmt(2)) cumpct(fmt(2))") ///
varlabels(, blist(Total)) nonumber nomtitle noobs replace

//males currently employed by principal status
gen malecurremployed = .
replace malecurremployed = 0 if female == 0 & curremployed == 0
replace malecurremployed = 1 if female == 0 & curremployed == 1
lab def malecurremployed 0"male unemployed" 1"male employed"
lab val malecurremployed malecurremployed
svy: mean malecurremployed
estpost tabulate malecurremployed
esttab using "$pathout/tabmalecurremployed.tex", ///
cells("b(label(freq)) pct(fmt(2)) cumpct(fmt(2))") varlabels(, blist(Total)) nonumber nomtitle noobs replace

	  
svy: tab malecurremployed //just checking
svy: tab femalecurremployed //just checking

//to get the same code as above in one line
svy: mean curremployed, over(female) coeflegend
outreg2 using "$pathout/empprop.tex", replace label title("Mean Employment by Gender") ctitle("Mean") dec(4)


//normally we would have done a prtest, ttest or directly reg of means
//prtest malecurremployed == femalecurremployed


//using svy weights this is how we can test for difference in means
//here the mean is actually the proportion itself since this is a binary categorical var
lincom _b[c.curremployed@0bn.female] - _b[c.curremployed@1.female]

//exporting results of the test to LaTeX
matrix results = (round(r(estimate), 0.001) \ round(r(se), 0.001) \ round(r(t), 0.001) \ round(r(p), 0.001) \ round(r(lb), 0.001) \ round(r(ub), 0.001) \ r(df))
matrix rownames results = Estimate Std_Err t_stat P_value Lower_Bound Upper_Bound Degrees_Freedom 
esttab matrix(results) using "$pathout/hyptest.tex", collabels(none) compress booktabs title("Difference of Proportion Employed by Sex") replace

//saving the data
save "$pathtemp/templevel01030406employ.dta", replace

********************************************************************************
*        Q1 (iv): Female employment rate by deciles
********************************************************************************

*svy: mean femalecurremployed, over(decile)
/*There is no direct graph command using svyset
hence we can actually just use [pw=pw] as weight while graphing, since we do not require standard errors
and we just need point estimates to graph. However, storing the scalars from svyset and then plotting them can also be done
Additionally, the mean of femalecurremployed would be the female employment rate (empl / (unemp+emp)*100)
*/

*graphing proportions
graph bar femalecurremployed [pw = pweight], over(decile) blabel(bar, format(%9.3f)) ytitle("Female Employment Rate (%)") ///
    title("Mean Female Employment Rate by Decile") bar(1, lcolor(black) lwidth(medium))

*graphing percentages (out of 100)
gen femalecurremployed_pct = femalecurremployed * 100
graph bar femalecurremployed_pct [pw = pweight], over(decile) blabel(bar, format(%9.2f)) ///
    ytitle("Female Employment Rate (%)") title("Mean Female Employment Rate by Decile") subtitle("Deciles on X axis") ///
    bar(1, lcolor(black) lwidth(medium) color(lavender)) legend(off)
graph export "$pathout/graph1.png", replace


********************************************************************************
*        Q1 (v): Daily wage rate variable
********************************************************************************
/*Note: Q1(v) does not ask to subset on 15-59 aged individuals explicitly, but the previous data used
has been subsetted on working age population, so that itself is continued here

Note: Q1(v) just mentions about using daily employment variables so I have not considered the
*principal activity status variable in this case. Hence I have used daily activity status 31 code only
This is my interpretation of the question
*/
use "$pathtemp/templevel01030406employ.dta", clear
//constructing daily wage rate variable for those having salaried employment
destring earning_total_seven_days_work daily_activity_status, replace
keep if inlist(daily_activity_status, 31) //only salaried wage employment individuals
gen dailywage = earning_total_seven_days_work/7

destring date_of_survey, gen(surveydate)
// assert surveydate != . //assertion is false
drop if surveydate == . //3 missing values for which survey date was not enumerated

*survey date is in the format DDMMYY
*so subsetting the string as needed
gen year_str = substr(date_of_survey, 5, 2)  // take only YY
gen month_str = substr(date_of_survey, 3, 2)  //take only MM
gen year_month = year_str + month_str //YYMM format
destring year_month, gen(yearmonth)
destring month_str, replace
label define yearmonth 0407"Jul 2004" 0408"Aug 2004" 0409"Sep 2004" 0410"Oct 2004" ///
  0411"Nov 2004" 0412"Dec 2004" 0501"Jan 2005" 0502"Feb 2005" 0503"Mar 2005" 0504"Apr 2005" ///
  0505"May 2005" 0506"Jun 2005" 0507"Jul 2005" 0508"Aug 2005" ///
  0509"Sep 2005" 0510"Oct 2005" 0511"Nov 2005" 0512"Dec 2005", replace
lab val yearmonth yearmonth

*mean daily wage in the given time frame
svy: mean dailywage if yearmonth >= 0407 & yearmonth <= 0506

*daily wage rate variable for individuals who had salaried employment (July 2004-June 2005)
graph bar dailywage [pw = pweight] if yearmonth >= 0407 & yearmonth <= 0506, over(yearmonth, label(labsize(*0.8) angle(45)) ) blabel(bar, format(%9.2f)) ytitle("Daily wage rate (Rs.)") title("Average daily wage rate (Rs.) by months") subtitle("July 2004 to June 2005") bar(1, lcolor(black) lwidth(medium) color(sienna))
	//yline(168.27, lcolor(red) lwidth(medium) lpattern(dash))
graph export "$pathout/graph2.png", replace


********************************************************************************
*        Q1 (vi): ln(dailywage) difference between men and women
********************************************************************************
//only 15-59 aged kept (from earlier data only)

gen lndailywage = ln(dailywage)
reg lndailywage female 
destring district, replace
destring education, replace
//assert pri_industry_nco_hh != "" //245 instances where occupation is missing

*some worker categories are not classified and are denoted by X at the beginning
*I am not removing them, since they not being classified into major categories itself makes them a different category
replace pri_industry_nco_hh = "1000" if pri_industry_nco_hh == "X01" //seeking work, not classified by occupation
replace pri_industry_nco_hh = "1001" if pri_industry_nco_hh == "X09" //workers without occupation
replace pri_industry_nco_hh = "1002" if pri_industry_nco_hh == "X10" //workers with inadeuqately identified occupation
replace pri_industry_nco_hh = "1003" if pri_industry_nco_hh == "X99" //workers not reporting occupation
destring pri_industry_nco_hh, replace

*regression using svy
svy: regress lndailywage female age education i.district i.pri_industry_nco_hh i.yearmonth

*Main regression
eststo reg1: reghdfe lndailywage female [pw = pweight], absorb(pri_industry_nco_hh month_str district) vce(robust)
eststo reg2: reghdfe lndailywage female age education [pw = pweight], absorb(pri_industry_nco_hh month_str district ) vce(robust)

esttab reg1 reg2 using "$pathout/reg_gwagegap.tex", r2 ar2 b(3) se label replace

/*The svy command does not work with reghdfe
The standard errors from code line 313  are bound to be slightly different from reg1 and reg2 although the estimates are same
I preferred using regdhfe and a separate pweight, given the various levels of unobservable heterogeneity
*/
********************************************************************************
*        Q1 (vii): policy change from Jan 2005 onwards
********************************************************************************

gen post = 0
replace post = 1 if yearmonth > 0501
lab def post 0"before Jan 2005" 1"after Jan 2005"
lab val post post

eststo reg3: reghdfe lndailywage post##female [pw = pweight], absorb(pri_industry_nco_hh district month_str) vce(robust)
eststo reg4: reghdfe lndailywage post##female age education [pw = pweight], absorb(pri_industry_nco_hh district month_str) vce(robust)

esttab reg3 reg4 using "$pathout/reg_DID.tex", r2 ar2 b(3) se label replace
