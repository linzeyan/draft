-- Generated fixture. Do not edit by hand; see fixtures/gen/gen.mjs.
-- Comments here are deliberate: the parser must blank them to
-- equal-length whitespace so byte offsets stay valid.

CREATE TABLE v2_account_audit (
  id bigint PRIMARY KEY,
  legacy_carrier_history_id bigint NOT NULL,
  is_active timestamp,
  status bytea,
  amount smallint NOT NULL,
  locale varchar(255) NOT NULL
);

CREATE TABLE "public"."external_inventory_meta" (
  id bigint PRIMARY KEY,
  v2_claim_detail_id bigint NOT NULL,
  subscription_id bigint NOT NULL,
  v2_department_item_id bigint NOT NULL REFERENCES v2_department_item(id),
  deleted_at varchar(64) NOT NULL,
  label integer NOT NULL,
  is_default jsonb NOT NULL,
  created_at timestamp NOT NULL,
  position varchar(255),
  email double precision NOT NULL
);

CREATE TABLE legacy_carrier_history (
  id bigint PRIMARY KEY,
  name inet NOT NULL,
  is_locked double precision NOT NULL
);

CREATE TABLE department (
  id bigint PRIMARY KEY,
  external_inventory_meta_id bigint,
  v2_account_audit_id bigint NOT NULL,
  checksum bytea,
  body integer NOT NULL,
  currency date NOT NULL
);

CREATE TABLE "public"."legacy_invoice_line" (
  id bigint PRIMARY KEY,
  v2_account_audit_id bigint REFERENCES v2_account_audit(id),
  legacy_carrier_history_id bigint,
  v2_task_detail_id bigint NOT NULL REFERENCES v2_task_detail(id),
  total char(2),
  starts_at jsonb NOT NULL,
  price varchar(64) NOT NULL,
  note char(2),
  slug varchar(64) NOT NULL,
  code bytea NOT NULL,
  note_7 smallint,
  total_8 char(2)
);

CREATE TABLE subscription (
  id bigint PRIMARY KEY,
  legacy_carrier_history_id bigint NOT NULL REFERENCES legacy_carrier_history(id),
  is_default varchar(64) NOT NULL,
  updated_at uuid,
  code text,
  is_active bigint NOT NULL,
  UNIQUE (is_active)
);

CREATE TABLE staging_attachment_item (
  id bigint PRIMARY KEY,
  v2_account_audit_id bigint NOT NULL REFERENCES v2_account_audit(id),
  external_inventory_meta_id bigint REFERENCES external_inventory_meta(id),
  checksum jsonb NOT NULL,
  quantity numeric(12,2) NOT NULL,
  timezone date,
  is_active smallint NOT NULL
);

CREATE TABLE "public"."v2_claim_detail" (
  id bigint PRIMARY KEY,
  channel_id bigint REFERENCES channel(id),
  legacy_carrier_history_id bigint NOT NULL REFERENCES legacy_carrier_history(id),
  legacy_campaign_id bigint NOT NULL REFERENCES legacy_campaign(id),
  legacy_product_line_id bigint REFERENCES legacy_product_line(id),
  label uuid NOT NULL,
  is_active varchar(255),
  timezone integer NOT NULL,
  slug jsonb NOT NULL,
  updated_at boolean,
  note integer,
  phone bigint,
  kind boolean
);

CREATE TABLE v2_task_detail (
  id bigint PRIMARY KEY,
  external_notification_id bigint,
  v2_account_audit_id bigint REFERENCES v2_account_audit(id),
  legacy_carrier_history_id bigint NOT NULL REFERENCES legacy_carrier_history(id),
  price uuid NOT NULL,
  amount inet,
  updated_at bigint NOT NULL,
  starts_at varchar(255) NOT NULL,
  is_active numeric(12,2) NOT NULL
);

CREATE TABLE channel (
  id bigint PRIMARY KEY,
  staging_category_id bigint,
  legacy_carrier_history_id bigint REFERENCES legacy_carrier_history(id),
  external_inventory_meta_id bigint REFERENCES external_inventory_meta(id),
  code boolean,
  is_active bytea,
  UNIQUE (is_active)
);

CREATE TABLE legacy_campaign (
  id bigint PRIMARY KEY,
  external_inventory_meta_id bigint NOT NULL,
  email bigint,
  timezone bigint,
  updated_at date NOT NULL,
  kind integer,
  price bigint,
  deleted_at jsonb
);

CREATE TABLE staging_product_item (
  id bigint PRIMARY KEY,
  external_inventory_meta_id bigint,
  metadata integer NOT NULL,
  external_ref text,
  metadata_3 integer NOT NULL,
  is_locked bigint,
  email varchar(64)
);

CREATE TABLE staging_category (
  id bigint PRIMARY KEY,
  external_notification_id bigint NOT NULL REFERENCES external_notification(id),
  v2_account_audit_id bigint,
  starts_at timestamptz,
  rate text NOT NULL,
  timezone numeric(12,2) NOT NULL,
  expires_at numeric(12,2) NOT NULL,
  slug inet NOT NULL,
  name timestamp NOT NULL,
  phone numeric(12,2),
  name_8 numeric(12,2) NOT NULL
);

-- v2_department_item: 10 columns
CREATE TABLE public.v2_department_item (
  id bigint PRIMARY KEY,
  legacy_product_line_id bigint NOT NULL REFERENCES legacy_product_line(id),
  external_inventory_meta_id bigint REFERENCES external_inventory_meta(id),
  phone text,
  locale numeric(12,2),
  currency numeric(12,2),
  metadata double precision NOT NULL,
  metadata_5 uuid NOT NULL,
  slug char(2) NOT NULL,
  email timestamp
);

CREATE TABLE external_review_link (
  id bigint PRIMARY KEY,
  external_inventory_meta_id bigint NOT NULL REFERENCES external_inventory_meta(id),
  kind uuid,
  metadata smallint NOT NULL,
  metadata_3 bytea NOT NULL,
  total uuid NOT NULL
);

CREATE TABLE archived_review (
  id bigint PRIMARY KEY,
  legacy_product_line_id bigint REFERENCES legacy_product_line(id),
  external_inventory_meta_id bigint NOT NULL REFERENCES external_inventory_meta(id),
  code varchar(64),
  total boolean,
  label numeric(12,2)
);

-- archived_warehouse_snapshot: 10 columns
CREATE TABLE archived_warehouse_snapshot (
  id bigint PRIMARY KEY,
  subscription_id bigint NOT NULL REFERENCES subscription(id),
  legacy_carrier_history_id bigint NOT NULL REFERENCES legacy_carrier_history(id),
  v2_claim_detail_id bigint REFERENCES v2_claim_detail(id),
  weight integer,
  timezone timestamptz,
  phone numeric(12,2) NOT NULL,
  is_active numeric(12,2),
  locale boolean,
  code timestamptz NOT NULL,
  UNIQUE (weight)
);

-- external_notification: 4 columns
CREATE TABLE external_notification (
  id bigint PRIMARY KEY,
  legacy_invoice_line_id bigint REFERENCES legacy_invoice_line(id),
  v2_account_audit_id bigint NOT NULL,
  created_at timestamptz
);
/* trailing block comment */

CREATE TABLE external_customer_config (
  id bigint PRIMARY KEY,
  legacy_carrier_history_id bigint NOT NULL,
  staging_category_id bigint NOT NULL REFERENCES staging_category(id),
  external_inventory_meta_id bigint NOT NULL REFERENCES external_inventory_meta(id),
  position char(2),
  title date,
  price inet
);

CREATE TABLE legacy_product_line (
  id bigint PRIMARY KEY,
  legacy_carrier_history_id bigint NOT NULL REFERENCES legacy_carrier_history(id),
  weight bigint,
  title date NOT NULL,
  deleted_at varchar(64),
  body smallint NOT NULL,
  total varchar(255)
);

ALTER TABLE ONLY public.staging_product_item ADD CONSTRAINT staging_product_item_external_inventory_meta_id_fkey FOREIGN KEY (external_inventory_meta_id) REFERENCES public.external_inventory_meta(id);
ALTER TABLE ONLY public.legacy_campaign ADD CONSTRAINT legacy_campaign_external_inventory_meta_id_fkey FOREIGN KEY (external_inventory_meta_id) REFERENCES public.external_inventory_meta(id);
ALTER TABLE ONLY public.v2_account_audit ADD CONSTRAINT v2_account_audit_legacy_carrier_history_id_fkey FOREIGN KEY (legacy_carrier_history_id) REFERENCES public.legacy_carrier_history(id);
ALTER TABLE ONLY public.staging_category ADD CONSTRAINT staging_category_v2_account_audit_id_fkey FOREIGN KEY (v2_account_audit_id) REFERENCES public.v2_account_audit(id);
ALTER TABLE ONLY public.external_inventory_meta ADD CONSTRAINT external_inventory_meta_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES public.subscription(id);
ALTER TABLE ONLY public.department ADD CONSTRAINT department_v2_account_audit_id_fkey FOREIGN KEY (v2_account_audit_id) REFERENCES public.v2_account_audit(id);
ALTER TABLE ONLY public.channel ADD CONSTRAINT channel_staging_category_id_fkey FOREIGN KEY (staging_category_id) REFERENCES public.staging_category(id);
ALTER TABLE ONLY public.legacy_invoice_line ADD CONSTRAINT legacy_invoice_line_legacy_carrier_history_id_fkey FOREIGN KEY (legacy_carrier_history_id) REFERENCES public.legacy_carrier_history(id);
ALTER TABLE ONLY public.v2_task_detail ADD CONSTRAINT v2_task_detail_external_notification_id_fkey FOREIGN KEY (external_notification_id) REFERENCES public.external_notification(id);
ALTER TABLE ONLY public.external_inventory_meta ADD CONSTRAINT external_inventory_meta_v2_claim_detail_id_fkey FOREIGN KEY (v2_claim_detail_id) REFERENCES public.v2_claim_detail(id);
ALTER TABLE ONLY public.department ADD CONSTRAINT department_external_inventory_meta_id_fkey FOREIGN KEY (external_inventory_meta_id) REFERENCES public.external_inventory_meta(id);
ALTER TABLE ONLY public.external_notification ADD CONSTRAINT external_notification_v2_account_audit_id_fkey FOREIGN KEY (v2_account_audit_id) REFERENCES public.v2_account_audit(id);
ALTER TABLE ONLY public.external_customer_config ADD CONSTRAINT external_customer_config_legacy_carrier_history_id_fkey FOREIGN KEY (legacy_carrier_history_id) REFERENCES public.legacy_carrier_history(id);
