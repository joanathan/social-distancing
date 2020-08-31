In your terminal, run this code to set up your database table, and import all the source files.

```sql
--to create the table structure run this from /sql folder
psql -U [USERNAME] -h [HOST] -d [DATABASE NAME] -f setup.sql


--to import all source files to your database run these from /input folder
shp2pgsql -I -s 4326 sf_sidewalk_line.shp public.sf_sidewalk | psql -U [USERNAME] -h [HOST] -d [DATABASE NAME]

shp2pgsql -I -s 4326 sf_population_blockgroups.shp public.sf_population_blockgroups | psql -U [USERNAME] -h [HOST] -d [DATABASE NAME]

shp2pgsql -I -s 4326 sf_hospital.shp public.sf_hospital | psql -U [USERNAME] -h [HOST] -d [DATABASE NAME]

psql -d [DATABASE NAME] -U [USERNAME] -c "\copy sf_restaurant from sf_restaurant.csv delimiter ',' csv header;"
```

Below is the magic command to run the analysis from start to finish. 

```sql
--to analyze social distancing density run this in /sql folder
psql -U [USERNAME] -h [HOST] -d [DATABASE NAME] -f processing.sql


--to export the file run this in /static/geojson folder
ogr2ogr -f "GeoJSON" social_distancing.json PG:"host=[HOST] dbname=[DATABASE NAME] user=[USERNAME] password=[PASSWORD] port=5432" -sql "select * from social_distancing"
```