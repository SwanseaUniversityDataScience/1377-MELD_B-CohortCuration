 ----------------------------------------------
--PROJECT: MELD-B 1377
--WP02 (Work Package 02) - Stage 01 
--AUTHOR: roberta.chiovoloni@swansea.ac.uk
----------------------------------------------
--AIM: Extracting ALF_PE to create the smv cohort file
--	   Extracting demographic details to use toward the creation of the consort diagram for Stage 01. 
--     Creation of Residency and GP information table for the individuals in the cohort. 

--This script can be split in 2 parts 
-- Check some dem information with ADBE and ADDE (WOB/DOD/GNDR_CD)
-- Extract rows from WDSD_PER_RESIDENCE_GPREG_20230605 relevant for our study period (between 01-01-2000 / 31-12-2022) 
-- Extract ALF_PE from WDSD_PER_RESIDENCE_GPREG_20230605 using exclusion criteria

--  Final tables created: 
--	1. WP02_COHORT_TABLE : Final table for the SMC cohort. Each row refers to one individual in the cohort 
--	2. WP02_WDSD_GP_BREAK : Table including residency and GP information for individuals in the cohort 
-- 3. TEMP_WP02_CT_BREAK -- this is a temporary table used in the Jupyter code. This will be dropped in the Jup code. 
----------------------------------------------
-- Variables created in this script:
--DROP VARIABLE SAILW1377V.COHORT_ST_DT;
--DROP VARIABLE SAILW1377V.COHORT_END_DT;
--DROP VARIABLE SAILW1377V.AGE_MAX;

--Temporary Table created: 
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WDSD_AP2');
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WDSD_AP2_T');
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WP02_CT_BREAK');
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WP02_COHORT_TABLE');
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_EXIT_REASON');
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_ALF_PU');

--Final tables created 
--CALL FNC.DROP_IF_EXISTS ('SAILW1377V.WP02_COHORT_TABLE');
--CALL FNC.DROP_IF_EXISTS ('SAILW1377V.WP02_WDSD_GP_BREAK');
----------------------------------------------
-------------------
--	Creating variables used for data preparation
-------------------
--------------------------------------
CREATE OR REPLACE VARIABLE SAILW1377V.COHORT_ST_DT DATE DEFAULT '2000-01-01'; 
CREATE OR REPLACE VARIABLE SAILW1377V.COHORT_END_DT DATE DEFAULT '2022-12-31';
CREATE OR REPLACE VARIABLE SAILW1377V.AGE_MAX INTEGER DEFAULT 38325; --105 years of age 

---------------------------------------
--	Confirm distinct number of individuals in Wales based on the WDSD
---------------------------------------
SELECT  
	COUNT(DISTINCT ALF_PE)	AS	TOT_WDSD
FROM
    SAIL1377V.WDSD_PER_RESIDENCE_GPREG_20230605;
----------------------------------------------------------
---------
-- PART 1 
---------
----------------------------------------------------------
--  Extract all rows from the SAIL1377V.WDSD_PER_RESIDENCE_GPREG_20230605 table 
--  joining them with relative rows in ADBE and ADDE to check for WOB, DOD and GNDR_CD 
--  remove rows not relative to the study period 
--  add AGE column (in days) 
--  add ethnicity (NOR/ONS)
----------------------------------------------------------
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WDSD_AP2');
-------------------
 -- Create table 
 CREATE TABLE SAILW1377V.TEMP_WDSD_AP2(
	ALF_PE BIGINT, 
	WOB DATE, 
	DOD DATE,
	GNDR_CD VARCHAR(1), 
	LSOA2011_CD VARCHAR(9), 
	PRAC_CD_PE BIGINT, 
	ACTIVEFROM DATE, 
	ACTIVETO DATE
)
DISTRIBUTE BY HASH(ALF_PE); 

-------------------
-- Insert into table
INSERT INTO SAILW1377V.TEMP_WDSD_AP2 
	WITH WOB AS ( --people with valid WOB
		SELECT T1.ALF_PE FROM SAIL1377V.WDSD_PER_RESIDENCE_GPREG_20230605 T1 
		LEFT JOIN SAIL1377V.ADBE_BIRTHS_20230401 T2 
		ON T1.ALF_PE = T2.ALF_PE 
		WHERE (T1.WOB IS NOT NULL AND T2.WOB IS NOT NULL AND T1.WOB = T2.WOB) OR 
			(T1.WOB IS NOT NULL AND T2.WOB IS NULL) OR 
			(T1.WOB IS NULL AND T2.WOB IS NOT NULL)
	), 
	DOD AS ( --people with valid DOD
		SELECT T1.ALF_PE FROM SAIL1377V.WDSD_PER_RESIDENCE_GPREG_20230605 T1 
		LEFT JOIN SAIL1377V.ADDE_DEATHS_20230601 T2
		ON T1.ALF_PE = T2.ALF_PE
		WHERE (T1.DEATH_DT IS NOT NULL AND T2.DEATH_DT IS NOT NULL AND T1.DEATH_DT = T2.DEATH_DT) OR 
			(T1.DEATH_DT IS NOT NULL AND T2.DEATH_DT IS NULL) OR 
			(T1.DEATH_DT IS NULL AND T2.DEATH_DT IS NOT NULL) OR
			(T1.DEATH_DT IS NULL AND T2.DEATH_DT IS NULL) 	
	)
	SELECT DISTINCT 
		T1.ALF_PE, 
		CASE WHEN T1.WOB IS NULL OR T1.WOB <> T2.WOB AND T2.BIRTH_REG_DT_VALID = 'Valid' THEN T2.WOB
			ELSE T1.WOB
		END AS WOB, 
		CASE WHEN T1.DEATH_DT IS NULL OR T1.DEATH_DT <> T3.DEATH_DT AND T3.DEATH_DT_VALID = 'Valid' THEN T3.DEATH_DT 
			ELSE T1.DEATH_DT
		END AS DOD, 
		CASE WHEN T1.GNDR_CD IS NULL AND T2.NENONATE_SEX_CD IS NOT NULL THEN T2.NENONATE_SEX_CD
			ELSE T1.GNDR_CD 
		END AS GNDR_CD, 
		T1.LSOA2011_CD, T1.PRAC_CD_PE, T1.ACTIVEFROM, 
		CASE WHEN T1.ACTIVETO IS NULL THEN '9999-01-01' --if an individual is still a resident change NULL with '9999-01-01'
			 ELSE T1.ACTIVETO 
		END AS ACTIVETO
	FROM 
		SAIL1377V.WDSD_PER_RESIDENCE_GPREG_20230605 T1 
	LEFT JOIN 
		SAIL1377V.ADBE_BIRTHS_20230401 T2 
	ON 
		T1.ALF_PE = T2.ALF_PE
	LEFT JOIN 
		SAIL1377V.ADDE_DEATHS_20230601 T3
	ON 
		T1.ALF_PE = T3.ALF_PE 
	WHERE 
		T1.ALF_PE IS NOT NULL 
	AND T1.ALF_PE IN (SELECT ALF_PE FROM WOB)
	AND T1.ALF_PE IN (SELECT ALF_PE FROM DOD)
; 

-----------------------------
-- Keeping rows related to the study period + 
-- adding age column (age at cohort start date) in days 
-- adding ethnicity + ethnicity description
--
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WDSD_AP2_T');

CREATE TABLE SAILW1377V.TEMP_WDSD_AP2_T(
	ALF_PE BIGINT, 
	WOB DATE, 
	DOD DATE,
	GNDR_CD VARCHAR(1),
	AGE_COHORTSTART INTEGER, 
	ETHN_NER_CODE INTEGER, 
	ETHN_NER_DESC VARCHAR(20), 
	ETHN_ONS_CODE INTEGER, 
	ETHN_ONS_DESC VARCHAR(20),
	LSOA2011_CD VARCHAR(9), 
	PRAC_CD_PE BIGINT, 
	ACTIVEFROM DATE, 
	ACTIVETO DATE
)
DISTRIBUTE BY HASH(ALF_PE); 

-- Insert 
INSERT INTO SAILW1377V.TEMP_WDSD_AP2_T 
	SELECT 
		T1.ALF_PE, T1.WOB, T1.DOD, T1.GNDR_CD, 
		CASE 
		WHEN DAYS_BETWEEN('2000-01-01', T1.WOB) >= 0 THEN DAYS_BETWEEN('2000-01-01', T1.WOB) 
		ELSE NULL
		END AS AGE_COHORTSTART, 
		C.ETHN_EC_NER_DATE_LATEST_CODE AS ETHN_NER_CODE, C.ETHN_EC_NER_DATE_LATEST_DESC AS ETHN_NER_DESC, 
		C.ETHN_EC_ONS_DATE_LATEST_CODE AS ETHN_ONS_CODE, C.ETHN_EC_ONS_DATE_LATEST_DESC AS ETHN_ONS_DESC,
		T1.LSOA2011_CD, T1.PRAC_CD_PE, T1.ACTIVEFROM, T1.ACTIVETO
	FROM 
		SAILW1377V.TEMP_WDSD_AP2 T1
	LEFT JOIN 
		SAILW1377V.WP02_ETHN C
	ON 
		T1.ALF_PE = C.ALF_PE 
	WHERE 
		T1.LSOA2011_CD IS NOT NULL --PEOPLE WITH RESIDENCE INFO 
		AND T1.PRAC_CD_PE IS NOT NULL --PEOPLE WITH GP INFO 
		AND T1.WOB <= SAILW1377V.COHORT_END_DT -- BORN BEFORE COHORT END DT 
		AND (T1.DOD IS NULL OR T1.DOD >= SAILW1377V.COHORT_ST_DT) --STILL ALIVE OR DEAD AFTER COHORT START DT 
		AND (T1.ACTIVETO >= SAILW1377V.COHORT_ST_DT )--OR T1.ACTIVETO IS NULL)  --PEOPLE WITH ERESIDENCE/GP DATA AFTER COHORT_START 
		AND T1.ACTIVEFROM <= SAILW1377V.COHORT_END_DT --PEOPLE WITH RESIDENCE/GP DATA BEFORE COHORT_END 
		AND (T1.DOD > T1.ACTIVEFROM OR T1.DOD IS NULL) -- PEOPLE ALIVE OR WITH DOD CONSISTENCY
; 

--Check(s)
SELECT 
	COUNT(DISTINCT ALF_PE) AS ALF_DATA_IN_RANGE
FROM 
	SAILW1377V.TEMP_WDSD_AP2_T;
--
CALL FNC.DROP_IF_EXISTS('SAILW1377V.TEMP_WDSD_AP2');
RENAME TABLE SAILW1377V.TEMP_WDSD_AP2_T TO TEMP_WDSD_AP2;

SELECT 
	COUNT(DISTINCT ALF_PE) AS ALF_DATA_IN_RANGE
FROM 
	SAILW1377V.TEMP_WDSD_AP2;

---------------------------
--  Extract individuals from SAILW1377V.WDSD_AP2:
--	that are within the age requirements (<105) at the study start (AGE < AGE_MAX)
--  and that have a defined gender (GNDR_CD = 1 OR GNDR_CD = 2)
---------------------------
CALL FNC.DROP_IF_EXISTS('SAILW1377V.TEMP_WDSD_AP2_T');
CREATE TABLE SAILW1377V.TEMP_WDSD_AP2_T LIKE SAILW1377V.TEMP_WDSD_AP2;

INSERT INTO SAILW1377V.TEMP_WDSD_AP2_T
	SELECT * FROM SAILW1377V.TEMP_WDSD_AP2 T1
	WHERE (T1.AGE_COHORTSTART < SAILW1377V.AGE_MAX OR T1.AGE_COHORTSTART IS NULL) --PEOPLE < 105 YO
	AND (GNDR_CD = 1 OR GNDR_CD = 2)
	;

CALL FNC.DROP_IF_EXISTS('SAILW1377V.TEMP_WDSD_AP2');
RENAME TABLE SAILW1377V.TEMP_WDSD_AP2_T TO TEMP_WDSD_AP2;
-----------------------
-- 1. Adding WIMD, WIMD decsription, TOWNSEND and TOWNSEND description by  joining the LSOA in 
-- WDSD_PER_RESIDENCE_GPREG_20230605 with those in WDSD_SINGLE_CLEAN_GEO_CHAR_LSOA2011_20230605
----------------------------------------------------------
--  Create table  
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WP02_COHORT_TABLE');
--
CREATE TABLE SAILW1377V.TEMP_WP02_COHORT_TABLE (
	ALF_PE BIGINT, 
	WOB DATE, 
	DOD DATE, 
	GNDR_CD SMALLINT, 
	AGE_COHORTSTART INTEGER, 
	ETHN_NER_CODE INTEGER, 
	ETHN_NER_DESC VARCHAR(20), 
	ETHN_ONS_CODE INTEGER, 
	ETHN_ONS_DESC VARCHAR(20),
	FLAG_DEAD SMALLINT, 
	ACTIVEFROM DATE, 
	ACTIVETO DATE,
	LSOA2011_CD VARCHAR(9), 
	WIMD_2019_QUINTILE SMALLINT, 
	WIMD_2019_QUINTILE_DESC VARCHAR(20), 
	TOWNSEND_2011_QUINTILE SMALLINT, 
	TOWNSEND_2011_QUINTILE_DESC VARCHAR(20),
	PRAC_CD_PE BIGINT
)
DISTRIBUTE BY HASH(ALF_PE); 
--
-- Insert 
INSERT INTO SAILW1377V.TEMP_WP02_COHORT_TABLE --this table includes more than one row per person
	WITH LSOA_WIMD_MAP AS (
		SELECT DISTINCT 
			T2.LSOA2011_CD, T2.WIMD_2019_QUINTILE, 
			CASE WHEN T2.WIMD_2019_QUINTILE = 1 THEN '1. Most Deprived'
				WHEN T2.WIMD_2019_QUINTILE = 2 THEN '2.'
				WHEN T2.WIMD_2019_QUINTILE = 3 THEN '3.'
				WHEN T2.WIMD_2019_QUINTILE = 4 THEN '4.'
				WHEN T2.WIMD_2019_QUINTILE = 5 THEN '5. Least Deprived'
			END AS WIMD_QUINTILE_DESC, 
			CASE WHEN T2.TOWNSEND_2011_QUINTILE = 1 THEN 5
				 WHEN T2.TOWNSEND_2011_QUINTILE = 2 THEN 4
			    WHEN T2.TOWNSEND_2011_QUINTILE = 3 THEN 3
			 	WHEN T2.TOWNSEND_2011_QUINTILE = 4 THEN 2
			 	WHEN T2.TOWNSEND_2011_QUINTILE = 5 THEN 1
			END AS TOWNSEND_2011_QUINTILE, 
			CASE WHEN TOWNSEND_2011_QUINTILE = 5 THEN '1. Most Deprived'
				WHEN TOWNSEND_2011_QUINTILE = 4 THEN '2.'
				WHEN TOWNSEND_2011_QUINTILE = 3 THEN '3.'
				WHEN TOWNSEND_2011_QUINTILE = 2 THEN '4.'
				WHEN TOWNSEND_2011_QUINTILE = 1 THEN '5. Least Deprived'
			END AS TOWNSEND_2011_QUINTILE_DESC
		FROM SAIL1377V.WDSD_SINGLE_CLEAN_GEO_CHAR_LSOA2011_20230605 T2
	)
	SELECT 
		T1.ALF_PE, T1.WOB, T1.DOD, T1.GNDR_CD, T1.AGE_COHORTSTART,  
		T1.ETHN_NER_CODE, T1.ETHN_NER_DESC , T1.ETHN_ONS_CODE, T1.ETHN_ONS_DESC,
		CASE WHEN T1.DOD <= SAILW1377V.COHORT_END_DT THEN 1 
			ELSE 0 
		END AS FLAG_DEAD, 
		T1.ACTIVEFROM, T1.ACTIVETO,
		T1.LSOA2011_CD, 
		T2.WIMD_2019_QUINTILE, T2.WIMD_QUINTILE_DESC, 
		T2.TOWNSEND_2011_QUINTILE, T2.TOWNSEND_2011_QUINTILE_DESC,	
		T1.PRAC_CD_PE
	FROM 
		SAILW1377V.TEMP_WDSD_AP2 T1
	LEFT JOIN 
		LSOA_WIMD_MAP T2
	ON 
		T1.LSOA2011_CD = T2.LSOA2011_CD;

CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WDSD_AP2');
--
----------------------------------------------------------------------
-- PART 1.b--
----------------------------------------------------------------------
--------
-- Adding columns for FLAG_START, FLAG_LATER_DATE and FLAG_WIMD_START
-- If FLAG_START = 1 : the individual is in the cohort at cohort start date  
-- If FLAG_START = 0 : the individual joins the cohort after the cohort start date 
-- FLAG_LATER_DATE = the first date an individual joins the cohort if he does not join at cohort start date 
-- FLAG_WIMD_START = WIMD at cohort start date is available  
--------
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WP02_COHORT_TABLE_T');

CREATE TABLE SAILW1377V.TEMP_WP02_COHORT_TABLE_T (
	ALF_PE BIGINT, 
	WOB DATE, 
	DOD DATE, 
	GNDR_CD SMALLINT, 
	AGE_COHORTSTART INTEGER, 
	ETHN_NER_CODE INTEGER, 
	ETHN_NER_DESC VARCHAR(20), 
	ETHN_ONS_CODE INTEGER, 
	ETHN_ONS_DESC VARCHAR(20),
	FLAG_DEAD SMALLINT, 
	ACTIVEFROM DATE, 
	ACTIVETO DATE,
	LSOA2011_CD VARCHAR(9), 
	WIMD_2019_QUINTILE SMALLINT, 
	WIMD_2019_QUINTILE_DESC VARCHAR(20), 
	TOWNSEND_2011_QUINTILE SMALLINT, 
	TOWNSEND_2011_QUINTILE_DESC VARCHAR(20),
	PRAC_CD_PE BIGINT, 
	FLAG_START SMALLINT, 
	FLAG_LATER_DATE DATE, 
	WIMD_START SMALLINT
); 
--Insert 
INSERT INTO SAILW1377V.TEMP_WP02_COHORT_TABLE_T
	WITH MIN_DATE AS (     --first date when an ALF has a LSOA registration
		SELECT 	
			ALF_PE,  MIN(ACTIVEFROM) AS MIN_DATE 
		FROM 
			SAILW1377V.TEMP_WP02_COHORT_TABLE
		GROUP BY 
			ALF_PE
		),
	COHORTLATER_DATE AS (  --set the date as null if it is before cohort_st_dt
		SELECT ALF_PE,  
			CASE WHEN MIN_DATE <= SAILW1377V.COHORT_ST_DT THEN NULL 
				 ELSE MIN_DATE
			END AS FLAG_LATER_DATE
		FROM 
			MIN_DATE
		), 
	FLAG1 AS (        --flagging rows where start_date < cohort start date and end_date > cohort start date - it flags wors where WIMD = WIMD_START
		SELECT
			ALF_PE, ACTIVEFROM, ACTIVETO,
			CASE WHEN SAILW1377V.COHORT_ST_DT BETWEEN ACTIVEFROM AND ACTIVETO THEN 1   
				ELSE 0 
			END AS FLAG_COHORTSTART
		FROM 
			SAILW1377V.TEMP_WP02_COHORT_TABLE 
		), 
	COHORTSTART AS (   
		SELECT 
			ALF_PE, SUM(FLAG_COHORTSTART) AS FLAG_START
		FROM 
			FLAG1
		GROUP BY 
			ALF_PE
		ORDER BY 
			ALF_PE 
		)
	SELECT DISTINCT 
		T1.ALF_PE, T1.WOB, T1.DOD, T1.GNDR_CD, T1.AGE_COHORTSTART,
		T1.ETHN_NER_CODE, T1.ETHN_NER_DESC, T1.ETHN_ONS_CODE, T1.ETHN_ONS_DESC,
		T1.FLAG_DEAD, T1.ACTIVEFROM, T1.ACTIVETO, 
		T1.LSOA2011_CD, T1.WIMD_2019_QUINTILE, T1.WIMD_2019_QUINTILE_DESC,
		T1.TOWNSEND_2011_QUINTILE, T1.TOWNSEND_2011_QUINTILE_DESC, 
		T1.PRAC_CD_PE,
		T2.FLAG_START, T3.FLAG_LATER_DATE, 
		T4.FLAG_COHORTSTART AS WIMD_START 	
	FROM 
		SAILW1377V.TEMP_WP02_COHORT_TABLE T1
	INNER JOIN 
		FLAG1 T4 
	ON 
		T1.ALF_PE = T4.ALF_PE
	AND 
		T1.ACTIVEFROM = T4.ACTIVEFROM 
	AND 
		T1.ACTIVETO = T4.ACTIVETO
	INNER JOIN 
		COHORTSTART T2
	ON 
		T1.ALF_PE = T2.ALF_PE
	INNER JOIN 
		COHORTLATER_DATE T3 
	ON 
		T1.ALF_PE = T3.ALF_PE
	ORDER BY 
		ALF_PE, ACTIVEFROM; 

CALL FNC.DROP_IF_EXISTS('SAILW1377V.TEMP_WP02_COHORT_TABLE');
RENAME TABLE SAILW1377V.TEMP_WP02_COHORT_TABLE_T TO TEMP_WP02_COHORT_TABLE;

---------------------
--PART2
-----------------------------------------------------------	
-- Modifying the table such that each individual appears only in one row. 
-- When two rows (for the same individual) have consecutive ACTIVETO and ACTIVEFROM dates we "collapse" them into a single row. 
-- so that the new columns COHORT_ENTRY and COHORT_EXIT represents the date of entrance/exit. 
-- (Note that as a team we decided to consider as "lost to follow up" individuals that leave Wales and then re-enter) 

CREATE TABLE SAILW1377V.TEMP_WP02_CT_BREAK ( --collapsing consecutive residence/registration period in one row 
	ALF_PE BIGINT, 
	NEW_ACTIVEFROM DATE,
	NEW_ACTIVETO DATE, 
	RW_SEQ INTEGER
)
DISTRIBUTE BY HASH(ALF_PE);

INSERT INTO SAILW1377V.TEMP_WP02_CT_BREAK
	WITH BREAK1 AS (
		SELECT DISTINCT 
			A.ALF_PE, A.ACTIVEFROM AS START_DATE, A.ACTIVETO AS END_DATE,
			LEAD(A.ACTIVEFROM) OVER (PARTITION BY A.ALF_PE ORDER BY A.ACTIVEFROM,  A.ACTIVETO) AS LEAD_ST, 		
			ROW_NUMBER() OVER (PARTITION BY A.ALF_PE ORDER BY A.ACTIVEFROM,  A.ACTIVETO) AS RW_SEQ                  
		FROM 
			SAILW1377V.TEMP_WP02_COHORT_TABLE A 
	), 
	DETAILS AS(
		SELECT 
			ALF_PE, START_DATE, END_DATE, LEAD_ST, RW_SEQ,
			CASE WHEN DAYS(LEAD_ST)-DAYS(END_DATE) < 2 THEN 1 ELSE 0 END AS SAME_PERIOD     
		FROM 
			BREAK1
		GROUP BY                   					
			ALF_PE, START_DATE, END_DATE, LEAD_ST, RW_SEQ,
			CASE WHEN DAYS(LEAD_ST)-DAYS(END_DATE) < 2 THEN 1 ELSE 0 END
	),
	FURTHER_DETAILS AS(
		SELECT 
			ALF_PE, START_DATE, END_DATE, LEAD_ST, RW_SEQ, SAME_PERIOD, 
			LAG(SAME_PERIOD) OVER (PARTITION BY ALF_PE ORDER BY ALF_PE, RW_SEQ) AS LAG_DATE        
		FROM 
			DETAILS
		GROUP BY									
			ALF_PE, START_DATE, END_DATE, LEAD_ST, RW_SEQ, SAME_PERIOD
	),
	RESULTS AS(
		SELECT 
			ALF_PE, START_DATE, END_DATE, LEAD_ST, RW_SEQ, SAME_PERIOD, LAG_DATE, 
			CASE
				WHEN RW_SEQ = 1 THEN START_DATE 						  
				WHEN RW_SEQ > 1 AND LAG_DATE = 1 THEN NULL 
				ELSE START_DATE 
			END AS NEW_START_DATE,  
			CASE WHEN DAYS(LEAD_ST)-DAYS(END_DATE) < 2 THEN NULL 
				ELSE END_DATE 
			END AS NEW_LAST_DATE    
		FROM 
			FURTHER_DETAILS
		GROUP BY
			ALF_PE, START_DATE, END_DATE, LEAD_ST, RW_SEQ, SAME_PERIOD,LAG_DATE,
			CASE
				WHEN RW_SEQ = 1 THEN START_DATE 
				WHEN RW_SEQ > 1 AND LAG_DATE = 1 THEN NULL 
				ELSE START_DATE 
			END,
			CASE 
				WHEN DAYS(LEAD_ST)-DAYS(END_DATE) < 2 THEN NULL 
				ELSE END_DATE 
			END
	),
	ROWSSELECT AS(
		SELECT 	
			ALF_PE, RW_SEQ, NEW_START_DATE, NEW_LAST_DATE,
			CASE 
				WHEN NEW_START_DATE IS NOT NULL AND NEW_LAST_DATE IS NULL THEN 1                        
				WHEN NEW_START_DATE IS NULL AND NEW_LAST_DATE IS NOT NULL THEN 1	
				WHEN NEW_START_DATE IS NOT NULL AND NEW_LAST_DATE IS NOT NULL THEN 2
				WHEN NEW_START_DATE IS NULL AND NEW_LAST_DATE IS NULL THEN 0
			END AS FLAGS
		FROM
			RESULTS
		GROUP BY
			ALF_PE, RW_SEQ, NEW_START_DATE, NEW_LAST_DATE,
			CASE 
				WHEN NEW_START_DATE IS NOT NULL AND NEW_LAST_DATE IS NULL THEN 1
				WHEN NEW_START_DATE IS NULL AND NEW_LAST_DATE IS NOT NULL THEN 1
				WHEN NEW_START_DATE IS NOT NULL AND NEW_LAST_DATE IS NOT NULL THEN 2
				WHEN NEW_START_DATE IS NULL AND NEW_LAST_DATE IS NULL THEN 0
			END
		ORDER BY 
			ALF_PE, RW_SEQ, NEW_START_DATE, NEW_LAST_DATE,
			CASE 
				WHEN NEW_START_DATE IS NOT NULL AND NEW_LAST_DATE IS NULL THEN 1
				WHEN NEW_START_DATE IS NULL AND NEW_LAST_DATE IS NOT NULL THEN 1
				WHEN NEW_START_DATE IS NOT NULL AND NEW_LAST_DATE IS NOT NULL THEN 2
				WHEN NEW_START_DATE IS NULL AND NEW_LAST_DATE IS NULL THEN 0
			END
	),
	GROUPINGDATES AS (
		SELECT
			ALF_PE, RW_SEQ, NEW_START_DATE, NEW_LAST_DATE, FLAGS,
			LEAD(NEW_LAST_DATE) OVER (PARTITION BY ALF_PE ORDER BY ALF_PE, RW_SEQ) AS FINAL_DATE
		FROM
			ROWSSELECT
		WHERE
			FLAGS = 1
		GROUP BY
			ALF_PE, RW_SEQ, NEW_START_DATE, NEW_LAST_DATE, FLAGS
		ORDER BY
			ALF_PE, RW_SEQ, NEW_START_DATE, NEW_LAST_DATE, FLAGS
	),
	UNION_T AS (
		SELECT
			ALF_PE, NEW_START_DATE, FINAL_DATE
		FROM
			(
				(
				SELECT                        
				ALF_PE, NEW_START_DATE, FINAL_DATE
				FROM
					GROUPINGDATES
				WHERE
					NEW_START_DATE IS NOT NULL
				GROUP BY
					ALF_PE, NEW_START_DATE, FINAL_DATE
				ORDER BY
					ALF_PE, NEW_START_DATE, FINAL_DATE
				)
			UNION ALL
				(
				SELECT                             
					ALF_PE, NEW_START_DATE, NEW_LAST_DATE AS FINAL_DATE
				FROM
					ROWSSELECT
				WHERE
					FLAGS = 2
				GROUP BY
					ALF_PE, NEW_START_DATE, NEW_LAST_DATE
				ORDER BY
					ALF_PE, NEW_START_DATE, NEW_LAST_DATE
				)
			)
		GROUP BY
			ALF_PE, NEW_START_DATE, FINAL_DATE
		ORDER BY
			ALF_PE, NEW_START_DATE, FINAL_DATE
	)
	SELECT ALF_PE,
		CASE WHEN NEW_START_DATE < SAILW1377V.COHORT_ST_DT THEN SAILW1377V.COHORT_ST_DT
			 ELSE NEW_START_DATE
		END AS NEW_START_DATE, 
		CASE WHEN FINAL_DATE > SAILW1377V.COHORT_END_DT THEN '9999-01-01'
			 ELSE FINAL_DATE 
		END AS NEW_FINAL_DATE,
		ROW_NUMBER() OVER (PARTITION BY ALF_PE ORDER BY NEW_START_DATE, FINAL_DATE) AS RW_SEQ
	FROM UNION_T; 	

-----------------------------------------------
-- Joining TEMP_WP02_COHORT_TABLE with the newly created TEMP_WP02_CT_BREAK 
-- to create a table with one row for individual -> we keep only the first period of residence/registration

CREATE TABLE SAILW1377V.TEMP_WP02_COHORT_TABLE2 (
	ALF_PE BIGINT, 
	WOB DATE, 
	DOD DATE, 
	GNDR_CD SMALLINT, 
	GNDR_DESC VARCHAR(10),
	AGE_COHORTSTART INTEGER, 
	ETHN_NER_CODE INTEGER, 
	ETHN_NER_DESC VARCHAR(20), 
	ETHN_ONS_CODE INTEGER, 
	ETHN_ONS_DESC VARCHAR(20),
	FLAG_START SMALLINT, 
	FLAG_START_DESC VARCHAR(50),
	FLAG_LATER_DATE DATE, 
	COHORT_ENTRY_DT DATE, 
	COHORT_EXIT_DT DATE,
	COHORT_LENGTH INTEGER,  
	EXIT_REASON VARCHAR(25),
	LSOA_COHORTSTART VARCHAR(9), 
	WIMD19_QUIN_COHORTSTART SMALLINT, 
	WIMD19_QUIN_DESC VARCHAR(20), 
	TOWNSEND11_QUIN_COHORTSTART SMALLINT, 
	TOWNSEND11_QUIN_DESC VARCHAR(20),
	PRAC_CD_PE_COHORTSTART BIGINT
); 

-----
--Creating auxiliary tables to fill TEMP_WP02_COHORT_TABLE2
-----
CREATE TABLE SAILW1377V.TEMP_ALF_FU (
	ALF_PE BIGINT, 
	FLAG_FU SMALLINT
); 

INSERT INTO SAILW1377V.TEMP_ALF_FU 
	WITH T1 AS (
		SELECT ALF_PE, MAX(RW_SEQ) AS MX
		FROM SAILW1377V.TEMP_WP02_CT_BREAK 
		GROUP BY ALF_PE
	)
	SELECT 
	ALF_PE, 1 AS FLAG_FU
	FROM T1 
	WHERE ALF_PE IN (SELECT ALF_PE FROM T1 WHERE MX > 1)
	UNION ALL 
	SELECT  
	ALF_PE, 0 AS FLAG_FU
	FROM T1
	WHERE ALF_PE IN (SELECT ALF_PE FROM T1 WHERE MX = 1); 
	 
--Exit reason temp table
CREATE TABLE SAILW1377V.TEMP_EXIT_REASON (
	ALF_PE BIGINT, 
	EXIT_REASON VARCHAR(25)
); 

INSERT INTO SAILW1377V.TEMP_EXIT_REASON 
	WITH TEMP_JOIN AS (
		SELECT DISTINCT 
			A.ALF_PE, A.DOD, B.NEW_ACTIVEFROM, B.NEW_ACTIVETO AS END_OVERLAP
		FROM SAILW1377V.TEMP_WP02_COHORT_TABLE A
		JOIN SAILW1377V.TEMP_WP02_CT_BREAK B 
		ON A.ALF_PE = B.ALF_PE 
		WHERE RW_SEQ = 1 -- keeping only the first time they are resident / registered 
	) 
	SELECT DISTINCT 
		A.ALF_PE, 
		CASE 
			WHEN A.DOD IS NOT NULL AND A.DOD <= B.END_OVERLAP THEN 'DEATH'
			WHEN A.DOD IS NOT NULL AND (A.DOD BETWEEN ADD_DAYS(B.END_OVERLAP, 1) AND ADD_DAYS(B.END_OVERLAP, 7) ) THEN 'DEATH'
			WHEN A.DOD IS NOT NULL AND A.DOD > ADD_DAYS(B.END_OVERLAP, 7) 
				AND B.END_OVERLAP <= SAILW1377V.COHORT_END_DT AND C.FLAG_FU = 1 THEN 'LOST TO FOLLOW UP BREAK'
			WHEN A.DOD IS NOT NULL AND A.DOD > ADD_DAYS(B.END_OVERLAP, 7) 
				AND B.END_OVERLAP <= SAILW1377V.COHORT_END_DT AND C.FLAG_FU = 0 THEN 'LOST TO FOLLOW UP'
			WHEN A.DOD IS NULL AND B.END_OVERLAP <= SAILW1377V.COHORT_END_DT 
				AND C.FLAG_FU = 1 THEN 'LOST TO FOLLOW UP BREAK'
			WHEN A.DOD IS NULL AND B.END_OVERLAP <= SAILW1377V.COHORT_END_DT 
				AND C.FLAG_FU = 0 THEN 'LOST TO FOLLOW UP'			
		ELSE NULL
			END AS EXIT_COHORT
		FROM 
			SAILW1377V.TEMP_WP02_COHORT_TABLE A 
		JOIN 
			TEMP_JOIN B 
		ON 
			A.ALF_PE = B.ALF_PE 
		JOIN 
			SAILW1377V.TEMP_ALF_FU C 
		ON 
			A.ALF_PE = C.ALF_PE ; 

CALL FNC.DROP_IF_EXISTS('SAILW1377V.TEMP_ALF_FU');
--------------------
--

INSERT INTO SAILW1377V.TEMP_WP02_COHORT_TABLE2 
	WITH LSOA_WIMD AS ( --selecting LSOA / WIMD / TOWNSEEND and PRAC_CD_PE when we have them available at cohort_start_date 
		SELECT DISTINCT 
			A.ALF_PE, 
			A.LSOA2011_CD AS LSOA_COHORTSTART, A.WIMD_2019_QUINTILE, A.WIMD_2019_QUINTILE_DESC, 
			A.TOWNSEND_2011_QUINTILE, A.TOWNSEND_2011_QUINTILE_DESC, 
			A.PRAC_CD_PE
		FROM SAILW1377V.TEMP_WP02_COHORT_TABLE A 
		WHERE FLAG_START = 1 AND WIMD_START = 1
	)
	SELECT DISTINCT 
		A.ALF_PE, A.WOB, A.DOD, A.GNDR_CD, 
		CASE WHEN A.GNDR_CD = 1 THEN 'Male'
			 WHEN A.GNDR_CD = 2 THEN 'Female'
		END AS GNDR_DESC,
		A.AGE_COHORTSTART, 
		A.ETHN_NER_CODE, A.ETHN_NER_DESC, A.ETHN_ONS_CODE, A.ETHN_ONS_DESC,
		A.FLAG_START, 
		CASE WHEN FLAG_START = 1 THEN 'Joined the cohort on COHORT_ST_DT'
			 WHEN FLAG_START = 0 THEN 'Joined the cohort after COHORT_ST_DT'
		END AS FLAG_START_DESC,
		A.FLAG_LATER_DATE, 
		B.NEW_ACTIVEFROM AS COHORT_ENTRY_DT, B.NEW_ACTIVETO AS COHORT_EXIT_DT, 
		CASE WHEN NEW_ACTIVETO = '9999-01-01' THEN DAYS_BETWEEN(SAILW1377V.COHORT_END_DT, B.NEW_ACTIVEFROM)
			 ELSE DAYS_BETWEEN(B.NEW_ACTIVETO, B.NEW_ACTIVEFROM) 
		END AS COHORT_LENGTH, 
		C.EXIT_REASON,
		D.LSOA_COHORTSTART, D.WIMD_2019_QUINTILE, D.WIMD_2019_QUINTILE_DESC, 
		D.TOWNSEND_2011_QUINTILE, D.TOWNSEND_2011_QUINTILE_DESC, 
		D.PRAC_CD_PE
	FROM SAILW1377V.TEMP_WP02_COHORT_TABLE A
	JOIN SAILW1377V.TEMP_WP02_CT_BREAK B 
	ON A.ALF_PE = B.ALF_PE
	JOIN SAILW1377V.TEMP_EXIT_REASON C
	ON A.ALF_PE = C.ALF_PE
	LEFT JOIN LSOA_WIMD D 
	ON A.ALF_PE = D.ALF_PE
	WHERE B.RW_SEQ = 1; 
	
CALL FNC.DROP_IF_EXISTS('SAILW1377V.TEMP_EXIT_REASON');
--CALL FNC.DROP_IF_EXISTS('SAILW1377V.TEMP_WP02_CT_BREAK');
CALL FNC.DROP_IF_EXISTS('SAILW1377V.TEMP_WP02_COHORT_TABLE');

CALL FNC.DROP_IF_EXISTS('SAILW1377V.WP02_COHORT_TABLE');
RENAME SAILW1377V.TEMP_WP02_COHORT_TABLE2 TO WP02_COHORT_TABLE; 

---------------------------------------------------------------------------------------
--PART 3 
--Create a table including all the residence/GP practices changes for each individual in the cohort
---------------------------------------------------------------------------------------
CALL FNC.DROP_IF_EXISTS('SAILW1377V.WP02_WDSD_GP_BREAK');

CREATE TABLE SAILW1377V.WP02_WDSD_GP_BREAK (
	ALF_PE BIGINT, 
	ACTIVEFROM DATE, 
	ACTIVETO DATE,
	PRAC_CD_PE BIGINT, 
	LSOA2011_CD VARCHAR(10), 
	LSOA2011_DESC VARCHAR(45), 
	LSOA2011_ONS_DESC VARCHAR(45),
	LSOA_DESC VARCHAR(17), 
	WELSH_ADDRESS INTEGER,
	WIMD_2014_SCORE DECIMAL(15,9),
	WIMD_2014_RANK INTEGER,
	WIMD_2014_QUINTILE INTEGER,
	WIMD_2014_QUINTILE_DESC VARCHAR(17),
	WIMD_2014_DECILE INTEGER,
	WIMD_2014_DECILE_DESC VARCHAR(18),
	WIMD_2014_QUARTILE INTEGER,
	WIMD_2014_QUARTILE_DESC VARCHAR(17),
	WIMD_2019_RANK INTEGER,
	WIMD_2019_QUINTILE INTEGER,
	WIMD_2019_QUINTILE_DESC VARCHAR(17),
	WIMD_2019_DECILE INTEGER,
	WIMD_2019_DECILE_DESC VARCHAR(18),
	WIMD_2019_QUARTILE INTEGER,
	WIMD_2019_QUARTILE_DESC VARCHAR(17),
	TOWNSEND_2011_SCORE DECIMAL(15,9),
	TOWNSEND_2011_QUINTILE INTEGER,
	TOWNSEND_2011_QUINTILE_DESC VARCHAR(17)
); 

INSERT INTO SAILW1377V.WP02_WDSD_GP_BREAK 
	WITH MAX_DT AS (
		SELECT ALF_PE, COHORT_EXIT_DT AS MAX_DT
		FROM SAILW1377V.WP02_COHORT_TABLE 
		),
	FIN1 AS (	
	SELECT DISTINCT
			A.ALF_PE, A.ACTIVEFROM , 
			CASE WHEN A.ACTIVETO IS NULL THEN '9999-01-01'
				 ELSE A.ACTIVETO 
			END AS ACTIVETO, 
			A.PRAC_CD_PE, A.LSOA2011_CD, 
			C.LSOA2011_DESC, C.LSOA2011_ONS_DESC, C.LSOA_DESC, C.WELSH_ADDRESS, 
			C.WIMD_2014_SCORE, C.WIMD_2014_RANK, C.WIMD_2014_QUINTILE, C.WIMD_2014_QUINTILE_DESC,
			C.WIMD_2014_DECILE, WIMD_2014_DECILE_DESC, C.WIMD_2014_QUARTILE, C.WIMD_2014_QUARTILE_DESC, 
			C.WIMD_2019_RANK, C.WIMD_2019_QUINTILE, C.WIMD_2019_QUINTILE_DESC, C.WIMD_2019_DECILE, 
			C.WIMD_2019_DECILE_DESC, C.WIMD_2019_QUARTILE, C.WIMD_2019_QUARTILE_DESC, 
			C.TOWNSEND_2011_SCORE, C.TOWNSEND_2011_QUINTILE, C.TOWNSEND_2011_QUINTILE_DESC
		FROM 
			SAIL1377V.WDSD_PER_RESIDENCE_GPREG_20230605 A 
		JOIN 
			SAILW1377V.WP02_COHORT_TABLE B 
		ON 
			A.ALF_PE = B.ALF_PE 
		JOIN 
			SAILW1377V.LSOA_WIMD_TOWNSEND11_MAP C 
		ON 
			A.LSOA2011_CD = C.LSOA2011_CD 
		WHERE 
			A.LSOA2011_CD IS NOT NULL --PEOPLE WITH RESIDENCE INFO 
			AND A.PRAC_CD_PE IS NOT NULL --PEOPLE WITH GP INFO 
			AND (A.ACTIVETO >= SAILW1377V.COHORT_ST_DT OR A.ACTIVETO IS NULL)--PEOPLE WITH ERESIDENCE/GP DATA AFTER COHORT_START 
			AND A.ACTIVEFROM <= SAILW1377V.COHORT_END_DT
		)
	SELECT FIN1.* FROM FIN1
	JOIN MAX_DT b 
	ON FIN1.ALF_PE = B.ALF_PE
	WHERE FIN1.ACTIVETO <= B.MAX_DT
; 
	




	


