*Saee Hatwalne
*hatwalne.saee@gmail.com

/*My experience with Stata: (in the PDF as well)
I have learnt Stata through a college course in early 2024. Then onwards, I have been using Stata for most of my
college assignments and data work. My entire graduate thesis is also being coded in Stata. I have cleaned 11 NSS/PLFS datasets (Government of India datasets on employment) and created appended cross sections of all in Stata. I have been working as a part time research assistant, so have exposure to the language from that experience as well. In total I have completed nearly 12-15 assignments/projects in Stata (Stata-LaTeX), apart from my thesis.
*/

global pathin = "/Users/Desktop/input"
global pathout = "/Users/Desktop/output"
global pathtemp = "/Users/Desktop/temp"


clear all

*******************************************************************************
**# Bookmark #1
*   DATA PREPARATION
*******************************************************************************

*----------------------------
* Q1(a) Loading the dataset
*----------------------------

import delimited "$pathin/student_test_data.csv" //importing csv data
save "$pathin/student_test_data.dta", replace //converting to Stata data format (just for convenience)

*----------------------------
* Q1(b) Dropping PII
*----------------------------
drop dob
/*Note: Date of birth is a personal information identifier. If the schoolid
is known and the dob is known, it is quite easy to narrow down on the student. Further, dob
is noted on all official documents, and is a threat to a student's security if found correctly
Here, I am considering pupilid as not being the same as a student's enrollment 
number from the school. If it is the same as a students' enrollment number, then the student
can easily be identified, and it would be a PII as well.
*/

*------------------------------------------------------------
* Q1 (c) Whether pupilid uniquely identifies the observations
*-----------------------------------------------------------

//checking if pupilid uniquely identifies
isid pupilid //no contradiction found - isid checks if the variable uniquely identifies the observations or not
//additional checks:
assert pupilid == . //checking if missing values present - not present
duplicates report pupilid //checking if duplicates present - not present

*---------------------------------------------------------------------------
* Q1(d) Converting all arithmetic score variables from string to integer
*---------------------------------------------------------------------------

*since the arithmetic variables are of a type a(number)_correct, it becomes easy to loop over them
*by using the Stata shortcut where you just put a * for some similar repeating character
*we use this even when we are checking fixed effects, where we have a lot of variables

foreach var of varlist a*_correct {
   replace `var'= "0" if `var' == "NONE" //replacing none by 0 first
   destring `var', replace //converting from string to numeric
   recast int `var' //changing the storage type to integer
}
*-----------------------
* Q1(e) Dropping missing data
*-----------------------
*same technique as the above answer used
foreach var of varlist s_correct w_correct *_incorrect *_missing{
	drop if `var' == -99
}
assert s_missing == -99 
assert w_missing == -99
assert w_incorrect == -99 //basic cross checking
assert s_incorrect == -99 //basic cross checking
*there were no -99 values reported in *_incorrect and *_missing, so cross checked if it really is the case

*------------------------------------
* Q1(f) Checking for outliers in the dataset
*------------------------------------
*NOTE: Details about how to check outliers mentioned in PDF document
summ s_correct w_correct //summarizing just to check the range etc.

//I also browsed the data, to get an idea about outliers

graph box w_correct //boxplot to see outliers
//found an anomaly in the w_correct variable

drop if w_correct == -98 //dropping one outlier in w_correct variable
*the code description for -98 was not provided, so considered it as an outlier
*code description for -99 only was provided

*Checking Outliers Answer:
/* Might be really basic to even write about, but I think that browsing the data
should be done and is quite underrated. I would also sort by ascending values for
necessary variables to understand the ranges. 
I would summarize required variables, check the min-max, and the broadly expected 
min max as per the variable description. I would then use histograms and 
boxplots (preferred) to see outliers.
*/

*------------------------------------
* Q1(g) Generating total scores
*------------------------------------
/*Note: Had there been negative marking for incorrect answers or a fraction type score 
was explicitly asked, then we would have had to make (correct/correct+incorrect+missing) if correct+incorrect+missing refers to the total number of questions which were asked
This type of a scenario is not considered here. 
So just the correct answered considered in the score.
*/

*total reading score
gen r_total = s_correct + w_correct

*total arithmetic score
*same technique of using * and looping over used here
*writing 8 variables as + is quite long

gen a_total = 0 //start with sum variable as 0
foreach var of varlist a*_correct{
	replace a_total = `var' + a_total  //add variables one by one
}

*Generating total score
gen totalscore = r_total + a_total + spelling_correct

*------------------------------------
* Q1(h) Grade labelling
*------------------------------------
*Generating grade variable, as per the grade boundaries provided
generate grade = .
replace grade = 4 if totalscore >= 80 & totalscore <= 98
replace grade = 3 if totalscore >= 60 & totalscore <= 79
replace grade = 2 if totalscore >= 40 & totalscore <= 59
replace grade = 1 if totalscore >= 20 & totalscore <= 39
replace grade = 0 if totalscore >= 0 & totalscore <= 19
lab def grade 4"A" 3"B" 2"C" 1"D" 0"F"
lab val grade grade

*------------------------------------------------------------------------------
* Q1(i)    Standardizing scores relative to the control group
*------------------------------------------------------------------------------
/*Note: Since we are standardizing relative to the control group, the mean and 
standard deviation of the control group has been used to standardize
In a summarize output, the scalars are already stored by Stata in formats such as r()
These given scalars are directly used while standardizing all score variables
*/

*Standardizing the total score
summ totalscore if tracking == 0 //only for control group
gen total_zscore = (totalscore - r(mean)) / r(sd)

summ r_total if tracking == 0
gen r_zscore = (r_total - r(mean)) / r(sd)

summ a_total if tracking == 0
gen a_zscore = (a_total - r(mean)) / r(sd)

summ spelling_correct if tracking == 0
gen sp_zscore = (spelling_correct - r(mean)) / r(sd)

/*checking out the distribution of the z score variables
*summ total_zscore, detail
*summ r_zscore
*summ a_zscore
*summ sp_zscore
*hist total_zscore
*/

*-------------------------------------------------
* Q1(j)  Labelling variables
*-------------------------------------------------
lab var total_zscore "Standardized total score"
lab var r_zscore "Standardized reading score"
lab var a_zscore "Standardized arithmetic score"
lab var sp_zscore "Standardized spelling score"
*---------------------------------------------------
* Q1(k)  Saving the student test data
*---------------------------------------------------
save "$pathin/student_test_data_edited.dta", replace //just wanted to save in a Stata format as well
export delimited "$pathin/student_test_data_edited.csv", replace //exporting as csv

*---------------------------------------------------
* Q1(l) Loading teacher dataset
*---------------------------------------------------
use "$pathin/teacher_data.dta", clear //was already in a Stata data format
//count //counting the number of obs

*---------------------------------------------------
* Q1(m) Randomly sample 40% of data
*---------------------------------------------------

set seed 45 //setting seed to get the same random sample every time the code is run
sample 40 // random sampling without replacement, since we want to interview individual teachers
//411 obs deleted


*Exporting this randomly sampled data as a separate data in a csv format
export delimited "$pathin/teacher_data_edited.csv", replace


/****************** NOTE: ******************************************************
The question had asked to separately export and save the randomly sampled 40% of 
the data for when the PI would re-interview later.
It was not mentioned whether the next part of analysis is to be done on this subsetted 40%.
Hence, logically, I have still considered the previous complete teacher data for the 
further data preparation. 
********************************************************************************
*/

clear
use "$pathin/teacher_data.dta"

*---------------------------------------------------
* Q1(n) Avg. years of experience per school
*---------------------------------------------------
/*If any of the values for experience are missing, then the average value is
 left missing for that entire school - as per the instructions provided
*/
gen temp = missing(yrstaught) //separate binary variable showing if value is missing or not
egen missingexp = sum(temp), by(schoolid) //sum total missing values in a school (just want to indicate non-zero)
drop temp //earlier variable not needed now

egen avgyrstaught = mean(yrstaught), by(schoolid) //average over a school
replace avgyrstaught = . if missingexp != 0 //don't want average for schools with missing values, so replace all as "missing" (.)

*--------------------------------------------------------------------
* Q1(o) Reshaping - so that observations are uniquely identified by school
*--------------------------------------------------------------------
collapse (mean) avgyrstaught , by(schoolid)
*note: one could do (count)teacherid as well, so that we get number of teachers in a school
*however, I have not considered it here

*--------------------------------------------------------------------
* Q1(p) Merging this teacher data with the student data from part (k)
*--------------------------------------------------------------------
/* Note: schoolid is the common key for the merge. Since schoolid is the same
for multiple students in a single school, and the teacher data is now collapsed at the school level,
a one to many merge would be the way to merge school level data to individual level data
*/
merge 1:m schoolid using "$pathin/student_test_data_edited.dta"
//0 unmatched

*-------------------------------------------------------------------------
* Q1(q) Labelling the variables required in the analysis portion of the exercise
*-------------------------------------------------------------------------
lab var avgyrstaught "Average years of teaching experience for a school"
lab var pupilid "Pupil identifier"
lab var schoolid "School identifier"
lab var zone "Zone of school"
lab var girl "Student gender is female"
*was not required but added for usage ease:
lab def girl 0"male" 1"female"
lab val girl girl

*-------------------------------------------------------------------------
* Q1(r) Saving the merged data
*-------------------------------------------------------------------------
save "$pathin/merged_student_teacher.dta", replace

*******************************************************************************
**# Bookmark #2
*   ANALYSIS
*******************************************************************************

use "$pathin/merged_student_teacher.dta", clear

*-------------------------------------------------------------------------
* Q2(a) Basic reg specification with zone FE - total zscore
*-------------------------------------------------------------------------
encode zone, gen(adminzone) //converting to categorical variable
eststo reg1: reg total_zscore tracking i.adminzone, vce(cl schoolid)
estadd local fixedeffects "Yes"  //no fixed effects (nofe)

*another way to get the same estimate on tracking as the previous equation:
*reghdfe total_zscore tracking, absorb(zone) vce(cl schoolid)
*I would use reghdfe when I have many other fixed effects.
*Given that zones are not many, I still stick to normal reg command
*and taking individual dummies.

*-------------------------------------------------------------------------
* Q2(b) Basic reg specification with zone FE - other variables
*-------------------------------------------------------------------------
*Using same specification as part (a), running on other score variables

eststo reg2: reg a_zscore tracking i.adminzone, vce(cl schoolid) 
estadd local fixedeffects "Yes"
eststo reg3: reg r_zscore tracking i.adminzone, vce(cl schoolid) 
estadd local fixedeffects "Yes"
eststo reg4: reg sp_zscore tracking i.adminzone, vce(cl schoolid)
estadd local fixedeffects "Yes" 

// matrix list e(b) //checking storage of estimates

*Tabulating together and exporting to LaTeX
esttab reg1 reg2 reg3 reg4 using "$pathout/Q2b.tex", drop(*.adminzone) starlevels(* 0.1 ** 0.05 *** 0.01) r2 ar2 b(3) scalars( "fixedeffects Zone-Fixed-Effects") se nolabel postfoot("\hline \hline \multicolumn{4}{l}{\footnotesize Standard errors in parentheses}\\ \multicolumn{4}{l}{\footnotesize * p$<$.10, ** p$<$.05, *** p$<$.01} \end{tabular}\vspace{0.2cm} \\ \begin{minipage}{0.6\linewidth} \small \textit{Notes: Dependent variables are in standardized z-scores. Total_zscore, a_zscore, r_zscore and sp_zscore are zscores for total score, arithmetic, reading and spelling scores resp. tracking takes value 1 for the treatment group, 0 for control group - base category is control group. Standard errors clustered at school level.} \end{minipage} \end{table}"}) prehead("{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{table}[htbp] \centering \caption*{Table 1: Basic regressions} \begin{tabular}{l*{4}{c}} \hline\hline") replace

/*Note: I use LaTeX regularly through Overleaf. I generally edit tables in Overleaf directly. 
However, added the LaTeX code here itself, so that manual editing is reduced. 
Some additional tweaks, as required, would be done in Overleaf.
A source I referred to for adding header and footer is: (Lingling, 2020)
Lingling - Medium." Medium. July 26, 2020. https://medium.com/@linglp/nice-regression-tables-in-stata-17d3895befd2.
Details mentioned in PDF
*/

*-------------------------------------------------------------------------
* Q2(c) Interpretation of results & choice of standard errors
*-------------------------------------------------------------------------
*Formatted table outputs, interpretation and rationale for standard errors
* are in the PDF document


*-------------------------------------------------------------------------
* Q2(d) Controlling for gender and avg years of teaching experience
*-------------------------------------------------------------------------
eststo reg5: reg total_zscore tracking girl avgyrstaught i.adminzone, vce(cl schoolid) 
estadd local fixedeffects "Yes" 

*Formatted table outputs and their interpretation are in the PDF document

*-------------------------------------------------------------------------
* Q2(e) Creating regression table from Q2(a) and Q2(d)
*-------------------------------------------------------------------------


esttab reg1 reg5 using "$pathout/Q2d.tex", drop(*.adminzone) starlevels(* 0.1 ** 0.05 *** 0.01) r2 ar2 b(3) se nolabel scalars( "fixedeffects Zone-Fixed-Effects") postfoot("\hline \hline \multicolumn{2}{l}{\footnotesize Standard errors in parentheses}\\ \multicolumn{4}{l}{\footnotesize * p$<$.10, ** p$<$.05, *** p$<$.01} \end{tabular}\vspace{0.2cm} \\ \begin{minipage}{0.6\linewidth} \small \textit{Notes: Dependent variables are in standardized z-scores. Base category for binary variable 'girl' is male. tracking takes value 1 for the treatment group, 0 for control group - base category is control group. avgyrstaught refers to the average years of teaching experience for a school. Standard errors clustered at school level.} \end{minipage} \end{table}"}) prehead("{\def\sym#1{\ifmmode^{#1}\else\(^{#1}\)\fi} \begin{table}[htbp] \centering \caption*{Table 2: Regression - Total scores} \begin{tabular}{l*{2}{c}} \hline\hline") replace


*-------------------------------------------------------------------------
* Q2(f) Graphical representation
*-------------------------------------------------------------------------
lab def tracking 0"non-tracking" 1"tracking", replace
lab val tracking tracking

*Graph presented in the PDF document as well
graph bar (mean) a_total,  over(tracking) over(district) asyvars bargap(40) showyvars legend(label(1 "non-tracking") label(2 "tracking")) ytitle("Average non-standardized arithmetic score") title("Arithmetic scores in districts") subtitle("by tracking status") blabel(bar, color(black) size(small) format(%9.1f))  bar(1, color(cranberry)) bar(2, color(dkgreen))
graph export "$pathout/graph1.png", replace
