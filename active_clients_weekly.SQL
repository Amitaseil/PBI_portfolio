-- active_weekly --

WITH

ams_clients as (
  SELECT
    pr.project_id,
    p.client_id,
    p.id AS ams_client_id,
    inf.register_date,
    last_activity_date,
      CASE 
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 1 THEN "< 1 month"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 2 THEN "1 month"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 3 THEN "2 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 4 THEN "3 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 5 THEN "4 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 6 THEN "5 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 7 THEN "6 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 8 THEN "7 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 9 THEN "8 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 10 THEN "9 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 11 THEN "10 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 12 THEN "11 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 13 THEN "12 months"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) < 25 THEN "1-2 years"
        WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), inf.register_date, MONTH) >= 25 THEN "> 2 years"
      END AS
    days_from_reg,
    COALESCE(f.flow, "unidentified") AS flow,
  FROM `ams_new.ams_client` as p
  JOIN (SELECT DISTINCT project_id, project_country, is_active, ams_id FROM `service.project_id`) AS pr ON p.project_id = pr.ams_id
  JOIN (SELECT * EXCEPT (register_date, first_deposit_date, last_activity_date, project_id), pr.project_id, 
      IF(pr.project_country = 'USA', date(timestamp(format_datetime('%Y-%m-%d %H:%M:%S', p.register_date), 'Europe/Kyiv'), 'America/New_York'), date(p.register_date)) as register_date,
      IF(pr.project_country = 'USA', date(timestamp(format_datetime('%Y-%m-%d %H:%M:%S', p.first_deposit_date), 'Europe/Kyiv'), 'America/New_York'), date(p.first_deposit_date)) as ftd,
      DATETIME(last_activity_date) AS last_activity_date
    FROM `web.clients` AS p
    JOIN (select distinct project_id, project_country, is_active from `service.project_id`) as pr on pr.project_id = p.project_id) AS inf 
    ON inf.client_id = p.client_id AND inf.project_id = pr.project_id
  LEFT JOIN `web.Flow` as f on pr.project_id = f.project_id and p.client_id = f.client_id
  WHERE inf.client_status <> 'SUSPENDED' 
    AND inf.is_system IS FALSE 
    AND pr.is_active IS TRUE
    AND p.test_client IS NOT TRUE
  GROUP BY 1,2,3,4,5,7
)

,deposits AS (
  SELECT 
    DISTINCT d.payment_id,
    d.project_id,
    d.client_id,
    ams.ams_client_id,
    date_paid,
    LAG(date_paid) OVER (PARTITION BY ams_client_id ORDER BY date_paid) AS lag_date_paid,
    amount_usd
  FROM (SELECT * EXCEPT (date_paid), DATETIME(date_paid) AS date_paid FROM `web.Payments` 
  WHERE date(date_paid) >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 YEAR)
  AND status = 'closed' and payment_gateway <> 'userbalance')  AS d
  JOIN ams_clients AS ams ON ams.client_id = d.client_id AND ams.project_id = d.project_id
  WHERE 1=1
  GROUP BY 1,2,3,4,5,7
)

,deposits_count AS (
  SELECT 
    ams.ams_client_id,
    ams.client_id,
    ams.project_id,
      CASE
        WHEN COUNT(payment_id) < 1 THEN "no deposits"
        WHEN COUNT(payment_id) < 2 THEN "1"
        WHEN COUNT(payment_id) < 3 THEN "2"
        WHEN COUNT(payment_id) < 4 THEN "3"
        WHEN COUNT(payment_id) < 5 THEN "4"
        WHEN COUNT(payment_id) < 6 THEN "5"
        WHEN COUNT(payment_id) <= 10 THEN "6-10"
        WHEN COUNT(payment_id) <= 50 THEN "11-50"
        WHEN COUNT(payment_id) > 50 THEN ">50"
    END AS 
  dep_group
  FROM deposits AS d
  RIGHT JOIN ams_clients AS ams ON d.ams_client_id = ams.ams_client_id
  GROUP BY 1,2,3
) 

,true_clients AS (
  SELECT 
    ams.ams_client_id,
    ams.project_id,
    date_ AS act_date,
    register_date,
    last_activity_date,
    days_from_reg,
    flow
  FROM `web.AppsAggr` AS g
  JOIN ams_clients AS ams ON g.client_id = ams.client_id AND g.project_id = ams.project_id
  WHERE date_ >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 YEAR)
)

,fake_clients AS (
  SELECT
    ams.ams_client_id,
    ams.project_id,
    dt,
    register_date,
    last_activity_date,
    days_from_reg,
    flow,
  FROM `Apps.river_transactions_points` AS g
  JOIN ams_clients AS ams ON g.client_id = ams.client_id AND g.project_id = ams.project_id
    WHERE DATE(dt) >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 YEAR)
  GROUP BY 1,2,3,4,5,6,7
)

,clients_merged AS(
  SELECT 
    *
  FROM true_clients

  UNION ALL
  
  SELECT 
    *
  FROM fake_clients 
)

,client_dates AS(
  SELECT 
    ams_client_id,
    project_id,
    act_date,
    register_date,
    last_activity_date,
    days_from_reg,
    flow,
    LAG(act_date) OVER (PARTITION BY ams_client_id ORDER BY act_date) AS lag_date,
      CASE 
        WHEN days_from_reg IN ("1-2 years", "> 2 years") THEN 0
        WHEN DATETIME_DIFF(act_date, register_date, WEEK) + 1 > 16 THEN 0
        ELSE DATETIME_DIFF(act_date, register_date, WEEK) + 1 
      END AS 
    activity_week 
  FROM clients_merged 
  WHERE 1=1 
  GROUP BY 1,2,3,4,5,6,7
)

, max_ld AS (
  SELECT
    ams_client_id,
    MAX(lag_date) AS max_lag_date
  FROM client_dates
  WHERE 1=1
  GROUP BY 1
)

,client_c AS (
SELECT
  g.ams_client_id,
  g.project_id,
  act_date,
  max_lag_date,
  dep_group,
  days_from_reg,
  flow,
  COALESCE(LAG(act_date) OVER (PARTITION BY g.ams_client_id, g.project_id ORDER BY act_date), DATE(register_date)) AS prev_act_date,
    CASE 
      WHEN max_lag_date IS NULL THEN "1 day active"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 1 THEN "0 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 2 THEN "1 day"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 3 THEN "2 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 4 THEN "3 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 5 THEN "4 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 6 THEN "5 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 7 THEN "6 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 8 THEN "7 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 16 THEN "8-15 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 31 THEN "16-30 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 61 THEN "31-60 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 91 THEN "61-90 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 121 THEN "91-120 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 151 THEN "121-150 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) < 181 THEN "151-180 days"
      WHEN DATE_DIFF(CURRENT_DATETIME("Europe/Kyiv"), max_lag_date, DAY) >= 181 THEN ">180 days"
    END AS 
  from_last_act,
  activity_week
  -- COUNT (DISTINCT g.ams_client_id) AS act_clients
FROM client_dates AS g
JOIN deposits_count AS dc ON dc.ams_client_id = g.ams_client_id
JOIN max_ld AS ld ON ld.ams_client_id = g.ams_client_id
WHERE 1=1
-- AND g.ams_client_id = 15146766
-- GROUP BY 1,2,3,4,5,6,7
)

,sent AS (
  SELECT
    id,
    client_id,
    account_id,
    send_time,
    campaign_sending_session_id,
    campaign_template_relation_id,
    is_successful_sent
  FROM (SELECT * EXCEPT (real_send_time), datetime(real_send_time,"Europe/Kyiv") as send_time from `ams_new.ams_campaign_client_message_new` where is_successful_sent is true
    AND datetime(real_send_time,"Europe/Kyiv") >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 YEAR))
  GROUP BY 1,2,3,4,5,6,7
)

,daily_sent AS(
  SELECT DISTINCT
    m.client_id AS ams_client_id,
    DATE(send_time) AS sent_date,
    transport_type,
    hit_type
  FROM sent AS m
  JOIN `ams_new.ams_campaign_template_relation` as ctr on m.campaign_template_relation_id = ctr.id
  INNER JOIN `ams_new.ams_campaign` AS c ON ctr.campaign_id = c.id AND transport_type != "notification_message"
  LEFT JOIN (SELECT * EXCEPT (created_at), DATETIME(created_at,"Europe/Kyiv") AS click_time FROM `ams_new.ams_campaign_client_message_hit` WHERE hit_type != "unsubscribe"
    AND DATETIME(created_at,"Europe/Kyiv") >= DATE_SUB(DATE_TRUNC(CURRENT_DATE(), MONTH), INTERVAL 1 YEAR)) AS cl ON cl.campaign_client_message_id = m.id
    AND DATETIME_DIFF(click_time, send_time, SECOND) < 60*60*24
  WHERE 1=1
    -- AND client_id = 15146766
    -- AND client_id = 13134476
  GROUP BY 1,2,3,4
  -- ORDER BY 1,2,3
)
  
, cases AS (
    SELECT
    p.ams_client_id,
    project_id,
    DATE_TRUNC(act_date, WEEK(MONDAY)) AS act_week,
    dep_group,
    days_from_reg,
    flow,
    from_last_act,
    activity_week,
    -- transport_type,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "email" ,sent_date, NULL)), DAY) <= 1), FALSE) AS emailed,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "sms", sent_date, NULL)), DAY) <= 1), FALSE) AS smsed,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "messenger" ,sent_date, NULL)), DAY) <= 1), FALSE) AS messengered,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "push" ,sent_date, NULL)), DAY) <= 1), FALSE) AS pushed,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "email" AND hit_type = "open", sent_date, NULL)), DAY) <= 1), FALSE) AS email_opened,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "email" AND hit_type = "click", sent_date, NULL)), DAY) <= 1), FALSE) AS email_clicked,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "sms" AND hit_type = "open", sent_date, NULL)), DAY) <= 1), FALSE) AS sms_opened,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "sms" AND hit_type = "click", sent_date, NULL)), DAY) <= 1), FALSE) AS sms_clicked,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "messenger" AND hit_type = "open", sent_date, NULL)), DAY) <= 1), FALSE) AS messenger_opened,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "messenger" AND hit_type = "click", sent_date, NULL)), DAY) <= 1), FALSE) AS messenger_clicked,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "push" AND hit_type = "open", sent_date, NULL)), DAY) <= 1), FALSE) AS push_opened,
    IFNULL((DATE_DIFF(MIN(act_date), MAX(IF(transport_type = "push" AND hit_type = "click", sent_date, NULL)), DAY) <= 1), FALSE) AS push_clicked
    -- COUNT(DISTINCT p.ams_client_id) AS act_cl_count
  FROM client_c AS p
  LEFT JOIN daily_sent AS m ON m.ams_client_id = p.ams_client_id
    AND act_date >= sent_date AND sent_date > prev_act_date
    AND DATE_DIFF(act_date, prev_act_date, DAY) > 1
  WHERE 1=1
  GROUP BY 1,2,3,4,5,6,7,8
)

  SELECT
    project_id,
    act_week,
    dep_group,
    days_from_reg,
    flow,
    from_last_act,
    activity_week,
    emailed,
    smsed,
    messengered,
    pushed,
    email_opened,
    email_clicked,
    sms_opened,
    sms_clicked,
    messenger_opened,
    messenger_clicked,
    push_opened,
    push_clicked,
    COUNT(DISTINCT p.ams_client_id) AS act_cl_count
  FROM cases AS p
  WHERE 1=1
  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
