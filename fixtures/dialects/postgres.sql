--
-- PostgreSQL database dump
-- Shaped like pg_dump output: schema-qualified names, keys declared through
-- ALTER TABLE rather than inline, and multi-word types.
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    display_name text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    settings jsonb DEFAULT '{}'::jsonb,
    tags text[]
);

ALTER TABLE public.users OWNER TO app;

--
-- "order" is a reserved word, so pg_dump quotes it everywhere.
--

CREATE TABLE public."order" (
    id integer NOT NULL,
    user_id integer NOT NULL,
    total numeric(12,2) DEFAULT 0 NOT NULL,
    placed_at timestamp with time zone,
    note text  -- may contain a semicolon; that must not split the statement
);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);

ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (id);

ALTER TABLE ONLY public."order"
    ADD CONSTRAINT order_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

CREATE INDEX order_user_id_idx ON public."order" USING btree (user_id);

CREATE VIEW public.recent_orders AS
 SELECT o.id, o.total FROM public."order" o WHERE (o.placed_at > now());
