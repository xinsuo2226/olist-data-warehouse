-- 1.建客户维度表
drop table if exists dw_olist.dim_customers;
create table dw_olist.dim_customers (
    customer_id varchar(32) not null , -- 买家编号，32位16进制，主键
    customer_unique_id varchar(32), -- 买家唯一编号，复购率相关
    zip_code_prefix varchar(10), -- 邮编前缀，非数字
    city varchar(50), -- 城市名，灌数时清洗
    state varchar(10), -- 州，两个字母
    lat decimal(10,6), -- 纬度，从地理表中取
    lng decimal(10,6), -- 经度，从地理表中取
    primary key (customer_id) -- 声明主键
);

insert into dw_olist.dim_customers
select customer_id,                                    -- 买家编号
       customer_unique_id,                             -- 唯一编号
       customer_zip_code_prefix,                       -- 源表原名，带前缀
       trim(lower(customer_city)) as city,             -- 源表叫 customer_city
       customer_state,                                 -- 源表叫 customer_state
       null,                                            -- 纬度先空
       null                                             -- 经度先空
from dw_olist.ods_customers;

-- 2.建地区维度表
drop table if exists dw_olist.dim_geo;
create table dw_olist.dim_geo as                 -- 建表的同时把数据灌进去
select geolocation_zip_code_prefix as zip_code_prefix,   -- 邮编，改成统一命名
       avg(geolocation_lat) as lat,              -- 这个邮编所有点的平均纬度
       avg(geolocation_lng) as lng,              -- 平均经度
       min(geolocation_city) as city,            -- 城市名取一个代表
       min(geolocation_state) as state           -- 州取一个代表
from dw_olist.ods_geolocation                    -- 数据来自地理表
group by geolocation_zip_code_prefix;            -- 按邮编收成一行
-- 补主键
alter table dw_olist.dim_geo
 add primary key (zip_code_prefix);
-- 补客户维度坐标
update dw_olist.dim_customers c                   -- 要改的表
join dw_olist.dim_geo g                           -- 连上地区维度
  on c.zip_code_prefix = g.zip_code_prefix        -- 靠邮编连
set c.lat = g.lat,                                -- 写回纬度
    c.lng = g.lng;                                -- 写回经度

-- 删除异常坐标
update dw_olist.dim_geo
set lat = null, lng = null
where lat > 6 or lat < -34 or lng > -32 or lng < -74;

-- 3.商品维度表
drop table if exists dw_olist.dim_products;
create table dw_olist.dim_products (
  product_id   varchar(32) not null,      -- 商品编号，32位十六进制
  category_pt  varchar(100),              -- 品类葡语原名
  category_en  varchar(100),              -- 品类英语名，从翻译表补
  weight_g     int,                       -- 重量，单位克
  length_cm    int,                       -- 长度，厘米
  height_cm    int,                       -- 高度，厘米
  width_cm     int,                       -- 宽度，厘米
  photos_qty   int,                       -- 图片张数
  primary key (product_id)                -- 主键
);
-- 灌入数据
insert into dw_olist.dim_products
select p.product_id,                                       -- 商品编号
       p.product_category_name,                            -- 品类葡语名
       ifnull(t.product_category_name_english, 'unknown'), -- 译不到就写 unknown
       cast(nullif(p.product_weight_g, '') as signed),     -- 空串转null，再转整数
       cast(nullif(p.product_length_cm, '') as signed),    -- 同上
       cast(nullif(p.product_height_cm, '') as signed),    -- 同上
       cast(nullif(p.product_width_cm, '') as signed),     -- 同上
       cast(nullif(p.product_photos_qty, '') as signed)    -- 同上
from dw_olist.ods_products p                               -- 主表
left join dw_olist.ods_translation t                       -- 左连翻译表
       on p.product_category_name = t.product_category_name;

-- 4.卖家维度表
drop table if exists dw_olist.dim_sellers;

create table dw_olist.dim_sellers (
  seller_id       varchar(32) not null,   -- 卖家编号
  zip_code_prefix varchar(10),            -- 邮编前缀
  city            varchar(50),            -- 城市，清洗过
  state           varchar(10),            -- 州
  lat             decimal(10,6),          -- 纬度
  lng             decimal(10,6),          -- 经度
  primary key (seller_id)                 -- 主键
);
-- 灌数
insert into dw_olist.dim_sellers
select s.seller_id,                              -- 卖家编号
       s.seller_zip_code_prefix,    -- 邮编，改掉前缀名
       trim(lower(s.seller_city)),           -- 城市名清洗
       s.seller_state,                      -- 州
       g.lat,                                    -- 纬度，从地区维度取
       g.lng                                     -- 经度
from dw_olist.ods_sellers s                      -- 主表：卖家
left join dw_olist.dim_geo g                     -- 左连地区维度
       on s.seller_zip_code_prefix = g.zip_code_prefix;

-- 5.日期维度表
drop table if exists dw_olist.dim_date;

create table dw_olist.dim_date (
    date_key    int not null,     -- 日期编号，格式 20180115
  full_date   date,               -- 完整日期
  year_num    int,                -- 年
  month_num   int,                -- 月
  day_num     int,                -- 日
  weekday_num int,                -- 星期几，1是周一，7是周日
  quarter_num int,                -- 季度
  is_weekend  tinyint,            -- 是否周末，1是，0不是
  primary key (date_key)
);
-- 灌数
insert into dw_olist.dim_date
select cast(date_format(dt, '%Y%m%d') as signed),   -- 日期编号，如 20180115
       dt,                                           -- 日期本身
       year(dt),                                     -- 年
       month(dt),                                    -- 月
       day(dt),                                      -- 日
       weekday(dt) + 1,                              -- 星期几，1到7
       quarter(dt),                                  -- 季度
       if(weekday(dt) >= 5, 1, 0)                    -- 周六周日标1
from (
  select date_add('2016-01-01', interval n day) as dt    -- 起点加上第n天
  from (
    select row_number() over (order by order_id) - 1 as n  -- 生成0,1,2...的序号
    from dw_olist.ods_orders                               -- 借订单表当数字来源
    limit 1100                                             -- 只要前1100个
  ) nums
) days;

-- 事实表

drop table if exists dw_olist.fact_order_items;
create table dw_olist.fact_order_items(
  order_id      varchar(32) not null,   -- 订单编号
  order_item_id int not null,           -- 这单里的第几件商品
  customer_id   varchar(32),            -- 买家编号，指向客户维度
  product_id    varchar(32),            -- 商品编号，指向商品维度
  seller_id     varchar(32),            -- 卖家编号，指向卖家维度
  date_key      int,                    -- 下单日期编号，指向日期维度
  order_status  varchar(20),            -- 订单状态
  price         decimal(10,2),          -- 商品金额
  freight_value decimal(10,2),          -- 运费
  delivery_days int,                    -- 下单到签收几天
  is_late       tinyint,                -- 是否晚于预估，1晚，0没晚
  primary key (order_id, order_item_id) -- 两个字段合起来唯一
);
-- 灌数
insert into dw_olist.fact_order_items
select i.order_id, -- 订单编号
       cast(i.order_item_id as signed), -- 本单第几件商品，并将字符串转整数
       o.customer_id, -- 买家编号
       i.product_id, -- 商品编号
       i.seller_id, -- 卖家编号
       cast(
       date_format(
               str_to_date(o.order_purchase_timestamp, '%Y-%m-%d %H:%i:%s') ,-- 字符串‘订单购买时间’转成日期并规定格式
       '%Y%m%d')     -- 日期格式化成字符串，规定格式如20180115
           as signed)  as date_key,  -- 字符串转成整数，作为日期维度的键
       o.order_status, -- 订单状态照搬
       cast(i.price as decimal(10,2)), -- 商品价格，转成小数，规定两位小数
       cast(i.freight_value as decimal (10,2)), -- 运费同上

       if(o.order_delivered_customer_date = '',
       null, -- 如果是空串就给null
       datediff( -- 非空开始算日期差
       str_to_date(o.order_delivered_customer_date,'%Y-%m-%d %H:%i:%s'), -- 签收时间转日期
       str_to_date(o.order_purchase_timestamp,'%Y-%m-%d %H:%i:%s')  -- 下单时间转日期
       )
       ) as delivery_days, -- 结果命名为 配送时间

       if(o.order_delivered_customer_date = '',
       null,
            if(o.order_delivered_customer_date > o.order_estimated_delivery_date,  -- 签收晚于预估
             1 , 0 ) -- 晚了标记1，不晚标记0
       ) as is_late  -- 结果命名为 是否迟到
from dw_olist.ods_items i
left join dw_olist.ods_orders o
 on i.order_id = o.order_id;

select count(1), sum(price), sum(freight_value),
       sum(delivery_days is null), sum(is_late)
from dw_olist.fact_order_items;

select sum(cast(price as decimal(10,2))),
       sum(cast(freight_value as decimal(10,2)))
from dw_olist.ods_items;