create database if not exists dw_olist
    default character set utf8mb4
    collate utf8mb4_0900_ai_ci ;
-- 1.订单表 99441行
drop table if exists dw_olist.ods_orders;

create table dw_olist.ods_orders (
  order_id varchar(255),
  customer_id varchar(255),
  order_status varchar(255),
  order_purchase_timestamp varchar(255),
  order_approved_at varchar(255),
  order_delivered_carrier_date varchar(255),
  order_delivered_customer_date varchar(255),
  order_estimated_delivery_date varchar(255)
);

load data local infile 'D:/辛一/olist/olist_orders_dataset.csv'
into table dw_olist.ods_orders
fields terminated by ',' optionally enclosed by '"'
lines terminated by '\n'
ignore 1 lines;

-- ods_sellers 2.卖家表 预期3095行
drop table if exists dw_olist.ods_sellers;
create table dw_olist.ods_sellers (
    seller_id varchar(255),
    seller_zip_code_prefix varchar(255),
    seller_city varchar(255),
    seller_state varchar(255)
);

load data local infile 'D:/辛一/olist/olist_sellers_dataset.csv'
into table dw_olist.ods_sellers
fields terminated by ',' optionally enclosed by '"'
ignore 1 lines ;

-- ods_translation 3.翻译表
drop table if exists dw_olist.ods_translation;

create table dw_olist.ods_translation (
    product_category_name varchar(255),
    product_category_name_english varchar(255)
);

load data local infile 'D:/辛一/olist/product_category_name_translation.csv'
into table dw_olist.ods_translation
fields terminated by ',' optionally enclosed by '"'
ignore 1 lines;

-- ods_products 4.产品表 预期32951
drop table if exists dw_olist.ods_products;

create table dw_olist.ods_products (
    product_id varchar(255),
    product_category_name varchar(255),
    product_name_lenght varchar(255),
    product_description_lenght varchar(255),
    product_photos_qty varchar(255),
    product_weight_g varchar(255),
    product_length_cm varchar(255),
    product_height_cm varchar(255),
    product_width_cm varchar(255)
);

load data local infile 'D:/辛一/olist/olist_products_dataset.csv'
into table dw_olist.ods_products
fields terminated by ','  optionally enclosed by '"'
ignore 1 lines;

-- ods_customers 5.顾客表 预期99441
drop table if exists dw_olist.ods_customers;

create table dw_olist.ods_customers (
    customer_id varchar(255),
    customer_unique_id varchar(255),
    customer_zip_code_prefix varchar(255),
    customer_city varchar(255),
    customer_state varchar(255)
);

load data local infile 'D:/辛一/olist/olist_customers_dataset.csv'
into table dw_olist.ods_customers
fields terminated by ','  optionally enclosed by '"'
ignore 1 lines;

-- 6.购买商品表 ods_items 预期112650
drop table if exists dw_olist.ods_items;

create table dw_olist.ods_items (
    order_id varchar(255),
    order_item_id varchar(255),
    product_id varchar(255),
    seller_id varchar(255),
    shipping_limit_date varchar(255),
    price varchar(255),
    freight_value varchar(255)
);

load data local infile 'D:/辛一/olist/olist_order_items_dataset.csv'
into table dw_olist.ods_items
fields terminated by ','  optionally enclosed by '"'
ignore 1 lines;

-- 7.付费表 ods_payments 预期103886
drop table if exists dw_olist.ods_payments ;

create table dw_olist.ods_payments (
    order_id varchar(255),
    payment_sequential varchar(255),
    payment_type varchar(255),
    payment_installments varchar(255),
    payment_value varchar(255)
);

load data local infile 'D:/辛一/olist/olist_order_payments_dataset.csv'
into table dw_olist.ods_payments
fields terminated by ','  optionally enclosed by '"'
ignore 1 lines;

-- 8.评论表 ods_reviews 预期99224
drop table if exists dw_olist.ods_reviews ;

create table dw_olist.ods_reviews (
    review_id varchar(255),
    order_id varchar(255),
    review_score varchar(255),
    review_comment_title varchar(255),
    review_comment_message varchar(255),
    review_creation_date varchar(255),
    review_answer_timestamp varchar(255)
);

load data local infile 'D:/辛一/olist/olist_order_reviews_dataset.csv'
into table dw_olist.ods_reviews
character set utf8mb4
fields terminated by ',' optionally enclosed by '"'
ignore 1 lines;

-- 9.地理位置表 预期1000163
drop table if exists dw_olist.ods_geolocation;

create table dw_olist.ods_geolocation (
    geolocation_zip_code_prefix varchar(255),
    geolocation_lat varchar(255),
    geolocation_lng varchar(255),
    geolocation_city varchar(255),
    geolocation_state varchar(255)
);

load data local infile 'D:/辛一/olist/olist_geolocation_dataset.csv'
into table dw_olist.ods_geolocation
fields terminated by ','  optionally enclosed by '"'
ignore 1 lines;
-- 汇总：
select 'customers' as tbl, count(1) as rows_cnt from dw_olist.ods_customers
union all
select 'geolocation', count(1) from dw_olist.ods_geolocation
union all
select 'items', count(1) from dw_olist.ods_items
union all
select 'orders', count(1) from dw_olist.ods_orders
union all
select 'payments', count(1) from dw_olist.ods_payments
union all
select 'products', count(1) from dw_olist.ods_products
union all
select 'reviews', count(1) from dw_olist.ods_reviews
union all
select 'sellers', count(1) from dw_olist.ods_sellers
union all
select 'translation', count(1) from dw_olist.ods_translation;

