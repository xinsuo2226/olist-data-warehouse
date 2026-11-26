-- DWS 第一张：销售主题

drop table if exists dw_olist.dws_sales_daily;
create table dw_olist.dws_sales_daily (
  date_key    int not null,        -- 日期编号，形如 20180115
  year_num    int,                 -- 年
  month_num   int,                 -- 月
  category_en varchar(100),        -- 品类英文名
  state       varchar(10),         -- 买家所在州
  order_cnt   int,                 -- 订单数，去重后的
  item_cnt    int,                 -- 商品件数
  buyer_cnt   int,                 -- 买家数，按真人去重
  gmv         decimal(14,2),       -- 商品金额合计
  freight_sum decimal(14,2),       -- 运费合计
  primary key (date_key, category_en, state)   -- 三列组合唯一
);
-- 灌数
insert into dw_olist.dws_sales_daily
select f.date_key,                              -- 日期编号
       d.year_num,                              -- 年
       d.month_num,                             -- 月
       p.category_en,                           -- 品类
       c.state,                                 -- 州
       count(distinct f.order_id),     -- 订单数，已按订单号去重
       count(1),                       -- 件数
       count(distinct c.customer_unique_id), -- 买家数，已按ID去重
       sum(f.price),                      -- 总计金额
       sum(f.freight_value)         -- 总计运费
from dw_olist.fact_order_items f               -- 来自主表：事实表
join dw_olist.dim_date d             -- 连日期维度
  on f.date_key = d.date_key
join dw_olist.dim_products p         -- 连商品维度
  on f.product_id = p.product_id
join dw_olist.dim_customers c        -- 连客户维度
  on f.customer_id = c.customer_id
group by f.date_key,d.year_num,d.month_num,p.category_en,c.state; -- 粒度：五列唯一

-- DWS 第二张：用户主题
drop table if exists dw_olist.dws_buyer;

create table dw_olist.dws_buyer (
  customer_unique_id varchar(32) not null,  -- 真人编号，主键
  state       varchar(10),                  -- 所在州
  first_date_key int,                       -- 首次下单日期编号
  last_date_key  int,                       -- 最后下单日期编号
  order_cnt   int,                          -- 下单次数
  item_cnt    int,                          -- 购买件数
  total_gmv   decimal(14,2),                -- 累计消费金额
  is_repeat   tinyint,                      -- 是否复购，1是0否
  primary key (customer_unique_id)
);
-- 灌数
insert into dw_olist.dws_buyer
select c.customer_unique_id,                        -- 真人编号
       min(c.state),                                -- 州，一人可能有多个，取一个
       min(f.date_key),                             -- 首次下单
       max(f.date_key),                             -- 最后下单
       count(distinct f.order_id),                  -- 下单次数，去重
       count(1),                                    -- 件数
       sum(f.price),                                -- 累计消费
       if(count(distinct f.order_id) > 1, 1, 0)     -- 单数大于1就是复购
from dw_olist.fact_order_items f
join dw_olist.dim_customers c on f.customer_id = c.customer_id
group by c.customer_unique_id;                      -- 按真人分组，一人一行

-- DWS 第三张：履约主题
-- 一行 = 某天 + 某州 的配送表现
drop table if exists dw_olist.dws_delivery;
create table dw_olist.dws_delivery (
  date_key         int not null,      -- 下单日期编号
  year_num         int,               -- 年
  month_num        int,               -- 月
  state            varchar(10),       -- 买家所在州
  order_cnt        int,               -- 订单数，已按订单去重
  avg_delivery_days decimal(6,2),     -- 平均配送天数
  late_cnt         int,               -- 迟到订单数
  late_rate        decimal(6,4),      -- 迟到率，迟到的占已送达的
  primary key (date_key, state)
);
-- 灌数
insert into dw_olist.dws_delivery
select o.date_key,                              -- 下单日期
       d.year_num,                              -- 年
       d.month_num,                             -- 月
       c.state,                                 -- 州
       count(1),                                -- 订单数
       round(avg(o.delivery_days), 2),          -- 平均配送天数，null自动跳过
       sum(o.is_late),                          -- 迟到订单数
       round(sum(o.is_late) / count(o.delivery_days), 4)  -- 迟到率
from (
  select distinct                              -- 根据五列总体去重
         f.order_id,                            -- 订单号
         f.date_key,                            -- 下单日期
         f.delivery_days,                       -- 配送天数
         f.is_late,                             -- 是否迟到
         f.customer_id                          -- 买家
  from dw_olist.fact_order_items f
) o
join dw_olist.dim_date d      on o.date_key = d.date_key          -- 连日期维度
join dw_olist.dim_customers c on o.customer_id = c.customer_id    -- 连客户维度
group by o.date_key, d.year_num, d.month_num, c.state;            -- 粒度

