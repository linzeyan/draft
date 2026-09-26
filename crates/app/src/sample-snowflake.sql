-- An analytics warehouse in Snowflake's idiom: lowercase DDL, fully qualified
-- three-part names, a transient staging table and `variant` for raw payloads.
-- Paste your own schema over it, or drop a .sql file anywhere on this window.

create or replace table ANALYTICS.PUBLIC.DIM_ACCOUNT (
    ACCOUNT_ID     number(38,0) not null primary key,
    NAME           varchar(256) not null,
    REGION         varchar(32),
    CREATED_AT     timestamp_ntz(9) default current_timestamp()
);

create or replace table ANALYTICS.PUBLIC.DIM_PLAN (
    PLAN_ID        number(38,0) not null primary key,
    CODE           varchar(32) not null,
    SEAT_PRICE     number(12,2) not null,
    IS_ACTIVE      boolean not null default true
);

create or replace table ANALYTICS.PUBLIC.DIM_USER (
    USER_ID        number(38,0) not null primary key,
    ACCOUNT_ID     number(38,0) not null,
    EMAIL          varchar(320) not null,
    ROLE           varchar(32) not null,
    constraint FK_USER_ACCOUNT foreign key (ACCOUNT_ID)
        references ANALYTICS.PUBLIC.DIM_ACCOUNT (ACCOUNT_ID)
);

create or replace table ANALYTICS.PUBLIC.DIM_DATE (
    DATE_KEY        number(38,0) not null primary key,
    CALENDAR_DATE   date not null,
    FISCAL_QUARTER  varchar(8) not null
);

-- Transient: it holds what the loader dropped in, and is rebuilt rather than
-- recovered.
create or replace transient table ANALYTICS.PUBLIC.STG_EVENT_RAW (
    RAW_ID         number(38,0) not null primary key,
    PAYLOAD        variant not null,
    LOADED_AT      timestamp_ntz(9) default current_timestamp()
);

create or replace table ANALYTICS.PUBLIC.FCT_EVENT (
    EVENT_ID       number(38,0) not null primary key,
    RAW_ID         number(38,0),
    ACCOUNT_ID     number(38,0) not null,
    USER_ID        number(38,0),
    DATE_KEY       number(38,0) not null,
    EVENT_TYPE     varchar(64) not null,
    PROPERTIES     variant,
    constraint FK_EVENT_RAW foreign key (RAW_ID)
        references ANALYTICS.PUBLIC.STG_EVENT_RAW (RAW_ID),
    constraint FK_EVENT_ACCOUNT foreign key (ACCOUNT_ID)
        references ANALYTICS.PUBLIC.DIM_ACCOUNT (ACCOUNT_ID),
    constraint FK_EVENT_USER foreign key (USER_ID)
        references ANALYTICS.PUBLIC.DIM_USER (USER_ID),
    constraint FK_EVENT_DATE foreign key (DATE_KEY)
        references ANALYTICS.PUBLIC.DIM_DATE (DATE_KEY)
);

create or replace table ANALYTICS.PUBLIC.FCT_SUBSCRIPTION (
    SUBSCRIPTION_ID  number(38,0) not null primary key,
    ACCOUNT_ID       number(38,0) not null,
    PLAN_ID          number(38,0) not null,
    SEATS            number(38,0) not null,
    STARTED_ON       date not null,
    ENDED_ON         date,
    constraint FK_SUB_ACCOUNT foreign key (ACCOUNT_ID)
        references ANALYTICS.PUBLIC.DIM_ACCOUNT (ACCOUNT_ID),
    constraint FK_SUB_PLAN foreign key (PLAN_ID)
        references ANALYTICS.PUBLIC.DIM_PLAN (PLAN_ID)
);

create or replace table ANALYTICS.PUBLIC.FCT_INVOICE (
    INVOICE_ID       number(38,0) not null primary key,
    SUBSCRIPTION_ID  number(38,0) not null,
    DATE_KEY         number(38,0) not null,
    AMOUNT           number(12,2) not null,
    constraint FK_INVOICE_SUB foreign key (SUBSCRIPTION_ID)
        references ANALYTICS.PUBLIC.FCT_SUBSCRIPTION (SUBSCRIPTION_ID),
    constraint FK_INVOICE_DATE foreign key (DATE_KEY)
        references ANALYTICS.PUBLIC.DIM_DATE (DATE_KEY)
);
