WITH
-- 1. Последние 12 календарных месяцев
months AS (
    SELECT
        generate_series(
            date_trunc('month', current_date) - interval '11 months',
            date_trunc('month', current_date),
            interval '1 month'
        )::date AS month_start
),

-- 2. Фактически выданные издания за последние 12 месяцев
issued_requests AS (
    SELECT
        pr.request_id,
        pr.request_date,
        date_trunc('month', pr.request_date)::date AS month_start,
        sp.section_id,
        rp.publication_id
    FROM publication_request pr
    JOIN request_publications rp
        ON rp.request_id = pr.request_id
    JOIN section_publications sp
        ON sp.publication_id = rp.publication_id
    WHERE pr.request_date >= date_trunc('month', current_date) - interval '11 months'
      AND pr.request_date <= current_date
      AND rp.issued_count > 0
),

-- 3. Количество запросов по каждому разделу в каждом месяце
section_month_requests AS (
    SELECT
        month_start,
        section_id,
        COUNT(DISTINCT request_id) AS month_request_count
    FROM issued_requests
    GROUP BY
        month_start,
        section_id
),

-- 4. Количество запросов по каждому разделу за 12 месяцев
section_year_requests AS (
    SELECT
        section_id,
        COUNT(DISTINCT request_id) AS year_request_count
    FROM issued_requests
    GROUP BY section_id
),

-- 5. Самый популярный раздел каждого месяца
popular_section AS (
    SELECT DISTINCT ON (month_start)
        month_start,
        section_id,
        month_request_count
    FROM section_month_requests
    ORDER BY
        month_start,
        month_request_count DESC,
        section_id
),

-- 6. Статистика изданий по разделам и месяцам
publication_month_requests AS (
    SELECT
        month_start,
        section_id,
        publication_id,

        COUNT(DISTINCT request_id)
            AS publication_request_count,

        MAX(request_date)
            AS last_request_date

    FROM issued_requests
    GROUP BY
        month_start,
        section_id,
        publication_id
),

-- 7. Самое популярное издание в каждом разделе каждого месяца
popular_publication AS (
    SELECT DISTINCT ON (month_start, section_id)
        month_start,
        section_id,
        publication_id,
        publication_request_count,
        last_request_date
    FROM publication_month_requests
    ORDER BY
        month_start,
        section_id,
        publication_request_count DESC,
        last_request_date DESC,
        publication_id
)

SELECT
    CASE EXTRACT(MONTH FROM m.month_start)
        WHEN 1  THEN 'Январь'
        WHEN 2  THEN 'Февраль'
        WHEN 3  THEN 'Март'
        WHEN 4  THEN 'Апрель'
        WHEN 5  THEN 'Май'
        WHEN 6  THEN 'Июнь'
        WHEN 7  THEN 'Июль'
        WHEN 8  THEN 'Август'
        WHEN 9  THEN 'Сентябрь'
        WHEN 10 THEN 'Октябрь'
        WHEN 11 THEN 'Ноябрь'
        WHEN 12 THEN 'Декабрь'
    END AS "Название месяца",

    s.section_name
        AS "Самый популярный раздел",

    p.title
        AS "Самое популярное издание",

    COALESCE(ps.month_request_count, 0)
        AS "Запросов по разделу в месяце",

    COALESCE(syr.year_request_count, 0)
        AS "Запросов по разделу за 12 месяцев",

    COALESCE(pp.publication_request_count, 0)
        AS "Запросов на популярное издание",

    pp.last_request_date
        AS "Дата последнего запроса"

FROM months m

LEFT JOIN popular_section ps
    ON ps.month_start = m.month_start

LEFT JOIN section s
    ON s.section_id = ps.section_id

LEFT JOIN section_year_requests syr
    ON syr.section_id = ps.section_id

LEFT JOIN popular_publication pp
    ON pp.month_start = ps.month_start
   AND pp.section_id = ps.section_id

LEFT JOIN publication p
    ON p.publication_id = pp.publication_id

ORDER BY m.month_start;