--В каких городах больше одного аэропорта?

-- 1. Выбираем столбцы city и airport_name.
-- 2. На один город приходится несколько аэропортов. Группируем по городам,
-- считаем названия аэропортов с помощью агрегирующей функции count.
-- 3. Отфильтруем результат по условию количество airport_name > 1,
-- чтобы обратиться к результату агрегации count используем having.

SELECT
city ->> 'en' as city_en,
COUNT(airport_name ->> 'en') AS airport_name_en
FROM airports_data
GROUP BY city_en
HAVING COUNT(airport_name ->> 'en') > 1;



--В каких аэропортах есть рейсы, которые обслуживаются самолетами с максимальной дальностью перелетов?

-- 1. Выбираем модель самолетов (aircraft_code) с максимальной дальностью полетов. Выносим запрос в CTE.
-- 2. Объединяем результат подзапроса с таблицей flights, чтобы оставить только те аэропорты,
-- в которых есть рейсы с самолетами с максимальной дальностью
-- 3. Для удобства добавляем названия аэропортов из таблицы airports_data
-- 4. Самолеты вылетают (depart) из каждого аэропорта в который прилетели (arrive),
-- поэтому достаточно выбрать все аэропорты из departure или arrival
-- 5. Объединяем название и код аэропорта с помощью конкатенации для удобства


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



--Были ли брони, по которым не совершались перелеты?
-- Описание: Брони по которым не совершались перелеты не имеют посадочного талона boarding_no

-- 1. Объединяем таблицы bookings, tickets, boarding_passes,для сопоставления booking_no и boarding_no с помощью ticket_no
-- 2. Указываем условие boarding_no is null - чтобы отобразить те брони по которым не получены посадочные талоны
-- 3. В зависимости от задачи выбираем один из запросов:
-- получаем весь список броней по которым не совершались перелеты
-- или с помощью count() получаем количество таких броней

--Ответ: Были, их количество равно 127899

--Весь список броней без перелетов:
SELECT
bk.book_ref AS bookings_booking_no,
bp.boarding_no
FROM bookings bk
LEFT JOIN tickets t
    ON bk.book_ref = t.book_ref
LEFT JOIN boarding_passes bp
    ON t.ticket_no = bp.ticket_no
WHERE bp.boarding_no IS NULL;

--Количество броней по которым не было перелетов
SELECT
COUNT(bk.book_ref) AS bookings_booking_no
FROM bookings bk
LEFT JOIN tickets t
    ON bk.book_ref = t.book_ref
LEFT JOIN boarding_passes bp
    ON t.ticket_no = bp.ticket_no
WHERE bp.boarding_no IS NULL;



--Самолеты каких моделей совершают наибольший % перелетов?

-- 1. С помощью count() считаем количество перелетов flight_id совершенных каждой моделью самолета и группируем по моделям aircraft_code
-- 2. Объединяем получившуюся таблицу с aircrafts_data, чтобы добавить названия моделей, для удобства восприятия
-- 3. Считаем процент перелетов по каждой модели, округляем результат до десятой для удобства
-- 4. Сортируем по убыванию и ограничиваем результаты 3 моделями, совершившими наибольший % перелетов



-- Ответ: Наибольший % перелетов совершают самолеты (по убыванию):
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


--Узнать максимальное время задержки вылетов самолетов

-- 1. Есть 2 типа рейсов с задержкой вылета - те, что уже вылетели и те, что уже задерживаются, но еще не вылетели,
-- для работы с обоими случаями используем конструкцию case when else
-- 2. Для вылетевших рейсов, т.е. уже имеющих фактическое время вылета вычитаем scheduled_departure из actual_departure,
-- преобразуем timestamp в int и делим на 60, чтобы получить минуты
-- 3. Lля еще не вылетевших вместо actual_departure используем bookings.now() (“временной срез” данных),
-- и производим те же действия, что и выше
-- 4. Находим максимальное значение с помощью агрегирующей функции max()

-- Демонстрационная база содержит временной «срез» данных — так, как будто в некоторый
-- момент была сделана резервная копия реальной системы. Позиция «среза» сохранена в функции bookings.now().


-- Ответ: 281 минута

SELECT
	MAX(
	    CASE
		WHEN actual_departure IS NULL
		THEN EXTRACT(EPOCH FROM(bookings.NOW() - f.scheduled_departure))/60
		ELSE EXTRACT(EPOCH FROM(f.actual_departure - f.scheduled_departure))/60
	    END
	    ) AS max_delay_min
FROM flights f;



--Между какими городами нет прямых рейсов?

-- 1. Получаем список городов, выносим в CTE cte_cities
-- 2. Получаем все возможные комбинации городов, объединив cte_cities с собой с помощью cross join,
-- выносим в CTE cte_cities_comb
-- 3. Получаем все существующие маршруты перелетов между городами, объединив таблицы flights и airports_data,
-- объединяем дважды, чтобы соотнести название аэропорта с городом как для вылета,
-- так и для прилета, выносим в CTE flights_cities
-- 4. Объединяем все возможные комбинации городов cte_cities_comb и
-- все существующие маршруты перелетов flights_cities с помощью left join,
-- чтобы в результирующей таблице были комбинации городов, для которых нет соотносящихся значений из таблицы маршрутов,
-- т.е.прямых рейсов
-- 5. Фильтруем по условию, где города вылета depart_city и прилета arriv_city не имеют значений -
-- оставляем только те комбинации городов, где нет прямых рейсов
-- 6. Дополнительно исключаем дубли с одинаковыми городами, которые образовались во врем cross join - ccc.dep!=ccc.arr
-- 7. Выводим отфильтрованный список комбинаций городов из cte_cities_comb



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














