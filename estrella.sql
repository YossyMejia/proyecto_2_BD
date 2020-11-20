use PROYECTO2BD2
GO


--Modelo estrella

--Tabla dimension de taxon
DROP TABLE  INBIO.DIM_TAXON

CREATE TABLE INBIO.DIM_TAXON
(
	taxon_id  bigint not null,
	kingdom_name varchar(50),
	phylum_division_name varchar(50),
	class_name varchar(50),
	order_name varchar(50),
	family_name varchar(50),
	genus_name varchar(50),
	species_name varchar(50),
	scientific_name varchar(250)
)


ALTER TABLE INBIO.DIM_TAXON ADD PRIMARY KEY (taxon_id);

GO


--Tabla dimension sitio
DROP TABLE INBIO.DIM_SITE

CREATE TABLE INBIO.DIM_SITE
(
site_id bigint not null,
latitude  varchar(250) not null,
longitude  varchar(250) not null,
site_description varchar(max) not null
)

ALTER TABLE INBIO.DIM_SITE ADD PRIMARY KEY (site_id);

GO


--Tabla dimension gathering date 
DROP TABLE INBIO.DIM_GATHERING

CREATE TABLE INBIO.DIM_GATHERING
(
gathering_id int  not null,
gathering_ano int not null,
gathering_mes int not null,
gathering_dia int not null
)
 
ALTER TABLE INBIO.DIM_GATHERING ADD PRIMARY KEY (gathering_id);

select * from INBIO.DIM_GATHERING;

GO


--Tabla dimension gathering responsible
DROP TABLE INBIO.DIM_GATHERING_RESPONSIBLE

CREATE TABLE INBIO.DIM_GATHERING_RESPONSIBLE
(
gathering_responsible_id int  not null,
name  varchar(250) not null --GATHERING RESPONSIBLE 
)

ALTER TABLE INBIO.DIM_GATHERING_RESPONSIBLE ADD PRIMARY KEY (gathering_responsible_id);

GO



--Tabla specimen_fact
DROP TABLE INBIO.SPECIMEN_FACT

CREATE TABLE INBIO.SPECIMEN_FACT
(
	dim_specimen_fact int IDENTITY(1,1) not null,
	specimen_count bigint not null,
	cost_sum float not null,
	taxon_id bigint not null,
	site_id bigint not null,
	gathering_id int not null,
	gathering_responsible_id int not null
)


ALTER TABLE INBIO.SPECIMEN_FACT ADD PRIMARY KEY (dim_specimen_fact);

ALTER TABLE INBIO.SPECIMEN_FACT
ADD FOREIGN KEY (taxon_id) REFERENCES INBIO.DIM_TAXON(taxon_id);

ALTER TABLE INBIO.SPECIMEN_FACT
ADD FOREIGN KEY (site_id) REFERENCES INBIO.DIM_SITE(site_id);

ALTER TABLE INBIO.SPECIMEN_FACT
ADD FOREIGN KEY (gathering_id) REFERENCES INBIO.DIM_GATHERING(gathering_id);

ALTER TABLE INBIO.SPECIMEN_FACT
ADD FOREIGN KEY (gathering_responsible_id) REFERENCES INBIO.DIM_GATHERING_RESPONSIBLE(gathering_responsible_id);
GO




--SP para generar la estrella
CREATE OR ALTER PROCEDURE INBIO.datos_estrella
AS BEGIN

	INSERT INTO INBIO.DIM_TAXON
	SELECT DISTINCT 
	taxon_id, kingdom_name, phylum_division_name, class_name, 
	order_name, family_name, genus_name, species_name, scientific_name
	FROM INBIO.TAXON
	where NOT EXISTS (select t.taxon_id from INBIO.DIM_TAXON t where t.taxon_id = taxon_id)

	INSERT INTO INBIO.DIM_GATHERING_RESPONSIBLE
	SELECT DISTINCT
		gathering_responsible_id, name
	FROM INBIO.GATHERING_RESPONSIBLE
	where NOT EXISTS (select gar.name from INBIO.DIM_GATHERING_RESPONSIBLE gar 
	where gar.name = name and gar.gathering_responsible_id = gathering_responsible_id)

	INSERT INTO INBIO.DIM_SITE 
	SELECT DISTINCT
		site_id, latitude, longitude, site_description
	FROM INBIO.SITE
	where NOT EXISTS (select s.site_id from INBIO.DIM_SITE s where s.site_id = site_id)

	INSERT INTO INBIO.DIM_GATHERING	
	SELECT DISTINCT
		g.gathering_id, YEAR(g.gathering_date),  MONTH(g.gathering_date),  DAY(g.gathering_date)
	FROM INBIO.GATHERING g
	where NOT EXISTS (select * from INBIO.DIM_GATHERING ga where ga.gathering_ano = YEAR(g.gathering_date)
	AND ga.gathering_mes = MONTH(g.gathering_date) AND ga.gathering_dia = DAY(g.gathering_date) AND ga.gathering_id = g.gathering_id)  


	INSERT INTO INBIO.SPECIMEN_FACT
	SELECT DISTINCT
	COUNT(*), SUM(CAST(s.specimen_cost AS FLOAT)), t.taxon_id, si.site_id , g.gathering_id, gr.gathering_responsible_id
	FROM  INBIO.TAXON t
	inner join INBIO.SPECIMEN s on s.taxon_id = t.taxon_id
	inner join INBIO.GATHERING g on s.gathering_id = g.gathering_id
	inner join INBIO.SITE si on g.site_id = si.site_id
	inner join INBIO.GATHERING_RESPONSIBLE gr on g.gathering_responsible_id = gr.gathering_responsible_id
	WHERE NOT EXISTS ( SELECT * FROM INBIO.SPECIMEN_FACT sf WHERE sf.taxon_id = t.taxon_id AND sf.site_id = si.site_id 
	AND g.gathering_id = sf.gathering_id AND sf.gathering_responsible_id = gr.gathering_responsible_id) 
	GROUP BY t.taxon_id, g.gathering_id, gr.gathering_responsible_id, si.site_id
	

END
GO

EXEC INBIO.datos_estrella;

select * from INBIO.SPECIMEN_FACT
GO


-- 1  Para un mes dado, sin importar el año, dar para cada orden (nivel de la jerarquía taxonómica) el número de especímenes que pertenecen a este.
CREATE OR ALTER PROCEDURE INBIO.especimenesXorden (@mes int)
AS
BEGIN
	SELECT t.order_name, sum(sf.specimen_count) specimen_count 
	FROM INBIO.SPECIMEN_FACT sf
	INNER JOIN INBIO.DIM_TAXON t ON sf.taxon_id = t.taxon_id
	INNER JOIN INBIO.DIM_GATHERING g ON sf.gathering_id = g.gathering_id
	WHERE g.gathering_mes = @mes
	GROUP BY t.order_name
	ORDER BY specimen_count DESC
END
GO

EXEC INBIO.especimenesXorden 1;
GO


--1.1 Una función que calcule el costo total de recolección de un conjunto de especímenes. 
CREATE OR ALTER FUNCTION INBIO.costo_recoleccion
(@lista_especimenes VARCHAR(250))
RETURNS FLOAT
AS
BEGIN
DECLARE @total_recoleccion FLOAT
DECLARE @costo_especimen_actual FLOAT
DECLARE @specimen_id VARCHAR(250)
DECLARE specimen_cursor CURSOR FOR (SELECT value FROM STRING_SPLIT(@lista_especimenes, ','))

	SET @total_recoleccion = 0

	OPEN specimen_cursor
	FETCH NEXT FROM specimen_cursor INTO @specimen_id
	WHILE @@FETCH_STATUS = 0
	BEGIN
			SET @costo_especimen_actual = (SELECT CAST(specimen_cost AS FLOAT) FROM INBIO.SPECIMEN where specimen_id = CAST(@specimen_id AS BIGINT))
			IF @costo_especimen_actual IS NOT NULL
				SET @total_recoleccion = @total_recoleccion + @costo_especimen_actual
		FETCH NEXT FROM specimen_cursor INTO @specimen_id
	END
	CLOSE specimen_cursor
	DEALLOCATE specimen_cursor

RETURN @total_recoleccion
END
GO

SELECT INBIO.costo_recoleccion('1537846,3945297');
GO



-- 1.2	Una función que calcule la cantidad de especímenes asociada a un taxón teniendo en cuenta todos sus hijos.
CREATE OR ALTER FUNCTION INBIO.cantidad_especimenes
(@categoria_taxon INT,
 @nombre_taxon VARCHAR(250)
)
RETURNS INT
AS
BEGIN
	
	IF @categoria_taxon = 1
		BEGIN
			RETURN (SELECT sum(sf.specimen_count) from INBIO.SPECIMEN_FACT sf
			INNER JOIN INBIO.DIM_TAXON t on sf.taxon_id = t.taxon_id where t.kingdom_name = @nombre_taxon)
		END
	ELSE IF @categoria_taxon = 2
		BEGIN
			RETURN (SELECT sum(sf.specimen_count) from INBIO.SPECIMEN_FACT sf
			INNER JOIN INBIO.DIM_TAXON t on sf.taxon_id = t.taxon_id WHERE t.phylum_division_name = @nombre_taxon)
		END
	ELSE IF @categoria_taxon = 3
		BEGIN
			RETURN (SELECT sum(sf.specimen_count) from INBIO.SPECIMEN_FACT sf
			INNER JOIN INBIO.DIM_TAXON t on sf.taxon_id = t.taxon_id WHERE t.class_name = @nombre_taxon)
		END
	ELSE IF @categoria_taxon = 4
		BEGIN
			RETURN (SELECT sum(sf.specimen_count) from INBIO.SPECIMEN_FACT sf
			INNER JOIN INBIO.DIM_TAXON t on sf.taxon_id = t.taxon_id WHERE t.order_name = @nombre_taxon)
		END
	ELSE IF @categoria_taxon = 5
		BEGIN
			RETURN (SELECT sum(sf.specimen_count) from INBIO.SPECIMEN_FACT sf
			INNER JOIN INBIO.DIM_TAXON t on sf.taxon_id = t.taxon_id WHERE t.family_name = @nombre_taxon)
		END
	ELSE IF @categoria_taxon = 6
		BEGIN
			RETURN (SELECT sum(sf.specimen_count) from INBIO.SPECIMEN_FACT sf
			INNER JOIN INBIO.DIM_TAXON t on sf.taxon_id = t.taxon_id WHERE t.genus_name = @nombre_taxon)
		END
	ELSE IF @categoria_taxon = 7
		BEGIN
			RETURN (SELECT sum(sf.specimen_count) from INBIO.SPECIMEN_FACT sf
			INNER JOIN INBIO.DIM_TAXON t on sf.taxon_id = t.taxon_id WHERE t.species_name = @nombre_taxon)
		END
	ELSE IF @categoria_taxon = 8
		BEGIN
			RETURN (SELECT sum(sf.specimen_count) from INBIO.SPECIMEN_FACT sf
			INNER JOIN INBIO.DIM_TAXON t on sf.taxon_id = t.taxon_id WHERE t.scientific_name = @nombre_taxon)
		END
RETURN 0
END
GO

select INBIO.cantidad_especimenes(3, 'Magnoliopsida');
GO


-- 3. SP para hacer un rollup por año y mes para la cantidad y el costo total de los especímenes. 
CREATE OR ALTER PROCEDURE INBIO.ejercicio_rollup
AS BEGIN

	SELECT ISNULL(g.gathering_ano, 0) AS AÑO, ISNULL(g.gathering_mes, 0) AS MES, SUM(s.specimen_count) AS CANTIDAD_ESPECIES, SUM(s.cost_sum) AS COSTO_RECOLECCION
	FROM INBIO.SPECIMEN_FACT s
	INNER JOIN INBIO.DIM_GATHERING g ON s.gathering_id = g.gathering_id
	GROUP BY ROLLUP (g.gathering_ano, g.gathering_mes)
	ORDER BY 1,2

END
GO

EXEC INBIO.ejercicio_rollup;
GO

-- 4. Hacer un cubo por año y reino para la cantidad y costo asociados a la recolección de especímenes. 
CREATE OR ALTER PROCEDURE INBIO.ejercicio_cubo
AS BEGIN

	SELECT ISNULL(g.gathering_ano, 0) AS AÑO, ISNULL(t.kingdom_name,0) AS REINO , SUM(s.specimen_count) AS CANTIDAD_ESPECIES, SUM(s.cost_sum) AS COSTO_RECOLECCION
	FROM INBIO.SPECIMEN_FACT s
	INNER JOIN INBIO.DIM_TAXON t ON t.taxon_id = s.taxon_id
	INNER JOIN INBIO.DIM_GATHERING g ON s.gathering_id = g.gathering_id
	GROUP BY CUBE (g.gathering_ano, t.kingdom_name)
	ORDER BY 1,2

END
GO

EXEC INBIO.ejercicio_cubo;
GO