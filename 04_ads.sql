-- 建漏斗表
drop table if exists dw_olist.ads_funnel;
create table dw_olist.ads_funnel (
    step_no int not null,   -- 步骤序号 1到4
    step_name varchar(50),  -- 步骤名
    order_cnt int,          -- 这一步的订单数
    rate  decimal(6,4),     -- 相对第一步的留存率
    primary key(step_no)
);
-- 数据插入漏斗表
insert into dw_olist.ads_funnel
with base as ( -- 给下面这段查询命名为base方便之后引用
  select count(1) as s1,                -- 全部订单数
    sum(order_approved_at != '') as s2, -- 付款时间不为空的订单数
    sum(order_delivered_carrier_date != '') as s3, -- 发货时间不为空的订单数
    sum(order_delivered_customer_date != '') as s4 -- 签收时间不为空的订单数

  from dw_olist.ods_orders -- 来源ods订单表

)  -- base的结果为一行四列

select 1,'下单',s1, 1.0000 from base -- 填充这四个值作为第一行
union all
select 2,'付款确认',s2,round(s2/s1,4) from base
union all
select 3,'发货',s3,round(s3/s1,4) from base
union all
select 4,'签收',s4,round(s4/s1,4) from base ;

select * from dw_olist.ads_funnel;

-- 建复购表
drop table if exists dw_olist.ads_repurchase;
create table dw_olist.ads_repurchase (
  state       varchar(10) not null,   -- 州
  buyer_cnt   int,                    -- 该州买家数
  repeat_cnt  int,                    -- 其中复购买家数
  repeat_rate decimal(6,4),           -- 复购率
  primary key (state)                 -- 州做主键
);

insert into dw_olist.ads_repurchase
select state,              -- 州
       count(1),          -- 该州买家数
       sum(is_repeat),        -- 复购人数，标记加起来
       round(sum(is_repeat) / count(1), 4) --  复购率
from dw_olist.dws_buyer
group by state;

