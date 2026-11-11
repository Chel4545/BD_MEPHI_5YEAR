WITH
-- Техническая таблица: дата первого поступления каждого издания
publication_dates AS (
    SELECT
        pa.author_id,
        p.publication_id,
        p.title,
        MIN(ad.arrival_date) AS arrival_date
    FROM publication_authors pa
    JOIN publication p
        ON p.publication_id = pa.publication_id
    LEFT JOIN new_publications np
        ON np.registration_number = p.publication_id
    LEFT JOIN arrival_document ad
        ON ad.arrival_document_id = np.arrival_document_id
    GROUP BY
        pa.author_id,
        p.publication_id,
        p.title
),

-- 1. Общее число публикаций автора
total_publications AS (
    SELECT
        author_id,
        COUNT(*) AS publication_count
    FROM publication_authors
    GROUP BY author_id
),

-- 2. Число разных соавторов
different_coauthors AS (
    SELECT
        pa1.author_id,
        COUNT(DISTINCT pa2.author_id) AS coauthor_count
    FROM publication_authors pa1
    JOIN publication_authors pa2
        ON pa2.publication_id = pa1.publication_id
       AND pa2.author_id <> pa1.author_id
    GROUP BY pa1.author_id
),

-- 3. Число публикаций, написанных в соавторстве
coauthored_publications AS (
    SELECT
        pa.author_id,
        COUNT(*) AS coauthored_count
    FROM publication_authors pa
    WHERE EXISTS (
        SELECT 1
        FROM publication_authors other_author
        WHERE other_author.publication_id = pa.publication_id
          AND other_author.author_id <> pa.author_id
    )
    GROUP BY pa.author_id
),

-- 4. Первое издание автора
first_publication AS (
    SELECT DISTINCT ON (author_id)
        author_id,
        title AS first_title,
        arrival_date AS first_date
    FROM publication_dates
    WHERE arrival_date IS NOT NULL
    ORDER BY
        author_id,
        arrival_date,
        publication_id
),

-- 5. Последнее издание автора
last_publication AS (
    SELECT DISTINCT ON (author_id)
        author_id,
        title AS last_title,
        arrival_date AS last_date
    FROM publication_dates
    WHERE arrival_date IS NOT NULL
    ORDER BY
        author_id,
        arrival_date DESC,
        publication_id DESC
)

SELECT
    a.full_name AS "ФИО автора",

    COALESCE(tp.publication_count, 0)
        AS "Общее число публикаций",

    COALESCE(dc.coauthor_count, 0)
        AS "Число разных соавторов",

    COALESCE(cp.coauthored_count, 0)
        AS "Число публикаций в соавторстве",

    lp.last_title
        AS "Последнее издание",

    lp.last_date
        AS "Дата последнего издания",

    fp.first_title
        AS "Первое издание",

    fp.first_date
        AS "Дата первого издания"

FROM author a
LEFT JOIN total_publications tp
    ON tp.author_id = a.author_id
LEFT JOIN different_coauthors dc
    ON dc.author_id = a.author_id
LEFT JOIN coauthored_publications cp
    ON cp.author_id = a.author_id
LEFT JOIN first_publication fp
    ON fp.author_id = a.author_id
LEFT JOIN last_publication lp
    ON lp.author_id = a.author_id
ORDER BY
    a.full_name,
    a.author_id;