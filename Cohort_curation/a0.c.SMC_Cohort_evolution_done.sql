----------------------------------------------
--PROJECT: MELD-B 1377
--WP02 (Work Package 02) - Stage 01 
--AUTHOR: roberta.chiovoloni@swansea.ac.uk
-----------------------------------------------------------------------------------------------
--AIM: Create a temporary table to analyse in WP02_Cohort_year_by_year.ipynb to have a picture of how the SMC cohort evolves
--     during the cohort period. Note WP02_cohort_table includes all individuals in the SMC cohort 

--Tables created: 
CALL FNC.DROP_IF_EXISTS ('SAILW1377V.TEMP_WDSD_WIMD_START_TEMP');
----------------------------------------------

--Create temporary table 
CREATE TABLE SAILW1377V.TEMP_WDSD_WIMD_START_TEMP (
	ALF_PE BIGINT, 
	WOB DATE, 
	DOD DATE, 
	GNDR_CD SMALLINT, 
	AGE INTEGER,
	EXIT_COHORT VARCHAR(100),
	WIMD_START DATE, 
	WIMD_END DATE,  
	WIMD SMALLINT, 
	START_OVERLAP DATE, 
	END_OVERLAP DATE, 
	RW_SEQ SMALLINT
	);
--------------------------
--Insert into table -> this table includes all the GP and LSOA registration for indivdiuals in the SMC cohort during the period of the time they are part of the cohort 

INSERT INTO SAILW1377V.TEMP_WDSD_WIMD_START_TEMP
WITH WIMD AS ( 
	SELECT DISTINCT 
		A.ALF_PE, B.WOB, B.DOD, B.GNDR_CD, B.AGE_COHORTSTART, B.EXIT_REASON, 
		A.ACTIVEFROM AS WIMD_START, 
		CASE WHEN A.ACTIVETO > SAILW1377V.COHORT_END_DT THEN ADD_DAYS(SAILW1377V.COHORT_END_DT, 1)
		 	 ELSE A.ACTIVETO
		END AS WIMD_END,
		C.WIMD_2019_QUINTILE AS WIMD, 
		B.COHORT_ENTRY_DT,
		CASE WHEN B.COHORT_EXIT_DT > SAILW1377V.COHORT_END_DT THEN ADD_DAYS(SAILW1377V.COHORT_END_DT, 1)
		 	 ELSE B.COHORT_EXIT_DT 
		END AS COHORT_EXIT_DT 
	FROM 
		SAILW1377V.WP02_WDSD_GP_BREAK A 
	JOIN 
		SAILW1377V.WP02_COHORT_TABLE B 
	ON 
		A.ALF_PE = B.ALF_PE
	JOIN 
		SAILW1377V.LSOA_WIMD_TOWNSEND11_MAP C -- table that maps Welsh LSOA to WIMD 
	ON 
		A.LSOA2011_CD = C.LSOA2011_CD 
	ORDER BY 
		ALF_PE, ACTIVEFROM
),
FIN AS ( --final table 
	SELECT DISTINCT
		A.*,
		ROW_NUMBER() OVER (PARTITION BY A.ALF_PE ORDER BY A.COHORT_ENTRY_DT, A.WIMD_START) AS RW_SEQ -- adding a RW_SEQ column 
	FROM 
		WIMD A
	)
SELECT * FROM FIN; 

