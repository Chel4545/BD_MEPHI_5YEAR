-- Таблица Роль
CREATE TABLE role (
    code smallint PRIMARY KEY,
    name text NOT NULL UNIQUE
);

-- Таблица Пользователь
CREATE TABLE "user" (
    user_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_name text NOT NULL,
    login text NOT NULL UNIQUE,
    password text NOT NULL,
    role_code smallint NOT NULL,
    registration_date date NOT NULL DEFAULT current_date,
    admin_id int,
	user_type text NOT NULL,
    CONSTRAINT chk_user_type
        CHECK (user_type IN ('physical', 'legal')),
    CONSTRAINT fk_user_role 
		FOREIGN KEY (role_code) REFERENCES role(code)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_user_admin
	    FOREIGN KEY (admin_id) REFERENCES "user"(user_id)
	    ON DELETE SET NULL
	    ON UPDATE CASCADE
);

-- Физическое лицо (зависимая сущность от Пользователя)
CREATE TABLE physical_person (
    user_id int PRIMARY KEY,
    full_name text NOT NULL,
    CONSTRAINT fk_physical_person_user
        FOREIGN KEY (user_id) REFERENCES "user"(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Юридическое лицо (зависимая сущность от Пользователя)
CREATE TABLE legal_entity (
    user_id int PRIMARY KEY,
    organization_name text NOT NULL,
    is_confirmed boolean NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_legal_entity_user
        FOREIGN KEY (user_id) REFERENCES "user"(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Трудовой договор (сотрудник — физическое лицо)
CREATE TABLE employment_contract (
    employment_contract_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_id int NOT NULL,
    position text NOT NULL,
    contract_text text NOT NULL,
    start_date date NOT NULL,
    end_date date,
    salary int NOT NULL CHECK (salary > 0),
    status text NOT NULL,
    CONSTRAINT chk_employment_contract_dates
        CHECK (end_date IS NULL OR end_date >= start_date),
    CONSTRAINT chk_employment_contract_status
        CHECK (status IN ('active', 'suspended', 'terminated')),
    CONSTRAINT fk_employment_contract_person
        FOREIGN KEY (employee_id) REFERENCES physical_person(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Договор
CREATE TABLE contract (
    contract_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id int NOT NULL,
    contract_text text NOT NULL,
    contract_date date NOT NULL DEFAULT current_date,
    contract_duration_months int CHECK (contract_duration_months > 0),
    CONSTRAINT fk_contract_user FOREIGN KEY (user_id) REFERENCES "user"(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Платежный документ
CREATE TABLE payment_document (
    document_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id int NOT NULL,
    contract_id int NOT NULL,
    payment_date date NOT NULL DEFAULT current_date,
    amount int NOT NULL CHECK (amount >= 0),
    CONSTRAINT fk_payment_user FOREIGN KEY (user_id) REFERENCES "user"(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_payment_contract FOREIGN KEY (contract_id) REFERENCES contract(contract_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Подписка
CREATE TABLE subscription (
    subscription_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    payment_document_id int NOT NULL,
    term date NOT NULL,
    CONSTRAINT fk_subscription_payment FOREIGN KEY (payment_document_id) REFERENCES payment_document(document_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Раздел
CREATE TABLE section (
    section_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    section_name text NOT NULL UNIQUE,
    description text,
    parent_section_id int,
    monthly_subscription_price int NOT NULL CHECK (monthly_subscription_price >= 0),
    CONSTRAINT fk_section_parent FOREIGN KEY (parent_section_id) REFERENCES section(section_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT uq_section_name_per_parent UNIQUE (parent_section_id, section_name),
    CONSTRAINT chk_not_self_parent CHECK (parent_section_id IS NULL OR parent_section_id <> section_id)
);

-- Таблица Оплачиваемые разделы (связующая таблица)
CREATE TABLE paid_sections (
    subscription_id int NOT NULL,
    section_id int NOT NULL,
    PRIMARY KEY (subscription_id, section_id),
    CONSTRAINT fk_paid_sections_subscription FOREIGN KEY (subscription_id) REFERENCES subscription(subscription_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_paid_sections_section FOREIGN KEY (section_id) REFERENCES section(section_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Издание
CREATE TABLE publication (
    publication_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title text NOT NULL,
    annotation text,
    type text NOT NULL,
    available_books_count int NOT NULL CHECK (available_books_count >= 0)
);

-- Таблица Издания раздела (связующая таблица)
CREATE TABLE section_publications (
    publication_id int NOT NULL,
    section_id int NOT NULL,
    PRIMARY KEY (publication_id, section_id),
    CONSTRAINT fk_section_publications_publication FOREIGN KEY (publication_id) REFERENCES publication(publication_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_section_publications_section FOREIGN KEY (section_id) REFERENCES section(section_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Автор
CREATE TABLE author (
    author_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name text NOT NULL,
    academic_degree smallint,
    scientific_interests text
);

-- Таблица Издание автора (связующая таблица)
CREATE TABLE publication_authors (
    publication_id int NOT NULL,
    author_id int NOT NULL,
    PRIMARY KEY (publication_id, author_id),
    CONSTRAINT fk_publication_authors_publication FOREIGN KEY (publication_id) REFERENCES publication(publication_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_publication_authors_author FOREIGN KEY (author_id) REFERENCES author(author_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Запрос на издания
CREATE TABLE publication_request (
    request_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id int NOT NULL,
    employment_contract_id int,
    request_date date NOT NULL DEFAULT current_date,
    deadline date NOT NULL,
    ordered_books_count int NOT NULL DEFAULT 0 CHECK (ordered_books_count >= 0),
    issued_books_count int NOT NULL DEFAULT 0 CHECK (issued_books_count >= 0),
    returned_books_count int NOT NULL DEFAULT 0 CHECK (returned_books_count >= 0),
    status int NOT NULL,
    CONSTRAINT fk_request_user FOREIGN KEY (user_id) REFERENCES "user"(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_request_employment_contract
        FOREIGN KEY (employment_contract_id) REFERENCES employment_contract(employment_contract_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_request_deadline
        CHECK (deadline >= request_date),
    CONSTRAINT chk_request_book_counts
        CHECK (returned_books_count <= issued_books_count
           AND issued_books_count <= ordered_books_count)
);

-- Таблица Отказ
CREATE TABLE refusal (
    refusal_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    request_id int NOT NULL,
    CONSTRAINT fk_refusal_request FOREIGN KEY (request_id) REFERENCES publication_request(request_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Таблица Издания в заказе
CREATE TABLE request_publications (
    request_id int NOT NULL,
    publication_id int NOT NULL,
    ordered_count int NOT NULL DEFAULT 0 CHECK (ordered_count >= 0),
    issued_count int NOT NULL DEFAULT 0 CHECK (issued_count >= 0),
    returned_count int NOT NULL DEFAULT 0 CHECK (returned_count >= 0),
    PRIMARY KEY (request_id, publication_id),
    CONSTRAINT fk_request_publications_request FOREIGN KEY (request_id) REFERENCES publication_request(request_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_request_publications_publication FOREIGN KEY (publication_id) REFERENCES publication(publication_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
	CONSTRAINT chk_request_publication_counts
		CHECK (
		    returned_count <= issued_count
		    AND issued_count <= ordered_count
		)
);

-- Таблица Отказанные издания в заказе
CREATE TABLE refused_publications (
    refusal_id int NOT NULL,
    publication_id int NOT NULL,
    refusal_reason text NOT NULL,
    PRIMARY KEY (refusal_id, publication_id),
    CONSTRAINT fk_refused_publications_refusal FOREIGN KEY (refusal_id) REFERENCES refusal(refusal_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_refused_publications_publication FOREIGN KEY (publication_id) REFERENCES publication(publication_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Документ поступления
CREATE TABLE arrival_document (
    arrival_document_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employment_contract_id int NOT NULL,
    arrival_date date NOT NULL DEFAULT current_date,
    new_books_count int NOT NULL CHECK (new_books_count >= 0),
    CONSTRAINT fk_arrival_employment_contract
        FOREIGN KEY (employment_contract_id) REFERENCES employment_contract(employment_contract_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Документ списания
CREATE TABLE write_off_document (
    write_off_document_id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employment_contract_id int NOT NULL,
    write_off_date date NOT NULL DEFAULT current_date,
    reason text NOT NULL,
    written_off_books_count int NOT NULL CHECK (written_off_books_count >= 0),
    CONSTRAINT fk_write_off_employment_contract
        FOREIGN KEY (employment_contract_id) REFERENCES employment_contract(employment_contract_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Списанные издания
CREATE TABLE written_off_publications (
    write_off_document_id int NOT NULL,
    publication_id int NOT NULL,
    written_off_count int NOT NULL DEFAULT 0 CHECK (written_off_count >= 0),
    PRIMARY KEY (write_off_document_id, publication_id),
    CONSTRAINT fk_written_off_document FOREIGN KEY (write_off_document_id) REFERENCES write_off_document(write_off_document_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_written_off_publication FOREIGN KEY (publication_id) REFERENCES publication(publication_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- Таблица Новые издания
CREATE TABLE new_publications (
    arrival_document_id int NOT NULL,
    registration_number int NOT NULL,
    new_books_count int NOT NULL DEFAULT 0 CHECK (new_books_count >= 0),
    PRIMARY KEY (arrival_document_id, registration_number),
    CONSTRAINT fk_new_publications_document FOREIGN KEY (arrival_document_id) REFERENCES arrival_document(arrival_document_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_new_publications_publication FOREIGN KEY (registration_number) REFERENCES publication(publication_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);