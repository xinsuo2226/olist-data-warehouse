# Olist 电商数仓

基于 Kaggle 公开数据集 **Olist Brazilian E-Commerce**（巴西电商，9 张表，约 155 万行，时间跨度 2016.09 - 2018.10）搭建的离线数据仓库，用 MySQL 8.0 实现，覆盖 ODS → DWD → DWS → ADS 四层。

## 项目目标

不是做数据分析，是练一遍完整的数据链路：

1. 从原始 CSV 到可用的明细事实表，中间不断
2. 每层为什么存在，能说清楚
3. 链节能重跑，数据不对时能发现

## 技术栈

MySQL 8.0、SQL、Python（导入）、DataGrip、Git

## 分层设计

| 层 | 表 | 行数 | 职责 |
|---|---|---|---|
| ODS | ods_orders / ods_items / ods_payments / ods_reviews / ods_products / ods_sellers / ods_customers / ods_geolocation / ods_translation | 1,550,921 | 原样落库，全 varchar，不做业务加工 |
| DWD 维度 | dim_customers / dim_products / dim_sellers / dim_geo / dim_date | 约 14.6 万 | 清洗后的公共维度 |
| DWD 事实 | fact_order_items | 112,650 | 一行一个订单商品，金额与源表对账一致 |
| DWS | dws_sales_daily / dws_buyer / dws_delivery | 约 16.3 万 | 按天、按买家、按履约三个主题汇总 |
| ADS | ads_funnel / ads_repurchase | — | 履约漏斗、复购分布 |
| 质量 | dq_report | 10 | 十项检查的预期值、实测值、是否通过 |

## 关键指标

- GMV **13,591,643.70**，运费 2,251,909.54
- 订单 99,441，商品行 112,650，支付记录 103,886，评价 99,223
- 买家 95,420（有商品交易的），全部买家 96,096
- 履约漏斗：下单 99,441 → 付款 99,281 → 发货 97,658 → 签收 96,476
- 平均履约 12.5 天，迟到率 7.9%（8,715 行）
- 复购率 2% - 3%

## 数据质量

十项规则写入 `dq_report` 表，带预期值、实测值、通过标记、检查时间：

| # | 规则 | 检查内容 |
|---|---|---|
| 1 | ODS 订单表行数 = 99441 | 导入是否丢行 |
| 2 | 事实表行数 = 112650 | 加工是否多算少算 |
| 3 | 事实表金额合计 = 13591643.70 | 金额是否被改 |
| 4 | 客户维度主键重复数 = 0 | 唯一性 |
| 5 | 事实表孤儿买家数 = 0 | 外键完整性 |
| 6 | 事实表孤儿商品数 = 0 | 外键完整性 |
| 7 | 非法订单状态数 = 0 | 枚举值域 |
| 8 | 配送天数为负的行数 = 0 | 时间倒挂 |
| 9 | 地理坐标越界数 = 0 | 值域 |
| 10 | 漏斗首层与订单表差额 = 0 | 跨表勾稽 |

## 目录结构

```
dw_olist_sql/
├── 00_run_all.bat      一键跑通，按顺序执行下面五个 SQL
├── 01_ods.sql          九张 ODS 建表与导入
├── 02_dwd.sql          五张维度表 + 一张事实表
├── 02_dwd_desgin.txt   DWD 设计说明
├── 03_dws.sql          三张主题汇总
├── 04_ads.sql          漏斗与复购
├── 05_quality.sql      十项规则，写入 dq_report
├── 06_dictionary.txt   数据字典
├── 07_architecture.png 四层架构图
├── 08_speech.txt       十五分钟讲解稿
└── 00_错误记录.txt     开发过程中的报错与修正
```

## 怎么跑

### 一键跑通

把 `00_run_all.bat` 里的 `PASSWORD` 改成自己的 MySQL root 密码，双击运行。脚本按 ODS → DWD → DWS → ADS → 质量 的顺序执行五步，最后打印质检结果。

前提：9 个 CSV 放在 `../olist/` 目录下。`01_ods.sql` 里用的是 `load data local infile` 加绝对路径，换机器要先改路径。

### 手动执行

按顺序执行：

1. `01_ods.sql` — 建 ODS 表并导入 CSV
2. `02_dwd.sql` — 建维度表和事实表，跑清洗
3. `03_dws.sql` — 生成三张主题汇总
4. `04_ads.sql` — 生成漏斗和复购
5. `05_quality.sql` — 跑十项检查，结果写入 `dq_report`

## 三个设计判断

**ODS 全 varchar 是故意的。** 直接导 CSV 的结果，不在导入时做类型转换。ODS 保持原样才能重跑，清洗规则改了只重跑下游，不用回源头。

**做的是履约漏斗，不是浏览漏斗。** 这批数据没有浏览和加购记录，做不了经典的转化漏斗。硬做就是编，所以改做下单之后每一步还剩多少单。

**维度表不拆成雪花。** `dim_products` 里直接放品类名，不另建品类表。数仓用星型，用冗余换查询速度，避免多层 join。

## 已知局限

- 单机 MySQL，未做分区，数据量再大会撑不住
- 调度用的是手工执行，没有接 Airflow 或 DolphinScheduler
- 没有实时链路，全离线
