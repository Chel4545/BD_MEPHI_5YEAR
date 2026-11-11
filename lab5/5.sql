CREATE EXTENSION IF NOT EXISTS tablefunc;

DROP TABLE IF EXISTS pg_temp.tmp_coauthorship_matrix;

DO $$
DECLARE
    column_definitions text;
BEGIN
    -- Формируем список выходных столбцов
	-- "Иванов Иван [1]" bigint
    SELECT
        string_agg(
            format(
                '%I bigint',
                full_name || ' [' || author_id || ']'
            ),
            ', '
            ORDER BY author_id
        )
    INTO column_definitions
    FROM author;

    -- Создаём временную таблицу с динамическим количеством столбцов
    EXECUTE format(
        $matrix$
        CREATE TEMP TABLE tmp_coauthorship_matrix AS

        SELECT *
        FROM crosstab(

            -- автор строки, автор столбца, число совместных публикаций
            $source$
                SELECT
                    row_author.full_name
                        || ' [' || row_author.author_id || ']'
                        AS row_author_name,

                    column_author.full_name
                        || ' [' || column_author.author_id || ']'
                        AS column_author_name,

                    COUNT(DISTINCT pa1.publication_id)
                        FILTER (WHERE pa2.author_id IS NOT NULL) AS shared_publications

                FROM author row_author

                CROSS JOIN author column_author

                LEFT JOIN publication_authors pa1
                    ON pa1.author_id = row_author.author_id

                LEFT JOIN publication_authors pa2
                    ON pa2.publication_id = pa1.publication_id
                   AND pa2.author_id = column_author.author_id
                   AND pa2.author_id <> row_author.author_id

                GROUP BY
                    row_author.author_id,
                    row_author.full_name,
                    column_author.author_id,
                    column_author.full_name

                ORDER BY
                    row_author.author_id,
                    column_author.author_id
            $source$,

            -- Список авторов, которые должны стать столбцами
            $categories$
                SELECT
                    full_name || ' [' || author_id || ']'
                FROM author
                ORDER BY author_id
            $categories$

        ) AS matrix(
            "Имя автора" text,
            %s
        )
        $matrix$,
        column_definitions
    );
END;
$$;

-- Вывод готовой матрицы
SELECT *
FROM tmp_coauthorship_matrix;