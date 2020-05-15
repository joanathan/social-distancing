--create a buffered sidewalk polygon and unionize them. 
CREATE TABLE sf_sidewalk_buffered_union2 AS WITH sidewalk AS (
	SELECT
		s.cnn,
		CASE WHEN s.sidewalk_f ::integer <= 0 THEN 0
			WHEN s.side in('Both', 'BOTH') THEN (s.sidewalk_f::integer * 2 * 0.3)
			ELSE s.sidewalk_f ::integer * 0.3
		END AS sidewalk_size_meter, --convert from feet to meter
		s.geom,
		s.street,
		s.class
	FROM
		sf_sidewalk s
),
sidewalk_buffered AS (
	SELECT
		s.cnn,
		s.sidewalk_size_meter,
		s.street,
		s.class,
		ST_Buffer(s.geom::geography, s.sidewalk_size_meter,'endcap=butt join=round')::geometry AS geom
	FROM
		sidewalk s
),
sidewalk_buffered_clean AS (
	SELECT
		st_area(geom::geography) sidewalk_area_sqft,
		*
	FROM
		sidewalk_buffered
	WHERE
		st_area(geom::geography) < 60000 -- to exclude poorly created buff.
)
SELECT
	st_union(geom) AS geom
FROM
	sf_sidewalk_buffered_clean
	

--disaggregate the unionized zone by census block groups so we can map with population information
CREATE TABLE sf_sidewalk_intersect_v2 AS
SELECT
	t.geoid10,
	st_intersection(s.geom, t.geom) AS intersect_geom,
	st_area(st_intersection(s.geom, t.geom) ::geography) AS intersect_area
FROM
	sf_sidewalk_buffered_union2 s,
	sf_pop_bg_2010 t
WHERE
	st_intersects(s.geom, t.geom);

--calculate availability of sidewalk space per population for each census block group
CREATE TABLE sf_social_distancing AS 
WITH population AS (
	SELECT
		geoid10,
		(total_population * 1.095) AS population_2019,
		geom
	FROM
		sf_pop_bg_2010 p
) 
SELECT DISTINCT
	s.geoid10,
	s.intersect_geom AS sidewalk_geom,
	p.geom AS cbg_geom,
	round(st_area(s.intersect_geom::geography)) AS sidewalk_area,
	round(p.population_2019) AS population_2019,
	round(st_area(s.intersect_geom::geography) / p.population_2019) AS distance_per_person
FROM
	sf_sidewalk_intersect_v2 s
	JOIN population p ON (s.geoid10 = p.geoid10);


--run the query 10x to simulate different person out ratio (10%, 20%.., 100%)
--this step is only useful if you want to simulate population density
--otherwise, you can choose to calculate distance per person on the map UI.
CREATE TABLE sf_social_distancing_viz_3 AS 
WITH RECURSIVE recursive_distancing (
	geoid10,
	sidewalk_geom,
	cbg_geom,
	point_geom,
	sidewalk_area,
	population_2019,
	person_out_ratio,
	distance_per_person
) AS (
	SELECT
		s.geoid10,
		s.sidewalk_geom,
		s.cbg_geom,
		st_generatepoints (s.sidewalk_geom, (s.population_2019 * 0.1)) AS point_geom,
		s.sidewalk_area,
		s.population_2019,
		1.0 AS person_out_ratio,
		s.distance_per_person
	FROM
		sf_social_distancing s
	UNION ALL
	SELECT
		s.geoid10,
		s.sidewalk_geom,
		s.cbg_geom,
		st_generatepoints (s.sidewalk_geom, (s.population_2019 * (r.person_out_ratio - 0.1))) AS point_geom,
		s.sidewalk_area,
		s.population_2019,
		r.person_out_ratio - 0.1 AS person_out_ratio,
		s.distance_per_person / (r.person_out_ratio - 0.1) AS distance_per_person
	FROM
		sf_social_distancing s,
		recursive_distancing r
	WHERE
		s.geoid10 = r.geoid10
		AND r.person_out_ratio > 0.1
)
SELECT *
FROM recursive_distancing;


--to export file to create map visualization using the original line instead of buffered.
CREATE TABLE sf_social_distancing_viz_line3 AS 
SELECT DISTINCT
	a.geoid10,
	b.intersect_geom AS geom,
	a.person_out_ratio * 100 AS person_out_pct,
	sidewalk_area,
	population_2019,
	round(a.distance_per_person) AS distance_sqft,
	round(sqrt(a.distance_per_person)) AS distance_ft
FROM
	sf_social_distancing_viz_3 a
	JOIN sf_sidewalk_line_intersect b ON (a.geoid10 = b.geoid10)
WHERE
	a.geoid10 != '060750601001';


--to export file to create map visualization to simulate population density
CREATE TABLE sf_social_distancing_viz_point3 AS 
SELECT DISTINCT
	geoid10,
	point_geom AS geom,
	person_out_ratio * 100 AS person_out_pct,
	sidewalk_area,
	population_2019,
	round(distance_per_person) AS distance_sqft,
	round(sqrt(distance_per_person)) AS distance_ft
FROM
	sf_social_distancing_viz_3;
