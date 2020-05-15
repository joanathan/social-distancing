# Social Distancing Density

1. Import SF sidewalk shapefile to the database.
![](images/0_og.png)


2. Convert the line zones to polygons by making a buffer. Use sidewalk width column as guidance for buffer size.
![](images/1_buffer.png)


3. Since the edges of buffered polygons overlap with each other, unionize them.
![](images/2_union.png)


4. Import Census Block Groups shapefile to the database. This shapefile contains population information.
![](images/3_overlay.png)


5. Break the sidewalk polygon, so each census block group has its network of sidewalk. 
![](images/4_split.png)


6. Calculate the social distancing density for each census block group. Social Distancing Density is the sq.root of total sidewalk area per population density.
![](images/5_calculate.png)
