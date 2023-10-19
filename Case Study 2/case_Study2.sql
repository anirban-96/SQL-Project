use Pizza_Runner

select * from dbo.customer_orders;
select * from dbo.pizza_names;
select * from dbo.pizza_recipes;
select * from dbo.pizza_toppings;
select * from dbo.runner_orders;
select * from dbo.runners;

-- Pizza Metrics

-- 1. How many pizzas were ordered ?

select count (pizza_id) as tot_pizza from dbo.customer_orders 

select pizza_name, tot_ordered from 
(select pizza_id, count(o.pizza_id) as tot_ordered from dbo.customer_orders o group by pizza_id)x join dbo.pizza_names p on p.pizza_id=x.pizza_id

-- How many pizza were ordered by each customer ?

select customer_id, count(pizza_id) as tot_orders from dbo.customer_orders group by customer_id;

-- What type of pizza is mostly ordered ?

select pizza_name, ordered from 
(select pizza_id, count(pizza_id) as ordered from dbo.customer_orders group by pizza_id)x join dbo.pizza_names p on p.pizza_id=x.pizza_id

-- 2. How many unique customer orders were made ?

select count(distinct order_id) as unique_orders from dbo.customer_orders

-- 3. How many successful orders were delivered by each runner?

select count(distinct order_id) as [successful_orders] from dbo.customer_orders where order_id not in (
select order_id from dbo.runner_orders where cancellation like '%cancel%')

-- 4. How many of each type of pizza was delivered?

select pizza_name, tot_deliveries from (
select pizza_id, count(pizza_id) as tot_deliveries  from dbo.customer_orders where order_id not in
(select order_id from dbo.runner_orders where cancellation like '%cancel%') group by pizza_id)x join dbo.pizza_names p on p.pizza_id=x.pizza_id

-- 5. How many Vegetarian and Meatlovers were ordered by each customer?

select customer_id, pizza_name, ordered from (
select customer_id, pizza_id, count(pizza_id) as ordered from dbo.customer_orders group by pizza_id, customer_id)x join dbo.pizza_names p
on p.pizza_id=x.pizza_id order by customer_id

-- 6. What was the maximum number of pizzas delivered in a single order?

select top 1 order_id, count(pizza_id) as delivered from dbo.customer_orders where order_id not in
(select order_id from dbo.runner_orders where cancellation like '%cancel%') group by order_id
order by delivered desc

-- 7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

select customer_id, conclusion, count(conclusion) as result from (
select customer_id, pizza_id, exclude, extra, case when exclude='0' and extra='0' then 'No changes' else 'change' end as conclusion from (
select *, 
case when exclusions is null or exclusions like 'null%' or exclusions=' ' then '0' else exclusions end as exclude,
case when extras='NULL' or extras is null or extras=' ' then '0' else extras end as extra
from dbo.customer_orders where order_id not in
(select order_id from dbo.runner_orders where cancellation like '%cancel%'))x)y group by customer_id, conclusion
order by customer_id

-- 8. How many pizzas were delivered that had both exclusions and extras?

select conclusion, count(pizza_id) as delivered from (
select customer_id, pizza_id, exclude, extra, case when exclude<>'0' and extra<>'0' then 'Both changes' else 'Not Both' end as conclusion from (
select *, 
case when exclusions is null or exclusions like 'null%' or exclusions=' ' then '0' else exclusions end as exclude,
case when extras='NULL' or extras is null or extras=' ' then '0' else extras end as extra
from dbo.customer_orders where order_id not in
(select order_id from dbo.runner_orders where cancellation like '%cancel%'))x)y group by conclusion

-- 9. What was the total volume of pizzas ordered for each hour of the day?

select hour_range, count(pizza_id) as ordered from (
select *, concat(DATEPART(hour, order_time),'-',DATEPART(hour,order_time)+1) as hour_range from dbo.customer_orders)x group by hour_range

-- 10. What was the volume of orders for each day of the week?

select date_name, count(distinct order_id) as tot_orders from (
select *, datename(dw,order_time) as date_name from dbo.customer_orders)x group by date_name

-- Runner and Customer Experience

-- 1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)

select wk_num, count(runner_id) as tot_signedup_runners from (
select *, DATEPART(week,registration_date) as wk_num from dbo.runners where registration_date>='2021-01-01')x group by wk_num

-- 2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
-- time to arrive = pickup_time - order_time

select runner_id, cast(tot_time*1.0/tot_orders as dec(4,2)) as [avg_time_taken(mins)] from 
(select runner_id, count(order_id) as tot_orders, sum(time_taken) as tot_time from (
select runner_id, order_id, max(time_taken) as time_taken from(
select c.order_id, runner_id,order_time, pickup, DATEDIFF(minute, order_time, pickup) time_taken from (
select *, convert(datetime2,pickup_time) as pickup from dbo.runner_orders where pickup_time <> 'null')x
join dbo.customer_orders c on c.order_id=x.order_id)y group by runner_id, order_id)z group by runner_id)q

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?

select *, cast(tot_time*1.0/tot_pizza as dec(4,2)) as avg_time_takes from (
select order_id, count(pizza_id) tot_pizza, max(time_taken) as tot_time from
(select c.order_id, runner_id,c.pizza_id,order_time, pickup, DATEDIFF(minute, order_time, pickup) time_taken from (
select *, convert(datetime,pickup_time) as pickup from dbo.runner_orders where pickup_time <> 'null')x
join dbo.customer_orders c on c.order_id=x.order_id)y group by y.order_id)z

-- we find that all order_id from 1 to 7 takes 10 mins time to prepare 1 pizza, but Order_Id 8 took 21 mins 
-- whearas order_id 10 took 8 mins that varies from the above pattern. If we exclude Order_id(8,10) we can say that there exists relationship
-- between number of pizzas and preparation time.

-- 4. What was the average distance travelled for each customer?

select customer_id, convert(dec(8,3),tot_dis/tot_orders) as avg_dis_travel from (
select customer_id, count(customer_id) tot_orders, sum(cast(dist as dec(5,2))) as tot_dis from(
select c.order_id,customer_id, runner_id, distance,
case when right(trim(distance),2)='km' then trim(left(distance,CHARINDEX('k',distance)-1)) else trim(distance) end as dist
from dbo.customer_orders c join dbo.runner_orders r on r.order_id=c.order_id where distance<>'null')x group by customer_id)y

-- 5. What was the difference between the longest and shortest delivery times for all orders?

select concat(max(dur)-min(dur),' Mins') as [Diff btwn long & short delivery time in mins] from ( 
select order_id, runner_id, duration,
cast(case when duration like '%min%' then trim(left(duration,CHARINDEX('m',duration)-1)) else trim(duration) end as int) as dur
from dbo.runner_orders where duration <> 'null')x

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?

select runner_id, sum(dist)/sum(dur_hr) as avg_speed_kmhr from(
select order_id, runner_id, dist, convert(dec(4,2),dur*1.0/60) as dur_hr from(
select order_id, runner_id, distance, duration,
cast(case when right(trim(distance),2)='km' then left(distance,CHARINDEX('k',trim(distance))-1) else trim(distance) end as dec(5,1)) as dist,
cast(case when duration like '%min%' then trim(left(duration,CHARINDEX('m',duration)-1)) else trim(duration) end as int) as dur
from dbo.runner_orders where distance<>'null' and duration<>'null')x)y group by runner_id

-- 7. What is the successful delivery percentage for each runner?

select runner_id, concat(cast(status*100.0/tot_orders as dec(5,2)),'%') as [success rate] from
(select runner_id, count(runner_id) as tot_orders, count(case when Delivery='Pass' then 1 else null end) as status from (
select order_id,runner_id, case when pickup_time ='null' then 'Fail' else 'Pass' end as Delivery from dbo.runner_orders)x
group by runner_id)y

-- Ingredients Optimization

-- 1. What are the standard ingredients for each pizza?

select pizza_name, top_name from (
select pizza_id, toppings, cast(topping_name as varchar(255)) as top_name from(
select pizza_id, trim(toppings) as toppings from (
select pizza_id, value as toppings from (
select pizza_id, cast(toppings as varchar(50)) as toppings from dbo.pizza_recipes)x cross apply string_split(x.toppings,','))k)y
join dbo.pizza_toppings t on t.topping_id=y.toppings)z join dbo.pizza_names p on p.pizza_id=z.pizza_id

-- 2. What was the most commonly added extra?

select topping_name, total from(
select extra, count(extra) as total from (
select order_id, trim(value) as extra from (
select order_id, convert(varchar(100),extra) as extra from (
select order_id, extras, case when extras='NULL' or extras=' ' or extras is null then 'N/A' else extras end as extra from dbo.customer_orders)x
where extra<>'N/A')y cross apply string_split(extra,','))z group by extra)k join dbo.pizza_toppings pt on pt.topping_id=k.extra

-- 3. What was the most common exclusion?

select topping_name, total from(
select exclude, count(exclude) as total from (
select order_id, trim(value) as exclude from (
select order_id, convert(varchar(100),exclude) as exclude from (
select order_id, exclusions, case when exclusions='null' or exclusions=' ' then 'N/A' else exclusions end as exclude from dbo.customer_orders)x
where exclude<>'N/A')y cross apply string_split(exclude,','))z group by exclude)k join dbo.pizza_toppings pt on pt.topping_id=k.exclude
order by total desc

-- 4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--	Meat Lovers
--	Meat Lovers - Exclude Beef
--	Meat Lovers - Extra Bacon
--	Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers

select order_id, pizza,
case when x.exclude='N/A' then null else trim(a.value) end as exclude,
case when x.extra='N/A' then null else trim(b.value) end as extra
from(select order_id, pizza_name as pizza, exclusions, extras,
cast(case when exclusions=' ' or exclusions='null' then 'N/A' else exclusions end as varchar(255)) as exclude,
cast(case when extras=' ' or extras='NULL' or extras is null then 'N/A' else extras end as varchar(255)) as extra
from dbo.customer_orders c join dbo.pizza_names p on p.pizza_id=c.pizza_id)x cross apply string_split(x.exclude,',') as a 
cross apply string_split(x.extra,',') as b 

-- 5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table 
--	and add a 2x in front of any relevant ingredients. For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

select pizza_name, concat('2x',ingredients) as ingredients from (
select pizza_id, STRING_AGG(top_name,', ') as ingredients from (
select pizza_id, toppings, cast(topping_name as varchar(255)) as top_name from(
select pizza_id, trim(toppings) as toppings from (
select pizza_id, value as toppings from (
select pizza_id, cast(toppings as varchar(50)) as toppings from dbo.pizza_recipes)x cross apply string_split(x.toppings,','))k)y
join dbo.pizza_toppings t on t.topping_id=y.toppings)z group by z.pizza_id)q join dbo.pizza_names p on p.pizza_id=q.pizza_id

-- Pricing and Rating

-- 1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes -
--		how much money has Pizza Runner made so far if there are no delivery fees?

select concat('$',sum(price)) as total_earning from (
select order_id, x.pizza_id, pizza_name, case when x.pizza_id=1 then 12 else 10 end as price
from(select * from dbo.customer_orders where order_id not in (select order_id from dbo.runner_orders where cancellation like '%cancel%'))x
join dbo.pizza_names p on p.pizza_id=x.pizza_id)y

-- 2. What if there was an additional $1 charge for any pizza extras? Add cheese is $1 extra.

select sum(earn) as Earnings from (
select price+extra_cost as earn from (
select *, case when include='N/A' then 0 else 1 end as extra_cost from (
select order_id, pizza_name, price, value as include from (
select order_id, c.pizza_id, pizza_name,case when c.pizza_id=1 then 12 else 10 end as price,extras,
cast(case when extras=' ' or extras is null or extras='null' then 'N/A' else extras end as varchar(100)) as extra
from dbo.customer_orders c join dbo.pizza_names p on p.pizza_id=c.pizza_id
where c.order_id not in(select order_id from dbo.runner_orders where cancellation like '%cancel%'))x cross apply string_split(extra,','))y)z)k

-- 3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
--	how would you design an additional table for this new dataset - generate a schema for this new table and 
--	insert your own data for ratings for each successful customer order between 1 to 5.

DROP TABLE IF EXISTS ratings;
CREATE TABLE ratings (
order_id int,
rating int);

INSERT INTO ratings VALUES 
(1, 5), (2, 3), (3, 4), (4, 2), (5,3), (7, 3), (8, 4), (10, 5);

select * from ratings;

-- 4. Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
--	customer_id, order_id, runner_id, rating, order_time, pickup_time, Time between order and pickup, Delivery duration, Average speed, Total number of pizzas

select *, concat(dist/([Duration(Mins)]*1.0/60),' km/hr') as avg_speed from
(select order_id, customer_id, tot_pizza,runner_id, rating, order_time, pickup_time,concat(DATEDIFF(minute, order_time,pickup_time),' Mins') as time_toreach,
cast(case when duration like '%min%' then trim(left(duration,CHARINDEX('m',duration)-1)) else trim(duration) end as int)as [Duration(Mins)],
cast(case when right(trim(distance),2)='km' then trim(left(distance,CHARINDEX('k',distance)-1)) else trim(distance) end as dec(5,2))as dist from(
select b.order_id,customer_id,tot_pizza,order_time,runner_id,rating,pickup_time,duration,distance from(
select order_id, customer_id, count(pizza_id) as tot_pizza, max(order_time) order_time from (
select * from dbo.customer_orders where order_id not in (select order_id from dbo.runner_orders where cancellation like '%cancel%'))a
group by order_id, customer_id )b join dbo.runner_orders r on r.order_id=b.order_id join ratings rt on rt.order_id=b.order_id)c)d

-- 5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled,
-- how much money does Pizza Runner have left over after these deliveries?

select concat('$ ',sum(pizza_earn)-sum(travel_cost)) as [Money Left] from(
select runner_id, sum(tot_price) as pizza_earn, sum(cost_per_km) as travel_cost from(
select *, tot_km*0.3 as cost_per_km from(
select order_id, runner_id, sum(price) as tot_price, max(dist) as tot_km from(
select c.order_id, c.pizza_id,pizza_name, runner_id, case when c.pizza_id=1 then 12 else 10 end as price,
cast(case when right(distance,2)='km' then left(distance,CHARINDEX('k',trim(distance))-1) else trim(distance) end as dec(5,2)) as dist
from dbo.customer_orders c join dbo.runner_orders r on r.order_id=c.order_id join dbo.pizza_names p on p.pizza_id=c.pizza_id
where c.order_id not in (select order_id from dbo.runner_orders where cancellation like '%cancel%'))x group by order_id, runner_id)y)z
group by runner_id)k