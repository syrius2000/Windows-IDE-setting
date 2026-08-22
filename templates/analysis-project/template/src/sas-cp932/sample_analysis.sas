/* ========================================================================= */
/* SAS Sample Analysis Program (CP932 / Shift-JIS)                           */
/* 目的: 合成データを用いた要約統計量算出とカプランマイヤー生存曲線推定      */
/* ========================================================================= */

options nodate nonumber linesize=120 pagesize=60;

/* ログ・出力先は invoke-sas.ps1 により .run/sas/ 配下に自動分離されます */

data work.cohort;
    set sashelp.class;
    /* ダミー解析変数作成 */
    if age >= 13 then age_group = 'Senior';
    else age_group = 'Junior';
    
    /* 追跡期間とイベントのダミー定義 */
    time_to_event = height * 0.5 + weight * 0.2;
    event = (age >= 14);
run;

/* 基本統計量サマリー */
title '【検証】要約統計量出力';
proc means data=work.cohort n mean std median min max;
    class age_group;
    var height weight time_to_event;
run;

/* 頻度集計 */
title '【検証】群別頻度集計';
proc freq data=work.cohort;
    tables age_group * sex / chisq;
run;

/* 生存時間解析 (Kaplan-Meier) */
title '【検証】生存時間推定';
proc lifetest data=work.cohort plots=survival;
    time time_to_event * event(0);
    strata age_group;
run;

title;
