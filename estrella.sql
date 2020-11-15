use PROYECTO2BD2
go


--Modelo estrella

--Tabla specimen_fact
DROP TABLE  INBIO.SPECIMEN_FACT

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
ADD FOREIGN KEY (taxon_id) REFERENCES INBIO.TAXON(taxon_id);

ALTER TABLE INBIO.SPECIMEN_FACT
ADD FOREIGN KEY (site_id) REFERENCES INBIO.SITE(site_id);

ALTER TABLE INBIO.SPECIMEN_FACT
ADD FOREIGN KEY (gathering_id) REFERENCES INBIO.GATHERING(gathering_id);

ALTER TABLE INBIO.SPECIMEN_FACT
ADD FOREIGN KEY (gathering_responsible_id) REFERENCES INBIO.GATHERING_RESPONSIBLE(gathering_responsible_id);
GO




--SP para generar la estrella
CREATE OR ALTER PROCEDURE INBIO.datos_estrella
AS BEGIN

	INSERT INTO INBIO.SPECIMEN_FACT
	SELECT 
	(SELECT COUNT(sc.specimen_id) from INBIO.SPECIMEN sc), (SELECT SUM(CAST(sc.specimen_cost AS FLOAT)) from INBIO.SPECIMEN sc) ,
	t.taxon_id, si.site_id, g.gathering_id , gr.gathering_responsible_id
	FROM  INBIO.TAXON t
	inner join INBIO.SPECIMEN s on s.taxon_id = t.taxon_id
	inner join INBIO.GATHERING g on s.gathering_id = g.gathering_id
	inner join INBIO.SITE si on g.site_id = si.site_id
	inner join INBIO.GATHERING_RESPONSIBLE gr on g.gathering_responsible_id = gr.gathering_responsible_id
	GROUP BY t.taxon_id, s.specimen_id, g.gathering_id, gr.gathering_responsible_id, si.site_id

END
GO

EXEC INBIO.datos_estrella;

select * from INBIO.SPECIMEN_FACT
GO



--1 FUNCION QUE SUMA LOS COSTOS DE RECOLECCION DE UN STRING DE ESPECÍMENES
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



-- 3. SP para hacer un rollup por año y mes para la cantidad y el costo total de los especímenes. 
CREATE OR ALTER PROCEDURE INBIO.ejercicio_rollup
AS BEGIN

	SELECT ISNULL(YEAR(g.gathering_date), 0) AS AÑO, ISNULL(MONTH(g.gathering_date), 0) AS MES, COUNT(*) AS CANTIDAD_ESPECIES, SUM(CAST(s.specimen_cost AS FLOAT)) AS COSTO_RECOLECCION
	FROM INBIO.SPECIMEN s
	INNER JOIN INBIO.GATHERING g ON s.gathering_id = g.gathering_id
	GROUP BY ROLLUP (YEAR(g.gathering_date), MONTH(g.gathering_date))
	ORDER BY 1,2

END
GO


EXEC INBIO.ejercicio_rollup;


-- 4. Hacer un cubo por año y reino para la cantidad y costo asociados a la recolección de especímenes. 
CREATE OR ALTER PROCEDURE INBIO.ejercicio_cubo
AS BEGIN

	SELECT ISNULL(YEAR(g.gathering_date), 0) AS AÑO, ISNULL(t.kingdom_name,0) AS REINO , COUNT(*) AS CANTIDAD_ESPECIES, SUM(CAST(s.specimen_cost AS FLOAT)) AS COSTO_RECOLECCION
	FROM INBIO.SPECIMEN s
	INNER JOIN INBIO.TAXON t ON t.taxon_id = s.taxon_id
	INNER JOIN INBIO.GATHERING g ON s.gathering_id = g.gathering_id
	GROUP BY CUBE (YEAR(g.gathering_date), t.kingdom_name)
	ORDER BY 1,2

END
GO

EXEC INBIO.ejercicio_cubo;
                     