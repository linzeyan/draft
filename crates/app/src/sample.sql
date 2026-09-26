-- A small shop. Everything here is ordinary SQL: paste your own
-- schema over it, or drop a .sql file anywhere on this window.

CREATE TABLE customers (
    id            bigserial PRIMARY KEY,
    email         varchar(255) NOT NULL UNIQUE,
    display_name  text,
    created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE addresses (
    id           bigserial PRIMARY KEY,
    customer_id  bigint NOT NULL REFERENCES customers(id),
    line1        text NOT NULL,
    line2        text,
    city         text NOT NULL,
    postcode     varchar(16),
    country      char(2) NOT NULL
);

CREATE TABLE categories (
    id         bigserial PRIMARY KEY,
    parent_id  bigint REFERENCES categories(id),  -- a table may point at itself
    slug       varchar(64) NOT NULL UNIQUE,
    title      text NOT NULL
);

CREATE TABLE products (
    id           bigserial PRIMARY KEY,
    category_id  bigint REFERENCES categories(id),
    sku          varchar(32) NOT NULL UNIQUE,
    title        text NOT NULL,
    price_cents  integer NOT NULL,
    active       boolean NOT NULL DEFAULT true
);

CREATE TABLE inventory (
    product_id  bigint PRIMARY KEY REFERENCES products(id),
    on_hand     integer NOT NULL DEFAULT 0,
    reserved    integer NOT NULL DEFAULT 0
);

CREATE TABLE orders (
    id           bigserial PRIMARY KEY,
    customer_id  bigint NOT NULL REFERENCES customers(id),
    address_id   bigint REFERENCES addresses(id),
    status       varchar(24) NOT NULL DEFAULT 'pending',
    placed_at    timestamptz NOT NULL DEFAULT now(),
    total_cents  integer NOT NULL
);

CREATE TABLE order_lines (
    id          bigserial PRIMARY KEY,
    order_id    bigint NOT NULL REFERENCES orders(id),
    product_id  bigint NOT NULL REFERENCES products(id),
    quantity    integer NOT NULL,
    unit_cents  integer NOT NULL
);

CREATE TABLE payments (
    id           bigserial PRIMARY KEY,
    order_id     bigint NOT NULL REFERENCES orders(id),
    provider     varchar(32) NOT NULL,
    reference    text NOT NULL,
    amount_cents integer NOT NULL,
    captured_at  timestamptz
);

CREATE TABLE reviews (
    id          bigserial PRIMARY KEY,
    product_id  bigint NOT NULL REFERENCES products(id),
    customer_id bigint NOT NULL REFERENCES customers(id),
    rating      smallint NOT NULL,
    body        text
);
