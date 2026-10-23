CREATE DATABASE hospital_er;
\c hospital_er;

-- 1. Пациенты
CREATE TABLE patient (
    patient_id       SERIAL PRIMARY KEY,
    full_name        VARCHAR(200) NOT NULL,
    birth_date       DATE NOT NULL,
    gender           CHAR(1) CHECK (gender IN ('M', 'F', 'O')),
    policy_number    VARCHAR(50) UNIQUE NOT NULL,
    phone            VARCHAR(20),
    created_at       TIMESTAMP NOT NULL DEFAULT now()
);

-- 2. Врачи
CREATE TABLE doctor (
    doctor_id        SERIAL PRIMARY KEY,
    full_name        VARCHAR(200) NOT NULL,
    specialty        VARCHAR(100) NOT NULL,
    license_number   VARCHAR(50) UNIQUE NOT NULL
);

-- 3. Отделения
CREATE TABLE department (
    department_id    SERIAL PRIMARY KEY,
    name             VARCHAR(100) NOT NULL UNIQUE
);

-- 4. Обращения (визиты)
CREATE TABLE visit (
    visit_id         SERIAL PRIMARY KEY,
    patient_id       INT NOT NULL REFERENCES patient(patient_id),
    doctor_id        INT NOT NULL REFERENCES doctor(doctor_id),
    department_id    INT NOT NULL REFERENCES department(department_id),
    arrival_time     TIMESTAMP NOT NULL,
    triage_level     SMALLINT NOT NULL CHECK (triage_level BETWEEN 1 AND 5),
    chief_complaint  TEXT,
    discharge_time   TIMESTAMP,
    outcome          VARCHAR(20) CHECK (outcome IN ('discharged','admitted','transferred','deceased')),
    CONSTRAINT chk_discharge CHECK (discharge_time IS NULL OR discharge_time >= arrival_time)
);

-- 5. Диагнозы
CREATE TABLE diagnosis (
    diagnosis_id     SERIAL PRIMARY KEY,
    visit_id         INT NOT NULL REFERENCES visit(visit_id) ON DELETE CASCADE,
    icd_code         VARCHAR(10) NOT NULL,
    description      TEXT,
    diagnosed_at     TIMESTAMP NOT NULL DEFAULT now()
);

-- 6. Витальные показатели
CREATE TABLE vital_sign (
    vital_id            SERIAL PRIMARY KEY,
    visit_id            INT NOT NULL REFERENCES visit(visit_id) ON DELETE CASCADE,
    measured_at         TIMESTAMP NOT NULL DEFAULT now(),
    temperature         NUMERIC(4,1),
    systolic_bp         SMALLINT,
    diastolic_bp        SMALLINT,
    heart_rate          SMALLINT,
    respiratory_rate    SMALLINT,
    oxygen_saturation   SMALLINT CHECK (oxygen_saturation BETWEEN 0 AND 100)
);

-- Индексы для типовых запросов
CREATE INDEX idx_visit_patient ON visit(patient_id);
CREATE INDEX idx_visit_arrival ON visit(arrival_time);
CREATE INDEX idx_vital_visit ON vital_sign(visit_id);
CREATE INDEX idx_diagnosis_visit ON diagnosis(visit_id);

CREATE TABLE hub_patient (
    hub_patient_key  BIGSERIAL PRIMARY KEY,
    patient_bk       VARCHAR(50) NOT NULL UNIQUE,  -- policy_number
    load_date        TIMESTAMP NOT NULL DEFAULT now(),
    record_source    VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM'
);

CREATE TABLE hub_doctor (
    hub_doctor_key   BIGSERIAL PRIMARY KEY,
    doctor_bk        VARCHAR(50) NOT NULL UNIQUE,  -- license_number
    load_date        TIMESTAMP NOT NULL DEFAULT now(),
    record_source    VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM'
);

CREATE TABLE hub_department (
    hub_department_key BIGSERIAL PRIMARY KEY,
    department_bk      VARCHAR(100) NOT NULL UNIQUE,  -- name
    load_date          TIMESTAMP NOT NULL DEFAULT now(),
    record_source      VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM'
);

CREATE TABLE hub_visit (
    hub_visit_key    BIGSERIAL PRIMARY KEY,
    visit_bk         VARCHAR(50) NOT NULL UNIQUE,  -- внешний номер обращения
    load_date        TIMESTAMP NOT NULL DEFAULT now(),
    record_source    VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM'
);
CREATE TABLE link_visit_patient_doctor (
    link_visit_key   BIGSERIAL PRIMARY KEY,
    hub_visit_key    BIGINT NOT NULL REFERENCES hub_visit(hub_visit_key),
    hub_patient_key  BIGINT NOT NULL REFERENCES hub_patient(hub_patient_key),
    hub_doctor_key   BIGINT NOT NULL REFERENCES hub_doctor(hub_doctor_key),
    load_date        TIMESTAMP NOT NULL DEFAULT now(),
    record_source    VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM',
    UNIQUE (hub_visit_key, hub_patient_key, hub_doctor_key)
);

CREATE TABLE sat_patient (
    sat_patient_key  BIGSERIAL PRIMARY KEY,
    hub_patient_key  BIGINT NOT NULL REFERENCES hub_patient(hub_patient_key),
    full_name        VARCHAR(200),
    birth_date       DATE,
    gender           CHAR(1),
    phone            VARCHAR(20),
    hash_diff        VARCHAR(64) NOT NULL,  -- MD5 от конкатенации атрибутов
    load_date        TIMESTAMP NOT NULL DEFAULT now(),
    load_end_date    TIMESTAMP,             -- NULL = текущая версия
    record_source    VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM'
);
CREATE INDEX idx_sat_patient_current ON sat_patient(hub_patient_key) WHERE load_end_date IS NULL;

CREATE TABLE sat_doctor (
    sat_doctor_key   BIGSERIAL PRIMARY KEY,
    hub_doctor_key   BIGINT NOT NULL REFERENCES hub_doctor(hub_doctor_key),
    full_name        VARCHAR(200),
    specialty        VARCHAR(100),
    hash_diff        VARCHAR(64) NOT NULL,
    load_date        TIMESTAMP NOT NULL DEFAULT now(),
    load_end_date    TIMESTAMP,
    record_source    VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM'
);

CREATE TABLE sat_visit (
    sat_visit_key    BIGSERIAL PRIMARY KEY,
    hub_visit_key    BIGINT NOT NULL REFERENCES hub_visit(hub_visit_key),
    arrival_time     TIMESTAMP,
    triage_level     SMALLINT,
    chief_complaint  TEXT,
    discharge_time   TIMESTAMP,
    outcome          VARCHAR(20),
    hash_diff        VARCHAR(64) NOT NULL,
    load_date        TIMESTAMP NOT NULL DEFAULT now(),
    load_end_date    TIMESTAMP,
    record_source    VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM'
);
CREATE INDEX idx_sat_visit_current ON sat_visit(hub_visit_key) WHERE load_end_date IS NULL;

CREATE TABLE sat_vital (
    sat_vital_key     BIGSERIAL PRIMARY KEY,
    link_visit_key    BIGINT NOT NULL REFERENCES link_visit_patient_doctor(link_visit_key),
    measured_at       TIMESTAMP NOT NULL,
    temperature       NUMERIC(4,1),
    systolic_bp       SMALLINT,
    diastolic_bp      SMALLINT,
    heart_rate        SMALLINT,
    respiratory_rate  SMALLINT,
    oxygen_saturation SMALLINT,
    hash_diff         VARCHAR(64) NOT NULL,
    load_date         TIMESTAMP NOT NULL DEFAULT now(),
    record_source     VARCHAR(100) NOT NULL DEFAULT 'ER_SYSTEM'
);
CREATE INDEX idx_sat_vital_link ON sat_vital(link_visit_key);
