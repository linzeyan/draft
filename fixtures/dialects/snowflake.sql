-- Snowflake: CREATE OR REPLACE TRANSIENT TABLE, three-part names, and
-- constraints named before their kind.

create or replace transient table ANALYTICS.PUBLIC.ACCOUNT (
    ACCOUNT_ID   number(38,0) not null primary key,
    NAME         varchar(256),
    CREATED_AT   timestamp_ntz(9) default current_timestamp()
);

create table if not exists ANALYTICS.PUBLIC.EVENT_LOG (
    EVENT_ID     number(38,0) not null,
    ACCOUNT_ID   number(38,0),
    EVENT_TYPE   varchar(64),
    PAYLOAD      variant,
    LOADED_AT    timestamp_ntz(9) default current_timestamp(),
    constraint PK_EVENT_LOG primary key (EVENT_ID),
    constraint FK_EVENT_ACCOUNT foreign key (ACCOUNT_ID)
        references ANALYTICS.PUBLIC.ACCOUNT (ACCOUNT_ID)
);

create or replace view ANALYTICS.PUBLIC.RECENT as
    select EVENT_ID from ANALYTICS.PUBLIC.EVENT_LOG where LOADED_AT > current_date();
