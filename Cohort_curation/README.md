This folder contains .sql and .ipynb codes used to create SMC and the relevant tables on the database. <br>
The codes used to create SMYC and its relevant tables are similar. <br>

Both .sql and .ipynb codes have to be executed following the alphabetical order. 

- [a0.a.SMC_ALF_extraction.sql](https://github.com/SwanseaUniversityDataScience/1377-MELD_B-CohortCuration/blob/main/Cohort_curation/a0.a.SMC_ALF_extraction.sql) : this code is used to extract the ALF who are part of the SMC cohort
- [a0.b.SMC_CLT_creation.sql](https://github.com/SwanseaUniversityDataScience/1377-MELD_B-CohortCuration/blob/main/Cohort_curation/a0.b.SMC_CLT_creation.sql): This code creates Cohort Linkage Tables (CLTs). Each row represents an individual in the SMC (or SMYC), i.e an ALF, and each column represents a SAIL datasource (e.g., WLGP, PEDW, ...). If the value of the columns is 1, then that ALF has records available in that datasource. CLTs are used for Figure 4 and Figure 5. 
- [a0.c.SMC_Cohort_evolution_done.sql](https://github.com/SwanseaUniversityDataScience/1377-MELD_B-CohortCuration/blob/main/Cohort_curation/a0.c.SMC_Cohort_evolution_done.sql): this code is used to create an auxiliary table to extrapolate the SMC evolution data (Table 3 in Suppl.Material1)
- [a2.a.SMC_ALF_DatasetExtraction.sql](https://github.com/SwanseaUniversityDataScience/1377-MELD_B-CohortCuration/blob/main/Cohort_curation/a2.a.SMC_ALF_DatasetExtraction.sql): this code creates datasources extraction. Given the ALFs identified running a0.a, we extract all their records in the different datasources (WLGP, PEDW, OPDW, ....) 
