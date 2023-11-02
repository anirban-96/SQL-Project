--use trial;
select top 200 * from data_mart.weekly_sales;

-- Convert the week_date to a DATE format
-- Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc
-- Add a month_number with the calendar month for each week_date value as the 3rd column
-- Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values
-- Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value
-- Add a new demographic column using the following mapping for the first letter in the segment values:
-- Ensure all null string values with an "unknown" string value in the original segment column as well as the new age_band and demographic columns
-- Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record

create view clean_weekly_sales as (
select wk_date, DATEPART(wk,wk_date) as week_number, months, yr as Years,segment, age_band, demographic, avg_transaction from (
select DATEFROMPARTS(cast(concat('20',right(week_date,len(week_date)-CHARINDEX('/',week_date,4))) as int),
cast(SUBSTRING(week_date,charindex('/',week_date)+1,(charindex('/',week_date,4)-(charindex('/',week_date)+1))) as int),
cast(left(week_date, charindex('/',week_date)-1) as int)) as wk_date,
SUBSTRING(week_date,charindex('/',week_date)+1,(charindex('/',week_date,4)-(charindex('/',week_date)+1))) as months,
concat('20',right(week_date,len(week_date)-CHARINDEX('/',week_date,4))) as yr,
case when segment='null' then 'unknown' else segment end as segment,
case when right(segment, 1)='1' THEN 'Young Adults'  when right(segment, 1)='2' then 'Middle Aged' 
when right(segment,1) in ('3','4') then 'Retirees' else 'unknown' end as age_band,
case when LEFT(segment,1)='C' then 'Couples' when LEFT(segment,1)='F' then 'Families' else 'unknown' end as demographic,
round(sales/transactions,2) as avg_transaction from data_mart.weekly_sales)x)

select * from clean_weekly_sales;

-- Data Exploration

-- 1. What day of the week is used for each week_date value?

select day_name, count(*) Tot_Day_Count from (
select wk_date, DATENAME(DW,wk_date) as day_name from clean_weekly_sales)p group by day_name

-- Output: MONDAY is used for each week date.

-- 2. What range of week numbers are missing from the dataset?

with wk_num as ( 
select 1 as n
union all 
select n+1 from wk_num where n<53)
select n as [Missing week nums] from wk_num where n not in (select week_number from clean_weekly_sales) 

-- 3. How many total transactions were there for each year in the dataset?

select Years, count(avg_transaction) as [Total Transaction] from clean_weekly_sales group by Years

-- 4. What is the total sales for each region for each month?

select region [Regions], mnth [Month], sum(cast(sales as bigint)) [Total Sales] from (
select cast(SUBSTRING(week_date,charindex('/',week_date)+1,(charindex('/',week_date,4)-(charindex('/',week_date)+1))) as int) as Mnth,region,sales
from data_mart.weekly_sales)x group by region, Mnth
order by Mnth

-- 5. What is the total count of transactions for each platform .

select platform, sum(transactions) as [Total Count of Transaction] from data_mart.weekly_sales group by platform

-- 6. What is the percentage of sales for Retail vs Shopify for each month?

select *, cast(Retail*100.0/(Retail+Shopify) as dec(5,2)) as 'Retail%', cast(Shopify*100.0/(Retail+Shopify) as dec(5,2)) as 'Shopify%' from (
select * from (
select cast(SUBSTRING(week_date,charindex('/',week_date)+1,(charindex('/',week_date,4)-(charindex('/',week_date)+1))) as int) as Mnth, platform, cast(sales as bigint) as sales
from data_mart.weekly_sales)x
pivot
(sum(x.sales) for platform in ([Retail],[Shopify])) pivot_data)p order by Mnth

-- 7. What is the percentage of sales by demographic for each year in the dataset?

select *, cast(couples*100.0/(couples+families+unknown) as dec(5,2)) as [Couples Sales %],
cast(families*100.0/(couples+families+unknown) as dec(5,2)) as [Families Sales %],
cast(unknown*100.0/(couples+families+unknown) as dec(5,2)) as [Unknown Sales %] from (
select * from (
select convert(int,concat('20',right(week_date,len(week_date)-CHARINDEX('/',week_date,4)))) as [Years],
case when left(segment, 1)='C' then 'Couples' when left(segment,1)='F' then 'Families' else 'Unknown' end as demographic, convert(bigint,sales) sales
from data_mart.weekly_sales)a
pivot
(sum(sales) for demographic in ([Couples],[Families],[Unknown]))pivot_data)p 

-- 8. Which age_band and demographic values contribute the most to Retail sales?

select top 3 age_band, demographic, sum(sales) as Total_Retail_Sales from (
select case when right(segment,1)='1' then 'Young Adults' when right(segment,1)='2' then 'Middle Aged'
when right(segment,1) in ('3','4') then 'Retirees' else 'Unknown' end as age_band,
case when left(segment,1)='C' then 'Couples' when left(segment,1)='F' then 'Families' else 'Unknown' end as demographic, platform , 
convert(bigint,sales) as sales from data_mart.weekly_sales where platform='Retail')x group by age_band, demographic
order by Total_Retail_Sales desc

-- 9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify?
--	If not - how would you calculate it instead?

-- Average Transaction Size = Total Sales by Period/ Total No. of Transactions by same period

select Years, max(case when platform='Retail' then avg_trans_size end) as [Retail], 
max(case when platform='Shopify' then avg_trans_size end)as [Shopify] from
(select Years, platform, convert(dec(14,4),tot_sales*1.0/tot_trans) as avg_trans_size from (
select Years, platform, sum(transactions) as tot_trans, sum(cast(sales as bigint)) as tot_sales from (
select convert(int,concat('20',right(week_date,len(week_date)-charindex('/',week_date,4)))) as [Years],platform, transactions, sales 
from data_mart.weekly_sales)x group by Years, platform)y)z group by Years

-- Before and After Analysis

-- We would include all week_date values for 2020-06-15 as the start of the period after the change
--	and the previous week_date values would be before

-- Using this approach, answer the following questions:

-- 1. What is the total sales for the 4 weeks before and after 2020-06-15? 
--	What is the growth or reduction rate in actual values and percentage of sales?

with aft_bef as (
select * from (
select case when wk_date between DATEADD(week,-4,'2020-06-15') and '2020-06-15' then 'Before 15/06/20' else 'After 15/06/20' end as Changes, Sales from (
select * from (
select DATEFROMPARTS(cast(concat('20',right(week_date,len(week_date)-CHARINDEX('/',week_date,4))) as int),
cast(SUBSTRING(week_date,charindex('/',week_date)+1,(charindex('/',week_date,4)-(charindex('/',week_date)+1))) as int),
cast(left(week_date, charindex('/',week_date)-1) as int)) as wk_date, cast(sales as bigint) as Sales
from data_mart.weekly_sales)a where wk_date between DATEADD(week,-4,'2020-06-15') and DATEADD(week,4,'2020-06-15'))b)c
pivot
(sum(sales) for changes in ([After 15/06/20],[Before 15/06/20]))pivot_data)

select * from aft_bef;

select [after 15/06/20]-[before 15/06/20] as Grwth_Redc, 
cast(([after 15/06/20]-[before 15/06/20])*100.0/[before 15/06/20] as dec(5,2)) as [Gwth_Redc %] from aft_bef;

-- 2. What about the entire 12 weeks before and after?

select case when result>0 then 'Growth in Sales' else 'Reduction in Sales' end as Conclusion, abs(result) as Sales_Diff from (
select [after 12 wk]-[before 12 wk] as result from (
select * from (
select case when wk_date between dateadd(week, -12,'2020-06-15') and '2020-06-15' then 'Before 12 Wk' else 'After 12 Wk' end as After_Before, Sales from(
select * from(
select DATEFROMPARTS(cast(concat('20',right(week_date,len(week_date)-CHARINDEX('/',week_date,4))) as int),
cast(SUBSTRING(week_date,charindex('/',week_date)+1,(charindex('/',week_date,4)-(charindex('/',week_date)+1))) as int),
cast(left(week_date, charindex('/',week_date)-1) as int)) as wk_date, cast(sales as bigint) as Sales
from data_mart.weekly_sales)a where wk_date between DATEADD(week,-12,'2020-06-15') and DATEADD(week,12,'2020-06-15'))b)c
pivot
(sum(sales) for After_Before in ([After 12 Wk],[Before 12 Wk]))pivot_data)p)q

-- 3. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?

select * from (
select case when wk_date between DATEADD(week,-4,'2020-06-15') and '2020-06-15'  then 'Before' 
when  wk_date between '2020-06-15' and DATEADD(week,4,'2020-06-15') then 'After'
when year(wk_date)=2019 then '2019' else '2018' end as Comparison, sales from (
select wk_date, sales from (
select DATEFROMPARTS(cast(concat('20',RIGHT(week_date,len(week_date)-CHARINDEX('/',week_date,4))) as int),
SUBSTRING(week_date,CHARINDEX('/',week_date)+1,charindex('/',week_date,4)-(charindex('/',week_date)+1)),
cast(LEFT(week_date,CHARINDEX('/',week_date)-1) as int)) as wk_date,(cast(concat('20',RIGHT(week_date,len(week_date)-CHARINDEX('/',week_date,4))) as int)) as [Years],
cast(sales as bigint) as Sales from data_mart.weekly_sales)p 
where years in (2019,2018) or wk_date between DATEADD(week,-4,'2020-06-15') and DATEADD(week,4,'2020-06-15'))q)r
pivot
(sum(Sales) for Comparison in ([Before],[After],[2019],[2018]))pivot_data 

-- BONUS QUESTION

-- Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?
-- Region / Platform / age_band / Demographic / customer_type

with filt_tble as (
select wk_date,region, platform,
case when right(segment,1)='1' then 'Young Adult' when right(segment,1)='2' then 'Mid Aged' when right(segment,1) in ('3','4') then 'Retirees' else 'Unknown' end as age_band,
case when left(segment,1)='C' then 'Couples' when left(segment,1)='F' then 'Families' else 'Unknown' end as demographics,
customer_type,sales, case when wk_date between DATEADD(week,-12,wk_date) and '2020-06-15' then 'Before' else 'After' end as date_period
from (
select DATEFROMPARTS(convert(int,concat('20',right(week_date,len(week_date)-CHARINDEX('/',week_date,4)))),
convert(int,SUBSTRING(week_date, CHARINDEX('/',week_date)+1, CHARINDEX('/',week_date,4)-(charindex('/',week_date)+1))),
convert(int,left(week_date,charindex('/',week_date)-1))) as wk_date,
convert(int,concat('20',right(week_date,len(week_date)-CHARINDEX('/',week_date,4)))) years,
region, platform, customer_type,segment, convert(bigint,sales) sales
from data_mart.weekly_sales)p where years=2020 and wk_date between DATEADD(week,-12,wk_date) and DATEADD(week,12,wk_date))

select region, date_period, sum(sales) tot_sales from filt_tble group by region, date_period order by region; -- Region wise Grouping
select platform, date_period, sum(sales) tot_sales from filt_tble group by platform, date_period order by platform; -- Platform wise grouping
select customer_type, date_period, sum(sales) tot_sales from filt_tble group by customer_type, date_period order by customer_type; -- Customer wise
select age_band, date_period, sum(sales) as tot_sales from filt_tble group by age_band, date_period order by age_band; -- Age_Band wise grouping
select demographics, date_period, sum(sales) tot_sales from filt_tble group by demographics, date_period order by demographics; -- Demographics wise
