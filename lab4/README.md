# Электронная библиотека eLibrary

Учебная база данных PostgreSQL (вариант №31). Содержит 22 таблицы для хранения пользователей, книг, подписок, заказов, поступлений и списаний.

## Требования

- PostgreSQL 18 и pgAdmin 4
- Python 3
- Библиотека `psycopg2-binary`

```bash
pip install psycopg2-binary
```

## Первоначальный запуск

1. В pgAdmin подключиться к серверу PostgreSQL 18 и создать базу данных `BD_LAB`.
2. Открыть **Query Tool** для базы `BD_LAB` и выполнить `CREATE_SQL.sql` — создание таблиц.
3. В том же Query Tool выполнить `02_seed.sql` — добавление начальных данных.
4. В `generate_data.py` проверить параметры подключения (`DB_NAME`, `DB_USER`, `DB_HOST`, `DB_PORT`) и указать пароль PostgreSQL.
5. Запустить генератор из папки проекта:

```bash
python generate_data.py
```

## Пересоздание базы данных

1. В pgAdmin закрыть подключения и вкладки Query Tool, использующие `BD_LAB`.
2. Удалить базу `BD_LAB` через контекстное меню **Delete/Drop** (при необходимости сначала отключить активные сеансы).
3. Создать новую базу с тем же именем `BD_LAB`.
4. Повторить шаги первоначального запуска: `CREATE_SQL.sql` → `02_seed.sql` → `generate_data.py`.

## Проверка

В Query Tool базы `BD_LAB` выполнить:

```sql
SELECT COUNT(*) FROM "user";
SELECT COUNT(*) FROM publication;
SELECT COUNT(*) FROM publication_request;
```

**Примечание:** `generate_data.py` добавляет новые записи, а не очищает таблицы. Повторный запуск увеличит объём данных.
