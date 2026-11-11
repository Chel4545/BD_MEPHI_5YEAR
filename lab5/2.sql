WITH
-- 1. Число договоров читателя за всё время
contract_count AS (
    SELECT
        user_id,
        COUNT(*) AS total_contracts
    FROM contract
    GROUP BY user_id
),

-- 2. Признак наличия актуального договора
active_contract_presence AS (
    SELECT
        user_id,
        'есть' AS has_active_contract
    FROM contract
    WHERE contract_date <= current_date
      AND contract_duration_months IS NOT NULL
      AND contract_date + make_interval(months => contract_duration_months) >= current_date
    GROUP BY user_id
),

-- 3. Номер текущего договора
current_contract_number AS (
    SELECT DISTINCT ON (user_id)
        user_id,
        contract_id
    FROM contract
    WHERE contract_date <= current_date
      AND contract_duration_months IS NOT NULL
      AND contract_date + make_interval(months => contract_duration_months) >= current_date
    ORDER BY
        user_id,
        contract_date DESC,
        contract_id DESC
),

-- 4. Срок текущего договора
current_contract_duration AS (
    SELECT DISTINCT ON (user_id)
        user_id,
        contract_duration_months
    FROM contract
    WHERE contract_date <= current_date
      AND contract_duration_months IS NOT NULL
      AND contract_date + make_interval(months => contract_duration_months) >= current_date
    ORDER BY
        user_id,
        contract_date DESC,
        contract_id DESC
),

-- 5. Общее количество запросов читателя
total_requests AS (
    SELECT
        user_id,
        COUNT(*) AS request_count
    FROM publication_request
    GROUP BY user_id
),

-- 6. Количество запросов с нарушениями
violation_requests AS (
    SELECT
        pr.user_id,
        COUNT(DISTINCT pr.request_id) AS violation_count
    FROM publication_request pr
    JOIN request_publications rp
        ON rp.request_id = pr.request_id
    WHERE pr.deadline < current_date
      AND rp.issued_count > rp.returned_count
    GROUP BY pr.user_id
),

-- 7. Число текущих просроченных книг
overdue_books AS (
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

-- 8. Максимальная задолженность среди читателей
maximum_debt AS (
    SELECT
        MAX(COALESCE(ob.overdue_count, 0)) AS maximum_overdue_count
    FROM "user" u
    JOIN role r
        ON r.code = u.role_code
    LEFT JOIN overdue_books ob
        ON ob.user_id = u.user_id
    WHERE r.name = 'Читатель'
)

SELECT
    COALESCE(
        pp.full_name,
        le.organization_name,
        u.account_name
    ) AS "Имя читателя",

    COALESCE(cc.total_contracts, 0)
        AS "Число договоров",

    COALESCE(acp.has_active_contract, 'нет')
        AS "Актуальный договор",

    ccn.contract_id
        AS "Номер текущего договора",

    ccd.contract_duration_months
        AS "Срок договора, месяцев",

    COALESCE(tr.request_count, 0)
        AS "Общее количество запросов",

    COALESCE(vr.violation_count, 0)
        AS "Количество запросов с нарушениями",

    COALESCE(ob.overdue_count, 0)
        AS "Текущие просроченные книги"

FROM "user" u
JOIN role r
    ON r.code = u.role_code
LEFT JOIN physical_person pp
    ON pp.user_id = u.user_id
LEFT JOIN legal_entity le
    ON le.user_id = u.user_id
LEFT JOIN contract_count cc
    ON cc.user_id = u.user_id
LEFT JOIN active_contract_presence acp
    ON acp.user_id = u.user_id
LEFT JOIN current_contract_number ccn
    ON ccn.user_id = u.user_id
LEFT JOIN current_contract_duration ccd
    ON ccd.user_id = u.user_id
LEFT JOIN total_requests tr
    ON tr.user_id = u.user_id
LEFT JOIN violation_requests vr
    ON vr.user_id = u.user_id
LEFT JOIN overdue_books ob
    ON ob.user_id = u.user_id

ORDER BY "Текущие просроченные книги" DESC;