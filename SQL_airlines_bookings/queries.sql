--� ����� ������� ������ ������ ���������?

-- 1. �������� ������� city � airport_name.
-- 2. �� ���� ����� ���������� ��������� ����������. ���������� �� �������,
-- ������� �������� ���������� � ������� ������������ ������� count.
-- 3. ����������� ��������� �� ������� ���������� airport_name > 1,
-- ����� ���������� � ���������� ��������� count ���������� having.

SELECT
city ->> 'en' as city_en,
COUNT(airport_name ->> 'en') AS airport_name_en
FROM airports_data
GROUP BY city_en
HAVING COUNT(airport_name ->> 'en') > 1;



--� ����� ���������� ���� �����, ������� ������������� ���������� � ������������ ���������� ���������?

-- 1. �������� ������ ��������� (aircraft_code) � ������������ ���������� �������. ������� ������ � CTE.
-- 2. ���������� ��������� ���������� � �������� flights, ����� �������� ������ �� ���������,
-- � ������� ���� ����� � ���������� � ������������ ����������
-- 3. ��� �������� ��������� �������� ���������� �� ������� airports_data
-- 4. �������� �������� (depart) �� ������� ��������� � ������� ��������� (arrive),
-- ������� ���������� ������� ��� ��������� �� departure ��� arrival
-- 5. ���������� �������� � ��� ��������� � ������� ������������ ��� ��������


--Max flight range airplane model
WITH CTE_acd AS(
    SELECT
	"range",
    acd.aircraft_code
    FROM aircrafts_data acd
    ORDER BY "range" DESC
    LIMIT 1
)
SELECT
DISTINCT ad.airport_name ->> 'en' || ' - ' ||  f.departure_airport AS airport_name_code
FROM CTE_acd acd
INNER JOIN flights f
    ON acd.aircraft_code = f.aircraft_code
LEFT JOIN airports_data ad
    ON f.departure_airport = ad.airport_code;



--���� �� �����, �� ������� �� ����������� ��������?
-- ��������: ����� �� ������� �� ����������� �������� �� ����� ����������� ������ boarding_no

-- 1. ���������� ������� bookings, tickets, boarding_passes,��� ������������� booking_no � boarding_no � ������� ticket_no
-- 2. ��������� ������� boarding_no is null - ����� ���������� �� ����� �� ������� �� �������� ���������� ������
-- 3. � ����������� �� ������ �������� ���� �� ��������:
-- �������� ���� ������ ������ �� ������� �� ����������� ��������
-- ��� � ������� count() �������� ���������� ����� ������

--�����: ����, �� ���������� ����� 127899

--���� ������ ������ ��� ���������:
SELECT
bk.book_ref AS bookings_booking_no,
bp.boarding_no
FROM bookings bk
LEFT JOIN tickets t
    ON bk.book_ref = t.book_ref
LEFT JOIN boarding_passes bp
    ON t.ticket_no = bp.ticket_no
WHERE bp.boarding_no IS NULL;

--���������� ������ �� ������� �� ���� ���������
SELECT
COUNT(bk.book_ref) AS bookings_booking_no
FROM bookings bk
LEFT JOIN tickets t
    ON bk.book_ref = t.book_ref
LEFT JOIN boarding_passes bp
    ON t.ticket_no = bp.ticket_no
WHERE bp.boarding_no IS NULL;



--�������� ����� ������� ��������� ���������� % ���������?

-- 1. � ������� count() ������� ���������� ��������� flight_id ����������� ������ ������� �������� � ���������� �� ������� aircraft_code
-- 2. ���������� ������������ ������� � aircrafts_data, ����� �������� �������� �������, ��� �������� ����������
-- 3. ������� ������� ��������� �� ������ ������, ��������� ��������� �� ������� ��� ��������
-- 4. ��������� �� �������� � ������������ ���������� 3 ��������, ������������ ���������� % ���������



-- �����: ���������� % ��������� ��������� �������� (�� ��������):
-- CN1          |Cessna 208 Caravan
-- CR2          |Bombardier CRJ-200
-- SU9          |Sukhoi Superjet-100

--Count flights per model
WITH fl AS(
    SELECT
	fl.aircraft_code,
	COUNT(fl.flight_id) AS flights_per_model
	FROM flights fl
	GROUP BY fl.aircraft_code
)
SELECT
fl.aircraft_code,
model ->> 'en' as model_name,
flights_per_model,
ROUND(flights_per_model/ SUM(flights_per_model) OVER() * 100, 1) AS percentage
FROM fl
JOIN aircrafts_data ad
    ON fl.aircraft_code = ad.aircraft_code
ORDER BY percentage DESC
LIMIT 3;


--������ ������������ ����� �������� ������� ���������

-- 1. ���� 2 ���� ������ � ��������� ������ - ��, ��� ��� �������� � ��, ��� ��� �������������, �� ��� �� ��������,
-- ��� ������ � ������ �������� ���������� ����������� case when else
-- 2. ��� ���������� ������, �.�. ��� ������� ����������� ����� ������ �������� scheduled_departure �� actual_departure,
-- ����������� timestamp � int � ����� �� 60, ����� �������� ������
-- 3. L�� ��� �� ���������� ������ actual_departure ���������� bookings.now() (���������� ���� ������),
-- � ���������� �� �� ��������, ��� � ����
-- 4. ������� ������������ �������� � ������� ������������ ������� max()

-- ���������������� ���� �������� ��������� ����� ������ � ���, ��� ����� � ���������
-- ������ ���� ������� ��������� ����� �������� �������. ������� ������ ��������� � ������� bookings.now().


-- �����: 281 ������

SELECT
	MAX(
	    CASE
		WHEN actual_departure IS NULL
		THEN EXTRACT(EPOCH FROM(bookings.NOW() - f.scheduled_departure))/60
		ELSE EXTRACT(EPOCH FROM(f.actual_departure - f.scheduled_departure))/60
	    END
	    ) AS max_delay_min
FROM flights f;



--����� ������ �������� ��� ������ ������?

-- 1. �������� ������ �������, ������� � CTE cte_cities
-- 2. �������� ��� ��������� ���������� �������, ��������� cte_cities � ����� � ������� cross join,
-- ������� � CTE cte_cities_comb
-- 3. �������� ��� ������������ �������� ��������� ����� ��������, ��������� ������� flights � airports_data,
-- ���������� ������, ����� ��������� �������� ��������� � ������� ��� ��� ������,
-- ��� � ��� �������, ������� � CTE flights_cities
-- 4. ���������� ��� ��������� ���������� ������� cte_cities_comb �
-- ��� ������������ �������� ��������� flights_cities � ������� left join,
-- ����� � �������������� ������� ���� ���������� �������, ��� ������� ��� ������������� �������� �� ������� ���������,
-- �.�.������ ������
-- 5. ��������� �� �������, ��� ������ ������ depart_city � ������� arriv_city �� ����� �������� -
-- ��������� ������ �� ���������� �������, ��� ��� ������ ������
-- 6. ������������� ��������� ����� � ����������� ��������, ������� ������������ �� ���� cross join - ccc.dep!=ccc.arr
-- 7. ������� ��������������� ������ ���������� ������� �� cte_cities_comb



WITH cte_cities AS (
-- cities list
		SELECT DISTINCT
		ad.city ->> 'en' AS city
		FROM airports_data ad
),
    cte_cities_comb AS (
-- all possible combinations of cities
	SELECT
	cs1.city AS dep,
	cs2.city AS arr
	FROM cte_cities cs1
	CROSS JOIN cte_cities cs2
),
	flights_cities AS (
-- existing flights routes
SELECT DISTINCT
ad_dep.city ->> 'en' AS depart_city,
ad_arr.city ->> 'en' AS arriv_city
FROM flights f2
INNER JOIN airports_data ad_dep
    ON f2.departure_airport = ad_dep.airport_code
INNER JOIN airports_data ad_arr
    ON f2.arrival_airport = ad_arr.airport_code
)
SELECT
dep || '-' || arr AS no_direct_flights
FROM cte_cities_comb ccc
LEFT JOIN flights_cities flc
    ON ccc.dep = flc.depart_city
    AND ccc.arr = flc.arriv_city
WHERE flc.depart_city IS NULL
  AND flc.arriv_city IS NULL
  AND ccc.dep!=ccc.arr;














