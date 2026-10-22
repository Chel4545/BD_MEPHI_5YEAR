"""Генератор тестовых данных для электронной библиотеки (вариант 31).

Одна функция = одна таблица. Данные для генерации лежат внутри её функции.
Перед запуском создайте 22 таблицы (с GENERATED ALWAYS AS IDENTITY).
Установка: pip install psycopg2-binary
Запуск: python generate_data.py

Программа ДОБАВЛЯЕТ строки, а не удаляет существующие данные.
"""

import os
import random
from datetime import date, datetime, timedelta
from getpass import getpass

import psycopg2


# Настройки подключения к PostgreSQL
DB_NAME = "BD_LAB"
DB_USER = "postgres"
DB_HOST = "localhost"
DB_PORT = 5432


# 1. Роли
# Если роли уже добавлены через 02_seed.sql, повторно их не создаём.
def generate_role(cursor, data):
    roles = [
        (1, "Читатель"),
        (2, "Библиотекарь"),
        (3, "Администратор"),
    ]

    for code, name in roles:
        cursor.execute(
            "INSERT INTO role (code, name) VALUES (%s, %s) "
            "ON CONFLICT (code) DO NOTHING",
            (code, name),
        )


# 2. Пользователи
# Создаём одного библиотекаря и 200 читателей.
def generate_user(cursor, data):
    readers_count = 200
    run_id = data["run_id"]

    cursor.execute(
        'INSERT INTO "user" (account_name, login, password, role_code, user_type) '
        'VALUES (%s, %s, %s, %s, %s) RETURNING user_id',
        ("Тестовый библиотекарь", "librarian_" + run_id,
         "TEST_PASSWORD_NOT_FOR_LOGIN", 2, "physical"),
    )
    data["librarian_id"] = cursor.fetchone()[0]

    data["readers"] = []

    for i in range(readers_count):
        number = i + 1
        user_type = "legal" if i % 8 == 0 else "physical"
        login = "reader_" + run_id + "_" + str(number)

        cursor.execute(
            'INSERT INTO "user" (account_name, login, password, role_code, user_type) '
            'VALUES (%s, %s, %s, %s, %s) RETURNING user_id',
            ("Тестовый читатель " + str(number), login,
             "TEST_PASSWORD_NOT_FOR_LOGIN", 1, user_type),
        )
        user_id = cursor.fetchone()[0]
        data["readers"].append((user_id, user_type, number))


# 3. Физические лица
# Все ФИО задаются прямо здесь.
def generate_physical_person(cursor, data):
    surnames = ["Иванов", "Петров", "Смирнов", "Кузнецов", "Орлов",
                "Соколов", "Волков", "Попов", "Морозов", "Фёдоров"]
    names = ["Иван", "Пётр", "Алексей", "Дмитрий", "Николай",
             "Павел", "Максим", "Андрей"]
    patronymics = ["Иванович", "Петрович", "Алексеевич", "Дмитриевич"]

    cursor.execute(
        "INSERT INTO physical_person (user_id, full_name) VALUES (%s, %s)",
        (data["librarian_id"], "Ольга Ивановна Кузнецова"),
    )

    for user_id, user_type, number in data["readers"]:
        if user_type == "physical":
            full_name = (random.choice(surnames) + " "
                         + random.choice(names) + " "
                         + random.choice(patronymics))
            cursor.execute(
                "INSERT INTO physical_person (user_id, full_name) VALUES (%s, %s)",
                (user_id, full_name),
            )


# 4. Юридические лица
def generate_legal_entity(cursor, data):
    organization_prefixes = [
        "Учебный центр", "Университет", "Научная библиотека", "Институт"
    ]

    for user_id, user_type, number in data["readers"]:
        if user_type == "legal":
            name = random.choice(organization_prefixes) + " №" + str(number)
            cursor.execute(
                "INSERT INTO legal_entity (user_id, organization_name, is_confirmed) "
                "VALUES (%s, %s, %s)",
                (user_id, name, True),
            )


# 5. Трудовые договоры
def generate_employment_contract(cursor, data):
    position = "Библиотекарь"
    contract_text = "Тестовый трудовой договор библиотекаря"
    salary = 60000
    start_date = date.today() - timedelta(days=365)

    cursor.execute(
        "INSERT INTO employment_contract "
        "(employee_id, position, contract_text, start_date, salary, status) "
        "VALUES (%s, %s, %s, %s, %s, %s) RETURNING employment_contract_id",
        (data["librarian_id"], position, contract_text,
         start_date, salary, "active"),
    )
    data["employment_id"] = cursor.fetchone()[0]


# 6. Читательские договоры
def generate_contract(cursor, data):
    contract_text = "Бесплатный договор читателя"
    duration_months = 12
    data["contracts"] = {}

    for user_id, user_type, number in data["readers"]:
        cursor.execute(
            "INSERT INTO contract (user_id, contract_text, contract_duration_months) "
            "VALUES (%s, %s, %s) RETURNING contract_id",
            (user_id, contract_text, duration_months),
        )
        data["contracts"][user_id] = cursor.fetchone()[0]


# 7. Платёжные документы
# Скидки: на 3 месяца — 0%, на 6 — 10%, на 12 — 20%.
def generate_payment_document(cursor, data):
    possible_months = [3, 6, 12]
    discounts = {3: 0, 6: 10, 12: 20}
    data["payments"] = []
    sections = data["sections"]

    for i, (user_id, user_type, number) in enumerate(data["readers"]):
        section_id = sections[i % len(sections)]
        price = data["prices"][section_id]
        months = random.choice(possible_months)
        amount = price * months * (100 - discounts[months]) // 100

        cursor.execute(
            "INSERT INTO payment_document (user_id, contract_id, amount) "
            "VALUES (%s, %s, %s) RETURNING document_id",
            (user_id, data["contracts"][user_id], amount),
        )
        document_id = cursor.fetchone()[0]
        data["payments"].append((document_id, user_id, section_id, months))


# 8. Подписки
def generate_subscription(cursor, data):
    data["subscriptions"] = []

    for document_id, user_id, section_id, months in data["payments"]:
        cursor.execute(
            "INSERT INTO subscription (payment_document_id, term) "
            "VALUES (%s, (current_date + %s * INTERVAL '1 month')::date) "
            "RETURNING subscription_id",
            (document_id, months),
        )
        subscription_id = cursor.fetchone()[0]
        data["subscriptions"].append((subscription_id, user_id, section_id))


# 9. Разделы и подразделы
def generate_section(cursor, data):
    sections = [
        ("Программирование", 300),
        ("Python", 150),
        ("Базы данных", 200),
        ("Литература", 180),
    ]

    data["sections"] = []
    data["prices"] = {}
    run_id = data["run_id"]

    for name, price in sections:
        parent_id = None
        if name == "Python":
            parent_id = data["parent_section_id"]

        cursor.execute(
            "INSERT INTO section "
            "(section_name, parent_section_id, monthly_subscription_price) "
            "VALUES (%s, %s, %s) RETURNING section_id",
            (name + " " + run_id, parent_id, price),
        )
        section_id = cursor.fetchone()[0]
        data["sections"].append(section_id)
        data["prices"][section_id] = price

        if name == "Программирование":
            data["parent_section_id"] = section_id
        if name == "Python":
            data["python_section_id"] = section_id


# 10. Оплаченные разделы
def generate_paid_sections(cursor, data):
    data["reader_sections"] = []

    for subscription_id, user_id, section_id in data["subscriptions"]:
        cursor.execute(
            "INSERT INTO paid_sections (subscription_id, section_id) "
            "VALUES (%s, %s)",
            (subscription_id, section_id),
        )
        data["reader_sections"].append((user_id, section_id))


# 11. Издания
def generate_publication(cursor, data):
    books_count = 300
    types = ["учебник", "практикум", "справочник", "монография"]
    book_names = ["Основы программирования", "Практика Python", "Базы данных",
                  "Алгоритмы", "История литературы", "Разработка приложений"]

    data["book_ids"] = []
    data["books_by_section"] = {}
    data["stock"] = {}
    data["book_sections"] = {}
    sections = data["sections"]

    for section_id in sections:
        data["books_by_section"][section_id] = []

    for i in range(books_count):
        section_id = sections[i % len(sections)]
        quantity = random.randint(15, 30)
        title = (random.choice(book_names) + " №" + str(i + 1)
                 + " (" + data["run_id"] + ")")

        cursor.execute(
            "INSERT INTO publication (title, annotation, type, available_books_count) "
            "VALUES (%s, %s, %s, %s) RETURNING publication_id",
            (title, "Тестовое издание для лабораторной работы",
             random.choice(types), quantity),
        )
        book_id = cursor.fetchone()[0]
        data["book_ids"].append(book_id)
        data["books_by_section"][section_id].append(book_id)
        data["stock"][book_id] = quantity
        data["book_sections"][book_id] = section_id


# 12. Издания раздела (связующая таблица)
def generate_section_publications(cursor, data):
    for book_id in data["book_ids"]:
        section_id = data["book_sections"][book_id]
        cursor.execute(
            "INSERT INTO section_publications (publication_id, section_id) "
            "VALUES (%s, %s)",
            (book_id, section_id),
        )


# 13. Авторы
def generate_author(cursor, data):
    authors_count = 80
    surnames = ["Иванов", "Петров", "Смирнов", "Орлов", "Соколов",
                "Кузнецов", "Волков", "Морозов"]
    names = ["Алексей", "Иван", "Дмитрий", "Максим", "Пётр", "Павел"]
    patronymics = ["Иванович", "Петрович", "Алексеевич", "Дмитриевич"]
    interests = ["Программирование", "Базы данных", "Математика", "Литература"]

    data["author_ids"] = []

    for i in range(authors_count):
        full_name = (random.choice(surnames) + " "
                     + random.choice(names) + " "
                     + random.choice(patronymics))
        cursor.execute(
            "INSERT INTO author (full_name, scientific_interests) "
            "VALUES (%s, %s) RETURNING author_id",
            (full_name, random.choice(interests)),
        )
        data["author_ids"].append(cursor.fetchone()[0])


# 14. Авторы изданий (связующая таблица)
def generate_publication_authors(cursor, data):
    for book_id in data["book_ids"]:
        author_id = random.choice(data["author_ids"])
        cursor.execute(
            "INSERT INTO publication_authors (publication_id, author_id) "
            "VALUES (%s, %s)",
            (book_id, author_id),
        )


# 15. Запросы на выдачу книг
def generate_publication_request(cursor, data):
    requests_count = 400
    statuses = [0, 2, 3, 4, 4, 5]
    data["requests"] = []

    for i in range(requests_count):
        user_id, section_id = random.choice(data["reader_sections"])
        status = random.choice(statuses)

        # Если отказ — выбираем книгу из неоплаченного раздела.
        if status == 2:
            candidates = []
            for another_section in data["sections"]:
                if another_section == section_id:
                    continue
                if (section_id == data["parent_section_id"]
                        and another_section == data["python_section_id"]):
                    continue
                candidates.extend(data["books_by_section"][another_section])
        else:
            candidates = data["books_by_section"][section_id]

        if status in (4, 5):
            candidates = [book for book in candidates if data["stock"][book] > 0]

        if not candidates:
            raise ValueError("Нет книг для заказа №" + str(i + 1))

        number_of_titles = min(random.randint(1, 3), len(candidates))
        chosen_books = random.sample(candidates, number_of_titles)
        lines = []
        ordered_total = 0
        issued_total = 0
        returned_total = 0

        for index, book_id in enumerate(chosen_books):
            ordered = random.randint(1, 3)
            issued = 0
            returned = 0

            if status in (4, 5):
                ordered = min(ordered, data["stock"][book_id])
                issued = ordered

                if status == 5:
                    returned = issued
                elif index == 0:
                    returned = random.randint(0, issued - 1)
                else:
                    returned = random.randint(0, issued)

                data["stock"][book_id] -= issued - returned

            ordered_total += ordered
            issued_total += issued
            returned_total += returned
            lines.append((book_id, ordered, issued, returned))

        employee_id = None if status == 0 else data["employment_id"]
        deadline = date.today() + timedelta(days=random.randint(7, 30))

        cursor.execute(
            "INSERT INTO publication_request "
            "(user_id, employment_contract_id, deadline, ordered_books_count, "
            "issued_books_count, returned_books_count, status) "
            "VALUES (%s, %s, %s, %s, %s, %s, %s) RETURNING request_id",
            (user_id, employee_id, deadline, ordered_total,
             issued_total, returned_total, status),
        )
        request_id = cursor.fetchone()[0]
        data["requests"].append((request_id, status, lines))


# 16. Отказы
def generate_refusal(cursor, data):
    data["refusals"] = []

    for request_id, status, lines in data["requests"]:
        if status == 2:
            cursor.execute(
                "INSERT INTO refusal (request_id) VALUES (%s) RETURNING refusal_id",
                (request_id,),
            )
            refusal_id = cursor.fetchone()[0]
            data["refusals"].append((refusal_id, lines))


# 17. Издания в заказе (связующая таблица)
def generate_request_publications(cursor, data):
    for request_id, status, lines in data["requests"]:
        for book_id, ordered, issued, returned in lines:
            cursor.execute(
                "INSERT INTO request_publications "
                "(request_id, publication_id, ordered_count, issued_count, returned_count) "
                "VALUES (%s, %s, %s, %s, %s)",
                (request_id, book_id, ordered, issued, returned),
            )


# 18. Отказанные издания (связующая таблица)
def generate_refused_publications(cursor, data):
    reason = "Нет подписки на раздел"

    for refusal_id, lines in data["refusals"]:
        for book_id, ordered, issued, returned in lines:
            cursor.execute(
                "INSERT INTO refused_publications "
                "(refusal_id, publication_id, refusal_reason) VALUES (%s, %s, %s)",
                (refusal_id, book_id, reason),
            )


# 19. Документы поступления
def generate_arrival_document(cursor, data):
    documents_count = 5
    titles_per_document = 5
    data["arrivals"] = []

    for i in range(documents_count):
        book_ids = random.sample(data["book_ids"], titles_per_document)
        lines = []

        for book_id in book_ids:
            quantity = random.randint(1, 3)
            lines.append((book_id, quantity))

        total = sum(quantity for book_id, quantity in lines)
        cursor.execute(
            "INSERT INTO arrival_document (employment_contract_id, new_books_count) "
            "VALUES (%s, %s) RETURNING arrival_document_id",
            (data["employment_id"], total),
        )
        arrival_id = cursor.fetchone()[0]
        data["arrivals"].append((arrival_id, lines))


# 20. Документы списания
def generate_write_off_document(cursor, data):
    documents_count = 5
    titles_per_document = 5
    reason = "Повреждение экземпляров"
    data["write_offs"] = []

    # Резервируем списываемые экземпляры, чтобы не списать лишнего.
    available = data["stock"].copy()

    for i in range(documents_count):
        eligible = [book_id for book_id in data["book_ids"] if available[book_id] >= 2]
        if len(eligible) < titles_per_document:
            raise ValueError("Недостаточно экземпляров для списания")

        book_ids = random.sample(eligible, titles_per_document)
        lines = []

        for book_id in book_ids:
            quantity = random.randint(1, 2)
            lines.append((book_id, quantity))
            available[book_id] -= quantity

        total = sum(quantity for book_id, quantity in lines)
        cursor.execute(
            "INSERT INTO write_off_document "
            "(employment_contract_id, reason, written_off_books_count) "
            "VALUES (%s, %s, %s) RETURNING write_off_document_id",
            (data["employment_id"], reason, total),
        )
        write_off_id = cursor.fetchone()[0]
        data["write_offs"].append((write_off_id, lines))


# 21. Списанные издания (связующая таблица)
def generate_written_off_publications(cursor, data):
    for write_off_id, lines in data["write_offs"]:
        for book_id, quantity in lines:
            cursor.execute(
                "INSERT INTO written_off_publications "
                "(write_off_document_id, publication_id, written_off_count) "
                "VALUES (%s, %s, %s)",
                (write_off_id, book_id, quantity),
            )
            data["stock"][book_id] -= quantity


# 22. Поступившие издания (связующая таблица)
def generate_new_publications(cursor, data):
    for arrival_id, lines in data["arrivals"]:
        for book_id, quantity in lines:
            cursor.execute(
                "INSERT INTO new_publications "
                "(arrival_document_id, registration_number, new_books_count) "
                "VALUES (%s, %s, %s)",
                (arrival_id, book_id, quantity),
            )
            data["stock"][book_id] += quantity


# После операций с книгами обновляем их остатки в publication.
def update_book_counts(cursor, data):
    for book_id, quantity in data["stock"].items():
        cursor.execute(
            "UPDATE publication SET available_books_count = %s "
            "WHERE publication_id = %s",
            (quantity, book_id),
        )


# Запускаем функции в порядке, который учитывает внешние ключи.
def main():

    random.seed(42)
    data = {"run_id": datetime.now().strftime("%Y%m%d_%H%M%S_%f")}
    password = "4545"

    connection = psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=password,
        host=DB_HOST,
        port=DB_PORT,
    )
    cursor = connection.cursor()

    try:
        generate_role(cursor, data)
        generate_user(cursor, data)
        generate_physical_person(cursor, data)
        generate_legal_entity(cursor, data)
        generate_employment_contract(cursor, data)
        generate_section(cursor, data)
        generate_author(cursor, data)
        generate_publication(cursor, data)
        generate_section_publications(cursor, data)
        generate_publication_authors(cursor, data)
        generate_contract(cursor, data)
        generate_payment_document(cursor, data)
        generate_subscription(cursor, data)
        generate_paid_sections(cursor, data)
        generate_publication_request(cursor, data)
        generate_request_publications(cursor, data)
        generate_refusal(cursor, data)
        generate_refused_publications(cursor, data)
        generate_arrival_document(cursor, data)
        generate_new_publications(cursor, data)
        generate_write_off_document(cursor, data)
        generate_written_off_publications(cursor, data)
        update_book_counts(cursor, data)

        connection.commit()
        print("Данные успешно добавлены!")
        print("Читателей:", len(data["readers"]))
        print("Авторов:", len(data["author_ids"]))
        print("Изданий:", len(data["book_ids"]))
        print("Заказов:", len(data["requests"]))
        print("Поступлений:", len(data["arrivals"]))
        print("Списаний:", len(data["write_offs"]))
    except Exception:
        connection.rollback()
        raise
    finally:
        cursor.close()
        connection.close()


if __name__ == "__main__":
    main()
