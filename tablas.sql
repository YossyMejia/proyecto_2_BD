use PROYECTO2BD2
go


--Table taxon
DROP TABLE INBIO.TAXON

CREATE TABLE INBIO.TAXON
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

ALTER TABLE INBIO.TAXON ADD PRIMARY KEY (taxon_id);

GO


--Table gathering responsable
DROP TABLE INBIO.GATHERING_RESPONSIBLE

CREATE TABLE INBIO.GATHERING_RESPONSIBLE
(
gathering_responsible_id int IDENTITY(1,1) not null,
name  varchar(250) not null --GATHERING RESPONSIBLE 
)

ALTER TABLE INBIO.GATHERING_RESPONSIBLE ADD PRIMARY KEY (gathering_responsible_id);

GO


--Table site
DROP TABLE INBIO.SITE

CREATE TABLE INBIO.SITE
(
site_id bigint not null,
latitude  varchar(250) not null,
longitude  varchar(250) not null,
site_description varchar(max) not null
)

ALTER TABLE INBIO.SITE ADD PRIMARY KEY (site_id);

GO


--Table gathering
DROP TABLE INBIO.GATHERING

CREATE TABLE INBIO.GATHERING
(
gathering_id int IDENTITY(1,1) not null,
gathering_date date not null,
gathering_responsible_id  int not null, --alterar a que sea int 
site_id bigint not null
)
 
ALTER TABLE INBIO.GATHERING ADD PRIMARY KEY (gathering_id);

ALTER TABLE INBIO.GATHERING
ADD FOREIGN KEY (gathering_responsible_id) REFERENCES INBIO.GATHERING_RESPONSIBLE(gathering_responsible_id);

ALTER TABLE INBIO.GATHERING
ADD FOREIGN KEY (site_id) REFERENCES INBIO.SITE(site_id);

GO


--Table specimen
DROP TABLE INBIO.SPECIMEN

CREATE TABLE INBIO.SPECIMEN
(
specimen_id bigint not null,
specimen_description varchar(max),
specimen_cost varchar(250),
taxon_id bigint not null,
gathering_id int not null
)
 
 ALTER TABLE INBIO.SPECIMEN ADD PRIMARY KEY (specimen_id);

ALTER TABLE INBIO.SPECIMEN
ADD FOREIGN KEY (taxon_id) REFERENCES INBIO.TAXON(taxon_id);

ALTER TABLE INBIO.SPECIMEN
ADD FOREIGN KEY (gathering_id) REFERENCES INBIO.GATHERING(gathering_id);

GO


