DROP DATABASE IF EXISTS heart;
CREATE DATABASE  heart;
DROP USER IF EXISTS 'user';
USE  heart;

#Creazione tabelle con relativi vincoli di integrità referenziale e chiave primaria
CREATE TABLE Utilizzatore(
  PID varchar(200) primary key not null,
  Email varchar(200)not null,
  Password varchar(200) not null,
  nome  varchar(200) not null,
  cognome  varchar(200) not null,
  num_tel varchar(200) not null,
  Categoria enum("Medico","Infermiere","admin") not null
)engine=innodb;

CREATE TABLE Paziente(
  ID int auto_increment primary key,
   nome  varchar(200) not null,
  cognome  varchar(200) not null,
  num_tel varchar(200) not null,
  luogo_nascita varchar(200) not null,
  data_nascita date not null,
  residenza varchar(200) not null,
  sesso enum("M","F") not null,
  peso int,
  altezza int,
  class_gravita enum ("alta","media","bassa"), 
  class_NYHA int not null,
  class_INTERMACS int not null,
  tipologia enum("LVAD HM3","LVAD HVAD","NO LVAD"),
  PID_medico varchar(200),
  foreign key (PID_medico) REFERENCES Utilizzatore(PID) on delete set null
)engine=innodb;

CREATE TABLE Terapia(
  data datetime not null,
  ID_paz int,
  nota varchar(1000) not null,
  PID_medico varchar(200),
  primary key (ID_paz, data),
  foreign key (PID_medico) REFERENCES Utilizzatore(PID) on delete set null,
  foreign key (ID_paz) references Paziente(ID)
)engine=innodb;

CREATE TABLE Rilevazione(
  ID int auto_increment primary key,
  data datetime not null,
  ID_paz int,
  peso int default 0,
  frequenza int default 0,
  pressione varchar(200) default "",
  passi int default 0,
  nota varchar(1000) default "",
  allarme_aut varchar(200) default "",
  foreign key (ID_paz) REFERENCES Paziente(ID) on delete set null
  )engine=innodb;

CREATE TABLE LVAD(
  ID_rilev int  primary key,
  rpm int default 0,
  watt double default 0,
  fLusso int default 0,
  picco double default 0,
  depressione double default 0,
  PI double default 0,
  allarme enum("Basso Flusso", "Watt alti", "Nessuno") default "Nessuno",
  foreign key (ID_rilev) REFERENCES Rilevazione(ID) on delete cascade
 )engine=innodb;


CREATE TABLE Validazione(
  dataR datetime not null,
  ID_pazR int not null,
  data datetime not null,
  nota varchar(1000),
  PID_u varchar(200),
  PRIMARY KEY (dataR, ID_pazR),
  foreign key (PID_u) REFERENCES Utilizzatore(PID),
  foreign key (ID_pazR) references Rilevazione(ID_paz) on delete cascade
  #foreign key (dataR) references Rilevazione(data) on delete cascade
  )engine=innodb;



#Creazione trigger allarme_aut su flusso e watt pazienti LVAD
/*Allarme viene settato dopo aver confrontato il flusso e/o watt della rilevazione inserita con
la rilevazione piu recente tra quelle piu vecchie di 15gg */
DELIMITER |
create trigger AllarmeFlusso
after insert on LVAD
for each row
begin
   declare paziente int;
  declare data_ril datetime;
  declare allarme_autV varchar(200);
  set paziente= (SELECT ID_paz from Rilevazione where (Rilevazione.ID=new.ID_rilev));
  set data_ril=(SELECT data from Rilevazione where (Rilevazione.ID=new.ID_rilev) );
  if(new.flusso <= ((SELECT flusso from Rilevazione R join  LVAD L on R.ID=L.ID_rilev
														  where (R.ID_paz=paziente)
														  AND 
                                                          (R.data<date_add(data_ril,interval -15 DAY))
                                                           order by R.data desc  LIMIT 1)) -1.5) then
	update Rilevazione  set allarme_aut="Flusso basso" where (Rilevazione.ID=new.ID_rilev);
  end if;
  
  set allarme_autV=(SELECT allarme_aut FROM Rilevazione where (ID=last_insert_id()));
	if(new.watt >=((SELECT watt from Rilevazione R join  LVAD L on R.ID=L.ID_rilev
														  where (R.ID_paz=paziente)
														  AND 
                                                          (R.data< date_add(data_ril,interval -15 DAY))
                                                          order by R.data desc  LIMIT 1)) +1) then
	update Rilevazione  set allarme_aut =CONCAT("Watt alti - ",allarme_autV) where (Rilevazione.ID=new.ID_rilev);
   end if;
end|
DELIMITER ;

#Pricedura di inserimento rilevazione
DELIMITER |
create procedure InsRil(in ID_pazIn int ,in pesoIn int,in frequenzaIn int,in pressioneIn varchar(200),in passiIn int,in notaIn varchar(1000),in allarme_autIn varchar(200),in  rpmIn int , in wattIn double, in flussoIn int ,in piccoIn double ,in depressioneIn double ,in PIIn double,in allarmeIn varchar(200))
begin
   start transaction; 
  insert into Rilevazione(data,ID_paz,peso,frequenza,pressione,passi,nota,allarme_aut) VALUES (now(),ID_pazIn,pesoIn,frequenzaIn,pressioneIn,passiIn,notaIn,allarme_autIn);
  if((SELECT tipologia FROM Paziente where (ID=ID_pazIn))!="NO LVAD" ) then
   
    insert into LVAD (ID_rilev,rpm,watt,flusso,picco,depressione,PI,allarme) VALUES (last_insert_id(),rpmIn,wattIn,flussoIn,piccoIn,depressioneIn,PIIn,allarmeIn);
    commit work;
    end if;
end|
DELIMITER ;

SET @pwad=md5("admin");
SET @pwin=md5("inf");
SET @pwmd=md5("med");

#Inseriti 1 Medico,1 Paziente LVAD ,1 Paziente No LVAD
insert into Utilizzatore(PID,Email,Password,nome,cognome,num_tel,categoria) values ("0","inf@",@pwad,"stefano","verdi","33454244","admin");
insert into Utilizzatore(PID,Email,Password,nome,cognome,num_tel,categoria) values ("2","inf@",@pwin,"stefano","bianchi","33454244","Infermiere");
insert into Utilizzatore(PID,Email,Password,nome,cognome,num_tel,categoria) values ("3","medico1@",@pwmd,"stefano","rossi","33454244","Medico");
insert into Paziente (ID,nome,cognome,num_tel,luogo_nascita,data_nascita,residenza,sesso,peso,altezza,class_gravita,class_NYHA,class_INTERMACS,tipologia,PID_medico) values (1,"CLAUDIO","ROSSI","3311016613","Benevento",'1990-06-01',"via S g","M",60,1.89,"alta",5,6,"LVAD HM3","3");
insert into Paziente (ID,nome,cognome,num_tel,luogo_nascita,data_nascita,residenza,sesso,peso,altezza,class_gravita,class_NYHA,class_INTERMACS,tipologia,PID_medico) values (2,"MARTINA","IANARO","3311016613","Benevento",'1990-06-01',"via S g","M",60,1.89,"alta",5,6,"NO LVAD","3");

#Inseriti 1 rilevazione ,1 lvad con data 02/06
insert into Rilevazione(data,ID_paz,peso,frequenza,pressione,passi,nota,allarme_aut) VALUES ('2020-12-2',1,61,67,"alta",300,"","");
insert into LVAD (ID_rilev,rpm,watt,flusso,picco,depressione,PI,allarme) VALUES (last_insert_id(),4,4.0,5,1.1,1.2,1.3,"Watt alti");

#Inseriti 1 rilevazione ,1 lvad con data 15/06
insert into Rilevazione(data,ID_paz,peso,frequenza,pressione,passi,nota,allarme_aut) VALUES ('2020-11-11',1,50,80,"bassa",300,"","");
insert into LVAD (ID_rilev,rpm,watt,flusso,picco,depressione,PI,allarme) VALUES (last_insert_id(),4,3.0,5,1.1,1.2,1.3,"Watt alti");

insert into Rilevazione(data,ID_paz,peso,frequenza,pressione,passi,nota,allarme_aut) VALUES ('2020-12-3',1,61,67,"alta",200,"","");
insert into LVAD (ID_rilev,rpm,watt,flusso,picco,depressione,PI,allarme) VALUES (last_insert_id(),4,3.0,5,1.1,1.2,1.3,"Watt alti");

insert into Rilevazione(data,ID_paz,peso,frequenza,pressione,passi,nota,allarme_aut) VALUES ('2020-12-4',1,61,67,"alta",300,"","");
insert into LVAD (ID_rilev,rpm,watt,flusso,picco,depressione,PI,allarme) VALUES (last_insert_id(),4,3.0,5,1.1,1.2,1.3,"Watt alti");

insert into Rilevazione(data,ID_paz,peso,frequenza,pressione,passi,nota,allarme_aut) VALUES ('2020-12-5',1,57,100,"alta",100,"","");
insert into LVAD (ID_rilev,rpm,watt,flusso,picco,depressione,PI,allarme) VALUES (last_insert_id(),2,5.1,6,2.1,1.7,1.0,"Watt alti");

insert into Rilevazione(data,ID_paz,peso,frequenza,pressione,passi,nota,allarme_aut) VALUES ('2020-12-6',1,61,67,"alta",300,"","");
insert into LVAD (ID_rilev,rpm,watt,flusso,picco,depressione,PI,allarme) VALUES (last_insert_id(),4,3.0,5,1.1,1.2,1.3,"Watt alti");

insert into Rilevazione(data,ID_paz,peso,frequenza,pressione,passi,nota,allarme_aut) VALUES ('2020-12-7',1,70,80,"alta",100,"","");
insert into LVAD (ID_rilev,rpm,watt,flusso,picco,depressione,PI,allarme) VALUES (last_insert_id(),1,2.0,2,1.6,1.0,1.9,"Watt alti");

#Chiamate 2 volte procedura per inserimento rilevazione + Lvad (se il paziente è LVAD)
#1 call ->Paziente LVAD
CALL InsRil(1,61,56,"alta",120,"","",4,5.0,1,1.1,1.2,1.3,"Watt alti");

#2* call ->Paziente No-LVAD
CALL InsRil(2,61,56,"alta",120,"","",4,3.4,1,1.1,1.2,1.3,"Watt alti");


CREATE USER 'user'@'%' IDENTIFIED BY 'heart99';
GRANT SELECT, INSERT, UPDATE, EXECUTE ON heart.* TO 'user'@'%';
FLUSH PRIVILEGES;