@echo off
chcp 65001 >nul
rem ============================================
rem  Olist 电商数仓  一键跑通
rem
rem  用法：把下面 PASSWORD 改成你的 MySQL root 密码，双击运行
rem  前提：9 个 CSV 放在 ..\olist\ 目录下（和 dw_olist_sql 同级）
rem  顺序：ODS -> DWD -> DWS -> ADS -> 数据质量
rem ============================================

set PASSWORD=改成你的密码
set MYSQL=mysql -u root --local-infile=1 --default-character-set=utf8mb4

cd /d "%~dp0"
set MYSQL_PWD=%PASSWORD%

echo.
echo [1/5] ODS 层，导入 9 张原始表
%MYSQL% < 01_ods.sql
if errorlevel 1 goto fail

echo [2/5] DWD 层，建 5 张维度表和 1 张事实表
%MYSQL% < 02_dwd.sql
if errorlevel 1 goto fail

echo [3/5] DWS 层，建 3 张主题汇总
%MYSQL% < 03_dws.sql
if errorlevel 1 goto fail

echo [4/5] ADS 层，建漏斗和复购
%MYSQL% < 04_ads.sql
if errorlevel 1 goto fail

echo [5/5] 数据质量，跑 10 项检查
%MYSQL% < 05_quality.sql
if errorlevel 1 goto fail

echo.
echo ========================================
echo  全部完成，质检结果如下：
echo ========================================
%MYSQL% -e "select rule_no, rule_name, check_value, export_value, if(is_pass=1,'通过','失败') as result from dw_olist.dq_report order by rule_no;"
goto end

:fail
echo.
echo [失败] 上一步出错，看上面的报错信息

:end
echo.
pause
