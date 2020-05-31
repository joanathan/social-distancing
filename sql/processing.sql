--create a buffered sidewalk polygon and unionize them.
CREATE TABLE sf_sidewalk_buffered_union AS
WITH sidewalk AS (
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
CREATE TABLE sf_sidewalk_intersect AS
SELECT
	t.geoid10,
	st_intersection(s.geom, t.geom) AS intersect_geom,
	st_area(st_intersection(s.geom, t.geom) ::geography) AS intersect_area
FROM
	sf_sidewalk_buffered_union s,
	sf_pop_bg_2010 t
WHERE
	st_intersects(s.geom, t.geom);


--calculate availability of sidewalk space per population for each census block group
CREATE TABLE sf_social_distancing_prep AS
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
	round(p.population_2019) AS population_2019
FROM
	sf_sidewalk_intersect s
	JOIN population p ON (s.geoid10 = p.geoid10);

-- drop table sf_social_distancing;
CREATE TABLE sf_social_distancing AS
WITH hospital_closest AS (
	SELECT
		st_distance(st_transform(d.geom, 3857),
		st_transform(h.geom, 3857)) * 0.000189394 AS hospital_distance_miles,
		h. "hospital n" AS hospital_name,
		d.geoid10
	FROM
		sf_social_distancing_prep d,
		sf_hospital h
),
hospital_order AS (
	SELECT DISTINCT
		row_number() OVER (PARTITION BY h.geoid10 ORDER BY h.hospital_distance_miles) AS r,
		h.*
	FROM
		hospital_closest h
),
hospitals AS (
	SELECT
		h.*
	FROM
		hospital_order h
	WHERE
		h.r = 1
),
restaurants AS (
	SELECT
		b.geoid10,
		count(DISTINCT r.*) AS count_foodservices
	FROM
		sf_restaurant r,
		sf_pop_bg_2010 b
	WHERE
		st_intersects(r.geom, b.geom)
	GROUP BY 1
),
munistops AS (
	SELECT
		s.geoid10,
		count(DISTINCT m.*) AS count_munistops
	FROM
		sf_social_distancing_prep s,
		sf_muni_gtfs_stops m
	WHERE
		st_intersects(ST_Buffer(m.geom::geography, 15, 'endcap=round join=round')::geometry, s.geom) -- 50 meter
	GROUP BY 1
)
SELECT DISTINCT
	d.geoid10,
	r.count_foodservices,
	s.count_munistops,
	h.hospital_name,
	round(h.hospital_distance_miles::numeric, 2) AS hospital_distance_miles,
	d.sidewalk_area,
	d.population_2019,
	d.geom
FROM
	sf_social_distancing_prep d
	LEFT JOIN hospitals h ON (h.geoid10 = d.geoid10)
	LEFT JOIN munistops s ON (h.geoid10 = s.geoid10)
	LEFT JOIN restaurants r ON (h.geoid10 = r.geoid10);

--optional: create a Muni route for visualization
CREATE TABLE sf_muni_gtfs_shapes_line AS 
WITH line AS (
	SELECT
		shape_id,
		shape_pt_s,
		max(shape_pt_s) OVER (PARTITION BY shape_id) AS max,
		st_makeline (array_agg(geom) OVER (PARTITION BY shape_id ORDER BY shape_pt_s)) AS line_geom
	FROM
		sf_muni_gtfs_shapes
)
SELECT
	shape_id,
	line_geom
FROM
	line
WHERE
	shape_pt_s = max;

--optional:
--run the query 10x to simulate different person out ratio (10%, 20%.., 100%)
--this step is only useful if you want to generate points to simulate population density
--otherwise, skip this step and calculate distance per person on the map UI.
CREATE TABLE sf_social_distancing_recursive AS
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
		s.sidewalk_area / s.population_2019 as distance_per_person
	FROM
		sf_social_distancing_prep s
	UNION ALL
	SELECT
		s.geoid10,
		s.sidewalk_geom,
		s.cbg_geom,
		st_generatepoints (s.sidewalk_geom, (s.population_2019 * (r.person_out_ratio - 0.1))) AS point_geom,
		s.sidewalk_area,
		s.population_2019,
		r.person_out_ratio - 0.1 AS person_out_ratio,
		s.sidewalk_area / s.population_2019 / (r.person_out_ratio - 0.1) AS distance_per_person
	FROM
		sf_social_distancing_prep s,
		recursive_distancing r
	WHERE
		s.geoid10 = r.geoid10
		AND r.person_out_ratio > 0.1
)
SELECT *
FROM recursive_distancing;