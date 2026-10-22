BEGIN;

-- 1. Роли
INSERT INTO role (code, name) VALUES
    (1, 'Читатель'),
    (2, 'Библиотекарь'),
    (3, 'Администратор');

-- 2. Пользователи
INSERT INTO "user" (account_name, login, password, role_code, user_type)
VALUES ('Администратор библиотеки', 'admin.library', 'DEMO_HASH_ADMIN', 3, 'physical');

INSERT INTO "user" (account_name, login, password, role_code, admin_id, user_type)
VALUES ('Библиотекарь Ольга', 'librarian.olga', 'DEMO_HASH_LIBRARIAN', 2,
    (SELECT user_id FROM "user" WHERE login = 'admin.library'), 'physical'
);

INSERT INTO "user" (account_name, login, password, role_code, user_type) VALUES
    ('Алексей Орлов', 'aleksei.orlov', 'DEMO_HASH_READER_1', 1, 'physical'),
    ('Мария Соколова', 'maria.sokolova', 'DEMO_HASH_READER_2', 1, 'physical'),
    ('Университетская библиотека', 'library.uni', 'DEMO_HASH_ORGANIZATION', 1, 'legal');

-- 3. Физические и юридические лица
INSERT INTO physical_person (user_id, full_name)
SELECT u.user_id, v.full_name
FROM (VALUES
    ('admin.library', 'Павел Николаевич Смирнов'),
    ('librarian.olga', 'Ольга Ивановна Кузнецова'),
    ('aleksei.orlov', 'Алексей Дмитриевич Орлов'),
    ('maria.sokolova', 'Мария Сергеевна Соколова')
) AS v(login, full_name)
JOIN "user" u ON u.login = v.login;

INSERT INTO legal_entity (user_id, organization_name, is_confirmed)
SELECT user_id, 'Университетская библиотека «Наука»', TRUE
FROM "user" WHERE login = 'library.uni';

-- 4. Трудовые договоры сотрудников
INSERT INTO employment_contract
    (employee_id, position, contract_text, start_date, end_date, salary, status)
VALUES
    (
        (SELECT user_id FROM "user" WHERE login = 'admin.library'),
        'Администратор', 'Тестовый трудовой договор администратора',
        current_date - INTERVAL '1 year', NULL, 85000, 'active'
    ),
    (
        (SELECT user_id FROM "user" WHERE login = 'librarian.olga'),
        'Библиотекарь', 'Тестовый трудовой договор библиотекаря',
        current_date - INTERVAL '6 months', NULL, 60000, 'active'
    );

-- 5. Читательские договоры: по одному для каждого читателя
INSERT INTO contract (user_id, contract_text, contract_duration_months)
VALUES
    ((SELECT user_id FROM "user" WHERE login = 'aleksei.orlov'),
     'Бесплатный договор читателя: Алексей Орлов', 12),
    ((SELECT user_id FROM "user" WHERE login = 'maria.sokolova'),
     'Бесплатный договор читателя: Мария Соколова', 12),
    ((SELECT user_id FROM "user" WHERE login = 'library.uni'),
     'Бесплатный договор читателя: университетская библиотека', NULL);

-- 6. Разделы и подраздел
INSERT INTO section (section_name, description, monthly_subscription_price) VALUES
    ('Программирование', 'Языки программирования и разработка ПО', 300),
    ('Базы данных', 'SQL, СУБД и проектирование баз данных', 200),
    ('Художественная литература', 'Проза и литературоведение', 180);

INSERT INTO section
    (section_name, description, parent_section_id, monthly_subscription_price)
VALUES (
    'Python', 'Книги и практикумы по Python',
    (SELECT section_id FROM section WHERE section_name = 'Программирование'), 150
);

-- 7. Авторы
INSERT INTO author (full_name, academic_degree, scientific_interests) VALUES
    ('Иванова Анна Сергеевна', NULL, 'Python, методика программирования'),
    ('Петров Максим Андреевич', NULL, 'SQL, реляционные базы данных'),
    ('Кузнецов Артём Игоревич', NULL, 'Алгоритмы, структуры данных'),
    ('Смирнова Елена Викторовна', NULL, 'История литературы');

-- 8. Издания
INSERT INTO publication (title, annotation, type, available_books_count) VALUES
    ('Основы Python', 'Введение в синтаксис языка Python', 'учебник', 12),
    ('Практика Python', 'Упражнения по программированию на Python', 'практикум', 9),
    ('Практика SQL', 'SQL-запросы и работа с данными', 'учебник', 15),
    ('Администрирование PostgreSQL', 'Основы сопровождения PostgreSQL', 'справочник', 6),
    ('Алгоритмы и структуры данных', 'Основные алгоритмы и структуры данных', 'учебник', 10),
    ('Русская литература: обзор', 'Краткий обзор русской литературы', 'монография', 3);

-- 9. Издания по разделам (связь M:N)
INSERT INTO section_publications (publication_id, section_id) VALUES
    ((SELECT publication_id FROM publication WHERE title = 'Основы Python'),
     (SELECT section_id FROM section WHERE section_name = 'Python')),
    ((SELECT publication_id FROM publication WHERE title = 'Практика Python'),
     (SELECT section_id FROM section WHERE section_name = 'Python')),
    ((SELECT publication_id FROM publication WHERE title = 'Практика SQL'),
     (SELECT section_id FROM section WHERE section_name = 'Базы данных')),
    ((SELECT publication_id FROM publication WHERE title = 'Администрирование PostgreSQL'),
     (SELECT section_id FROM section WHERE section_name = 'Базы данных')),
    ((SELECT publication_id FROM publication WHERE title = 'Алгоритмы и структуры данных'),
     (SELECT section_id FROM section WHERE section_name = 'Программирование')),
    ((SELECT publication_id FROM publication WHERE title = 'Русская литература: обзор'),
     (SELECT section_id FROM section WHERE section_name = 'Художественная литература'));

-- 10. Авторы изданий
INSERT INTO publication_authors (publication_id, author_id) VALUES
    ((SELECT publication_id FROM publication WHERE title = 'Основы Python'),
     (SELECT author_id FROM author WHERE full_name = 'Иванова Анна Сергеевна')),
    ((SELECT publication_id FROM publication WHERE title = 'Практика Python'),
     (SELECT author_id FROM author WHERE full_name = 'Иванова Анна Сергеевна')),
    ((SELECT publication_id FROM publication WHERE title = 'Практика Python'),
     (SELECT author_id FROM author WHERE full_name = 'Петров Максим Андреевич')),
    ((SELECT publication_id FROM publication WHERE title = 'Практика SQL'),
     (SELECT author_id FROM author WHERE full_name = 'Петров Максим Андреевич')),
    ((SELECT publication_id FROM publication WHERE title = 'Администрирование PostgreSQL'),
     (SELECT author_id FROM author WHERE full_name = 'Петров Максим Андреевич')),
    ((SELECT publication_id FROM publication WHERE title = 'Алгоритмы и структуры данных'),
     (SELECT author_id FROM author WHERE full_name = 'Кузнецов Артём Игоревич')),
    ((SELECT publication_id FROM publication WHERE title = 'Русская литература: обзор'),
     (SELECT author_id FROM author WHERE full_name = 'Смирнова Елена Викторовна'));

-- 11. Платёжные документы (плательщик и владелец договора совпадают)
INSERT INTO payment_document (user_id, contract_id, amount)
SELECT u.user_id, c.contract_id, v.amount
FROM (VALUES
    ('aleksei.orlov', 450),
    ('maria.sokolova', 1080),
    ('library.uni', 2880)
) AS v(login, amount)
JOIN "user" u ON u.login = v.login
JOIN contract c ON c.user_id = u.user_id;

-- 12. Подписки
INSERT INTO subscription (payment_document_id, term)
SELECT pd.document_id,
       (pd.payment_date + (v.months || ' months')::interval)::date
FROM (VALUES
    ('aleksei.orlov', 3),
    ('maria.sokolova', 6),
    ('library.uni', 12)
) AS v(login, months)
JOIN "user" u ON u.login = v.login
JOIN payment_document pd ON pd.user_id = u.user_id;

-- 13. Оплаченные разделы
INSERT INTO paid_sections (subscription_id, section_id)
SELECT s.subscription_id, sec.section_id
FROM (VALUES
    ('aleksei.orlov', 'Python'),
    ('maria.sokolova', 'Базы данных'),
    ('library.uni', 'Программирование')
) AS v(login, section_name)
JOIN "user" u ON u.login = v.login
JOIN payment_document pd ON pd.user_id = u.user_id
JOIN subscription s ON s.payment_document_id = pd.document_id
JOIN section sec ON sec.section_name = v.section_name;

-- 14. Запросы на выдачу книг
INSERT INTO publication_request
    (user_id, employment_contract_id, deadline,
     ordered_books_count, issued_books_count, returned_books_count, status)
VALUES (
    (SELECT user_id FROM "user" WHERE login = 'aleksei.orlov'),
    (SELECT ec.employment_contract_id
     FROM employment_contract ec JOIN "user" u ON ec.employee_id = u.user_id
     WHERE u.login = 'librarian.olga' AND ec.status = 'active'),
    current_date + 14, 3, 3, 1, 4
);

-- Мария: черновик
INSERT INTO publication_request
    (user_id, employment_contract_id, deadline,
     ordered_books_count, issued_books_count, returned_books_count, status)
VALUES (
    (SELECT user_id FROM "user" WHERE login = 'maria.sokolova'),
    NULL, current_date + 21, 1, 0, 0, 0
);
-- Организация отказ
INSERT INTO publication_request
    (user_id, employment_contract_id, deadline,
     ordered_books_count, issued_books_count, returned_books_count, status)
VALUES (
    (SELECT user_id FROM "user" WHERE login = 'library.uni'),
    (SELECT ec.employment_contract_id
     FROM employment_contract ec JOIN "user" u ON ec.employee_id = u.user_id
     WHERE u.login = 'librarian.olga' AND ec.status = 'active'),
    current_date + 7, 1, 0, 0, 2
);

-- 15. Состав заказов
INSERT INTO request_publications
    (request_id, publication_id, ordered_count, issued_count, returned_count)
VALUES
    (
        (SELECT pr.request_id FROM publication_request pr JOIN "user" u ON u.user_id = pr.user_id
         WHERE u.login = 'aleksei.orlov' AND pr.status = 4),
        (SELECT publication_id FROM publication WHERE title = 'Основы Python'), 2, 2, 1
    ),
    (
        (SELECT pr.request_id FROM publication_request pr JOIN "user" u ON u.user_id = pr.user_id
         WHERE u.login = 'aleksei.orlov' AND pr.status = 4),
        (SELECT publication_id FROM publication WHERE title = 'Практика Python'), 1, 1, 0
    ),
    (
        (SELECT pr.request_id FROM publication_request pr JOIN "user" u ON u.user_id = pr.user_id
         WHERE u.login = 'maria.sokolova' AND pr.status = 0),
        (SELECT publication_id FROM publication WHERE title = 'Практика SQL'), 1, 0, 0
    ),
    (
        (SELECT pr.request_id FROM publication_request pr JOIN "user" u ON u.user_id = pr.user_id
         WHERE u.login = 'library.uni' AND pr.status = 2),
        (SELECT publication_id FROM publication WHERE title = 'Русская литература: обзор'), 1, 0, 0
    );

-- 16. Отказ для заказа организации
INSERT INTO refusal (request_id)
SELECT pr.request_id
FROM publication_request pr
JOIN "user" u ON u.user_id = pr.user_id
WHERE u.login = 'library.uni' AND pr.status = 2;

INSERT INTO refused_publications (refusal_id, publication_id, refusal_reason)
SELECT r.refusal_id, p.publication_id, 'Нет подписки на раздел'
FROM refusal r
JOIN publication_request pr ON pr.request_id = r.request_id
JOIN "user" u ON u.user_id = pr.user_id
CROSS JOIN publication p
WHERE u.login = 'library.uni' AND p.title = 'Русская литература: обзор';

-- 17. Документ поступления
INSERT INTO arrival_document (employment_contract_id, new_books_count)
VALUES (
    (SELECT ec.employment_contract_id
     FROM employment_contract ec JOIN "user" u ON ec.employee_id = u.user_id
     WHERE u.login = 'librarian.olga' AND ec.status = 'active'),
    10
);

INSERT INTO new_publications (arrival_document_id, registration_number, new_books_count)
SELECT ad.arrival_document_id, p.publication_id, v.qty
FROM (VALUES
    ('Основы Python', 3),
    ('Практика SQL', 7)
) AS v(title, qty)
JOIN publication p ON p.title = v.title
CROSS JOIN arrival_document ad;

-- 18. Документ списания
INSERT INTO write_off_document (employment_contract_id, reason, written_off_books_count)
VALUES (
    (SELECT ec.employment_contract_id
     FROM employment_contract ec JOIN "user" u ON ec.employee_id = u.user_id
     WHERE u.login = 'librarian.olga' AND ec.status = 'active'),
    'Повреждение экземпляров', 2
);

INSERT INTO written_off_publications (write_off_document_id, publication_id, written_off_count)
SELECT wd.write_off_document_id, p.publication_id, 2
FROM write_off_document wd
CROSS JOIN publication p
WHERE p.title = 'Русская литература: обзор';

COMMIT;

-- Контроль наполнения
SELECT 'role' AS table_name, COUNT(*) AS row_count FROM role
UNION ALL SELECT 'user', COUNT(*) FROM "user"
UNION ALL SELECT 'physical_person', COUNT(*) FROM physical_person
UNION ALL SELECT 'legal_entity', COUNT(*) FROM legal_entity
UNION ALL SELECT 'employment_contract', COUNT(*) FROM employment_contract
UNION ALL SELECT 'contract', COUNT(*) FROM contract
UNION ALL SELECT 'section', COUNT(*) FROM section
UNION ALL SELECT 'author', COUNT(*) FROM author
UNION ALL SELECT 'publication', COUNT(*) FROM publication
UNION ALL SELECT 'section_publications', COUNT(*) FROM section_publications
UNION ALL SELECT 'publication_authors', COUNT(*) FROM publication_authors
UNION ALL SELECT 'payment_document', COUNT(*) FROM payment_document
UNION ALL SELECT 'subscription', COUNT(*) FROM subscription
UNION ALL SELECT 'paid_sections', COUNT(*) FROM paid_sections
UNION ALL SELECT 'publication_request', COUNT(*) FROM publication_request
UNION ALL SELECT 'request_publications', COUNT(*) FROM request_publications
UNION ALL SELECT 'refusal', COUNT(*) FROM refusal
UNION ALL SELECT 'refused_publications', COUNT(*) FROM refused_publications
UNION ALL SELECT 'arrival_document', COUNT(*) FROM arrival_document
UNION ALL SELECT 'new_publications', COUNT(*) FROM new_publications
UNION ALL SELECT 'write_off_document', COUNT(*) FROM write_off_document
UNION ALL SELECT 'written_off_publications', COUNT(*) FROM written_off_publications
ORDER BY table_name;
