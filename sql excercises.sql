-- Find the average number of orderws per encounter by provider/physician.--
WITH provider_encounters AS
	(SELECT 
		ordering_provider_id,
		patient_encounter_id,
		COUNT(order_procedure_id) num_orders
	FROM gh.orders_procedures
	GROUP BY 1,2),
provider_orders AS 
	(SELECT 
		ordering_provider_id, 
		AVG(num_orders) avg
	 FROM provider_encounters
	 GROUP BY ordering_provider_id)

SELECT
	first_name, 
	last_name, 
	avg
FROM gh.physicians p 
LEFT JOIN provider_orders o
ON o.ordering_provider_id=p.id
WHERE avg IS NOT NULL 
ORDER BY avg DESC;

--Find encounters with any of the top 10 most common order codes
SELECT 
DISTINCT(patient_encounter_id)
FROM gh.orders_procedures
WHERE order_cd IN 
	(SELECT order_cd
	FROM gh.orders_procedures
	GROUP BY order_cd
	ORDER BY COUNT(*) DESC
	LIMIT 10);
--	Find encounters for patients born on or after 1995-01-01 whose length of stay is greater tan or equal to the average surgical length stay for patients 65 or older--
WITH old AS (
	SELECT EXTRACT(year FROM now())-EXTRACT(year FROM date_of_birth) age,
	AVG(patient_discharge_datetime - patient_admission_datetime) avg_len
	FROM gh.patients p
	INNER JOIN gh.encounters e
	ON p.master_patient_id= e.master_patient_id
	WHERE EXTRACT(year FROM now())-EXTRACT(year FROM date_of_birth)>=65 
	AND date_of_birth IS NOT NULL
	GROUP BY age
	ORDER BY avg_len
	DESC)

SELECT gh.patients.master_patient_id from gh.encounters 
INNER JOIN gh.patients
ON gh.encounters.master_patient_id=gh.patients.master_patient_id
AND date_of_birth >='1995-01-01'
WHERE patient_discharge_datetime - patient_admission_datetime >= ALL(SELECT avg_len FROM old);


--For each department find the 3 physicians with the most admissions--
WITH provider_department AS (
	SELECT 
		admitting_provider_id,
		department_id,
		COUNT(*) AS num_encounters
	FROM gh.encounters
	GROUP BY 1,2), 
pd_ranked AS (
	SELECT 
	*,
	ROW_NUMBER() OVER(PARTITION BY department_id ORDER BY num_encounters DESC ) encounter_rank
	FROM provider_department)
	
SELECT 
d.department_name,
p.full_name
num_encounters,
encounter_rank 
FROM pd_ranked r
LEFT OUTER JOIN gh.physicians p
ON p.id= r.admitting_provider_id
LEFT OUTER JOIN gh.departments d
ON d.department_id=r.department_id
WHERE encounter_rank <=3;


-- Find all surgeries that occured within 30 days of a previous surgery -- 

WITH surgeries_lagged AS(
	SELECT 
	surgery_id,
	master_patient_id,
	surgical_admission_date,
	surgical_discharge_date,
	LAG(surgical_discharge_date) OVER(PARTITION BY master_patient_id ORDER BY surgical_admission_date )
	AS previous_discharge_date 
	FROM gh.surgical_encounters)

SELECT 
	*,
	(surgical_admission_date - previous_discharge_date) days_between_surgeries
FROM surgeries_lagged
WHERE surgical_admission_date - previous_discharge_date <=30
	
	
	


