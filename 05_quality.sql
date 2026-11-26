-- 报告表
drop table if exists dw_olist.dq_report;
create table dw_olist.dq_report (
    rule_no int,              -- 规则编号
    rule_name varchar(100),   -- 规则名称
    check_value varchar(100), -- 实际查出来的值
    export_value varchar(100),-- 预期值
    is_pass tinyint,          -- 1通过 0失败
    check_time datetime       -- 检查时间
);

-- 规则1：ODS订单表行数必须等于源文件行数
insert into dw_olist.dq_report
select 1,'ods_orders 行数',
       cast(count(1)as char), '99441',
       if(count(1) = 99441,1,0),now()
from dw_olist.ods_orders;

-- 规则2：事实表行数必须等于订单商品行数
insert into dw_olist.dq_report
select 2,'fact_order_items 行数',
       cast(count(1)as char),'112650',
       if(count(1) = 112650,1,0),now()
from dw_olist.fact_order_items;

-- 规则3：事实表金额合计必须等于源表金额合计
insert into  dw_olist.dq_report
select 3,'事实表金额对账',
       cast(round(sum(price),2)as char),'13591643.70',
       if(round(sum(price),2) = 13591643.70,1,0),now()
from dw_olist.fact_order_items;

-- 规则4：客户维度主键不许重复
insert into dw_olist.dq_report
select 4, 'dim_customers 主键重复行数',
       cast(count(1) - count(distinct customer_id) as char), '0',
       if(count(1) = count(distinct customer_id), 1, 0), now()
from dw_olist.dim_customers;

-- 规则5：事实表里的买家，每个都要能在客户维度找到
insert into dw_olist.dq_report
select 5, '事实表孤儿买家数',
       cast(count(1) as char), '0',
       if(count(1) = 0, 1, 0), now()
from dw_olist.fact_order_items f
left join dw_olist.dim_customers c
  on f.customer_id = c.customer_id
where c.customer_id is null;

-- 规则6：事实表里的商品，每个都要能在商品维度找到
insert into dw_olist.dq_report
select 6, '事实表孤儿商品数',
       cast(count(1) as char), '0',
       if(count(1) = 0, 1, 0), now()
from dw_olist.fact_order_items f
left join dw_olist.dim_products p
  on f.product_id = p.product_id
where p.product_id is null;

-- 规则7：订单状态只能是这八种，不许出现别的
insert into dw_olist.dq_report
select 7, '非法订单状态数',
       cast(count(1) as char), '0',
       if(count(1) = 0, 1, 0), now()
from dw_olist.fact_order_items
where order_status not in ('delivered','shipped','canceled','unavailable',
                           'invoiced','processing','created','approved');

-- 规则8：配送天数不许为负，签收不能早于下单
insert into dw_olist.dq_report
select 8, '配送天数为负的行数',
       cast(count(1) as char), '0',
       if(count(1) = 0, 1, 0), now()
from dw_olist.fact_order_items
where delivery_days < 0;

-- 规则9：地理坐标必须在巴西范围内
insert into dw_olist.dq_report
select 9, '越界坐标数',
       cast(count(1) as char), '0',
       if(count(1) = 0, 1, 0), now()
from dw_olist.dim_geo
where lat is not null
  and (lat > 6 or lat < -34 or lng > -32 or lng < -74);

-- 规则10：漏斗第一层必须等于订单表总行数
insert into dw_olist.dq_report
select 10, '漏斗首层与订单表差额',
       cast((select order_cnt from dw_olist.ads_funnel where step_no = 1)
          - (select count(1)   from dw_olist.ods_orders) as char), '0',
       if((select order_cnt from dw_olist.ads_funnel where step_no = 1)
        = (select count(1)   from dw_olist.ods_orders), 1, 0), now();

select * from dw_olist.dq_report order by rule_no;

