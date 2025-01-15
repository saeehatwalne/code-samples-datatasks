*Saee Hatwalne
********************************************************************************
*This is a data exercise to create a district wise panel for NFHS-4 and NFHS5 data
*An exploration into the association between female education and age at marriage
*dependent variable is age at marriage

// ssc install ternary
// ssc install joyplot
// ssc install heatplot

global pathin = "/Users/saeehatwalne/Desktop/APU 2023-25/CS & Panel/assn3"
global pathout = "/Users/saeehatwalne/Desktop/APU 2023-25/CS & Panel/assn3"

clear all
use "$pathin/IPUMS45.dta"

********************************************************************************
*                  Q3. BASIC DATA MANIPULATION
********************************************************************************
*Renaming variables
//tab year //survey round

//creating time dummy variable 0 or 1 for rounds
gen timeperiod = .
replace timeperiod = 0 if year == 2015 // Round 4: 2015-16
replace timeperiod = 1 if year == 2019  // Round 5: 2019-21
lab def timeperiod 0"NFHS4" 1"NFHS5"
lab val timeperiod timeperiod

//geoalt_ia2015_2019 is the harmonized variable for districts across two waves
rename geoalt_ia2015_2019 dist //renamed the variable

//state variable
rename geo_ia1992_2019 state

//dependent variable: age at (first) marriage
//variable agrfrstmar is already subsetted on ever married sample
drop if agefrstmar == 99 //not in universe dropped (never married)
keep if agefrstmar > 5 //keep women whose age of marriage is above 6 years


// for region, 1 is urban, 2 is rural
recode urban (1=1) (2=0) //recoding the urban variable
//this is done so that proportions can be taken (0*weight won't be counted)
lab def urban 0"rural" 1"urban" 
lab val urban urban

//for caste i.e. variable ethnicityia
tab ethnicityia
drop if ethnicityia == 97 | ethnicityia == 98 //don't know and missing
recode ethnicityia (30=1)(32=1)(10=2)(20=3)(31=4)
lab def ethnicityia 1"upper caste" 2"sc" 3"st" 4"obc"
lab val ethnicityia ethnicityia
tab ethnicityia, gen(caste)
rename caste1 uppercaste
rename caste4 obc

//for religion 
tab religion
// assert religion == 9998 //no missing
// assert religion == 9999 //no missing
recode religion (4000=1)(1000=2)(2000=3)(3000=4)(5000=4)(6000/9000=4)(0=4)
lab def religion 1"hindu" 2"muslim" 3"christian" 4"others"
lab val religion religion
tab religion, gen(religion)
rename religion1 hindu
rename religion2 muslim
rename religion3 christian
rename religion4 otherreligion

//media exposure - newspaper binary variable
tab newsfq
recode newsfq (0=0)(10/22=1)
lab def newsfq 0"no" 1"yes"
lab val newsfq newsfq
rename newsfq readsnews

// //husedyrs: husband's years of education
// tab husedyrs
//drop if inlist(husedyrs, 97, 99)

//age at menarche
drop if inlist(agemenarche, 95, 97, 98,99)

//wealth quintile
tab wealthq, gen(wquintile)
rename wquintile1 poorest
rename wquintile2 poorer
rename wquintile3 middle
rename wquintile4 richer
rename wquintile5 richest
gen rich = 0 //creating variable for upper two quintiles only
replace rich = 1 if richer == 1 | richest == 1 | middle == 1 //to get "proportion of rich" in the district

gen poor = 0
replace poor = 1 if poorest == 1 | poorer == 1

summarize wealths, detail

//trying joyplot
//joyplot agefrstmar, by(wealthq)

********************************************************************************
*                    Q3. CREATING A PANEL
********************************************************************************

//collapsing by district - using population weights
collapse (mean) agefrstmar wealths edyrtotal rich poor urban uppercaste obc hindu muslim readsnews agemenarche husedyrs [weight=popwt], by(dist state timeperiod)


//setting the `i' and `t' variable
xtset dist timeperiod //strongly balanced


********************************************************************************
*                     Q4. SUMMARY STATS
********************************************************************************

estpost tabstat agefrstmar edyrtotal poor wealths urban uppercaste obc hindu muslim readsnews agemenarche rich husedyrs, by(timeperiod) c(stat) stat(mean sd min max n) nototal 

esttab, cells("mean(fmt(2)) sd min(fmt(2)) max(fmt(2)) count(fmt(0))") unstack nonumber noobs replace
esttab using "$pathout/output1.tex", cells("mean(fmt(2)) sd min(fmt(2)) max(fmt(2)) count(fmt(0))") unstack nonumber noobs replace

********************************************************************************
*                   Q5. COVARIATES CHANGING OVER TIME
********************************************************************************

*to check if 'mean' of variables have changed over time, doing a t test
*the data can be browsed to see if actual values have changed
*all variables are having changed values if seen at the data

estpost ttest agefrstmar edyrtotal poor wealths urban uppercaste obc hindu muslim readsnews agemenarche rich husedyrs, by(timeperiod)

esttab using "$pathout/ttest.tex", wide cell("mu_1(fmt(2)) N_1(fmt(0)) mu_2(fmt(2)) N_2(fmt(0)) b(fmt(2) star)") nomtitle nonumber mgroups("pre" "post", pattern(1 0 1 0)) star(* 0.10 ** 0.05 *** 0.01) addnotes("* p < 0.10, ** p < 0.05, *** p < 0.01") replace

********************************************************************************
*                  Q5. CORRELATIONS
********************************************************************************

*Correlation matrices

*NFHS4
quietly correlate agefrstmar edyrtotal if timeperiod == 0
matrix C = r(C)
matrix colnames C = "Age at Marriage" "Education"
matrix rownames C = "Age at Marriage" "Education"
heatplot C, title("NFHS4 (Time Period 0)" "Correlation between age at marriage and education")values(format(%4.3f) size(large) color(white)) color(hcl diverging, intensity(.7)) xlabel(, angle(90)) name(plot1, replace)

matrix drop C

*NFHS5
quietly correlate agefrstmar edyrtotal if timeperiod == 1
matrix C = r(C)
matrix colnames C = "Age at Marriage" "Education"
matrix rownames C = "Age at Marriage" "Education"
heatplot C, title("NFHS5 (Time Period 1)" "Correlation between age at marriage and education")values(format(%4.3f) size(large) color(white)) color(hcl diverging, intensity(.7)) xlabel(, angle(90)) name(plot2, replace)

matrix drop C

*both time periods combined
quietly correlate agefrstmar edyrtotal
matrix C = r(C)
matrix colnames C = "Age at Marriage" "Education"
matrix rownames C = "Age at Marriage" "Education"
heatplot C, title("Both time periods" "Correlation between age at marriage and education")values(format(%4.3f) size(large) color(white)) color(hcl diverging, intensity(.7)) xlabel(, angle(90)) name(plot3, replace)

matrix drop C

*Heat plots
heatplot agefrstmar edyrtotal if timeperiod
heatplot agefrstmar edyrtotal if timeperiod == 0
heatplot agefrstmar edyrtotal if timeperiod == 1


quietly correlate agefrstmar wealths edyrtotal rich poor urban uppercaste obc hindu muslim readsnews agemenarche husedyrs, means
matrix C = r(C)

matrix C_lower = C
local n = colsof(C)
forval i = 1/`n' {
    forval j = `=`i' + 1'/`n' {
        matrix C_lower[`i', `j'] = .
    }
}

matrix colnames C_lower = "agefrstmar" "wealths" "edyrtotal" "rich" "poor" "urban" "uppercaste" "obc" "hindu" "muslim" "readsnews" "agemenarche" "husedyrs"
matrix rownames C_lower = "agefrstmar" "wealths" "edyrtotal" "rich" "poor" "urban" "uppercaste" "obc" "hindu" "muslim" "readsnews" "agemenarche" "husedyrs"

*plot generating
heatplot C_lower, ///
    title("Lower Diagonal: Correlation Matrix", size(medium)) ///
    values(format(%4.2f) color(white)) ///
    color(hcl) /// // Use HCL green-purple for better aesthetics
    xlabel(, angle(45)) ///
    ylabel(, angle(0)) ///
    name(lower_diagonal_plot, replace)

matrix drop C

*Scatter plots

twoway(scatter agefrstmar edyrtotal, title("Both time periods") ytitle("Age at marriage") xtitle("Years of education") mcolor(green) msize(small) name(plot1, replace))(lfitci agefrstmar edyrtotal)

twoway(scatter agefrstmar edyrtotal if timeperiod == 0, title("Both time periods") ytitle("Age at marriage") xtitle("Years of education") mcolor(green) msize(small) name(plot2, replace))(lfitci agefrstmar edyrtotal)

twoway(scatter agefrstmar edyrtotal if timeperiod == 1, title("Both time periods") ytitle("Age at marriage") xtitle("Years of education") mcolor(green) msize(small) name(plot3, replace))(lfitci agefrstmar edyrtotal)


twoway(scatter agefrstmar edyrtotal if timeperiod == 0, title("Both time periods") ytitle("Age at marriage") xtitle("Years of education") mcolor(blue))(scatter agefrstmar edyrtotal if timeperiod == 1, mcolor(red))(lfit agefrstmar edyrtotal if timeperiod == 0, clwidth(medthick))(lfit agefrstmar edyrtotal if timeperiod == 1, clwidth(medthick))


*Distributions

twoway(kdensity agefrstmar if timeperiod == 1, color(blue))(kdensity agefrstmar if timeperiod == 0, color (red)), title("Density of age of (first) marriage for two time periods") xtitle("Age at (first) marriage") ytitle("Density of agefrstmar") legend(order(1 "NFHS5" 2 "NFHS4"))

********************************************************************************
*                   Q7. REGRESSIONS
********************************************************************************

*POLS
eststo reg1: reg agefrstmar edyrtotal uppercaste rich agemenarche husedyrs readsnews urban hindu timeperiod 
*FE
eststo reg2: xtreg agefrstmar edyrtotal uppercaste rich agemenarche husedyrs readsnews urban hindu timeperiod, fe 

*RE
eststo reg3: xtreg agefrstmar edyrtotal uppercaste rich agemenarche husedyrs readsnews urban hindu timeperiod, re

esttab reg1 reg2 reg3 using "$pathout/reg.tex", r2 ar2 b(3) se starlevels(* .10 ** .05 *** .01) label replace

