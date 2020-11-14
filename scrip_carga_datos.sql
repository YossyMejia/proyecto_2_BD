--BASE DE DATOS A USAR
use PROYECTO2BD2
go

--CREAR EL ESQUEMA EN CASO DE NO TENERLO CREADO
CREATE SCHEMA INBIO AUTHORIZATION dbo
go


--Check the imported data.
SELECT *
FROM INBIO.datos_inbio
GO



--PROCEDIMIENTO PARA BORRAR REGISTROS NULOS Y ID DE SPECIMEN REPETIDO
CREATE OR ALTER PROCEDURE INBIO.borrar_registros_invalidos
AS BEGIN

	DELETE FROM INBIO.datos_inbio WHERE specimen_id IS NULL OR taxon_id IS NULL 
	OR specimen_cost IS NULL OR gathering_date IS NULL OR gathering_responsible IS NULL 
	OR latitude IS NULL OR longitude IS NULL OR site_description IS NULL

	;WITH cte 
	AS 
	(
	 SELECT specimen_id, 
     ROW_NUMBER() OVER(PARTITION BY specimen_id ORDER BY specimen_id) AS Rn
	 FROM INBIO.datos_inbio
	)
	DELETE cte WHERE Rn > 1

END
GO


--PRODECIMIENTO PARA INSERTAR
CREATE OR ALTER PROCEDURE INBIO.normalizar_datos
AS BEGIN

	INSERT INTO INBIO.TAXON
	SELECT DISTINCT 
	taxon_id, kingdom_name, phylum_division_name, class_name, 
	order_name, family_name, genus_name, species_name, scientific_name
	FROM INBIO.datos_inbio
	where NOT EXISTS (select t.taxon_id from INBIO.TAXON t where t.taxon_id = taxon_id)
	 
	INSERT INTO INBIO.GATHERING_RESPONSIBLE
	SELECT DISTINCT
		gathering_responsible
	FROM INBIO.datos_inbio
	where NOT EXISTS (select gar.name from INBIO.GATHERING_RESPONSIBLE gar 
	where gar.name = gathering_responsible)

	INSERT INTO INBIO.SITE 
	SELECT DISTINCT
		site_id, latitude, longitude, site_description
	FROM INBIO.datos_inbio
	where NOT EXISTS (select s.site_id from INBIO.SITE s where s.site_id = site_id)


	INSERT INTO INBIO.GATHERING	
	SELECT DISTINCT
		d.gathering_date, g.gathering_responsible_id , d.site_id
	FROM INBIO.datos_inbio d
	INNER JOIN INBIO.GATHERING_RESPONSIBLE g ON d.gathering_responsible = g.name
	where NOT EXISTS (select * from INBIO.GATHERING ga where ga.gathering_date = d.gathering_date 
	and ga.gathering_responsible_id = g.gathering_responsible_id and ga.site_id = d.site_id)  

	INSERT INTO INBIO.SPECIMEN
	SELECT DISTINCT
		d.specimen_id, d.specimen_description , d.specimen_cost, d.taxon_id, g.gathering_id
	FROM INBIO.datos_inbio d
	INNER JOIN INBIO.GATHERING g ON d.gathering_date = g.gathering_date and d.site_id = g.site_id and 
	g.gathering_responsible_id = (select gr.gathering_responsible_id from INBIO.GATHERING_RESPONSIBLE gr where gr.name = d.gathering_responsible)
	where NOT EXISTS (select s.specimen_id from INBIO.SPECIMEN s where s.specimen_id = d.specimen_id)  

END
GO


--SP GENERAL PARA NORMALIZAR
CREATE OR ALTER PROCEDURE INBIO.normalizar_general
AS BEGIN
	exec INBIO.borrar_registros_invalidos
	exec INBIO.normalizar_datos
END
GO


--LLAMADA DE SP GENERAL
exec INBIO.normalizar_general
go



--SP INSERTAR ESPECIMEN
CREATE PROCEDURE INBIO.sp_insertar_especimen 
@specimen_id bigint, 
@specimen_description varchar(max),
@specimen_cost varchar(250),
@taxon_id bigint,
@gathering_id int
AS
IF NOT EXISTS(select s.specimen_id from INBIO.SPECIMEN s where s.specimen_id = @specimen_id)
	INSERT INTO INBIO.SPECIMEN VALUES(@specimen_id,@specimen_description,@specimen_cost,@taxon_id,@gathering_id);
ELSE
	print 'ERROR SPECIMEN ID INGRESADO'
GO

--SP INSERTAR ESPECIMEN CORRER EJEMPLO
exec INBIO.sp_insertar_especimen @specimen_id = 'PRUEBA', @specimen_description ='PRUEBA', @specimen_cost = 'PRUEBA' , @taxon_id = 'PRUEBA' , @gathering_id = 'PRUEBA';

SELECT * FROM INBIO.SPECIMEN where specimen_id = 'PRUEBA'--PONER ID DE INSERT
DELETE FROM  INBIO.SPECIMEN WHERE  specimen_id = 'PRUEBA'--PONER ID DE INSERT
go



--SP INSERTAR TAXON
CREATE PROCEDURE INBIO.sp_insertar_taxon
@taxon_id  bigint,
@kingdom_name varchar(50),
@phylum_division_name varchar(50),
@class_name varchar(50),
@order_name varchar(50),
@family_name varchar(50),
@genus_name varchar(50),
@species_name varchar(50),
@scientific_name varchar(250)
AS
IF NOT EXISTS(select t.taxon_id from INBIO.TAXON t where t.taxon_id = @taxon_id)
	INSERT INTO INBIO.TAXON VALUES(@taxon_id, @kingdom_name, @phylum_division_name, @class_name, 
	@order_name, @family_name, @genus_name, @species_name, @scientific_name);
ELSE
	print 'ERROR TAXON ID INGRESADO'
GO

--SP INSERTAR TAXON CORRER EJEMPLO
exec INBIO.sp_insertar_taxon @taxon_id = 'PRUEBA', @kingdom_name = 'PRUEBA', @phylum_division_name = 'PRUEBA', @class_name = 'PRUEBA', 
@order_name = 'PRUEBA', @family_name = 'PRUEBA', @genus_name = 'PRUEBA', @species_name = 'PRUEBA', @scientific_name = 'PRUEBA'

SELECT * FROM INBIO.TAXON where taxon_id = 'PRUEBA' --PONER ID DE INSERT
DELETE FROM  INBIO.TAXON WHERE  taxon_id = 'PRUEBA' --PONER ID DE INSERT
go

--SP INSERTAR GATHERING
CREATE PROCEDURE INBIO.sp_insertar_gathering
@gathering_date datetime2(7),
@gathering_responsible_id  int,
@site_id bigint
AS
IF NOT EXISTS(select * from INBIO.GATHERING g where g.gathering_date = @gathering_date and g.gathering_responsible_id = @gathering_responsible_id 
and g.site_id = @site_id)
	INSERT INTO INBIO.GATHERING VALUES(@gathering_date, @gathering_responsible_id, @site_id);
ELSE
	print 'ERROR DATOS DE RECOLECCION INGRESADOS'
GO

--SP INSERTAR GATHERING CORRER EJEMPLO
exec INBIO.sp_insertar_gathering @gathering_date = '1991-01-13', @gathering_responsible_id = 2, @site_id = 2216

SELECT * FROM INBIO.GATHERING where gathering_date = '1991-01-13' and site_id = 2216 --PONER ID DE INSERT
DELETE FROM  INBIO.GATHERING WHERE  gathering_date = '1991-01-13' and site_id = 2216--PONER ID DE INSERT
go


--REVISAR DATOS
select * from INBIO.TAXON
SELECT * FROM INBIO.datos_inbio
SELECT * FROM INBIO.SPECIMEN
select * from INBIO.GATHERING_RESPONSIBLE
SELECT * FROM INBIO.SITE
go