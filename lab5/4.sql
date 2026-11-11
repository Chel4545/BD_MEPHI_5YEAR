WITH
-- 1. Число договоров читателя (оставляем только читателей с несколькими договорами)
contract_count AS (
    SELECT
        user_id,
        COUNT(*) AS total_contracts
    FROM contract
    GROUP BY user_id
    -- HAVING COUNT(*) > 1
),

-- 2. Дата оформления первого договора
first_contract_date AS (
    SELECT
        user_id,
        MIN(contract_date) AS first_contract_date
    FROM contract
    GROUP BY user_id
),

-- 3. Дата окончания последнего оформленного договора
last_contract_end_date AS (
    SELECT DISTINCT ON (user_id)
        user_id,
        (contract_date + make_interval(months => contract_duration_months))::date AS last_contract_end_date

    FROM contract
    ORDER BY
        user_id,
        contract_date DESC,
        contract_id DESC
),

-- 4. Общее количество заказанной литературы
total_ordered_books AS (
    SELECT
        pr.user_id,
        SUM(rp.ordered_count) AS total_ordered_count
    FROM publication_request pr
    JOIN request_publications rp
        ON rp.request_id = pr.request_id
    GROUP BY pr.user_id
),

-- 5. Количество текущих просроченных экземпляров
overdue_publications AS (
    SELECT
        pr.user_id,

        SUM(rp.issued_count - rp.returned_count) AS overdue_count

    FROM publication_request pr
    JOIN request_publications rp
        ON rp.request_id = pr.request_id

    WHERE pr.deadline < current_date
      AND rp.issued_count > rp.returned_count

    GROUP BY pr.user_id
),

-- 6. Самое популярное издание каждого читателя
popular_publication AS (
    SELECT DISTINCT ON (pr.user_id)
        pr.user_id,
        p.title AS popular_publication_title,

        SUM(rp.ordered_count)
            AS publication_ordered_count

    FROM publication_request pr
    JOIN request_publications rp
        ON rp.request_id = pr.request_id
    JOIN publication p
        ON p.publication_id = rp.publication_id

    GROUP BY
        pr.user_id,
        p.publication_id,
        p.title

    ORDER BY
        pr.user_id,
        publication_ordered_count DESC,
        p.publication_id
),

-- 7. Признак наличия активного договора
active_contract_presence AS (
    SELECT
        u.user_id,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM contract c
                WHERE c.user_id = u.user_id
                  AND c.contract_date <= current_date
                  AND c.contract_duration_months IS NOT NULL
                  AND c.contract_date + make_interval(months => c.contract_duration_months) >= current_date
            )
            THEN 'есть'
            ELSE 'нет'
        END AS has_active_contract

    FROM "user" u
    JOIN role r
        ON r.code = u.role_code
    WHERE r.name = 'Читатель'
)

SELECT
    COALESCE(
        pp.full_name,
        le.organization_name,
        u.account_name
    ) AS "Имя читателя",

    cc.total_contracts
        AS "Число оформленных договоров",

    fcd.first_contract_date
        AS "Дата первого договора",

    lced.last_contract_end_date
        AS "Дата окончания последнего договора",

    COALESCE(tob.total_ordered_count, 0)
        AS "Общее количество заказанной литературы",

    COALESCE(op.overdue_count, 0)
        AS "Количество просроченных изданий",

    pop.popular_publication_title
        AS "Самое популярное издание",

    acp.has_active_contract
        AS "Активный договор"

FROM "user" u

JOIN role r
    ON r.code = u.role_code

JOIN contract_count cc
    ON cc.user_id = u.user_id

LEFT JOIN physical_person pp
    ON pp.user_id = u.user_id

LEFT JOIN legal_entity le
    ON le.user_id = u.user_id

LEFT JOIN first_contract_date fcd
    ON fcd.user_id = u.user_id

LEFT JOIN last_contract_end_date lced
    ON lced.user_id = u.user_id

LEFT JOIN total_ordered_books tob
    ON tob.user_id = u.user_id

LEFT JOIN overdue_publications op
    ON op.user_id = u.user_id

LEFT JOIN popular_publication pop
    ON pop.user_id = u.user_id

LEFT JOIN active_contract_presence acp
    ON acp.user_id = u.user_id

WHERE r.name = 'Читатель'

ORDER BY
    cc.total_contracts DESC,
    "Имя читателя";