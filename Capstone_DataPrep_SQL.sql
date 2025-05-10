CREATE TABLE admission (
	patient_id VARCHAR(8),
	admission_id VARCHAR(8) PRIMARY KEY NOT NULL,
	admission_time TIMESTAMP,
	discharge_time TIMESTAMP,
	drop_death_time TEXT,
	admission_type VARCHAR(40),
	drop_admission_provider_id TEXT,
	admission_location VARCHAR(40),
	discharge_location VARCHAR(40),
	insurance VARCHAR(10),
	primary_language VARCHAR(30),
	marital_status VARCHAR(15),
	race VARCHAR(50),
	drop_edregtime TEXT,
	drop_edouttime TEXT,
	drop_hospital_expire_flag TEXT
);

-- drop irrelevant columns
ALTER TABLE admission
DROP COLUMN drop_death_time,
DROP COLUMN drop_admission_provider_id,
DROP COLUMN drop_edregtime,
DROP COLUMN drop_edouttime,
DROP COLUMN drop_hospital_expire_flag,
DROP COLUMN discharge_location;

CREATE TABLE patient (
	patient_id VARCHAR(8) PRIMARY KEY,
	gender VARCHAR(1),
	age INTEGER,
	drop_anchor_year TEXT,
	drop_anchor_year_group TEXT,
	drop_dod TEXT
);

ALTER TABLE patient
DROP COLUMN drop_anchor_year,
DROP COLUMN drop_anchor_year_group,
DROP COLUMN drop_dod;

CREATE TABLE service (
	patient_id VARCHAR(8),
	admission_id VARCHAR(8),
	drop_transfertime TEXT,
	previous_service VARCHAR(8),
	current_service VARCHAR(8)
);

ALTER TABLE service
DROP COLUMN drop_transfertime;

CREATE TABLE diagnoses_icd (
	patient_id VARCHAR(8),
	admission_id VARCHAR(8),
	drop_seq_num TEXT,
	drop_icd_code TEXT,
	drop_ice_version TEXT
);

ALTER TABLE diagnoses_icd
DROP COLUMN drop_seq_num,  
DROP COLUMN drop_icd_code,
DROP COLUMN drop_ice_version;

CREATE TABLE procedures_icd (
	patient_id VARCHAR(8),
	admission_id VARCHAR(8),
	drop_seq_num TEXT,
	drop_chartdate TEXT,
	drop_icd_code TEXT,
	drop_icd_version TEXT
);

ALTER TABLE procedures_icd
DROP COLUMN drop_seq_num,  
DROP COLUMN drop_chartdate,
DROP COLUMN drop_icd_code,
DROP COLUMN drop_icd_version;

-- Electronic Medication Administration Record
CREATE TABLE emar (
	patient_id VARCHAR(8),
	admission_id VARCHAR(8),
	drop_emar_id TEXT,
	drop_emar_seq TEXT,
	drop_poe_id TEXT,
	drop_pharmacy_id TEXT,
	drop_enter_provider_id TEXT,
	chart_time TIMESTAMP,
	drop_medication TEXT,
	event_txt VARCHAR(50),
	scheduletime TIMESTAMP,
	storetime TIMESTAMP
);

ALTER TABLE emar
DROP COLUMN drop_emar_id, 
DROP COLUMN drop_emar_seq, 
DROP COLUMN drop_poe_id, 
DROP COLUMN drop_pharmacy_id, 
DROP COLUMN drop_enter_provider_id, 
DROP COLUMN drop_medication;

WITH Delete_Negative_Durations AS (
	-- delete negative durations
	SELECT admission_id
	FROM admission
	WHERE discharge_time - admission_time < '0'::INTERVAL
)

DELETE FROM admission 
WHERE admission_id IN (SELECT admission_id FROM Delete_Negative_Durations);

– delete admissions with no first service
DELETE FROM admission A
WHERE NOT EXISTS (
    SELECT 1
    FROM service S
    WHERE S.admission_id = A.admission_id
);

- - delete admissions with service errors
WITH Delete_Service_Errors AS (

	SELECT admission_id
	FROM service
	GROUP BY admission_id
	HAVING COUNT(*) = 1
	
) 

DELETE FROM admission A
WHERE A.admission_id IN (
    SELECT S.admission_id
    FROM service S
    INNER JOIN Delete_Service_Errors DSE
    USING(admission_id)
    WHERE S.previous_service IS NOT NULL
);

CREATE TABLE critical_care_data AS
WITH Set_Procedure_Count AS (

	-- get the count of procedures per admission
	-- count admission_id in procedures_icd for the total procedure count
	-- use left join to amke sure admsissions without procedures are included with count 0
	SELECT admission_id, COUNT(P.admission_id) AS procedure_count
	FROM admission A
	LEFT JOIN procedures_icd P
	USING(admission_id)
	GROUP BY admission_id
	
), Set_Diagnoses_Count AS (

	-- get the count of diagnoses per admission
	-- count admission_id in diagnoses_icd for the total diagnoses count
	-- use left join to amke sure admissions without any diagnoses are included with count 0
	SELECT admission_id, COUNT(D.admission_id) AS diagnoses_count
	FROM admission A
	LEFT JOIN diagnoses_icd D
	USING(admission_id)
	GROUP BY admission_id
	
), First_Service AS (

	-- get the first service 
	SELECT admission_id, current_service AS first_service
	FROM service
	WHERE previous_service IS NULL
	
), Set_Mediccation_Ordered_Count AS (

	-- all ordered medications are not administered
	SELECT admission_id, COUNT(E.admission_id) AS medications_ordered
	FROM admission A
	LEFT JOIN emar E
	USING(admission_id)
	GROUP BY admission_id
	
), Set_Mediccation_Given_Count AS (

	-- get the count of medications acutually administered
	SELECT A.admission_id, COUNT(E.admission_id) AS medications_given
	FROM admission A
	LEFT JOIN emar E
	ON A.admission_id = E.admission_id  AND 
	E.event_txt IN ('Administered', 'Administered Bolus from IV Drip', 
	                   'Administered in Other Location', 'Applied', 
	                   'Applied in Other Location', 'Delayed Administered', 
	                   'Delayed Applied', 'Partial Administered', 'Started', 
	                   'Started in Other Location', 'Restarted', 
	                   'Restarted in Other Location', 
	                   'Removed Existing / Applied New',
	                   'Removed Existing / Applied New in Other Location')
	GROUP BY A.admission_id

), Calc_Time_Between AS (

	SELECT patient_id, 
		   admission_id, 
		   admission_time, 
		   discharge_time,
		   -- subtract the previous discharge from the current admission time to
		   -- get the time since the last admission
		   admission_time - LAG(discharge_time, 1) OVER(PARTITION BY patient_id ORDER BY admission_time) AS time_since_last_admission
	FROM admission 
	
), Readmission AS (

	SELECT admission_id, 
		   discharge_time - admission_time AS duration,
		   -- by design time_since_last_admission NULL is not a readmission
		   CASE WHEN time_since_last_admission < '30 days'::INTERVAL
		   	    THEN 1
				ELSE 0 
				END AS readmission_status
	FROM Calc_Time_Between
	
)

SELECT 
	A.*,
	SPC.procedure_count,
	SDC.diagnoses_count,
	F.first_service,
	SMOC.medications_ordered,
	SMGC.medications_given,
	R.readmission_status,
	R.duration,
	P.age,
	P.gender
FROM admission A
INNER JOIN Set_Procedure_Count SPC
USING(admission_id)
INNER JOIN Set_Diagnoses_Count SDC
USING(admission_id)
INNER JOIN First_Service F
USING(admission_id)
INNER JOIN Set_Mediccation_Ordered_Count SMOC
USING(admission_id)
INNER JOIN Set_Mediccation_Given_Count SMGC
USING(admission_id)
INNER JOIN Readmission R
USING(admission_id)
INNER JOIN patient P
USING(patient_id)
ORDER BY patient_id;

-- first add a new column
ALTER TABLE critical_care_data 
ADD COLUMN duration_hours NUMERIC;

WITH Convert_Duration AS (
	SELECT 
		admission_id,
	    ROUND((EXTRACT(DAY FROM duration) * 24) + 
	           EXTRACT(HOUR FROM duration) + 
	          (EXTRACT(MINUTE FROM duration) / 60), 4) AS duration_hours
	FROM critical_care_data
)

UPDATE critical_care_data
SET duration_hours = ROUND((EXTRACT(DAY FROM duration) * 24) + 
                            EXTRACT(HOUR FROM duration) + 
                           (EXTRACT(MINUTE FROM duration) / 60), 4);

CREATE TABLE drg_code (
	patient_id VARCHAR(8),
	admission_id VARCHAR(8),
	drg_type VARCHAR(8),
	drop_drg_code TEXT,
	drop_description TEXT,
	drg_severity INTEGER,
	drg_mortality INTEGER
)

ALTER TABLE critical_care_data
ADD COLUMN drg_severity INTEGER,
ADD COLUMN drg_mortality INTEGER;

UPDATE critical_care_data
SET drg_severity = DRGC.drg_severity,
	drg_mortality = DRGC.drg_mortality
FROM drg_code AS DRGC
WHERE critical_care_data.admission_id = DRGC.admission_id;

DELETE FROM critical_care_data
WHERE drg_severity IS NULL OR drg_mortality IS NULL;

-- negative delays means medicine ahead of schedule
SELECT admission_id, SUM(chart_time - scheduletime) AS delays
FROM emar
INNER JOIN critical_care_data
USING(admission_id)
GROUP BY admission_id;

-- ignore negative medication durations
SELECT admission_id, SUM(storetime - chart_time) AS medication_duration
FROM emar
INNER JOIN critical_care_data
USING(admission_id)
GROUP BY admission_id
HAVING SUM(storetime - chart_time) < '0'::INTERVAL;

-- add the extra emar cols
CREATE TABLE critical_care_emar AS
WITH add_emar_cols AS (
	SELECT 
	    CCD.admission_id, 
	    -- add the medication delays/duration but use a 0 intervals for nulls
	    -- as a substitute b/c entries with no medications given have 0 delay/duration
	    COALESCE(SUM(E.chart_time - E.scheduletime), '0'::INTERVAL) AS medication_delays,
		-- exclude medication entries where the start time is after the application time
		-- those are data entry errors
	    COALESCE(SUM(CASE WHEN E.storetime > E.chart_time 
	                      THEN E.storetime - E.chart_time 
	                      ELSE NULL END), '0'::INTERVAL) AS medication_duration
	FROM critical_care_data CCD
	LEFT JOIN emar E
	    USING(admission_id)
	GROUP BY CCD.admission_id
)

SELECT 
	CCD.*, 
	AEC.medication_delays, 
	AEC.medication_duration
FROM critical_care_data CCD
INNER JOIN add_emar_cols AEC
	USING(admission_id);

ALTER TABLE critical_care_emar
ADD COLUMN drg_severity INTEGER,
ADD COLUMN drg_mortality INTEGER;

UPDATE critical_care_emar
SET drg_severity = DRGC.drg_severity,
	drg_mortality = DRGC.drg_mortality
FROM drg_code AS DRGC
WHERE critical_care_emar.admission_id = DRGC.admission_id;

UPDATE critical_care_emar
SET drg_severity = COALESCE(drg_severity, 0),
	drg_mortality = COALESCE(drg_mortality, 0);
ALTER TABLE critical_care_emar
ADD COLUMN medication_delays_hours FLOAT,
ADD COLUMN medication_duration_hours FLOAT;

-- update the new columns with the converted values
UPDATE critical_care_emar
SET medication_delays_hours = EXTRACT(EPOCH FROM medication_delays)/3600,
    medication_duration_hours = EXTRACT(EPOCH FROM medication_duration)/3600;

ALTER TABLE critical_care_emar
ALTER COLUMN medication_delays_hours TYPE numeric,
ALTER COLUMN medication_duration_hours TYPE numeric;

CREATE TABLE vital (
	patient_id VARCHAR(8),
	chartdate TIMESTAMP,
	seq_num INTEGER,
	result_name VARCHAR(50),
	result_value VARCHAR(20)
);

CREATE TABLE critical_care_vitals AS
WITH pivoted_vitals AS (
    SELECT 
		patient_id, 
		chartdate, 
		--MAX(CASE WHEN result_name = 'Blood Pressure' THEN result_value END) AS max_blood_pressure,
		--MIN(CASE WHEN result_name = 'Blood Pressure' THEN result_value END) AS min_blood_pressure,
    	MAX(CASE WHEN result_name = 'BMI (kg/m2)' THEN result_value END) AS max_bmi,
		MIN(CASE WHEN result_name = 'BMI (kg/m2)' THEN result_value END) AS min_bmi,
    	MAX(CASE WHEN result_name = 'Weight (Lbs)' THEN result_value END) AS weight,
    	MAX(CASE WHEN result_name = 'Height (Inches)' THEN result_value END) AS height
    FROM vital
    WHERE result_name IN ('BMI (kg/m2)', 'Weight (Lbs)', 'Height (Inches)')
	AND result_value IS NOT NULL
	AND result_value <> '.'
    GROUP BY patient_id, chartdate
    HAVING COUNT(DISTINCT result_name) = 3
)

SELECT 
	CCE.*,
	--PV.max_blood_pressure,
	--PV.min_blood_pressure,
    PV.max_bmi::NUMERIC,
	PV.min_bmi::NUMERIC,
    PV.weight::NUMERIC,
    PV.height::NUMERIC
FROM critical_care_emar CCE
INNER JOIN pivoted_vitals PV
ON (CCE.patient_id = PV.patient_id) AND 
   (PV.chartdate BETWEEN (admission_time - '2 day'::INTERVAL) AND discharge_time)

CREATE TABLE critical_care_bp AS
WITH pivoted_vitals AS (
    SELECT 
        patient_id, 
        chartdate, 
        -- Extract SBP (systolic) and DBP (diastolic) by splitting the 'Blood Pressure' value
        MAX(CASE 
                WHEN result_name = 'Blood Pressure' 
                THEN CAST(SPLIT_PART(result_value, '/', 1) AS NUMERIC) 
            END) AS sbp, 
        MAX(CASE 
                WHEN result_name = 'Blood Pressure' 
                THEN CAST(SPLIT_PART(result_value, '/', 2) AS NUMERIC) 
            END) AS dbp
    FROM vital
    WHERE result_name = 'Blood Pressure'
    AND result_value IS NOT NULL
    AND result_value <> '.'
    GROUP BY patient_id, chartdate
)

SELECT 
    CCE.*,
    PV.sbp,
    PV.dbp,
    -- Calculate MAP: (SBP + 2 * DBP) / 3
    ROUND((PV.sbp + 2 * PV.dbp) / 3, 2) AS map
FROM critical_care_emar CCE
INNER JOIN pivoted_vitals PV
ON (CCE.patient_id = PV.patient_id) 
AND (PV.chartdate BETWEEN (admission_time - INTERVAL '2 days') AND discharge_time);

CREATE TABLE critical_care_emar_procedures AS
SELECT 
	c.*,
    CASE 
        WHEN p.drop_icd_code BETWEEN '00' AND '00' THEN '0'
        WHEN p.drop_icd_code BETWEEN '01' AND '05' THEN '1'
        WHEN p.drop_icd_code BETWEEN '06' AND '07' THEN '2'
        WHEN p.drop_icd_code BETWEEN '08' AND '16' THEN '3'
        WHEN p.drop_icd_code BETWEEN '17' AND '17' THEN '4'
        WHEN p.drop_icd_code BETWEEN '18' AND '20' THEN '5'
        WHEN p.drop_icd_code BETWEEN '21' AND '29' THEN '6'
        WHEN p.drop_icd_code BETWEEN '30' AND '34' THEN '7'
        WHEN p.drop_icd_code BETWEEN '35' AND '39' THEN '8'
        WHEN p.drop_icd_code BETWEEN '40' AND '41' THEN '9'
        WHEN p.drop_icd_code BETWEEN '42' AND '54' THEN '10'
        WHEN p.drop_icd_code BETWEEN '55' AND '59' THEN '11'
        WHEN p.drop_icd_code BETWEEN '60' AND '64' THEN '12'
        WHEN p.drop_icd_code BETWEEN '65' AND '71' THEN '13'
        WHEN p.drop_icd_code BETWEEN '72' AND '75' THEN '14'
        WHEN p.drop_icd_code BETWEEN '76' AND '84' THEN '15'
        WHEN p.drop_icd_code BETWEEN '85' AND '86' THEN '16'
        WHEN p.drop_icd_code BETWEEN '87' AND '99' THEN '17'
        ELSE '18'
    END AS procedure_category
FROM procedures_icd p
INNER JOIN critical_care_emar c ON p.admission_id = c.admission_id
WHERE p.drop_icd_version = '9'
AND p.drop_seq_num = '1';

-- FIX THE ERROR THAT CAUSED ALL THE MEDICATION ORDERED/GIVEN VALUES TO BE ALL ZEROS
WITH Set_Mediccation_Ordered_Count AS (

	-- all ordered medications are not administered
	SELECT admission_id, COUNT(E.admission_id) AS medications_ordered
	FROM admission A
	LEFT JOIN emar E
	USING(admission_id)
	GROUP BY admission_id
	
), Set_Mediccation_Given_Count AS (

	-- get the count of medications acutually administered
	SELECT A.admission_id, COUNT(E.admission_id) AS medications_given
	FROM admission A
	LEFT JOIN emar E
	ON A.admission_id = E.admission_id  AND 
	E.event_txt IN ('Administered', 'Administered Bolus from IV Drip', 
	                   'Administered in Other Location', 'Applied', 
	                   'Applied in Other Location', 'Delayed Administered', 
	                   'Delayed Applied', 'Partial Administered', 'Started', 
	                   'Started in Other Location', 'Restarted', 
	                   'Restarted in Other Location', 
	                   'Removed Existing / Applied New',
	                   'Removed Existing / Applied New in Other Location')
	GROUP BY A.admission_id

)

-- change the table for critical_care_emar, critical_care_emar_procedures, critical_care_vitals, and critical_care_bp
UPDATE critical_care_data CCE
SET medications_ordered = SMOC.medications_ordered,
    medications_given = SMGC.medications_given
FROM Set_Mediccation_Ordered_Count SMOC,
	 Set_Mediccation_Given_Count SMGC
WHERE CCE.admission_id = SMOC.admission_id AND
	  CCE.admission_id = SMGC.admission_id;
