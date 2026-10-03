create database if not exists cafe_project;
use cafe_project;
 -- create staging table without judgment.
-- Transaction ID	Item	Quantity	Price Per Unit	Total Spent	Payment Method	Location	Transaction Date
create table  stg_cafe (
TRANSACTION_ID varchar(30),
ITEM varchar(30),
QUANTITY varchar(30),
PRICE_PER_UNIT varchar(30),
TOTAL_SPENT varchar(30),
PAYMENT_METHOD varchar(30),
LOCATION varchar(30),
TRANSACTION_DATE varchar(30)
);

SHOW GLOBAL VARIABLES LIKE 'local_infile';
set global local_infile = 1;

load data local infile 'C:/data/project2/dirty_cafe_sales.csv'
into table stg_cafe
char set utf8mb4
fields
terminated by ','
enclosed by '"'
lines
starting by '' -- default
terminated by '\r\n'
ignore  1 lines;