-- Generated fixture. Do not edit by hand; see fixtures/gen/gen.mjs.
-- Comments here are deliberate: the parser must blank them to
-- equal-length whitespace so byte offsets stay valid.

-- invoice_config: 9 columns
CREATE TABLE invoice_config (
  id bigint PRIMARY KEY,
  external_session_id bigint NOT NULL REFERENCES external_session(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  deleted_at char(2) NOT NULL,
  position numeric(12,2),
  checksum inet NOT NULL,
  name smallint NOT NULL,
  note numeric(12,2) NOT NULL,
  locale inet NOT NULL
);
/* trailing block comment */

CREATE TABLE staging_department_history (
  id bigint PRIMARY KEY,
  v2_booking_snapshot_id bigint NOT NULL REFERENCES v2_booking_snapshot(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  v2_claim_link_id bigint NOT NULL REFERENCES v2_claim_link(id),
  is_default integer,
  currency timestamp NOT NULL,
  is_active varchar(255)
);

CREATE TABLE staging_template_item (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  title timestamp,
  slug jsonb,
  currency bytea,
  phone uuid NOT NULL,
  is_default uuid NOT NULL,
  note timestamptz,
  total jsonb NOT NULL,
  phone_8 smallint,
  is_active double precision NOT NULL
);

CREATE TABLE archived_policy (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  note bigint NOT NULL,
  is_default jsonb NOT NULL,
  label text NOT NULL
);

-- policy_item: 15 columns
CREATE TABLE policy_item (
  id bigint PRIMARY KEY,
  discount_id bigint REFERENCES discount(id),
  legacy_task_id bigint,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  slug uuid,
  title date NOT NULL,
  phone double precision NOT NULL,
  title_4 varchar(64) NOT NULL,
  timezone timestamptz NOT NULL,
  version varchar(64) NOT NULL,
  currency double precision NOT NULL,
  slug_8 uuid,
  price jsonb NOT NULL,
  locale inet
);

CREATE TABLE discount (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  shipment_history_id bigint NOT NULL,
  version char(2) NOT NULL,
  note uuid NOT NULL,
  phone varchar(64),
  note_4 smallint NOT NULL,
  slug timestamp
);

CREATE TABLE warehouse_audit (
  id bigint PRIMARY KEY,
  legacy_ticket_detail_id bigint NOT NULL REFERENCES legacy_ticket_detail(id),
  v2_channel_meta_id bigint NOT NULL REFERENCES v2_channel_meta(id),
  v2_refund_snapshot_id bigint NOT NULL REFERENCES v2_refund_snapshot(id),
  status bytea NOT NULL,
  deleted_at varchar(255) NOT NULL,
  price jsonb,
  total boolean,
  quantity smallint,
  external_ref uuid NOT NULL,
  expires_at bigint
);

-- refund_audit: 7 columns
CREATE TABLE refund_audit (
  id bigint PRIMARY KEY,
  legacy_contract_id bigint NOT NULL REFERENCES legacy_contract(id),
  email varchar(64),
  status bytea NOT NULL,
  position bigint NOT NULL,
  timezone bytea,
  title numeric(12,2)
);

CREATE TABLE v2_shipment_leg_meta (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  note double precision,
  price char(2),
  locale double precision NOT NULL
);

CREATE TABLE archived_order (
  id bigint PRIMARY KEY,
  staging_vehicle_line_id bigint,
  refund_audit_id bigint REFERENCES refund_audit(id),
  external_campaign_id bigint NOT NULL REFERENCES external_campaign(id),
  quantity bigint,
  name char(2),
  note text,
  amount text,
  position jsonb
);
/* trailing block comment */

CREATE TABLE "public"."legacy_account" (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  archived_message_audit_id bigint REFERENCES archived_message_audit(id),
  metadata inet,
  is_default varchar(255) NOT NULL,
  starts_at double precision NOT NULL,
  external_ref varchar(64),
  phone smallint NOT NULL,
  external_ref_6 uuid NOT NULL,
  body char(2),
  label timestamptz NOT NULL
);

CREATE TABLE project_history (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  name timestamp,
  rate uuid,
  version varchar(64) NOT NULL,
  external_ref double precision,
  expires_at uuid NOT NULL,
  currency numeric(12,2),
  note uuid NOT NULL,
  note_8 text,
  email smallint
);

CREATE TABLE v2_audit_item (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  deleted_at uuid,
  slug date,
  kind double precision NOT NULL,
  position bigint,
  updated_at timestamp,
  price boolean,
  amount bytea NOT NULL,
  name char(2)
);

CREATE TABLE customer_snapshot (
  id bigint PRIMARY KEY,
  refund_audit_id bigint,
  note numeric(12,2),
  phone numeric(12,2) NOT NULL,
  email timestamp NOT NULL,
  email_4 date,
  slug timestamptz NOT NULL,
  quantity uuid NOT NULL,
  currency char(2),
  updated_at varchar(255) NOT NULL
);

CREATE TABLE booking_line (
  id bigint PRIMARY KEY,
  legacy_account_id bigint REFERENCES legacy_account(id),
  timezone bytea NOT NULL,
  kind integer NOT NULL,
  quantity double precision,
  total text,
  total_5 timestamptz
);

CREATE TABLE v2_refund_audit (
  id bigint PRIMARY KEY,
  task_id bigint NOT NULL REFERENCES task(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  template_history_id bigint NOT NULL REFERENCES template_history(id),
  booking_detail_id bigint,
  expires_at text NOT NULL,
  status varchar(255),
  expires_at_3 integer,
  timezone varchar(255) NOT NULL,
  external_ref timestamp,
  status_6 date,
  total bigint NOT NULL,
  name timestamptz
);

-- v2_refund: 12 columns
CREATE TABLE v2_refund (
  id bigint PRIMARY KEY,
  legacy_template_link_id bigint REFERENCES legacy_template_link(id),
  vehicle_link_id bigint NOT NULL REFERENCES vehicle_link(id),
  email text NOT NULL,
  body text,
  price numeric(12,2) NOT NULL,
  version text,
  kind timestamptz,
  email_6 boolean,
  label text,
  title bytea,
  slug char(2)
);

-- v2_discount_config: 6 columns
CREATE TABLE "v2_discount_config" (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL,
  archived_policy_id bigint REFERENCES archived_policy(id),
  email smallint NOT NULL,
  amount boolean NOT NULL,
  is_active numeric(12,2)
);

-- staging_shipment_leg_config: 5 columns
CREATE TABLE staging_shipment_leg_config (
  id bigint PRIMARY KEY,
  staging_ticket_meta_id bigint NOT NULL REFERENCES staging_ticket_meta(id),
  version double precision,
  slug text NOT NULL,
  body bytea NOT NULL
);
/* trailing block comment */

CREATE TABLE archived_account_audit (
  id bigint PRIMARY KEY,
  legacy_shipment_leg_meta_id bigint NOT NULL REFERENCES legacy_shipment_leg_meta(id),
  expires_at text,
  code jsonb NOT NULL,
  metadata boolean,
  slug date NOT NULL,
  rate timestamptz NOT NULL,
  kind double precision,
  starts_at integer,
  email uuid
);

CREATE TABLE v2_claim_detail (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  archived_policy_id bigint NOT NULL,
  template_id bigint REFERENCES template(id),
  email timestamp,
  quantity double precision,
  starts_at date,
  external_ref bigint NOT NULL,
  created_at date,
  body timestamp,
  is_default varchar(64),
  is_locked text
);

CREATE TABLE staging_tag_history (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  v2_session_item_id bigint NOT NULL,
  category_line_id bigint NOT NULL REFERENCES category_line(id),
  name text NOT NULL,
  checksum bytea,
  price uuid NOT NULL,
  deleted_at varchar(64)
);

CREATE TABLE v2_claim_item (
  id bigint PRIMARY KEY,
  staging_channel_meta_id bigint,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  external_employee_id bigint REFERENCES external_employee(id),
  email timestamptz NOT NULL,
  timezone varchar(255)
);

CREATE TABLE "account_config" (
  id bigint PRIMARY KEY,
  discount_id bigint REFERENCES discount(id),
  title numeric(12,2) NOT NULL,
  phone text NOT NULL,
  quantity char(2)
);

CREATE TABLE v2_account_meta (
  id bigint PRIMARY KEY,
  slug bigint,
  is_default jsonb,
  code timestamptz,
  timezone bytea,
  checksum smallint,
  code_6 bigint
);

-- v2_carrier_item: 15 columns
CREATE TABLE v2_carrier_item (
  id bigint PRIMARY KEY,
  legacy_invoice_config_id bigint NOT NULL,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  metadata smallint,
  version smallint,
  expires_at boolean,
  title boolean,
  metadata_5 double precision,
  locale date NOT NULL,
  starts_at char(2),
  label integer NOT NULL,
  total numeric(12,2),
  checksum inet NOT NULL
);

-- v2_attachment_meta: 7 columns
CREATE TABLE v2_attachment_meta (
  id bigint PRIMARY KEY,
  staging_attachment_line_id bigint NOT NULL REFERENCES staging_attachment_line(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  external_ref bigint,
  currency varchar(255) NOT NULL,
  rate integer,
  version inet NOT NULL
);

-- carrier_audit: 12 columns
CREATE TABLE carrier_audit (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  refund_audit_id bigint,
  phone bytea NOT NULL,
  is_locked numeric(12,2),
  kind boolean NOT NULL,
  title inet NOT NULL,
  created_at double precision NOT NULL,
  currency numeric(12,2),
  currency_7 timestamp NOT NULL,
  created_at_8 jsonb NOT NULL,
  checksum date,
  UNIQUE (is_locked)
);

-- department: 9 columns
CREATE TABLE department (
  id bigint PRIMARY KEY,
  timezone smallint NOT NULL,
  kind inet,
  updated_at integer,
  deleted_at numeric(12,2) NOT NULL,
  checksum inet NOT NULL,
  metadata timestamp NOT NULL,
  is_default jsonb,
  name date
);

-- archived_template_meta: 4 columns
CREATE TABLE archived_template_meta (
  id bigint PRIMARY KEY,
  label bytea,
  slug text NOT NULL,
  timezone smallint
);

CREATE TABLE staging_template_config (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  note char(2),
  weight char(2),
  version uuid NOT NULL,
  updated_at inet,
  price numeric(12,2) NOT NULL
);

CREATE TABLE route_detail (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  timezone bytea NOT NULL,
  note timestamp,
  name varchar(64),
  UNIQUE (v2_audit_item_id)
);

CREATE TABLE claim_history (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  slug text,
  starts_at timestamp,
  email inet NOT NULL,
  total uuid NOT NULL,
  currency char(2) NOT NULL,
  timezone char(2)
);

-- campaign_history: 10 columns
CREATE TABLE "campaign_history" (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  staging_department_history_id bigint,
  legacy_campaign_snapshot_id bigint REFERENCES legacy_campaign_snapshot(id),
  legacy_policy_line_id bigint NOT NULL REFERENCES legacy_policy_line(id),
  position integer,
  deleted_at double precision,
  status date,
  note bytea,
  updated_at text
);

CREATE TABLE public.account (
  id bigint PRIMARY KEY,
  v2_account_detail_id bigint NOT NULL,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  expires_at boolean,
  title char(2),
  checksum smallint
);

CREATE TABLE "public"."discount_config" (
  id bigint PRIMARY KEY,
  title smallint,
  rate timestamptz NOT NULL,
  amount smallint NOT NULL,
  status jsonb,
  status_5 uuid,
  price date NOT NULL,
  is_default bytea,
  body bytea NOT NULL,
  kind jsonb
);

CREATE TABLE department_history (
  id bigint PRIMARY KEY,
  v2_document_id bigint NOT NULL,
  external_department_detail_id bigint REFERENCES external_department_detail(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  kind bigint,
  title inet,
  rate inet,
  checksum date
);

-- employee_detail: 6 columns
CREATE TABLE employee_detail (
  id bigint PRIMARY KEY,
  version smallint NOT NULL,
  position text,
  external_ref bigint NOT NULL,
  starts_at inet,
  updated_at smallint
);
/* trailing block comment */

CREATE TABLE archived_policy_detail (
  id bigint PRIMARY KEY,
  staging_project_id bigint NOT NULL REFERENCES staging_project(id),
  v2_carrier_detail_id bigint NOT NULL REFERENCES v2_carrier_detail(id),
  archived_order_id bigint REFERENCES archived_order(id),
  staging_campaign_meta_id bigint NOT NULL REFERENCES staging_campaign_meta(id),
  is_active numeric(12,2),
  external_ref char(2) NOT NULL,
  email char(2),
  locale bigint NOT NULL,
  slug smallint,
  checksum varchar(64)
);

CREATE TABLE staging_warehouse_audit (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  v2_audit_item_id bigint,
  position double precision,
  kind char(2) NOT NULL,
  external_ref varchar(64) NOT NULL,
  deleted_at integer NOT NULL,
  version inet NOT NULL,
  phone uuid,
  code timestamptz
);

CREATE TABLE campaign_detail (
  id bigint PRIMARY KEY,
  staging_payment_audit_id bigint REFERENCES staging_payment_audit(id),
  staging_review_item_id bigint NOT NULL,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  name varchar(255),
  body char(2),
  external_ref inet,
  email timestamptz NOT NULL,
  code boolean NOT NULL,
  name_6 integer,
  UNIQUE (name_6)
);

-- archived_project_line: 13 columns
CREATE TABLE archived_project_line (
  id bigint PRIMARY KEY,
  channel_link_id bigint NOT NULL REFERENCES channel_link(id),
  staging_carrier_snapshot_id bigint NOT NULL REFERENCES staging_carrier_snapshot(id),
  position text,
  starts_at integer NOT NULL,
  email smallint NOT NULL,
  phone date,
  starts_at_5 bytea,
  metadata timestamp,
  version timestamptz NOT NULL,
  is_locked integer,
  checksum bytea,
  currency timestamptz,
  UNIQUE (version)
);

CREATE TABLE employee_history (
  id bigint PRIMARY KEY,
  staging_audit_history_id bigint REFERENCES staging_audit_history(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  archived_document_history_id bigint REFERENCES archived_document_history(id),
  v2_invoice_meta_id bigint,
  subscription_line_id bigint,
  checksum text,
  code uuid,
  position inet NOT NULL,
  name text,
  title numeric(12,2),
  created_at varchar(64) NOT NULL,
  is_active jsonb,
  version numeric(12,2) NOT NULL,
  is_default double precision
);

CREATE TABLE legacy_carrier_audit (
  id bigint PRIMARY KEY,
  is_locked boolean,
  slug boolean,
  checksum bigint
);

CREATE TABLE staging_carrier_snapshot (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  title inet,
  total timestamp,
  label numeric(12,2),
  status bytea,
  slug bytea
);

CREATE TABLE legacy_notification_config (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  total jsonb NOT NULL,
  total_2 varchar(255) NOT NULL,
  deleted_at uuid,
  deleted_at_4 bigint,
  title varchar(255) NOT NULL,
  locale numeric(12,2) NOT NULL,
  code boolean NOT NULL,
  UNIQUE (code)
);

CREATE TABLE "v2_payment_link" (
  id bigint PRIMARY KEY,
  archived_category_audit_id bigint NOT NULL REFERENCES archived_category_audit(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  metadata numeric(12,2),
  external_ref char(2)
);

CREATE TABLE staging_category_line (
  id bigint PRIMARY KEY,
  status bigint NOT NULL,
  kind double precision NOT NULL,
  phone char(2) NOT NULL,
  is_default jsonb,
  code double precision,
  external_ref date,
  body char(2) NOT NULL
);

CREATE TABLE audit_link (
  id bigint PRIMARY KEY,
  archived_vendor_history_id bigint NOT NULL REFERENCES archived_vendor_history(id),
  expires_at uuid,
  metadata uuid,
  is_default timestamp,
  quantity integer NOT NULL,
  locale timestamp,
  title jsonb NOT NULL,
  phone bigint NOT NULL,
  amount inet NOT NULL
);

CREATE TABLE inventory (
  id bigint PRIMARY KEY,
  v2_session_line_id bigint NOT NULL REFERENCES v2_session_line(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  booking_line_id bigint NOT NULL,
  locale smallint NOT NULL,
  created_at numeric(12,2) NOT NULL,
  price date NOT NULL
);

CREATE TABLE external_message_detail (
  id bigint PRIMARY KEY,
  staging_customer_audit_id bigint REFERENCES staging_customer_audit(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  position inet NOT NULL,
  is_locked numeric(12,2),
  title text,
  title_4 numeric(12,2),
  position_5 date,
  deleted_at double precision
);

-- carrier_item: 7 columns
CREATE TABLE carrier_item (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  is_default varchar(255) NOT NULL,
  rate smallint,
  locale boolean NOT NULL,
  checksum bigint,
  metadata double precision
);

CREATE TABLE public.legacy_notification_detail (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  price varchar(64),
  deleted_at numeric(12,2),
  expires_at char(2) NOT NULL,
  expires_at_4 inet NOT NULL,
  slug date NOT NULL
);

CREATE TABLE public.v2_booking_meta (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  refund_line_id bigint NOT NULL REFERENCES refund_line(id),
  label boolean,
  slug text NOT NULL,
  phone bytea NOT NULL,
  metadata inet NOT NULL
);

CREATE TABLE archived_document (
  id bigint PRIMARY KEY,
  session_detail_id bigint NOT NULL REFERENCES session_detail(id),
  discount_id bigint REFERENCES discount(id),
  checksum timestamp,
  position timestamptz,
  price inet,
  updated_at jsonb,
  body jsonb,
  metadata integer,
  UNIQUE (body)
);

CREATE TABLE legacy_claim_audit (
  id bigint PRIMARY KEY,
  version inet,
  external_ref numeric(12,2),
  rate inet NOT NULL,
  title jsonb NOT NULL,
  label varchar(255),
  created_at integer,
  email varchar(64) NOT NULL,
  is_default timestamp,
  status date,
  kind timestamp
);

CREATE TABLE external_customer (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  booking_line_id bigint NOT NULL,
  deleted_at smallint,
  external_ref uuid,
  amount text NOT NULL
);

CREATE TABLE staging_department_snapshot (
  id bigint PRIMARY KEY,
  asset_link_id bigint NOT NULL REFERENCES asset_link(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  project_history_id bigint REFERENCES project_history(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  rate char(2) NOT NULL,
  metadata numeric(12,2),
  updated_at uuid NOT NULL,
  UNIQUE (rate)
);

CREATE TABLE staging_refund_item (
  id bigint PRIMARY KEY,
  legacy_message_meta_id bigint REFERENCES legacy_message_meta(id),
  body char(2),
  body_2 timestamp NOT NULL,
  deleted_at double precision,
  starts_at timestamp,
  note text
);

CREATE TABLE external_audit_detail (
  id bigint PRIMARY KEY,
  status timestamptz,
  locale inet
);
/* trailing block comment */

CREATE TABLE external_shipment_leg_snapshot (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  project_history_id bigint REFERENCES project_history(id),
  amount uuid,
  price double precision NOT NULL,
  price_3 varchar(255)
);

CREATE TABLE payment_channel (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  archived_document_history_id bigint NOT NULL REFERENCES archived_document_history(id),
  external_order_meta_id bigint REFERENCES external_order_meta(id),
  updated_at timestamptz,
  amount inet NOT NULL,
  price integer NOT NULL,
  timezone smallint NOT NULL,
  total varchar(64),
  is_default smallint,
  note uuid NOT NULL,
  rate varchar(64)
);

CREATE TABLE shipment_snapshot (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL,
  updated_at date NOT NULL,
  position date,
  rate bigint,
  amount integer,
  quantity varchar(255) NOT NULL,
  total date,
  is_active varchar(255),
  UNIQUE (updated_at)
);

CREATE TABLE "public"."staging_inventory_detail" (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL,
  title char(2),
  expires_at timestamp NOT NULL,
  weight bytea NOT NULL,
  name bytea NOT NULL,
  position char(2) NOT NULL,
  title_6 timestamp
);

CREATE TABLE task_config (
  id bigint PRIMARY KEY,
  legacy_document_line_id bigint NOT NULL REFERENCES legacy_document_line(id),
  locale integer NOT NULL,
  is_locked varchar(64) NOT NULL,
  price date,
  status inet,
  slug varchar(255),
  slug_6 numeric(12,2),
  weight uuid
);

-- asset: 10 columns
CREATE TABLE asset (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  project_history_id bigint REFERENCES project_history(id),
  phone timestamptz,
  amount text,
  is_active char(2),
  label varchar(255) NOT NULL,
  expires_at boolean,
  metadata uuid
);

CREATE TABLE legacy_claim (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  archived_carrier_history_id bigint REFERENCES archived_carrier_history(id),
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  archived_asset_config_id bigint REFERENCES archived_asset_config(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  v2_invoice_meta_id bigint NOT NULL REFERENCES v2_invoice_meta(id),
  quantity varchar(255) NOT NULL,
  is_active boolean,
  kind text,
  updated_at date,
  created_at timestamp,
  metadata uuid NOT NULL,
  price integer NOT NULL,
  UNIQUE (created_at)
);

CREATE TABLE audit_detail (
  id bigint PRIMARY KEY,
  is_default jsonb,
  created_at jsonb NOT NULL,
  locale timestamptz,
  metadata text NOT NULL,
  status bigint,
  deleted_at smallint NOT NULL,
  currency smallint,
  currency_8 double precision
);

-- notification_snapshot: 12 columns
CREATE TABLE "public"."notification_snapshot" (
  id bigint PRIMARY KEY,
  legacy_ticket_id bigint NOT NULL REFERENCES legacy_ticket(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  position bigint,
  is_active boolean NOT NULL,
  created_at timestamptz,
  starts_at inet NOT NULL,
  locale double precision,
  total boolean,
  body varchar(64) NOT NULL,
  expires_at integer NOT NULL,
  locale_9 timestamptz NOT NULL,
  UNIQUE (locale_9)
);

CREATE TABLE archived_session_item (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  updated_at integer,
  label integer NOT NULL,
  is_active bigint
);
/* trailing block comment */

CREATE TABLE carrier_link (
  id bigint PRIMARY KEY,
  inventory_history_id bigint NOT NULL REFERENCES inventory_history(id),
  v2_notification_id bigint NOT NULL REFERENCES v2_notification(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  slug varchar(64) NOT NULL,
  is_default double precision,
  position timestamptz,
  currency bytea NOT NULL,
  UNIQUE (archived_policy_id)
);

-- staging_invoice_audit: 6 columns
CREATE TABLE staging_invoice_audit (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  kind jsonb,
  locale text,
  weight text,
  status bytea,
  UNIQUE (kind)
);

CREATE TABLE archived_payment_link (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  body varchar(64),
  status smallint NOT NULL,
  updated_at date
);
/* trailing block comment */

CREATE TABLE subscription_snapshot (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  title boolean,
  note smallint,
  label timestamptz
);

CREATE TABLE review_config (
  id bigint PRIMARY KEY,
  staging_tag_meta_id bigint NOT NULL REFERENCES staging_tag_meta(id),
  updated_at varchar(255) NOT NULL,
  title timestamp,
  label uuid,
  checksum char(2) NOT NULL,
  label_5 timestamp NOT NULL,
  currency boolean,
  code jsonb,
  slug smallint
);

CREATE TABLE staging_notification (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  rate char(2) NOT NULL,
  status bigint,
  label varchar(64),
  label_4 varchar(255)
);

CREATE TABLE vehicle_link (
  id bigint PRIMARY KEY,
  archived_policy_id bigint REFERENCES archived_policy(id),
  locale timestamp NOT NULL,
  rate inet,
  is_locked smallint,
  amount varchar(255)
);
/* trailing block comment */

-- route_line: 4 columns
CREATE TABLE route_line (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  email inet,
  timezone timestamptz NOT NULL,
  UNIQUE (timezone)
);

CREATE TABLE external_inventory (
  id bigint PRIMARY KEY,
  inventory_audit_id bigint,
  v2_claim_config_id bigint REFERENCES v2_claim_config(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  staging_payment_snapshot_id bigint NOT NULL REFERENCES staging_payment_snapshot(id),
  status timestamptz NOT NULL,
  locale integer NOT NULL,
  email text NOT NULL,
  checksum date,
  quantity bigint NOT NULL
);

-- message_detail: 10 columns
CREATE TABLE message_detail (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  email boolean NOT NULL,
  expires_at bigint NOT NULL,
  is_active timestamptz NOT NULL,
  rate bytea,
  checksum bytea NOT NULL,
  title bytea
);

CREATE TABLE archived_notification_snapshot (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  staging_booking_snapshot_id bigint NOT NULL REFERENCES staging_booking_snapshot(id),
  project_history_id bigint REFERENCES project_history(id),
  shipment_id bigint NOT NULL,
  phone bytea,
  price char(2),
  expires_at timestamptz NOT NULL
);

CREATE TABLE v2_vendor (
  id bigint PRIMARY KEY,
  staging_refund_line_id bigint NOT NULL,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  legacy_discount_snapshot_id bigint NOT NULL,
  archived_account_audit_id bigint NOT NULL,
  email numeric(12,2),
  note timestamptz,
  is_active timestamptz NOT NULL,
  UNIQUE (note)
);

CREATE TABLE staging_audit_history (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  timezone bigint,
  position timestamptz,
  body smallint,
  updated_at double precision NOT NULL,
  is_default date,
  slug integer NOT NULL,
  is_active uuid,
  email boolean,
  total boolean
);

CREATE TABLE template_audit (
  id bigint PRIMARY KEY,
  locale jsonb,
  status integer NOT NULL,
  note varchar(255) NOT NULL,
  UNIQUE (status)
);

CREATE TABLE legacy_attachment (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  updated_at timestamp NOT NULL,
  slug inet,
  slug_3 integer,
  name inet NOT NULL,
  phone date
);

CREATE TABLE staging_session_meta (
  id bigint PRIMARY KEY,
  tag_detail_id bigint NOT NULL REFERENCES tag_detail(id),
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  v2_shipment_line_id bigint NOT NULL REFERENCES v2_shipment_line(id),
  invoice_config_id bigint NOT NULL,
  subscription_meta_id bigint REFERENCES subscription_meta(id),
  inventory_line_id bigint NOT NULL REFERENCES inventory_line(id),
  external_ref char(2),
  created_at bytea,
  kind char(2),
  body date,
  total boolean NOT NULL,
  kind_6 inet,
  weight smallint NOT NULL,
  amount timestamptz NOT NULL
);

CREATE TABLE legacy_review_link (
  id bigint PRIMARY KEY,
  staging_tag_id bigint REFERENCES staging_tag(id),
  timezone date,
  amount timestamptz NOT NULL,
  updated_at varchar(64) NOT NULL,
  is_active double precision
);

-- v2_vendor_config: 7 columns
CREATE TABLE "public"."v2_vendor_config" (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  total double precision,
  total_2 varchar(255) NOT NULL,
  updated_at uuid,
  is_default bigint
);

CREATE TABLE archived_task (
  id bigint PRIMARY KEY,
  external_category_id bigint,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  position timestamptz NOT NULL,
  status date,
  starts_at varchar(255),
  checksum char(2) NOT NULL,
  body char(2) NOT NULL,
  slug varchar(255),
  slug_7 timestamptz,
  weight boolean NOT NULL
);

-- category_config: 10 columns
CREATE TABLE category_config (
  id bigint PRIMARY KEY,
  external_ref timestamp,
  is_default jsonb NOT NULL,
  amount boolean,
  quantity timestamp,
  updated_at text,
  metadata uuid NOT NULL,
  email boolean,
  total jsonb NOT NULL,
  starts_at text
);

CREATE TABLE external_payment_history (
  id bigint PRIMARY KEY,
  name smallint NOT NULL,
  deleted_at varchar(255),
  created_at bytea,
  amount date,
  total bigint NOT NULL,
  external_ref timestamptz NOT NULL
);

CREATE TABLE notification_detail (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  is_active numeric(12,2),
  kind char(2),
  external_ref varchar(255) NOT NULL,
  label text
);

CREATE TABLE document_meta (
  id bigint PRIMARY KEY,
  external_claim_meta_id bigint REFERENCES external_claim_meta(id),
  discount_id bigint REFERENCES discount(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  label char(2),
  is_locked numeric(12,2),
  currency jsonb
);

CREATE TABLE staging_review_item (
  id bigint PRIMARY KEY,
  product_carrier_id bigint REFERENCES product_carrier(id),
  order_audit_id bigint NOT NULL REFERENCES order_audit(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  booking_snapshot_id bigint NOT NULL REFERENCES booking_snapshot(id),
  legacy_project_line_id bigint NOT NULL REFERENCES legacy_project_line(id),
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  label char(2),
  locale text,
  note boolean,
  UNIQUE (discount_id)
);
/* trailing block comment */

CREATE TABLE v2_warehouse (
  id bigint PRIMARY KEY,
  rate double precision NOT NULL,
  body double precision,
  code date NOT NULL
);
/* trailing block comment */

-- archived_template_audit: 12 columns
CREATE TABLE archived_template_audit (
  id bigint PRIMARY KEY,
  v2_refund_id bigint,
  notification_audit_id bigint NOT NULL,
  archived_message_id bigint NOT NULL REFERENCES archived_message(id),
  project_history_id bigint NOT NULL,
  review_detail_id bigint REFERENCES review_detail(id),
  status integer,
  email bytea NOT NULL,
  total bigint,
  metadata smallint,
  email_5 varchar(255) NOT NULL,
  weight jsonb
);

CREATE TABLE staging_channel_meta (
  id bigint PRIMARY KEY,
  external_attachment_history_id bigint NOT NULL REFERENCES external_attachment_history(id),
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  rate varchar(255) NOT NULL,
  slug integer,
  amount varchar(64) NOT NULL,
  deleted_at numeric(12,2),
  status text NOT NULL,
  weight varchar(64) NOT NULL,
  code bytea NOT NULL,
  phone boolean NOT NULL,
  starts_at date NOT NULL
);

CREATE TABLE "staging_audit_detail" (
  id bigint PRIMARY KEY,
  note text NOT NULL,
  body timestamp,
  version varchar(255),
  deleted_at timestamp,
  is_default jsonb,
  expires_at text,
  is_locked jsonb,
  note_8 integer NOT NULL,
  label date,
  version_10 numeric(12,2)
);

CREATE TABLE external_category_link (
  id bigint PRIMARY KEY,
  product_item_id bigint NOT NULL REFERENCES product_item(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  starts_at varchar(64),
  name text,
  created_at varchar(255),
  rate jsonb,
  phone numeric(12,2),
  name_6 bytea,
  created_at_7 smallint
);

CREATE TABLE campaign_config (
  id bigint PRIMARY KEY,
  legacy_audit_link_id bigint NOT NULL REFERENCES legacy_audit_link(id),
  discount_id bigint NOT NULL,
  created_at jsonb,
  expires_at boolean,
  updated_at bytea NOT NULL,
  deleted_at integer NOT NULL,
  name date NOT NULL,
  code varchar(255) NOT NULL,
  total integer,
  quantity bytea,
  UNIQUE (discount_id)
);

CREATE TABLE "public"."external_order_link" (
  id bigint PRIMARY KEY,
  archived_notification_config_id bigint NOT NULL,
  deleted_at numeric(12,2) NOT NULL,
  expires_at inet NOT NULL,
  name uuid NOT NULL,
  amount varchar(255) NOT NULL,
  locale uuid,
  starts_at integer NOT NULL,
  position numeric(12,2) NOT NULL,
  UNIQUE (amount)
);

-- archived_inventory: 13 columns
CREATE TABLE archived_inventory (
  id bigint PRIMARY KEY,
  archived_vendor_meta_id bigint REFERENCES archived_vendor_meta(id),
  v2_refund_id bigint,
  channel_config_id bigint REFERENCES channel_config(id),
  created_at text,
  code jsonb,
  name integer,
  deleted_at bytea,
  slug varchar(255),
  is_active numeric(12,2) NOT NULL,
  external_ref varchar(255),
  metadata uuid NOT NULL,
  checksum jsonb NOT NULL
);

CREATE TABLE v2_session_item (
  id bigint PRIMARY KEY,
  v2_document_line_id bigint NOT NULL REFERENCES v2_document_line(id),
  created_at char(2) NOT NULL,
  status boolean,
  currency timestamptz,
  price numeric(12,2) NOT NULL,
  metadata date,
  total varchar(64),
  position integer NOT NULL,
  currency_8 text NOT NULL
);

CREATE TABLE review (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  v2_discount_audit_id bigint REFERENCES v2_discount_audit(id),
  deleted_at date NOT NULL,
  weight integer NOT NULL,
  is_locked bytea NOT NULL,
  checksum jsonb NOT NULL,
  updated_at double precision,
  code inet,
  code_7 numeric(12,2) NOT NULL,
  timezone double precision NOT NULL
);

CREATE TABLE template (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  is_active bytea,
  metadata inet,
  total smallint,
  is_default double precision NOT NULL,
  locale varchar(255),
  version boolean,
  starts_at timestamp
);

CREATE TABLE staging_department_detail (
  id bigint PRIMARY KEY,
  route_project_id bigint REFERENCES route_project(id),
  quantity varchar(64),
  weight uuid NOT NULL,
  body numeric(12,2) NOT NULL,
  currency smallint
);

CREATE TABLE session_detail (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  code uuid,
  quantity smallint,
  is_active uuid,
  kind smallint,
  total smallint
);

CREATE TABLE v2_employee_meta (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  staging_employee_meta_id bigint NOT NULL REFERENCES staging_employee_meta(id),
  starts_at text,
  checksum double precision,
  name bigint NOT NULL,
  email double precision NOT NULL,
  total char(2),
  starts_at_6 inet,
  created_at bytea NOT NULL
);

CREATE TABLE vendor (
  id bigint PRIMARY KEY,
  quantity bytea,
  title numeric(12,2) NOT NULL,
  quantity_3 text,
  phone double precision,
  expires_at varchar(64) NOT NULL,
  weight char(2) NOT NULL,
  metadata numeric(12,2),
  body timestamptz NOT NULL,
  checksum text NOT NULL,
  is_default boolean
);

-- external_discount_meta: 9 columns
CREATE TABLE external_discount_meta (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  invoice_config_id bigint,
  checksum timestamptz,
  is_default date,
  price numeric(12,2),
  code uuid NOT NULL,
  checksum_5 uuid NOT NULL,
  note uuid NOT NULL
);

CREATE TABLE public.archived_account (
  id bigint PRIMARY KEY,
  booking_line_id bigint,
  deleted_at integer NOT NULL,
  is_default char(2) NOT NULL
);
/* trailing block comment */

-- legacy_task: 7 columns
CREATE TABLE legacy_task (
  id bigint PRIMARY KEY,
  position text,
  locale numeric(12,2) NOT NULL,
  deleted_at numeric(12,2) NOT NULL,
  price bytea,
  metadata timestamptz NOT NULL,
  status boolean,
  UNIQUE (locale)
);

CREATE TABLE legacy_warehouse (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  deleted_at date NOT NULL,
  created_at jsonb,
  price varchar(64),
  price_4 uuid,
  name double precision NOT NULL,
  expires_at jsonb,
  starts_at smallint,
  weight varchar(255) NOT NULL,
  body varchar(255) NOT NULL
);

CREATE TABLE archived_category_audit (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  version boolean,
  created_at char(2),
  name double precision NOT NULL,
  amount timestamp,
  position char(2),
  deleted_at inet,
  UNIQUE (v2_refund_audit_id)
);

CREATE TABLE "external_shipment_leg_line" (
  id bigint PRIMARY KEY,
  staging_discount_item_id bigint NOT NULL REFERENCES staging_discount_item(id),
  legacy_channel_history_id bigint REFERENCES legacy_channel_history(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  v2_order_id bigint NOT NULL REFERENCES v2_order(id),
  slug smallint NOT NULL,
  total timestamp NOT NULL,
  is_default smallint,
  quantity bytea NOT NULL,
  code timestamp,
  expires_at boolean NOT NULL,
  UNIQUE (expires_at)
);

CREATE TABLE "public"."archived_attachment_config" (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  v2_audit_item_id bigint NOT NULL,
  v2_asset_config_id bigint NOT NULL REFERENCES v2_asset_config(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  label varchar(64) NOT NULL,
  quantity uuid,
  is_locked timestamp NOT NULL,
  rate bytea NOT NULL,
  note jsonb NOT NULL,
  email bigint NOT NULL,
  expires_at inet,
  currency timestamptz,
  weight varchar(255),
  UNIQUE (weight)
);

CREATE TABLE v2_vendor_item (
  id bigint PRIMARY KEY,
  archived_template_audit_id bigint NOT NULL,
  staging_route_meta_id bigint REFERENCES staging_route_meta(id),
  is_default timestamp,
  total smallint,
  external_ref timestamp
);

CREATE TABLE channel (
  id bigint PRIMARY KEY,
  subscription_meta_id bigint REFERENCES subscription_meta(id),
  position integer,
  created_at inet,
  created_at_3 integer,
  is_active varchar(255) NOT NULL
);

CREATE TABLE staging_campaign_history (
  id bigint PRIMARY KEY,
  booking_line_id bigint REFERENCES booking_line(id),
  status double precision,
  body varchar(255),
  is_locked char(2),
  code timestamp,
  version text,
  kind smallint,
  title bigint,
  deleted_at date,
  UNIQUE (booking_line_id)
);
/* trailing block comment */

-- external_warehouse: 12 columns
CREATE TABLE external_warehouse (
  id bigint PRIMARY KEY,
  audit_config_id bigint REFERENCES audit_config(id),
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  external_ref jsonb,
  quantity bigint,
  weight bigint NOT NULL,
  status timestamp NOT NULL,
  weight_5 timestamp,
  amount char(2),
  body boolean,
  deleted_at double precision NOT NULL
);

CREATE TABLE legacy_order (
  id bigint PRIMARY KEY,
  template_history_id bigint NOT NULL REFERENCES template_history(id),
  price jsonb,
  body double precision NOT NULL
);

-- archived_message_audit: 8 columns
CREATE TABLE archived_message_audit (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  v2_policy_id bigint NOT NULL REFERENCES v2_policy(id),
  is_active text NOT NULL,
  total char(2) NOT NULL,
  currency timestamp,
  weight uuid,
  is_default date
);

CREATE TABLE public.external_policy_config (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL,
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  project_history_id bigint REFERENCES project_history(id),
  body varchar(255),
  is_locked varchar(255),
  position timestamp NOT NULL,
  total timestamp,
  price timestamp,
  title varchar(64) NOT NULL,
  external_ref numeric(12,2) NOT NULL,
  position_8 smallint
);

CREATE TABLE refund_detail (
  id bigint PRIMARY KEY,
  legacy_session_snapshot_id bigint REFERENCES legacy_session_snapshot(id),
  version smallint,
  currency timestamptz,
  locale timestamp NOT NULL,
  title uuid NOT NULL,
  email char(2),
  note jsonb NOT NULL,
  quantity boolean,
  status timestamp,
  kind numeric(12,2)
);

CREATE TABLE legacy_inventory_history (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  archived_account_audit_id bigint NOT NULL,
  title text,
  name bytea,
  body char(2),
  deleted_at numeric(12,2) NOT NULL,
  phone inet,
  kind integer NOT NULL,
  deleted_at_7 date,
  total integer,
  is_default date NOT NULL
);

CREATE TABLE v2_contract_detail (
  id bigint PRIMARY KEY,
  archived_contract_id bigint NOT NULL REFERENCES archived_contract(id),
  metadata uuid NOT NULL,
  quantity timestamp NOT NULL,
  UNIQUE (quantity)
);

CREATE TABLE v2_template_meta (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  phone timestamptz,
  external_ref bytea NOT NULL,
  amount inet NOT NULL,
  expires_at uuid,
  weight numeric(12,2),
  UNIQUE (weight)
);

-- message_config: 12 columns
CREATE TABLE message_config (
  id bigint PRIMARY KEY,
  tag_link_id bigint REFERENCES tag_link(id),
  refund_audit_id bigint,
  expires_at jsonb,
  kind double precision,
  rate date NOT NULL,
  checksum timestamp NOT NULL,
  position text,
  price text NOT NULL,
  title double precision,
  code integer,
  expires_at_9 varchar(255) NOT NULL
);

CREATE TABLE legacy_template_detail (
  id bigint PRIMARY KEY,
  total bytea NOT NULL,
  name double precision NOT NULL,
  timezone char(2),
  email integer NOT NULL,
  UNIQUE (email)
);

CREATE TABLE legacy_review_config (
  id bigint PRIMARY KEY,
  updated_at numeric(12,2),
  body varchar(255),
  currency varchar(64) NOT NULL,
  weight timestamptz,
  note numeric(12,2),
  title numeric(12,2) NOT NULL,
  starts_at bigint
);

CREATE TABLE v2_campaign_audit (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  email text,
  phone timestamptz NOT NULL,
  is_active smallint NOT NULL,
  name varchar(64),
  deleted_at date NOT NULL,
  timezone bigint,
  status smallint NOT NULL
);

-- staging_department_link: 6 columns
CREATE TABLE staging_department_link (
  id bigint PRIMARY KEY,
  locale varchar(64),
  body varchar(255),
  metadata bigint,
  currency inet,
  deleted_at boolean NOT NULL
);

CREATE TABLE archived_shipment (
  id bigint PRIMARY KEY,
  staging_audit_id bigint REFERENCES staging_audit(id),
  refund_audit_id bigint REFERENCES refund_audit(id),
  amount jsonb NOT NULL,
  is_default inet NOT NULL,
  price double precision NOT NULL,
  amount_4 uuid,
  title inet NOT NULL,
  email numeric(12,2) NOT NULL,
  slug boolean,
  deleted_at numeric(12,2) NOT NULL,
  title_9 bigint
);

-- attachment_item: 8 columns
CREATE TABLE attachment_item (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  archived_account_audit_id bigint,
  phone double precision,
  checksum boolean NOT NULL,
  expires_at jsonb,
  kind bigint,
  expires_at_5 boolean NOT NULL
);

-- attachment: 14 columns
CREATE TABLE attachment (
  id bigint PRIMARY KEY,
  product_audit_id bigint,
  booking_line_id bigint REFERENCES booking_line(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  account_config_id bigint NOT NULL,
  email double precision,
  body timestamp NOT NULL,
  note boolean,
  deleted_at date NOT NULL,
  deleted_at_5 bytea,
  name varchar(255) NOT NULL,
  kind smallint,
  code jsonb,
  expires_at bytea
);

CREATE TABLE legacy_vehicle (
  id bigint PRIMARY KEY,
  staging_policy_id bigint NOT NULL REFERENCES staging_policy(id),
  task_audit_id bigint NOT NULL REFERENCES task_audit(id),
  metadata double precision,
  label integer,
  external_ref char(2),
  metadata_4 double precision,
  timezone text,
  expires_at bytea NOT NULL,
  is_active timestamp NOT NULL,
  weight timestamp,
  price numeric(12,2) NOT NULL,
  rate date
);

-- booking_audit: 14 columns
CREATE TABLE booking_audit (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint NOT NULL,
  ticket_audit_id bigint NOT NULL REFERENCES ticket_audit(id),
  legacy_audit_meta_id bigint REFERENCES legacy_audit_meta(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  quantity varchar(255),
  title uuid NOT NULL,
  created_at integer,
  slug double precision,
  name smallint NOT NULL,
  is_default jsonb,
  amount timestamp,
  deleted_at smallint,
  price smallint NOT NULL,
  UNIQUE (is_default)
);

CREATE TABLE archived_review_link (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  v2_audit_item_id bigint,
  v2_route_id bigint NOT NULL REFERENCES v2_route(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  price jsonb,
  created_at timestamp
);
/* trailing block comment */

CREATE TABLE route (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL,
  archived_booking_meta_id bigint NOT NULL REFERENCES archived_booking_meta(id),
  staging_booking_history_id bigint NOT NULL,
  account_link_id bigint NOT NULL REFERENCES account_link(id),
  legacy_order_history_id bigint NOT NULL REFERENCES legacy_order_history(id),
  staging_category_item_id bigint NOT NULL,
  price jsonb NOT NULL,
  currency char(2) NOT NULL,
  body bytea NOT NULL,
  quantity bytea,
  body_5 integer,
  weight varchar(64),
  updated_at varchar(255)
);

CREATE TABLE legacy_payment (
  id bigint PRIMARY KEY,
  external_asset_item_id bigint REFERENCES external_asset_item(id),
  body timestamptz,
  amount integer,
  weight numeric(12,2) NOT NULL
);

-- v2_review_meta: 8 columns
CREATE TABLE v2_review_meta (
  id bigint PRIMARY KEY,
  rate double precision,
  is_default smallint NOT NULL,
  rate_3 boolean,
  currency smallint NOT NULL,
  timezone char(2),
  version boolean,
  created_at numeric(12,2)
);

CREATE TABLE legacy_contract (
  id bigint PRIMARY KEY,
  label double precision,
  currency varchar(255),
  is_default numeric(12,2),
  created_at jsonb NOT NULL,
  currency_5 jsonb,
  weight numeric(12,2) NOT NULL,
  UNIQUE (currency_5)
);

CREATE TABLE staging_booking_snapshot (
  id bigint PRIMARY KEY,
  archived_template_audit_id bigint NOT NULL REFERENCES archived_template_audit(id),
  asset_item_id bigint NOT NULL REFERENCES asset_item(id),
  warehouse_audit_id bigint NOT NULL,
  is_locked text,
  starts_at smallint,
  label numeric(12,2) NOT NULL,
  slug varchar(255) NOT NULL,
  position text,
  title varchar(64),
  title_7 bytea NOT NULL,
  starts_at_8 timestamptz
);

CREATE TABLE invoice_history (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  timezone varchar(255),
  created_at double precision NOT NULL,
  timezone_3 boolean NOT NULL,
  is_active varchar(64) NOT NULL
);

-- external_shipment_detail: 6 columns
CREATE TABLE external_shipment_detail (
  id bigint PRIMARY KEY,
  staging_message_id bigint NOT NULL,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  currency inet,
  version numeric(12,2) NOT NULL,
  price inet
);
/* trailing block comment */

-- legacy_discount_snapshot: 9 columns
CREATE TABLE legacy_discount_snapshot (
  id bigint PRIMARY KEY,
  booking_line_id bigint REFERENCES booking_line(id),
  amount boolean,
  label jsonb,
  updated_at varchar(255) NOT NULL,
  position uuid,
  is_locked varchar(255) NOT NULL,
  phone text NOT NULL,
  amount_7 inet NOT NULL
);

CREATE TABLE message_link (
  id bigint PRIMARY KEY,
  legacy_carrier_id bigint NOT NULL REFERENCES legacy_carrier(id),
  document_id bigint NOT NULL REFERENCES document(id),
  staging_notification_config_id bigint NOT NULL,
  email timestamptz NOT NULL,
  metadata double precision NOT NULL,
  label bigint NOT NULL,
  is_default inet,
  currency smallint NOT NULL,
  price jsonb NOT NULL,
  is_locked double precision,
  created_at text
);

-- staging_message_link: 10 columns
CREATE TABLE staging_message_link (
  id bigint PRIMARY KEY,
  v2_document_id bigint REFERENCES v2_document(id),
  legacy_session_id bigint REFERENCES legacy_session(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  label boolean,
  position char(2),
  weight varchar(64),
  code jsonb NOT NULL,
  amount bigint,
  position_6 timestamptz,
  UNIQUE (code)
);

CREATE TABLE subscription_config (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  legacy_employee_link_id bigint NOT NULL REFERENCES legacy_employee_link(id),
  archived_claim_history_id bigint,
  archived_order_id bigint REFERENCES archived_order(id),
  project_history_id bigint NOT NULL,
  customer_snapshot_id bigint NOT NULL,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  external_ref varchar(255) NOT NULL,
  currency text NOT NULL
);

-- asset_meta: 11 columns
CREATE TABLE asset_meta (
  id bigint PRIMARY KEY,
  legacy_ticket_id bigint NOT NULL REFERENCES legacy_ticket(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  amount jsonb,
  created_at text NOT NULL,
  currency bytea,
  slug integer,
  timezone numeric(12,2) NOT NULL,
  kind numeric(12,2) NOT NULL,
  body varchar(255),
  locale timestamp
);

CREATE TABLE invoice_item (
  id bigint PRIMARY KEY,
  task_snapshot_id bigint REFERENCES task_snapshot(id),
  archived_order_id bigint NOT NULL,
  note timestamptz NOT NULL,
  version double precision NOT NULL,
  metadata date,
  name integer NOT NULL
);

CREATE TABLE archived_shipment_leg_detail (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  v2_carrier_detail_id bigint REFERENCES v2_carrier_detail(id),
  email bigint,
  weight text,
  external_ref timestamp NOT NULL,
  is_locked inet,
  label integer NOT NULL,
  metadata text NOT NULL
);

-- employee: 14 columns
CREATE TABLE employee (
  id bigint PRIMARY KEY,
  payment_config_id bigint NOT NULL REFERENCES payment_config(id),
  legacy_product_id bigint NOT NULL REFERENCES legacy_product(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  position double precision,
  is_active bytea NOT NULL,
  starts_at double precision NOT NULL,
  position_4 bytea,
  is_locked jsonb,
  weight inet,
  label double precision NOT NULL,
  status varchar(64),
  label_9 boolean,
  code varchar(64) NOT NULL
);

CREATE TABLE product_line (
  id bigint PRIMARY KEY,
  v2_ticket_link_id bigint NOT NULL REFERENCES v2_ticket_link(id),
  body timestamp NOT NULL,
  expires_at varchar(64),
  status inet NOT NULL,
  metadata date,
  is_default date,
  title boolean
);

CREATE TABLE booking_config (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL,
  customer_audit_id bigint NOT NULL REFERENCES customer_audit(id),
  title char(2),
  position text,
  slug varchar(64),
  slug_4 smallint,
  email integer NOT NULL,
  body date,
  phone timestamptz,
  created_at char(2) NOT NULL,
  note char(2),
  updated_at timestamp,
  UNIQUE (customer_audit_id)
);

-- review_snapshot: 5 columns
CREATE TABLE review_snapshot (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  is_default inet,
  total double precision NOT NULL,
  email double precision
);
/* trailing block comment */

CREATE TABLE archived_task_detail (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  archived_policy_id bigint REFERENCES archived_policy(id),
  updated_at bytea,
  checksum timestamptz NOT NULL,
  phone inet NOT NULL,
  UNIQUE (checksum)
);

CREATE TABLE archived_contract (
  id bigint PRIMARY KEY,
  locale text,
  created_at inet NOT NULL,
  kind bytea,
  checksum text,
  locale_5 text,
  locale_6 integer NOT NULL,
  deleted_at bigint,
  timezone varchar(64),
  label smallint NOT NULL,
  UNIQUE (locale)
);

CREATE TABLE account_detail (
  id bigint PRIMARY KEY,
  v2_account_id bigint NOT NULL REFERENCES v2_account(id),
  code bytea,
  status varchar(64),
  rate timestamptz,
  is_default date NOT NULL,
  title char(2) NOT NULL,
  code_6 varchar(64),
  is_locked uuid,
  UNIQUE (rate)
);

CREATE TABLE public.project (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  project_history_id bigint REFERENCES project_history(id),
  email integer NOT NULL,
  note boolean,
  updated_at inet,
  created_at varchar(255),
  position inet NOT NULL,
  total boolean NOT NULL,
  title timestamp
);

CREATE TABLE v2_contract_config (
  id bigint PRIMARY KEY,
  archived_vendor_item_id bigint NOT NULL,
  timezone date,
  external_ref jsonb,
  name date,
  metadata jsonb,
  name_5 bigint NOT NULL,
  timezone_6 boolean,
  is_locked varchar(255) NOT NULL
);

CREATE TABLE vehicle_audit (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  total timestamp NOT NULL,
  deleted_at bytea NOT NULL,
  version varchar(255) NOT NULL,
  deleted_at_4 boolean NOT NULL,
  status varchar(64) NOT NULL
);

CREATE TABLE archived_order_snapshot (
  id bigint PRIMARY KEY,
  invoice_config_id bigint REFERENCES invoice_config(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  is_default inet,
  external_ref varchar(64),
  version integer,
  rate double precision NOT NULL,
  price timestamptz
);

CREATE TABLE archived_account_history (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL,
  note smallint,
  slug date,
  email timestamptz
);

CREATE TABLE staging_invoice (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint NOT NULL,
  is_active jsonb NOT NULL,
  starts_at varchar(255) NOT NULL,
  deleted_at char(2),
  title bigint NOT NULL,
  timezone bigint,
  starts_at_6 numeric(12,2) NOT NULL,
  email integer NOT NULL,
  UNIQUE (deleted_at)
);

-- customer_audit: 8 columns
CREATE TABLE customer_audit (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL,
  invoice_config_id bigint NOT NULL,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  amount timestamp,
  checksum double precision,
  checksum_3 inet NOT NULL,
  UNIQUE (v2_refund_audit_id)
);

-- legacy_discount_config: 6 columns
CREATE TABLE legacy_discount_config (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  name varchar(255),
  created_at double precision,
  label timestamp
);

CREATE TABLE order_history (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  task_id bigint NOT NULL REFERENCES task(id),
  created_at jsonb NOT NULL,
  is_default varchar(255),
  label timestamp,
  price bigint,
  is_locked timestamptz NOT NULL,
  locale double precision NOT NULL,
  note bytea
);
/* trailing block comment */

CREATE TABLE archived_document_audit (
  id bigint PRIMARY KEY,
  created_at timestamptz,
  total char(2),
  kind bytea,
  name char(2),
  note bytea
);

-- archived_department: 7 columns
CREATE TABLE archived_department (
  id bigint PRIMARY KEY,
  discount_id bigint REFERENCES discount(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  v2_refund_id bigint REFERENCES v2_refund(id),
  status text NOT NULL,
  version text,
  is_locked integer NOT NULL
);

CREATE TABLE customer_history (
  id bigint PRIMARY KEY,
  v2_asset_config_id bigint NOT NULL REFERENCES v2_asset_config(id),
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  legacy_account_id bigint NOT NULL,
  tag_link_id bigint REFERENCES tag_link(id),
  phone bigint,
  currency uuid,
  slug jsonb,
  slug_4 jsonb NOT NULL,
  price uuid,
  expires_at uuid,
  quantity bytea,
  currency_8 double precision
);

-- archived_discount_link: 14 columns
CREATE TABLE "public"."archived_discount_link" (
  id bigint PRIMARY KEY,
  external_message_detail_id bigint NOT NULL REFERENCES external_message_detail(id),
  legacy_claim_history_id bigint NOT NULL REFERENCES legacy_claim_history(id),
  external_template_detail_id bigint REFERENCES external_template_detail(id),
  staging_ticket_link_id bigint NOT NULL REFERENCES staging_ticket_link(id),
  timezone bigint NOT NULL,
  deleted_at text,
  body uuid NOT NULL,
  version smallint,
  checksum timestamp NOT NULL,
  body_6 char(2),
  deleted_at_7 varchar(64) NOT NULL,
  slug numeric(12,2) NOT NULL,
  deleted_at_9 varchar(255) NOT NULL
);
/* trailing block comment */

CREATE TABLE claim_contract (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  staging_customer_audit_id bigint,
  email double precision NOT NULL,
  price boolean,
  label boolean,
  is_locked jsonb,
  checksum uuid
);

CREATE TABLE "staging_product" (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  deleted_at bytea,
  rate varchar(64) NOT NULL,
  is_active bytea,
  locale timestamp
);

-- v2_inventory_item: 8 columns
CREATE TABLE v2_inventory_item (
  id bigint PRIMARY KEY,
  v2_campaign_audit_id bigint NOT NULL REFERENCES v2_campaign_audit(id),
  staging_invoice_audit_id bigint NOT NULL REFERENCES staging_invoice_audit(id),
  v2_claim_item_id bigint NOT NULL REFERENCES v2_claim_item(id),
  is_active inet,
  is_locked varchar(64) NOT NULL,
  status bytea NOT NULL,
  body double precision NOT NULL
);

CREATE TABLE staging_inventory_history (
  id bigint PRIMARY KEY,
  title timestamptz NOT NULL,
  email varchar(64) NOT NULL,
  locale timestamptz,
  body boolean NOT NULL,
  deleted_at date,
  label integer,
  is_locked timestamp NOT NULL,
  currency uuid
);
/* trailing block comment */

CREATE TABLE refund_item (
  id bigint PRIMARY KEY,
  staging_message_link_id bigint NOT NULL REFERENCES staging_message_link(id),
  staging_policy_history_id bigint REFERENCES staging_policy_history(id),
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  archived_order_snapshot_id bigint,
  slug varchar(64) NOT NULL,
  rate date NOT NULL,
  UNIQUE (staging_policy_history_id)
);

CREATE TABLE legacy_session_snapshot (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  v2_review_history_id bigint REFERENCES v2_review_history(id),
  weight integer NOT NULL,
  external_ref integer,
  status boolean NOT NULL,
  email bytea,
  is_locked smallint,
  locale boolean,
  email_7 text
);
/* trailing block comment */

-- channel_audit: 11 columns
CREATE TABLE channel_audit (
  id bigint PRIMARY KEY,
  total inet NOT NULL,
  deleted_at date,
  is_locked inet,
  deleted_at_4 timestamp,
  is_default double precision NOT NULL,
  total_6 varchar(64),
  note text NOT NULL,
  total_8 varchar(64),
  created_at numeric(12,2),
  weight varchar(64)
);

CREATE TABLE external_attachment_meta (
  id bigint PRIMARY KEY,
  phone jsonb,
  kind text,
  is_active inet NOT NULL,
  is_default smallint,
  status varchar(64) NOT NULL,
  note varchar(255) NOT NULL,
  phone_7 bigint,
  slug bytea,
  slug_9 numeric(12,2),
  UNIQUE (phone)
);

CREATE TABLE attachment_snapshot (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  created_at smallint NOT NULL,
  rate double precision,
  checksum numeric(12,2),
  slug integer,
  created_at_5 text,
  rate_6 smallint,
  is_default timestamptz NOT NULL,
  starts_at integer NOT NULL
);

CREATE TABLE project_config (
  id bigint PRIMARY KEY,
  label jsonb,
  code integer,
  status uuid NOT NULL,
  slug char(2),
  metadata text,
  currency timestamptz,
  starts_at smallint NOT NULL,
  slug_8 bytea
);

CREATE TABLE staging_channel_line (
  id bigint PRIMARY KEY,
  price char(2),
  status integer,
  weight varchar(64),
  metadata smallint NOT NULL,
  title text,
  body bigint,
  status_7 smallint,
  note varchar(255) NOT NULL,
  slug smallint
);

CREATE TABLE payment_link (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  campaign_audit_id bigint,
  metadata timestamp NOT NULL,
  created_at numeric(12,2) NOT NULL,
  email boolean NOT NULL,
  email_4 text NOT NULL
);

CREATE TABLE staging_template (
  id bigint PRIMARY KEY,
  legacy_order_detail_id bigint NOT NULL REFERENCES legacy_order_detail(id),
  archived_account_audit_id bigint,
  attachment_audit_id bigint REFERENCES attachment_audit(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  name timestamp,
  amount uuid,
  code inet,
  is_active bytea NOT NULL,
  expires_at char(2),
  UNIQUE (attachment_audit_id)
);

-- shipment_leg_audit: 7 columns
CREATE TABLE shipment_leg_audit (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  title varchar(255),
  is_active timestamptz NOT NULL,
  is_locked bytea,
  rate jsonb
);

CREATE TABLE legacy_subscription_line (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  currency date,
  updated_at bigint
);
/* trailing block comment */

CREATE TABLE subscription_meta (
  id bigint PRIMARY KEY,
  slug char(2) NOT NULL,
  slug_2 text,
  price boolean
);

-- shipment_detail: 12 columns
CREATE TABLE shipment_detail (
  id bigint PRIMARY KEY,
  invoice_config_id bigint,
  weight jsonb,
  is_locked smallint,
  slug integer NOT NULL,
  total timestamp,
  weight_5 inet NOT NULL,
  is_active char(2) NOT NULL,
  code double precision NOT NULL,
  version smallint NOT NULL,
  external_ref date NOT NULL,
  position timestamptz NOT NULL
);

-- tag_line: 7 columns
CREATE TABLE tag_line (
  id bigint PRIMARY KEY,
  name numeric(12,2),
  timezone varchar(64),
  position boolean,
  metadata bigint NOT NULL,
  expires_at uuid,
  label boolean
);

CREATE TABLE legacy_route_item (
  id bigint PRIMARY KEY,
  external_template_detail_id bigint NOT NULL REFERENCES external_template_detail(id),
  expires_at double precision,
  is_active numeric(12,2),
  starts_at timestamp,
  title bigint,
  amount timestamptz,
  currency timestamp
);

CREATE TABLE v2_claim_snapshot (
  id bigint PRIMARY KEY,
  tag_link_id bigint,
  kind smallint,
  rate integer,
  position varchar(64) NOT NULL,
  code uuid NOT NULL,
  UNIQUE (position)
);

CREATE TABLE "public"."contract" (
  id bigint PRIMARY KEY,
  v2_employee_detail_id bigint REFERENCES v2_employee_detail(id),
  version bigint NOT NULL,
  name boolean,
  price text NOT NULL,
  weight timestamp,
  UNIQUE (weight)
);

CREATE TABLE legacy_account_meta (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  staging_category_id bigint NOT NULL,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  starts_at timestamp,
  email bigint,
  label char(2) NOT NULL,
  deleted_at numeric(12,2),
  created_at inet NOT NULL
);

CREATE TABLE staging_carrier (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  refund_audit_id bigint REFERENCES refund_audit(id),
  version smallint NOT NULL,
  rate date NOT NULL,
  price integer NOT NULL,
  created_at date,
  label text,
  UNIQUE (price)
);

-- discount_link: 10 columns
CREATE TABLE discount_link (
  id bigint PRIMARY KEY,
  contract_audit_id bigint NOT NULL REFERENCES contract_audit(id),
  updated_at integer,
  is_locked varchar(64),
  quantity numeric(12,2),
  phone inet,
  deleted_at char(2),
  updated_at_6 char(2) NOT NULL,
  position bigint,
  is_locked_8 date NOT NULL,
  UNIQUE (deleted_at)
);

-- carrier_detail: 11 columns
CREATE TABLE carrier_detail (
  id bigint PRIMARY KEY,
  legacy_template_detail_id bigint REFERENCES legacy_template_detail(id),
  is_active date,
  is_default varchar(64),
  label uuid NOT NULL,
  total bytea,
  locale varchar(64) NOT NULL,
  label_6 varchar(64) NOT NULL,
  email date,
  currency inet NOT NULL,
  amount jsonb
);

-- archived_project_config: 6 columns
CREATE TABLE archived_project_config (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  invoice_config_id bigint,
  starts_at numeric(12,2),
  expires_at date NOT NULL,
  price timestamptz
);
/* trailing block comment */

-- legacy_vehicle_link: 6 columns
CREATE TABLE legacy_vehicle_link (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  discount_id bigint,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  code inet,
  price bigint NOT NULL
);

CREATE TABLE audit_snapshot (
  id bigint PRIMARY KEY,
  document_history_id bigint REFERENCES document_history(id),
  price varchar(64) NOT NULL,
  total inet NOT NULL,
  created_at timestamptz,
  note smallint,
  email varchar(64) NOT NULL
);

CREATE TABLE legacy_project_history (
  id bigint PRIMARY KEY,
  carrier_item_id bigint REFERENCES carrier_item(id),
  locale text,
  amount jsonb NOT NULL,
  expires_at jsonb,
  body bigint,
  created_at timestamptz,
  total varchar(255),
  updated_at char(2),
  locale_8 bytea NOT NULL
);

CREATE TABLE policy_config (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  status char(2),
  kind boolean NOT NULL,
  currency jsonb,
  position double precision NOT NULL,
  position_5 bigint NOT NULL
);

CREATE TABLE staging_invoice_line (
  id bigint PRIMARY KEY,
  inventory_line_id bigint NOT NULL REFERENCES inventory_line(id),
  deleted_at inet,
  email numeric(12,2) NOT NULL,
  is_active date NOT NULL,
  starts_at inet,
  rate text,
  phone char(2),
  is_locked double precision,
  quantity jsonb,
  expires_at timestamp NOT NULL
);

CREATE TABLE staging_carrier_detail (
  id bigint PRIMARY KEY,
  archived_claim_meta_id bigint NOT NULL REFERENCES archived_claim_meta(id),
  phone smallint NOT NULL,
  currency char(2),
  quantity varchar(64)
);

-- v2_task_detail: 6 columns
CREATE TABLE public.v2_task_detail (
  id bigint PRIMARY KEY,
  v2_refund_id bigint,
  invoice_config_id bigint,
  rate bigint,
  kind boolean,
  price timestamp NOT NULL
);

-- legacy_payment_item: 12 columns
CREATE TABLE legacy_payment_item (
  id bigint PRIMARY KEY,
  invoice_config_id bigint REFERENCES invoice_config(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  archived_product_line_id bigint NOT NULL REFERENCES archived_product_line(id),
  expires_at bytea NOT NULL,
  created_at numeric(12,2),
  expires_at_3 integer NOT NULL,
  external_ref numeric(12,2),
  rate text NOT NULL,
  email boolean,
  external_ref_7 jsonb,
  position timestamp,
  UNIQUE (position)
);

CREATE TABLE staging_channel_config (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL,
  position jsonb,
  kind varchar(64),
  total timestamptz,
  expires_at smallint,
  title varchar(64)
);
/* trailing block comment */

CREATE TABLE task_meta (
  id bigint PRIMARY KEY,
  subscription_link_id bigint NOT NULL REFERENCES subscription_link(id),
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  archived_policy_id bigint,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  metadata char(2) NOT NULL,
  note varchar(255),
  deleted_at jsonb NOT NULL,
  rate timestamp,
  position bigint NOT NULL
);

CREATE TABLE "public"."document_booking" (
  id bigint PRIMARY KEY,
  external_shipment_id bigint REFERENCES external_shipment(id),
  total text,
  version timestamp,
  status varchar(64),
  rate boolean,
  code smallint NOT NULL,
  updated_at bigint,
  label inet NOT NULL,
  slug timestamptz NOT NULL,
  starts_at smallint NOT NULL
);

CREATE TABLE staging_claim (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  booking_line_id bigint NOT NULL,
  code uuid,
  rate date,
  locale timestamptz NOT NULL,
  slug char(2) NOT NULL,
  version jsonb NOT NULL,
  email text,
  status timestamptz NOT NULL,
  label integer,
  version_9 numeric(12,2) NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_shipment_line (
  id bigint PRIMARY KEY,
  legacy_template_link_id bigint REFERENCES legacy_template_link(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  code numeric(12,2),
  note smallint,
  deleted_at double precision,
  position integer,
  deleted_at_5 varchar(64) NOT NULL,
  kind inet
);

CREATE TABLE v2_discount_audit (
  id bigint PRIMARY KEY,
  message_item_id bigint NOT NULL REFERENCES message_item(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  metadata uuid NOT NULL,
  starts_at jsonb NOT NULL,
  status timestamp,
  name timestamp,
  rate inet,
  locale uuid,
  code timestamptz NOT NULL
);

CREATE TABLE claim_detail (
  id bigint PRIMARY KEY,
  legacy_order_snapshot_id bigint NOT NULL REFERENCES legacy_order_snapshot(id),
  version inet NOT NULL,
  label char(2),
  checksum double precision,
  rate varchar(255) NOT NULL,
  status double precision,
  title char(2) NOT NULL,
  timezone char(2) NOT NULL,
  created_at boolean,
  UNIQUE (legacy_order_snapshot_id)
);

CREATE TABLE external_route_item (
  id bigint PRIMARY KEY,
  inventory_message_id bigint REFERENCES inventory_message(id),
  staging_vendor_id bigint REFERENCES staging_vendor(id),
  external_refund_audit_id bigint NOT NULL,
  order_audit_id bigint NOT NULL REFERENCES order_audit(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  weight timestamp,
  locale uuid NOT NULL,
  metadata timestamptz,
  updated_at timestamptz NOT NULL,
  title text NOT NULL,
  price uuid,
  label timestamptz
);

CREATE TABLE "external_refund_config" (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  vehicle_item_id bigint REFERENCES vehicle_item(id),
  slug timestamp,
  metadata timestamptz,
  expires_at smallint
);

CREATE TABLE public.department_link (
  id bigint PRIMARY KEY,
  notification_audit_id bigint REFERENCES notification_audit(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  starts_at bytea,
  created_at jsonb,
  is_locked date,
  expires_at varchar(64) NOT NULL,
  phone integer NOT NULL,
  starts_at_6 varchar(255) NOT NULL,
  is_default integer,
  total timestamptz NOT NULL,
  price integer,
  UNIQUE (v2_refund_audit_id)
);

CREATE TABLE order_detail (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  version timestamptz,
  is_locked timestamp,
  is_locked_3 timestamptz NOT NULL,
  name date,
  body inet NOT NULL,
  name_6 numeric(12,2),
  email double precision NOT NULL,
  phone boolean,
  created_at boolean NOT NULL
);
/* trailing block comment */

CREATE TABLE policy (
  id bigint PRIMARY KEY,
  staging_notification_id bigint REFERENCES staging_notification(id),
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  archived_contract_meta_id bigint REFERENCES archived_contract_meta(id),
  staging_audit_id bigint REFERENCES staging_audit(id),
  version timestamptz,
  body double precision,
  timezone bigint,
  body_4 inet,
  expires_at boolean,
  rate uuid,
  price varchar(255),
  quantity numeric(12,2)
);

CREATE TABLE vehicle_detail (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  starts_at double precision,
  weight bytea NOT NULL,
  quantity smallint,
  quantity_4 numeric(12,2),
  position integer NOT NULL,
  is_locked double precision,
  code bigint NOT NULL,
  version timestamptz NOT NULL,
  UNIQUE (is_locked)
);

CREATE TABLE v2_ticket_line (
  id bigint PRIMARY KEY,
  message_meta_id bigint NOT NULL,
  campaign_meta_id bigint REFERENCES campaign_meta(id),
  legacy_customer_id bigint NOT NULL REFERENCES legacy_customer(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  metadata timestamp,
  amount jsonb,
  metadata_3 timestamptz,
  label bytea,
  code double precision,
  code_6 varchar(255) NOT NULL,
  UNIQUE (legacy_customer_id)
);

CREATE TABLE external_warehouse_line (
  id bigint PRIMARY KEY,
  title text,
  created_at integer,
  label timestamp,
  timezone varchar(255)
);

CREATE TABLE route_snapshot (
  id bigint PRIMARY KEY,
  external_warehouse_id bigint NOT NULL REFERENCES external_warehouse(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  message_id bigint,
  legacy_account_id bigint REFERENCES legacy_account(id),
  kind date NOT NULL,
  currency timestamptz,
  position bytea,
  timezone jsonb NOT NULL,
  quantity numeric(12,2) NOT NULL,
  quantity_6 numeric(12,2),
  email uuid
);

CREATE TABLE staging_campaign_detail (
  id bigint PRIMARY KEY,
  discount_meta_id bigint REFERENCES discount_meta(id),
  timezone char(2),
  quantity varchar(64),
  weight text,
  weight_4 uuid NOT NULL,
  currency uuid NOT NULL,
  rate date,
  rate_7 uuid NOT NULL,
  is_locked text,
  rate_9 integer NOT NULL
);

-- payment_item: 6 columns
CREATE TABLE payment_item (
  id bigint PRIMARY KEY,
  legacy_vehicle_link_id bigint NOT NULL REFERENCES legacy_vehicle_link(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  checksum inet NOT NULL,
  starts_at inet NOT NULL,
  starts_at_3 bytea
);

-- staging_policy: 7 columns
CREATE TABLE staging_policy (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  archived_invoice_id bigint NOT NULL REFERENCES archived_invoice(id),
  external_vendor_line_id bigint NOT NULL REFERENCES external_vendor_line(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  position bigint,
  locale jsonb
);

-- external_policy_meta: 6 columns
CREATE TABLE external_policy_meta (
  id bigint PRIMARY KEY,
  channel_detail_id bigint NOT NULL REFERENCES channel_detail(id),
  timezone varchar(64) NOT NULL,
  total timestamptz,
  price varchar(255) NOT NULL,
  kind bigint NOT NULL
);

CREATE TABLE staging_discount_detail (
  id bigint PRIMARY KEY,
  kind text,
  slug date,
  quantity jsonb NOT NULL,
  weight bigint NOT NULL,
  created_at uuid,
  email double precision
);

CREATE TABLE refund_meta (
  id bigint PRIMARY KEY,
  staging_template_config_id bigint NOT NULL REFERENCES staging_template_config(id),
  external_warehouse_link_id bigint,
  checksum inet,
  phone numeric(12,2),
  checksum_3 double precision,
  is_default varchar(64),
  metadata numeric(12,2),
  deleted_at jsonb NOT NULL
);

-- external_customer_config: 11 columns
CREATE TABLE "public"."external_customer_config" (
  id bigint PRIMARY KEY,
  legacy_account_id bigint REFERENCES legacy_account(id),
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  note date NOT NULL,
  currency timestamptz,
  total double precision,
  is_active smallint,
  quantity date,
  version varchar(255) NOT NULL,
  metadata text,
  timezone smallint
);

CREATE TABLE archived_policy_audit (
  id bigint PRIMARY KEY,
  price char(2),
  position double precision,
  status date,
  price_4 integer,
  status_5 numeric(12,2),
  UNIQUE (status)
);

CREATE TABLE staging_session_link (
  id bigint PRIMARY KEY,
  archived_order_id bigint,
  amount bigint NOT NULL,
  quantity varchar(64),
  email jsonb,
  deleted_at varchar(64),
  kind integer NOT NULL,
  is_active timestamp NOT NULL,
  phone char(2)
);

CREATE TABLE v2_policy_line (
  id bigint PRIMARY KEY,
  archived_task_id bigint NOT NULL REFERENCES archived_task(id),
  v2_session_audit_id bigint NOT NULL REFERENCES v2_session_audit(id),
  v2_audit_item_id bigint NOT NULL,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  name integer,
  phone integer,
  starts_at boolean,
  total smallint,
  deleted_at varchar(255),
  phone_6 jsonb NOT NULL,
  deleted_at_7 bigint NOT NULL,
  total_8 jsonb NOT NULL,
  label smallint,
  version timestamp NOT NULL
);

CREATE TABLE external_policy (
  id bigint PRIMARY KEY,
  project_history_id bigint REFERENCES project_history(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  payment_config_id bigint NOT NULL REFERENCES payment_config(id),
  is_default boolean,
  timezone timestamp,
  locale varchar(255),
  version date NOT NULL
);

CREATE TABLE external_inventory_line (
  id bigint PRIMARY KEY,
  subscription_history_id bigint REFERENCES subscription_history(id),
  version boolean,
  weight boolean,
  is_locked uuid NOT NULL,
  currency inet NOT NULL,
  checksum bytea NOT NULL,
  quantity timestamptz
);

CREATE TABLE staging_task (
  id bigint PRIMARY KEY,
  is_locked timestamptz,
  status jsonb,
  locale bigint,
  slug text,
  code bigint,
  weight integer,
  label smallint NOT NULL,
  total date NOT NULL
);

CREATE TABLE legacy_carrier_history (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  deleted_at smallint NOT NULL,
  timezone varchar(64) NOT NULL,
  title bytea NOT NULL,
  checksum double precision NOT NULL,
  metadata char(2),
  title_6 timestamp,
  email uuid NOT NULL,
  is_default char(2) NOT NULL,
  UNIQUE (checksum)
);

-- external_shipment_audit: 9 columns
CREATE TABLE external_shipment_audit (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  note date,
  name inet,
  code text,
  metadata varchar(255),
  quantity bytea,
  external_ref numeric(12,2) NOT NULL
);
/* trailing block comment */

CREATE TABLE "refund" (
  id bigint PRIMARY KEY,
  body varchar(255) NOT NULL,
  checksum date,
  phone smallint,
  amount char(2)
);
/* trailing block comment */

-- booking: 8 columns
CREATE TABLE booking (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  staging_task_history_id bigint REFERENCES staging_task_history(id),
  label smallint,
  currency bytea NOT NULL,
  metadata boolean NOT NULL,
  kind smallint,
  body timestamptz NOT NULL
);
/* trailing block comment */

CREATE TABLE legacy_subscription_item (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  body date,
  is_locked boolean,
  phone numeric(12,2),
  locale varchar(64) NOT NULL,
  email timestamptz,
  metadata char(2),
  title smallint,
  quantity jsonb NOT NULL,
  email_9 smallint NOT NULL
);

-- subscription: 5 columns
CREATE TABLE subscription (
  id bigint PRIMARY KEY,
  body jsonb,
  phone jsonb,
  rate bigint NOT NULL,
  is_locked boolean NOT NULL
);
/* trailing block comment */

CREATE TABLE "public"."archived_category_line" (
  id bigint PRIMARY KEY,
  v2_account_line_id bigint REFERENCES v2_account_line(id),
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  amount boolean,
  rate integer NOT NULL,
  is_active bytea,
  checksum smallint NOT NULL,
  total double precision NOT NULL
);

CREATE TABLE "public"."external_template" (
  id bigint PRIMARY KEY,
  subscription_audit_id bigint NOT NULL REFERENCES subscription_audit(id),
  checksum date NOT NULL,
  created_at varchar(64),
  email bigint
);

CREATE TABLE shipment_audit (
  id bigint PRIMARY KEY,
  v2_attachment_meta_id bigint NOT NULL REFERENCES v2_attachment_meta(id),
  price bytea NOT NULL,
  status numeric(12,2) NOT NULL,
  email text
);

CREATE TABLE warehouse_detail (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  is_default date,
  title bytea NOT NULL,
  status boolean,
  price varchar(255) NOT NULL,
  updated_at double precision NOT NULL,
  note varchar(64) NOT NULL,
  note_7 smallint,
  code numeric(12,2) NOT NULL,
  locale integer NOT NULL
);

CREATE TABLE archived_subscription_meta (
  id bigint PRIMARY KEY,
  email text,
  updated_at smallint,
  quantity double precision,
  kind numeric(12,2),
  checksum bigint,
  kind_6 integer,
  position text NOT NULL,
  expires_at smallint NOT NULL,
  locale timestamptz
);

CREATE TABLE v2_channel_audit (
  id bigint PRIMARY KEY,
  archived_warehouse_item_id bigint NOT NULL REFERENCES archived_warehouse_item(id),
  kind varchar(64) NOT NULL,
  currency timestamptz NOT NULL,
  label varchar(64) NOT NULL,
  label_4 varchar(64),
  locale smallint,
  total char(2),
  weight char(2),
  starts_at boolean
);

CREATE TABLE external_channel_item (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  staging_refund_history_id bigint NOT NULL REFERENCES staging_refund_history(id),
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  status numeric(12,2),
  quantity date NOT NULL,
  external_ref text,
  timezone numeric(12,2),
  name integer,
  kind uuid,
  updated_at timestamp
);

CREATE TABLE public.archived_vendor_item (
  id bigint PRIMARY KEY,
  weight boolean,
  price text,
  external_ref smallint
);

CREATE TABLE legacy_refund_snapshot (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  shipment_leg_audit_id bigint REFERENCES shipment_leg_audit(id),
  archived_project_line_id bigint NOT NULL REFERENCES archived_project_line(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  quantity text NOT NULL,
  price date,
  code timestamptz
);

CREATE TABLE staging_booking_history (
  id bigint PRIMARY KEY,
  updated_at timestamp NOT NULL,
  weight smallint,
  metadata varchar(64) NOT NULL,
  metadata_4 varchar(64) NOT NULL,
  weight_5 double precision,
  slug integer,
  position char(2),
  amount uuid,
  position_9 uuid NOT NULL
);
/* trailing block comment */

CREATE TABLE tag_audit (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  document_id bigint NOT NULL REFERENCES document(id),
  label boolean,
  currency integer NOT NULL,
  locale uuid NOT NULL,
  price numeric(12,2) NOT NULL
);

CREATE TABLE v2_policy_meta (
  id bigint PRIMARY KEY,
  staging_channel_config_id bigint REFERENCES staging_channel_config(id),
  external_customer_id bigint NOT NULL REFERENCES external_customer(id),
  legacy_department_id bigint NOT NULL REFERENCES legacy_department(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  note uuid NOT NULL,
  phone boolean,
  price integer NOT NULL,
  title jsonb NOT NULL,
  metadata text,
  timezone varchar(64) NOT NULL,
  kind numeric(12,2),
  currency double precision NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_attachment_config (
  id bigint PRIMARY KEY,
  created_at varchar(64),
  note boolean,
  is_active varchar(64),
  price timestamptz,
  currency bytea,
  version bigint,
  UNIQUE (created_at)
);

CREATE TABLE v2_route (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  product_detail_id bigint REFERENCES product_detail(id),
  staging_review_link_id bigint REFERENCES staging_review_link(id),
  v2_vendor_meta_id bigint,
  checksum timestamp,
  rate numeric(12,2) NOT NULL,
  amount date,
  expires_at varchar(255) NOT NULL,
  phone integer,
  is_locked integer NOT NULL,
  label char(2),
  phone_8 jsonb NOT NULL,
  status boolean,
  email varchar(64)
);

CREATE TABLE staging_document_link (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  amount date,
  expires_at text NOT NULL,
  updated_at timestamp,
  deleted_at text,
  name bigint NOT NULL,
  checksum timestamp,
  note bytea,
  deleted_at_8 double precision,
  slug timestamptz NOT NULL,
  status smallint NOT NULL
);

-- v2_audit_link: 5 columns
CREATE TABLE v2_audit_link (
  id bigint PRIMARY KEY,
  legacy_audit_id bigint NOT NULL REFERENCES legacy_audit(id),
  name inet,
  is_default uuid,
  kind varchar(255)
);

CREATE TABLE policy_audit (
  id bigint PRIMARY KEY,
  staging_session_meta_id bigint,
  contract_item_id bigint,
  account_id bigint NOT NULL REFERENCES account(id),
  locale varchar(255),
  timezone uuid NOT NULL,
  created_at text,
  rate jsonb,
  quantity char(2),
  deleted_at char(2) NOT NULL
);

CREATE TABLE warehouse (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  legacy_order_item_id bigint,
  weight varchar(64),
  deleted_at uuid NOT NULL,
  name text,
  email jsonb,
  starts_at timestamp,
  rate varchar(255),
  total timestamptz,
  UNIQUE (rate)
);

CREATE TABLE legacy_category_snapshot (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  archived_session_id bigint NOT NULL REFERENCES archived_session(id),
  rate date NOT NULL,
  slug char(2),
  checksum numeric(12,2),
  currency smallint,
  UNIQUE (legacy_account_id)
);

CREATE TABLE staging_vehicle_line (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  legacy_session_config_id bigint NOT NULL REFERENCES legacy_session_config(id),
  starts_at bigint,
  phone integer,
  deleted_at numeric(12,2) NOT NULL,
  deleted_at_4 inet,
  version bytea,
  locale bigint,
  status numeric(12,2) NOT NULL,
  currency numeric(12,2) NOT NULL,
  slug char(2) NOT NULL,
  UNIQUE (currency)
);

CREATE TABLE "department_meta" (
  id bigint PRIMARY KEY,
  archived_policy_id bigint REFERENCES archived_policy(id),
  subscription_config_id bigint NOT NULL REFERENCES subscription_config(id),
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  deleted_at char(2) NOT NULL,
  expires_at text,
  deleted_at_3 bigint NOT NULL
);

CREATE TABLE v2_vehicle_meta (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  customer_id bigint REFERENCES customer(id),
  price uuid NOT NULL,
  rate char(2) NOT NULL,
  quantity bigint,
  currency timestamp,
  label uuid
);

CREATE TABLE ticket_history (
  id bigint PRIMARY KEY,
  staging_discount_item_id bigint NOT NULL REFERENCES staging_discount_item(id),
  booking_line_id bigint NOT NULL,
  checksum bigint NOT NULL,
  metadata bigint,
  amount bigint,
  external_ref smallint,
  position numeric(12,2),
  phone varchar(64) NOT NULL
);

CREATE TABLE archived_route_item (
  id bigint PRIMARY KEY,
  legacy_account_id bigint,
  route_message_id bigint REFERENCES route_message(id),
  name timestamptz,
  currency uuid,
  locale numeric(12,2) NOT NULL,
  is_default char(2),
  is_default_5 jsonb,
  external_ref smallint,
  position timestamptz NOT NULL,
  deleted_at char(2)
);

-- payment: 11 columns
CREATE TABLE payment (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  amount bigint,
  deleted_at timestamptz,
  label varchar(255) NOT NULL,
  timezone jsonb,
  is_default timestamp NOT NULL,
  timezone_6 text NOT NULL,
  position jsonb,
  locale smallint NOT NULL,
  total text NOT NULL
);

CREATE TABLE "public"."legacy_order_detail" (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  timezone numeric(12,2),
  label double precision,
  version date NOT NULL,
  total boolean,
  code timestamptz,
  checksum boolean NOT NULL,
  expires_at varchar(255),
  locale bigint
);

CREATE TABLE legacy_channel (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  email timestamp,
  email_2 text,
  weight double precision NOT NULL,
  is_locked inet,
  updated_at varchar(64) NOT NULL
);

CREATE TABLE legacy_inventory_detail (
  id bigint PRIMARY KEY,
  title jsonb,
  metadata inet NOT NULL,
  total integer,
  is_default timestamp,
  updated_at timestamp NOT NULL,
  price smallint,
  status varchar(64),
  UNIQUE (is_default)
);
/* trailing block comment */

CREATE TABLE v2_session_history (
  id bigint PRIMARY KEY,
  invoice_config_id bigint REFERENCES invoice_config(id),
  locale char(2) NOT NULL,
  body integer,
  rate timestamptz
);
/* trailing block comment */

-- template_history: 10 columns
CREATE TABLE template_history (
  id bigint PRIMARY KEY,
  note double precision NOT NULL,
  total text NOT NULL,
  is_default numeric(12,2) NOT NULL,
  slug numeric(12,2),
  name varchar(64),
  quantity varchar(64),
  amount text,
  code text NOT NULL,
  status char(2)
);

-- v2_notification: 8 columns
CREATE TABLE v2_notification (
  id bigint PRIMARY KEY,
  position text,
  price char(2),
  rate varchar(255),
  amount boolean,
  amount_5 timestamptz,
  slug smallint,
  kind double precision NOT NULL,
  UNIQUE (slug)
);

CREATE TABLE v2_ticket_link (
  id bigint PRIMARY KEY,
  discount_id bigint REFERENCES discount(id),
  is_active uuid NOT NULL,
  label jsonb NOT NULL,
  updated_at char(2) NOT NULL,
  deleted_at smallint NOT NULL,
  currency smallint NOT NULL,
  code double precision NOT NULL,
  price varchar(64),
  quantity varchar(64)
);

CREATE TABLE staging_review_link (
  id bigint PRIMARY KEY,
  archived_order_id bigint REFERENCES archived_order(id),
  project_history_id bigint REFERENCES project_history(id),
  staging_refund_item_id bigint REFERENCES staging_refund_item(id),
  payment_detail_id bigint NOT NULL,
  locale char(2),
  external_ref smallint NOT NULL,
  metadata varchar(255)
);
/* trailing block comment */

-- v2_vendor_link: 10 columns
CREATE TABLE v2_vendor_link (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  kind timestamp,
  position char(2),
  body varchar(64),
  price char(2),
  kind_5 timestamp NOT NULL,
  metadata bytea,
  locale varchar(64) NOT NULL,
  checksum bigint NOT NULL
);

CREATE TABLE legacy_session (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  legacy_discount_snapshot_id bigint REFERENCES legacy_discount_snapshot(id),
  locale varchar(64),
  body uuid NOT NULL
);

CREATE TABLE subscription_audit (
  id bigint PRIMARY KEY,
  channel_detail_id bigint NOT NULL REFERENCES channel_detail(id),
  tag_detail_id bigint NOT NULL REFERENCES tag_detail(id),
  external_ref varchar(64),
  is_default jsonb,
  total timestamptz NOT NULL,
  currency date,
  price boolean NOT NULL,
  created_at timestamptz,
  expires_at timestamp,
  slug varchar(255) NOT NULL,
  checksum boolean,
  is_locked double precision
);

CREATE TABLE "v2_channel" (
  id bigint PRIMARY KEY,
  legacy_subscription_detail_id bigint NOT NULL REFERENCES legacy_subscription_detail(id),
  staging_refund_line_id bigint NOT NULL REFERENCES staging_refund_line(id),
  kind jsonb,
  weight integer,
  rate char(2),
  deleted_at varchar(64) NOT NULL,
  label text,
  rate_6 inet NOT NULL,
  external_ref timestamptz,
  currency integer NOT NULL,
  total smallint,
  label_10 double precision NOT NULL
);

CREATE TABLE staging_vendor_snapshot (
  id bigint PRIMARY KEY,
  staging_employee_detail_id bigint REFERENCES staging_employee_detail(id),
  legacy_booking_meta_id bigint NOT NULL REFERENCES legacy_booking_meta(id),
  external_shipment_snapshot_id bigint NOT NULL REFERENCES external_shipment_snapshot(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  position boolean,
  is_locked varchar(64) NOT NULL,
  quantity smallint,
  version jsonb,
  UNIQUE (discount_id)
);

-- project_line: 10 columns
CREATE TABLE project_line (
  id bigint PRIMARY KEY,
  carrier_line_id bigint REFERENCES carrier_line(id),
  project_history_id bigint NOT NULL,
  amount text,
  amount_2 char(2) NOT NULL,
  is_default boolean NOT NULL,
  label integer NOT NULL,
  deleted_at timestamp,
  currency uuid NOT NULL,
  title double precision
);

CREATE TABLE v2_product_history (
  id bigint PRIMARY KEY,
  project_history_id bigint REFERENCES project_history(id),
  staging_route_id bigint NOT NULL,
  starts_at timestamp NOT NULL,
  is_default bigint,
  total timestamptz NOT NULL
);

CREATE TABLE product_audit (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  session_vehicle_id bigint NOT NULL REFERENCES session_vehicle(id),
  code uuid,
  phone smallint,
  is_locked inet,
  expires_at date,
  name inet NOT NULL,
  version timestamptz,
  UNIQUE (v2_audit_item_id)
);

CREATE TABLE message_history (
  id bigint PRIMARY KEY,
  slug smallint NOT NULL,
  price varchar(255) NOT NULL,
  checksum timestamptz,
  is_default bytea,
  expires_at varchar(255),
  email timestamptz NOT NULL,
  price_7 text,
  label integer
);

CREATE TABLE public.archived_payment_line (
  id bigint PRIMARY KEY,
  status date NOT NULL,
  code date
);

-- channel_item: 6 columns
CREATE TABLE channel_item (
  id bigint PRIMARY KEY,
  starts_at smallint,
  price timestamp NOT NULL,
  quantity numeric(12,2),
  status jsonb NOT NULL,
  body date NOT NULL,
  UNIQUE (status)
);

-- external_refund_history: 6 columns
CREATE TABLE external_refund_history (
  id bigint PRIMARY KEY,
  quantity boolean NOT NULL,
  slug boolean,
  version boolean,
  expires_at boolean,
  note bigint
);

CREATE TABLE "v2_vendor_audit" (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  updated_at jsonb NOT NULL,
  created_at bigint,
  label date,
  external_ref timestamp,
  version numeric(12,2),
  is_active double precision,
  title bigint NOT NULL,
  rate numeric(12,2) NOT NULL,
  starts_at smallint NOT NULL,
  UNIQUE (version)
);

-- staging_warehouse: 9 columns
CREATE TABLE staging_warehouse (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  quantity timestamptz,
  deleted_at timestamp,
  currency integer,
  phone inet,
  deleted_at_5 integer NOT NULL,
  checksum smallint,
  deleted_at_7 date
);

CREATE TABLE archived_department_link (
  id bigint PRIMARY KEY,
  v2_template_snapshot_id bigint REFERENCES v2_template_snapshot(id),
  position inet,
  starts_at integer NOT NULL,
  code smallint NOT NULL,
  note timestamptz,
  is_locked varchar(255),
  weight bigint NOT NULL,
  total varchar(255)
);

CREATE TABLE "public"."legacy_shipment_link" (
  id bigint PRIMARY KEY,
  payment_channel_id bigint NOT NULL REFERENCES payment_channel(id),
  name bigint NOT NULL,
  updated_at char(2) NOT NULL
);

CREATE TABLE public.archived_shipment_leg_item (
  id bigint PRIMARY KEY,
  product_history_id bigint NOT NULL REFERENCES product_history(id),
  refund_audit_id bigint,
  email inet NOT NULL,
  updated_at boolean,
  phone smallint NOT NULL,
  kind numeric(12,2) NOT NULL,
  code boolean,
  timezone timestamp,
  label bytea,
  email_8 date
);

CREATE TABLE staging_notification_config (
  id bigint PRIMARY KEY,
  external_notification_id bigint NOT NULL REFERENCES external_notification(id),
  legacy_customer_link_id bigint,
  is_locked smallint NOT NULL,
  external_ref integer NOT NULL,
  is_locked_3 date,
  UNIQUE (is_locked)
);

CREATE TABLE external_subscription (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  external_contract_audit_id bigint NOT NULL REFERENCES external_contract_audit(id),
  v2_warehouse_id bigint NOT NULL,
  label inet NOT NULL,
  position bigint,
  deleted_at numeric(12,2) NOT NULL,
  label_4 timestamp,
  is_default uuid,
  rate numeric(12,2) NOT NULL,
  amount inet
);

CREATE TABLE notification_item (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  slug timestamptz NOT NULL,
  currency integer,
  name numeric(12,2),
  email uuid NOT NULL,
  amount numeric(12,2),
  starts_at varchar(64) NOT NULL,
  amount_7 integer NOT NULL,
  locale timestamp,
  total integer
);

CREATE TABLE channel_detail (
  id bigint PRIMARY KEY,
  v2_order_config_id bigint NOT NULL REFERENCES v2_order_config(id),
  version jsonb,
  weight smallint,
  position uuid,
  deleted_at bytea
);

CREATE TABLE "public"."channel_history" (
  id bigint PRIMARY KEY,
  v2_shipment_detail_id bigint,
  staging_department_history_id bigint,
  price date NOT NULL,
  title inet,
  starts_at jsonb,
  amount timestamp,
  external_ref bytea NOT NULL
);

CREATE TABLE public.archived_channel (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  v2_shipment_leg_meta_id bigint,
  currency smallint,
  title char(2),
  checksum timestamp,
  UNIQUE (checksum)
);

CREATE TABLE v2_project (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  archived_policy_id bigint NOT NULL,
  legacy_subscription_detail_id bigint NOT NULL REFERENCES legacy_subscription_detail(id),
  project_history_id bigint REFERENCES project_history(id),
  metadata inet,
  body text NOT NULL,
  timezone numeric(12,2),
  body_4 integer NOT NULL,
  UNIQUE (project_history_id)
);

CREATE TABLE ticket_audit (
  id bigint PRIMARY KEY,
  booking_detail_id bigint NOT NULL REFERENCES booking_detail(id),
  v2_shipment_leg_detail_id bigint,
  is_active jsonb NOT NULL,
  phone varchar(64) NOT NULL
);

CREATE TABLE staging_vehicle_item (
  id bigint PRIMARY KEY,
  legacy_account_id bigint REFERENCES legacy_account(id),
  staging_employee_history_id bigint NOT NULL REFERENCES staging_employee_history(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  tag_snapshot_id bigint REFERENCES tag_snapshot(id),
  amount text,
  version timestamp,
  updated_at uuid,
  version_4 varchar(255) NOT NULL,
  is_locked timestamp NOT NULL,
  phone uuid,
  amount_7 text
);

CREATE TABLE staging_discount_item (
  id bigint PRIMARY KEY,
  external_policy_link_id bigint NOT NULL REFERENCES external_policy_link(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  deleted_at bigint,
  status integer NOT NULL,
  amount bytea,
  is_active timestamptz,
  amount_5 inet NOT NULL,
  metadata double precision NOT NULL,
  quantity varchar(64)
);

CREATE TABLE "public"."external_payment_meta" (
  id bigint PRIMARY KEY,
  quantity numeric(12,2),
  is_locked inet NOT NULL,
  slug numeric(12,2)
);

CREATE TABLE external_employee (
  id bigint PRIMARY KEY,
  staging_booking_config_id bigint REFERENCES staging_booking_config(id),
  external_audit_id bigint REFERENCES external_audit(id),
  employee_audit_id bigint,
  metadata boolean,
  name text,
  code uuid NOT NULL,
  UNIQUE (name)
);

CREATE TABLE v2_vehicle_snapshot (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  body double precision,
  name uuid,
  status bigint,
  is_active numeric(12,2)
);
/* trailing block comment */

CREATE TABLE vendor_link (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  v2_attachment_config_id bigint NOT NULL REFERENCES v2_attachment_config(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  updated_at jsonb,
  name timestamp,
  UNIQUE (updated_at)
);

CREATE TABLE legacy_review_audit (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  currency integer NOT NULL,
  slug text NOT NULL,
  weight varchar(255),
  title varchar(255) NOT NULL,
  slug_5 varchar(64) NOT NULL
);

CREATE TABLE project_audit (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  name jsonb,
  note smallint,
  note_3 numeric(12,2),
  checksum date,
  UNIQUE (note_3)
);

CREATE TABLE staging_contract_audit (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  external_warehouse_id bigint NOT NULL,
  external_message_detail_id bigint NOT NULL,
  archived_subscription_id bigint NOT NULL REFERENCES archived_subscription(id),
  v2_audit_history_id bigint REFERENCES v2_audit_history(id),
  is_default boolean,
  created_at varchar(64) NOT NULL,
  version smallint,
  checksum varchar(64)
);

-- legacy_shipment_meta: 12 columns
CREATE TABLE legacy_shipment_meta (
  id bigint PRIMARY KEY,
  external_notification_line_id bigint REFERENCES external_notification_line(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  checksum char(2),
  body uuid NOT NULL,
  phone boolean,
  currency uuid,
  email boolean,
  rate text,
  note varchar(64),
  code timestamp NOT NULL
);

CREATE TABLE shipment_leg_shipment (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  kind text,
  kind_2 integer NOT NULL,
  code text NOT NULL,
  currency smallint NOT NULL,
  timezone smallint,
  UNIQUE (staging_template_item_id)
);

CREATE TABLE v2_shipment (
  id bigint PRIMARY KEY,
  archived_employee_id bigint REFERENCES archived_employee(id),
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  title numeric(12,2) NOT NULL,
  kind text,
  rate jsonb NOT NULL,
  position timestamp NOT NULL,
  checksum char(2),
  is_default uuid,
  deleted_at integer
);

CREATE TABLE "staging_asset_snapshot" (
  id bigint PRIMARY KEY,
  legacy_audit_link_id bigint NOT NULL REFERENCES legacy_audit_link(id),
  legacy_department_detail_id bigint NOT NULL REFERENCES legacy_department_detail(id),
  starts_at inet NOT NULL,
  label bytea,
  checksum varchar(255) NOT NULL,
  is_default date NOT NULL,
  UNIQUE (starts_at)
);
/* trailing block comment */

CREATE TABLE public.staging_shipment_leg_item (
  id bigint PRIMARY KEY,
  v2_vehicle_audit_id bigint REFERENCES v2_vehicle_audit(id),
  policy_item_id bigint REFERENCES policy_item(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  locale char(2),
  expires_at inet NOT NULL,
  updated_at bytea NOT NULL
);
/* trailing block comment */

CREATE TABLE subscription_link (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  project_history_id bigint REFERENCES project_history(id),
  warehouse_audit_id bigint NOT NULL,
  expires_at varchar(255),
  is_locked char(2) NOT NULL,
  is_default boolean,
  currency uuid,
  updated_at date NOT NULL,
  quantity boolean,
  currency_7 varchar(255),
  phone varchar(64),
  phone_9 uuid
);

CREATE TABLE staging_session_item (
  id bigint PRIMARY KEY,
  refund_audit_id bigint,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  timezone varchar(64),
  code boolean,
  timezone_3 smallint,
  slug double precision NOT NULL,
  note bytea
);

-- legacy_route_audit: 11 columns
CREATE TABLE legacy_route_audit (
  id bigint PRIMARY KEY,
  archived_project_audit_id bigint REFERENCES archived_project_audit(id),
  project_history_id bigint,
  locale bigint,
  checksum boolean NOT NULL,
  total bigint,
  kind timestamp,
  is_default date,
  name boolean NOT NULL,
  updated_at char(2) NOT NULL,
  rate boolean
);

CREATE TABLE staging_booking_link (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  booking_line_id bigint REFERENCES booking_line(id),
  v2_notification_item_id bigint REFERENCES v2_notification_item(id),
  is_locked varchar(64),
  amount bigint NOT NULL,
  timezone numeric(12,2),
  position timestamp,
  is_active numeric(12,2) NOT NULL,
  currency inet,
  external_ref bytea NOT NULL
);

CREATE TABLE "v2_department_item" (
  id bigint PRIMARY KEY,
  booking_line_id bigint REFERENCES booking_line(id),
  external_refund_line_id bigint NOT NULL REFERENCES external_refund_line(id),
  legacy_payment_history_id bigint NOT NULL REFERENCES legacy_payment_history(id),
  currency smallint,
  body smallint,
  kind date,
  UNIQUE (legacy_payment_history_id)
);

CREATE TABLE public.external_customer_item (
  id bigint PRIMARY KEY,
  employee_audit_id bigint NOT NULL REFERENCES employee_audit(id),
  staging_booking_id bigint REFERENCES staging_booking(id),
  external_account_item_id bigint REFERENCES external_account_item(id),
  timezone bytea,
  position timestamptz NOT NULL,
  name timestamptz NOT NULL,
  title uuid,
  created_at date,
  external_ref bytea NOT NULL,
  kind timestamp NOT NULL,
  email char(2),
  note uuid NOT NULL
);

-- session_item: 12 columns
CREATE TABLE session_item (
  id bigint PRIMARY KEY,
  invoice_config_id bigint REFERENCES invoice_config(id),
  external_warehouse_item_id bigint NOT NULL REFERENCES external_warehouse_item(id),
  expires_at uuid NOT NULL,
  version timestamp,
  starts_at double precision NOT NULL,
  rate varchar(255),
  position timestamptz NOT NULL,
  timezone timestamp,
  body timestamptz,
  is_locked smallint,
  status text NOT NULL
);

CREATE TABLE vehicle (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  metadata numeric(12,2) NOT NULL,
  name bigint NOT NULL,
  created_at date NOT NULL,
  position integer
);

-- v2_audit_history: 4 columns
CREATE TABLE v2_audit_history (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  is_active timestamptz,
  phone integer NOT NULL
);

CREATE TABLE legacy_template_audit (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  staging_carrier_id bigint NOT NULL REFERENCES staging_carrier(id),
  phone varchar(64),
  external_ref varchar(64),
  status uuid,
  position timestamp NOT NULL,
  status_5 bytea NOT NULL,
  version boolean,
  kind bytea,
  name timestamptz NOT NULL,
  metadata inet
);

CREATE TABLE staging_shipment_leg_history (
  id bigint PRIMARY KEY,
  quantity text,
  email integer NOT NULL,
  metadata bigint NOT NULL,
  is_default timestamp,
  starts_at timestamptz,
  position integer,
  body varchar(64) NOT NULL,
  title integer
);

-- v2_policy_item: 8 columns
CREATE TABLE "public"."v2_policy_item" (
  id bigint PRIMARY KEY,
  v2_session_history_id bigint NOT NULL REFERENCES v2_session_history(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  external_project_audit_id bigint NOT NULL REFERENCES external_project_audit(id),
  email bytea NOT NULL,
  kind date,
  name char(2) NOT NULL,
  name_4 numeric(12,2),
  UNIQUE (email)
);

-- asset_detail: 8 columns
CREATE TABLE public.asset_detail (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL,
  booking_line_id bigint REFERENCES booking_line(id),
  email timestamptz NOT NULL,
  quantity bigint,
  body smallint,
  code uuid NOT NULL,
  total smallint NOT NULL,
  UNIQUE (email)
);

CREATE TABLE "public"."v2_ticket_detail" (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL,
  v2_booking_history_id bigint NOT NULL REFERENCES v2_booking_history(id),
  is_default varchar(255) NOT NULL,
  external_ref smallint NOT NULL,
  is_default_3 numeric(12,2)
);

CREATE TABLE archived_session_line (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  warehouse_item_id bigint NOT NULL REFERENCES warehouse_item(id),
  category_customer_id bigint NOT NULL,
  quantity integer NOT NULL,
  is_active bigint NOT NULL,
  total smallint NOT NULL,
  UNIQUE (is_active)
);

-- product: 9 columns
CREATE TABLE product (
  id bigint PRIMARY KEY,
  email timestamp NOT NULL,
  expires_at timestamp NOT NULL,
  rate double precision,
  price timestamptz,
  locale inet,
  kind smallint,
  currency timestamptz NOT NULL,
  slug numeric(12,2),
  UNIQUE (kind)
);

CREATE TABLE public.legacy_payment_line (
  id bigint PRIMARY KEY,
  channel_link_id bigint NOT NULL REFERENCES channel_link(id),
  archived_account_id bigint REFERENCES archived_account(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  is_default text,
  updated_at varchar(255),
  kind bytea NOT NULL,
  phone bytea NOT NULL,
  external_ref varchar(255),
  UNIQUE (is_default)
);

CREATE TABLE document_history (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  payment_link_id bigint NOT NULL REFERENCES payment_link(id),
  version numeric(12,2) NOT NULL,
  starts_at uuid,
  is_locked inet,
  starts_at_4 boolean NOT NULL,
  is_default char(2),
  note smallint NOT NULL,
  rate numeric(12,2) NOT NULL,
  expires_at varchar(255) NOT NULL,
  UNIQUE (payment_link_id)
);

CREATE TABLE v2_inventory_detail (
  id bigint PRIMARY KEY,
  staging_inventory_item_id bigint REFERENCES staging_inventory_item(id),
  v2_refund_id bigint,
  legacy_notification_link_id bigint NOT NULL REFERENCES legacy_notification_link(id),
  is_default inet,
  currency integer NOT NULL,
  is_default_3 timestamp NOT NULL,
  name char(2),
  expires_at jsonb,
  metadata jsonb NOT NULL,
  is_active integer NOT NULL
);

CREATE TABLE "public"."legacy_campaign_config" (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  timezone boolean,
  slug uuid,
  email boolean NOT NULL,
  body char(2),
  body_5 bigint,
  phone timestamp,
  is_active bigint,
  is_default integer
);

-- category_customer: 10 columns
CREATE TABLE "public"."category_customer" (
  id bigint PRIMARY KEY,
  rate timestamp NOT NULL,
  quantity char(2),
  position varchar(64),
  status boolean,
  external_ref date,
  is_default timestamptz NOT NULL,
  kind timestamptz,
  slug date NOT NULL,
  metadata uuid NOT NULL
);

-- staging_department: 10 columns
CREATE TABLE public.staging_department (
  id bigint PRIMARY KEY,
  legacy_shipment_id bigint REFERENCES legacy_shipment(id),
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  locale jsonb NOT NULL,
  created_at inet,
  created_at_3 jsonb,
  created_at_4 uuid,
  note uuid NOT NULL,
  code timestamptz NOT NULL
);

CREATE TABLE public.staging_project_detail (
  id bigint PRIMARY KEY,
  legacy_notification_id bigint NOT NULL REFERENCES legacy_notification(id),
  archived_policy_id bigint REFERENCES archived_policy(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  label numeric(12,2) NOT NULL,
  is_active inet,
  phone varchar(64),
  quantity double precision NOT NULL,
  label_5 uuid,
  currency numeric(12,2) NOT NULL,
  phone_7 timestamptz
);

CREATE TABLE public.template_line (
  id bigint PRIMARY KEY,
  legacy_inventory_meta_id bigint REFERENCES legacy_inventory_meta(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  code jsonb,
  deleted_at double precision,
  slug varchar(255),
  status varchar(64),
  note bigint,
  deleted_at_6 varchar(64),
  body char(2),
  is_locked inet NOT NULL,
  body_9 date NOT NULL,
  kind varchar(255)
);

CREATE TABLE external_session_link (
  id bigint PRIMARY KEY,
  v2_contract_config_id bigint REFERENCES v2_contract_config(id),
  v2_ticket_link_id bigint NOT NULL REFERENCES v2_ticket_link(id),
  position bigint,
  status bigint
);

CREATE TABLE archived_inventory_line (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  starts_at bigint,
  starts_at_2 boolean,
  currency varchar(255),
  timezone varchar(255),
  amount varchar(255) NOT NULL,
  timezone_6 varchar(64),
  checksum char(2) NOT NULL
);
/* trailing block comment */

CREATE TABLE legacy_shipment_leg_meta (
  id bigint PRIMARY KEY,
  archived_project_meta_id bigint REFERENCES archived_project_meta(id),
  legacy_vehicle_link_id bigint REFERENCES legacy_vehicle_link(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  label uuid NOT NULL,
  version double precision,
  kind uuid NOT NULL,
  body date,
  locale uuid,
  starts_at varchar(64),
  slug varchar(64),
  weight boolean,
  is_locked bigint,
  phone numeric(12,2)
);

CREATE TABLE external_account_item (
  id bigint PRIMARY KEY,
  v2_booking_history_id bigint NOT NULL,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  staging_department_history_id bigint NOT NULL,
  staging_refund_history_id bigint NOT NULL REFERENCES staging_refund_history(id),
  deleted_at uuid,
  position varchar(255) NOT NULL,
  status smallint,
  body varchar(64) NOT NULL,
  total jsonb,
  quantity timestamp NOT NULL,
  checksum smallint,
  UNIQUE (v2_refund_id)
);
/* trailing block comment */

CREATE TABLE staging_category (
  id bigint PRIMARY KEY,
  archived_audit_id bigint REFERENCES archived_audit(id),
  v2_channel_item_id bigint NOT NULL REFERENCES v2_channel_item(id),
  is_locked double precision NOT NULL,
  currency numeric(12,2),
  slug integer,
  code double precision,
  is_locked_5 varchar(64),
  checksum text,
  UNIQUE (code)
);

-- legacy_carrier_meta: 10 columns
CREATE TABLE legacy_carrier_meta (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  name date,
  weight double precision NOT NULL,
  kind timestamptz NOT NULL,
  is_locked bytea NOT NULL,
  title smallint NOT NULL,
  deleted_at bigint NOT NULL,
  starts_at bigint,
  kind_8 varchar(255) NOT NULL
);

CREATE TABLE audit_audit (
  id bigint PRIMARY KEY,
  discount_id bigint REFERENCES discount(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  policy_item_id bigint REFERENCES policy_item(id),
  booking_line_id bigint REFERENCES booking_line(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  position bigint NOT NULL,
  title double precision NOT NULL,
  phone varchar(255),
  position_4 date
);

-- archived_project: 10 columns
CREATE TABLE archived_project (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  is_active bigint,
  deleted_at integer NOT NULL,
  kind uuid,
  is_default date NOT NULL,
  is_locked char(2) NOT NULL,
  amount timestamptz NOT NULL,
  status numeric(12,2),
  weight char(2)
);

CREATE TABLE task_snapshot (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL,
  archived_category_id bigint NOT NULL REFERENCES archived_category(id),
  refund_audit_id bigint REFERENCES refund_audit(id),
  code date NOT NULL,
  metadata char(2) NOT NULL,
  deleted_at numeric(12,2),
  price numeric(12,2) NOT NULL,
  total text NOT NULL,
  name uuid
);

CREATE TABLE public.archived_employee (
  id bigint PRIMARY KEY,
  refund_item_id bigint NOT NULL REFERENCES refund_item(id),
  slug varchar(64),
  created_at double precision NOT NULL,
  expires_at bigint NOT NULL,
  deleted_at smallint,
  timezone integer NOT NULL
);
/* trailing block comment */

CREATE TABLE external_contract (
  id bigint PRIMARY KEY,
  external_vehicle_id bigint REFERENCES external_vehicle(id),
  external_notification_line_id bigint NOT NULL REFERENCES external_notification_line(id),
  v2_tag_link_id bigint,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  v2_refund_id bigint REFERENCES v2_refund(id),
  phone varchar(64) NOT NULL,
  locale bytea NOT NULL,
  is_active bytea,
  UNIQUE (external_notification_line_id)
);

CREATE TABLE external_route_config (
  id bigint PRIMARY KEY,
  legacy_message_meta_id bigint NOT NULL REFERENCES legacy_message_meta(id),
  is_locked numeric(12,2),
  external_ref numeric(12,2) NOT NULL,
  is_active uuid NOT NULL,
  note smallint,
  expires_at timestamp,
  kind jsonb,
  is_default inet NOT NULL
);

CREATE TABLE v2_policy (
  id bigint PRIMARY KEY,
  invoice_config_id bigint REFERENCES invoice_config(id),
  position numeric(12,2) NOT NULL,
  locale bytea,
  updated_at varchar(255),
  timezone boolean NOT NULL,
  label text NOT NULL,
  amount inet,
  currency numeric(12,2),
  slug uuid NOT NULL,
  timezone_9 timestamp,
  amount_10 bytea
);

CREATE TABLE notification (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint,
  discount_id bigint NOT NULL REFERENCES discount(id),
  staging_shipment_leg_config_id bigint NOT NULL,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  archived_policy_id bigint REFERENCES archived_policy(id),
  created_at date,
  body timestamptz,
  is_default smallint,
  quantity inet NOT NULL,
  status smallint,
  name char(2),
  code bigint NOT NULL,
  amount varchar(255) NOT NULL
);

-- v2_audit: 15 columns
CREATE TABLE v2_audit (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  v2_inventory_detail_id bigint REFERENCES v2_inventory_detail(id),
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  slug timestamp,
  timezone timestamptz NOT NULL,
  price timestamptz NOT NULL,
  metadata double precision NOT NULL,
  weight double precision NOT NULL,
  is_locked varchar(255),
  starts_at smallint NOT NULL,
  version integer NOT NULL,
  created_at timestamp NOT NULL,
  status boolean
);
/* trailing block comment */

-- staging_notification_line: 8 columns
CREATE TABLE staging_notification_line (
  id bigint PRIMARY KEY,
  v2_task_item_id bigint NOT NULL REFERENCES v2_task_item(id),
  updated_at boolean,
  quantity date,
  updated_at_3 boolean,
  starts_at text,
  starts_at_5 bigint,
  is_locked boolean
);
/* trailing block comment */

CREATE TABLE v2_inventory_line (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  booking_line_id bigint,
  note varchar(64),
  kind text
);

-- v2_warehouse_link: 4 columns
CREATE TABLE "public"."v2_warehouse_link" (
  id bigint PRIMARY KEY,
  external_refund_audit_id bigint NOT NULL REFERENCES external_refund_audit(id),
  status date,
  position text
);

-- product_item: 7 columns
CREATE TABLE public.product_item (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  is_default bigint,
  metadata text NOT NULL,
  position text NOT NULL,
  quantity bytea NOT NULL,
  email integer
);

CREATE TABLE staging_campaign_meta (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  archived_review_detail_id bigint REFERENCES archived_review_detail(id),
  legacy_subscription_line_id bigint NOT NULL REFERENCES legacy_subscription_line(id),
  body date NOT NULL,
  expires_at timestamp NOT NULL,
  body_3 jsonb,
  expires_at_4 text,
  updated_at integer,
  timezone date,
  UNIQUE (expires_at_4)
);

CREATE TABLE external_shipment (
  id bigint PRIMARY KEY,
  archived_product_id bigint NOT NULL,
  invoice_config_id bigint REFERENCES invoice_config(id),
  payment_line_id bigint REFERENCES payment_line(id),
  total date,
  is_active integer NOT NULL,
  status varchar(64) NOT NULL,
  is_default boolean,
  label uuid NOT NULL,
  is_active_6 date,
  created_at timestamptz NOT NULL
);

-- invoice_meta: 5 columns
CREATE TABLE invoice_meta (
  id bigint PRIMARY KEY,
  staging_order_history_id bigint NOT NULL REFERENCES staging_order_history(id),
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  version char(2),
  amount text NOT NULL
);
/* trailing block comment */

CREATE TABLE "public"."legacy_order_snapshot" (
  id bigint PRIMARY KEY,
  archived_policy_id bigint REFERENCES archived_policy(id),
  starts_at numeric(12,2) NOT NULL,
  quantity timestamptz
);

CREATE TABLE audit (
  id bigint PRIMARY KEY,
  invoice_item_id bigint NOT NULL REFERENCES invoice_item(id),
  staging_department_snapshot_id bigint NOT NULL REFERENCES staging_department_snapshot(id),
  total jsonb NOT NULL,
  weight double precision NOT NULL,
  price bytea,
  label double precision NOT NULL,
  price_5 bigint,
  timezone inet,
  timezone_7 double precision,
  created_at bytea,
  is_default inet,
  UNIQUE (is_default)
);

CREATE TABLE legacy_payment_history (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  v2_review_line_id bigint NOT NULL REFERENCES v2_review_line(id),
  quantity boolean,
  is_default varchar(255) NOT NULL,
  quantity_3 char(2) NOT NULL,
  kind smallint,
  quantity_5 bigint,
  starts_at date,
  is_active text NOT NULL,
  UNIQUE (quantity_3)
);

-- customer_line: 8 columns
CREATE TABLE customer_line (
  id bigint PRIMARY KEY,
  archived_document_audit_id bigint,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  rate char(2) NOT NULL,
  is_locked double precision,
  slug timestamp NOT NULL,
  note text
);

CREATE TABLE invoice_policy (
  id bigint PRIMARY KEY,
  archived_policy_id bigint REFERENCES archived_policy(id),
  is_default text,
  external_ref inet,
  is_active varchar(64),
  note inet,
  updated_at varchar(64),
  external_ref_6 boolean,
  email double precision
);

-- employee_audit: 6 columns
CREATE TABLE employee_audit (
  id bigint PRIMARY KEY,
  invoice_config_id bigint REFERENCES invoice_config(id),
  contract_detail_id bigint NOT NULL,
  phone inet NOT NULL,
  version jsonb,
  amount timestamp
);

CREATE TABLE v2_channel_meta (
  id bigint PRIMARY KEY,
  department_link_id bigint NOT NULL REFERENCES department_link(id),
  staging_project_meta_id bigint REFERENCES staging_project_meta(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  booking_id bigint REFERENCES booking(id),
  staging_vehicle_link_id bigint NOT NULL REFERENCES staging_vehicle_link(id),
  is_locked char(2),
  version double precision
);
/* trailing block comment */

-- legacy_document_line: 11 columns
CREATE TABLE legacy_document_line (
  id bigint PRIMARY KEY,
  policy_order_id bigint NOT NULL REFERENCES policy_order(id),
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  v2_discount_config_id bigint NOT NULL,
  archived_order_id bigint,
  staging_policy_id bigint NOT NULL REFERENCES staging_policy(id),
  name timestamptz,
  updated_at varchar(255),
  amount varchar(64) NOT NULL,
  locale bigint,
  locale_5 char(2)
);

CREATE TABLE archived_project_meta (
  id bigint PRIMARY KEY,
  staging_session_config_id bigint,
  archived_message_id bigint NOT NULL REFERENCES archived_message(id),
  amount timestamptz,
  deleted_at date NOT NULL,
  total smallint NOT NULL,
  external_ref uuid,
  expires_at double precision,
  starts_at varchar(255)
);

CREATE TABLE order_config (
  id bigint PRIMARY KEY,
  shipment_leg_meta_id bigint NOT NULL REFERENCES shipment_leg_meta(id),
  weight uuid NOT NULL,
  updated_at double precision,
  position varchar(255),
  is_locked timestamptz,
  position_5 timestamptz,
  title timestamp
);

CREATE TABLE attachment_config (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  external_contract_id bigint NOT NULL REFERENCES external_contract(id),
  archived_subscription_id bigint REFERENCES archived_subscription(id),
  starts_at text NOT NULL,
  is_locked double precision NOT NULL,
  name smallint NOT NULL,
  UNIQUE (archived_subscription_id)
);

-- legacy_carrier: 5 columns
CREATE TABLE legacy_carrier (
  id bigint PRIMARY KEY,
  v2_refund_id bigint,
  status varchar(255) NOT NULL,
  is_default jsonb,
  currency timestamptz
);

CREATE TABLE archived_carrier_history (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  shipment_leg_history_id bigint NOT NULL REFERENCES shipment_leg_history(id),
  slug boolean,
  checksum timestamp,
  email double precision,
  is_locked inet,
  position timestamptz NOT NULL,
  expires_at inet NOT NULL,
  total double precision NOT NULL
);

CREATE TABLE external_asset_detail (
  id bigint PRIMARY KEY,
  discount_id bigint REFERENCES discount(id),
  created_at numeric(12,2),
  name double precision NOT NULL,
  is_default inet NOT NULL,
  starts_at bigint NOT NULL,
  title bigint,
  timezone char(2),
  UNIQUE (is_default)
);

-- staging_account_detail: 14 columns
CREATE TABLE staging_account_detail (
  id bigint PRIMARY KEY,
  v2_policy_line_id bigint NOT NULL REFERENCES v2_policy_line(id),
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  legacy_project_snapshot_id bigint NOT NULL REFERENCES legacy_project_snapshot(id),
  staging_employee_detail_id bigint NOT NULL REFERENCES staging_employee_detail(id),
  is_locked smallint,
  starts_at uuid,
  metadata double precision,
  locale timestamp,
  version double precision,
  status timestamptz NOT NULL,
  is_locked_7 smallint,
  is_default smallint NOT NULL,
  currency timestamptz NOT NULL
);

CREATE TABLE external_discount (
  id bigint PRIMARY KEY,
  legacy_account_id bigint,
  staging_shipment_leg_config_id bigint,
  archived_policy_id bigint,
  currency varchar(64) NOT NULL,
  starts_at uuid NOT NULL,
  updated_at char(2) NOT NULL,
  updated_at_4 double precision,
  is_default numeric(12,2),
  name text,
  slug numeric(12,2),
  weight integer
);

CREATE TABLE legacy_audit_snapshot (
  id bigint PRIMARY KEY,
  legacy_inventory_detail_id bigint NOT NULL REFERENCES legacy_inventory_detail(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  is_default date,
  position jsonb,
  label integer NOT NULL,
  metadata bigint NOT NULL,
  is_active bytea,
  checksum smallint,
  note jsonb NOT NULL
);

-- staging_vehicle_config: 9 columns
CREATE TABLE staging_vehicle_config (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  product_detail_id bigint NOT NULL REFERENCES product_detail(id),
  v2_discount_config_id bigint NOT NULL,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  booking_snapshot_id bigint NOT NULL REFERENCES booking_snapshot(id),
  external_ref uuid,
  total jsonb,
  quantity jsonb NOT NULL
);

CREATE TABLE notification_history (
  id bigint PRIMARY KEY,
  policy_history_id bigint NOT NULL,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  label boolean NOT NULL,
  starts_at varchar(255),
  locale varchar(255),
  expires_at jsonb NOT NULL,
  rate date
);

-- invoice: 12 columns
CREATE TABLE "invoice" (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  staging_invoice_audit_id bigint NOT NULL REFERENCES staging_invoice_audit(id),
  legacy_discount_config_id bigint NOT NULL REFERENCES legacy_discount_config(id),
  v2_vehicle_snapshot_id bigint NOT NULL REFERENCES v2_vehicle_snapshot(id),
  price date,
  email timestamp NOT NULL,
  name boolean,
  rate date,
  created_at smallint,
  code date,
  updated_at boolean
);

CREATE TABLE legacy_subscription (
  id bigint PRIMARY KEY,
  archived_order_id bigint REFERENCES archived_order(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  legacy_project_snapshot_id bigint NOT NULL REFERENCES legacy_project_snapshot(id),
  invoice_config_id bigint NOT NULL,
  v2_project_id bigint NOT NULL REFERENCES v2_project(id),
  payment_channel_id bigint NOT NULL REFERENCES payment_channel(id),
  weight boolean NOT NULL,
  total double precision,
  title varchar(64) NOT NULL,
  body date NOT NULL
);

-- v2_product_config: 11 columns
CREATE TABLE v2_product_config (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  legacy_account_audit_id bigint NOT NULL REFERENCES legacy_account_audit(id),
  deleted_at varchar(255),
  note varchar(64) NOT NULL,
  is_locked numeric(12,2) NOT NULL,
  checksum date,
  is_default timestamptz NOT NULL,
  email bigint NOT NULL,
  price date
);

CREATE TABLE "public"."staging_refund_history" (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  archived_warehouse_item_id bigint NOT NULL REFERENCES archived_warehouse_item(id),
  note double precision NOT NULL,
  name varchar(64) NOT NULL,
  status double precision,
  status_4 smallint
);

CREATE TABLE "public"."archived_payment_meta" (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL,
  expires_at inet,
  locale numeric(12,2) NOT NULL,
  external_ref integer,
  price bytea,
  locale_5 date,
  weight numeric(12,2),
  version integer
);
/* trailing block comment */

-- archived_booking_meta: 11 columns
CREATE TABLE archived_booking_meta (
  id bigint PRIMARY KEY,
  staging_carrier_snapshot_id bigint REFERENCES staging_carrier_snapshot(id),
  position date NOT NULL,
  name numeric(12,2) NOT NULL,
  created_at smallint,
  code jsonb NOT NULL,
  is_active char(2),
  version inet NOT NULL,
  status boolean NOT NULL,
  label jsonb,
  body varchar(64) NOT NULL
);

CREATE TABLE external_vendor_audit (
  id bigint PRIMARY KEY,
  document_detail_id bigint NOT NULL REFERENCES document_detail(id),
  status timestamp NOT NULL,
  external_ref bigint,
  checksum numeric(12,2) NOT NULL,
  note double precision,
  locale double precision NOT NULL
);

CREATE TABLE staging_customer_history (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  quantity timestamp NOT NULL,
  slug smallint,
  quantity_3 timestamptz NOT NULL,
  version char(2) NOT NULL,
  amount text,
  email varchar(64) NOT NULL,
  amount_7 double precision NOT NULL
);
/* trailing block comment */

-- vendor_history: 12 columns
CREATE TABLE vendor_history (
  id bigint PRIMARY KEY,
  legacy_shipment_history_id bigint NOT NULL REFERENCES legacy_shipment_history(id),
  v2_warehouse_history_id bigint NOT NULL REFERENCES v2_warehouse_history(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  is_active timestamp,
  amount varchar(255) NOT NULL,
  kind numeric(12,2),
  price bytea,
  title bigint,
  timezone double precision,
  expires_at timestamptz NOT NULL,
  status numeric(12,2)
);

CREATE TABLE legacy_project_audit (
  id bigint PRIMARY KEY,
  external_shipment_leg_snapshot_id bigint REFERENCES external_shipment_leg_snapshot(id),
  position date,
  is_locked uuid NOT NULL,
  status jsonb,
  status_4 jsonb,
  label bigint,
  status_6 inet,
  currency varchar(255) NOT NULL
);

-- shipment: 11 columns
CREATE TABLE shipment (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  external_discount_id bigint REFERENCES external_discount(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  external_refund_history_id bigint REFERENCES external_refund_history(id),
  amount date,
  note varchar(255) NOT NULL,
  position boolean,
  timezone jsonb
);

-- external_campaign: 5 columns
CREATE TABLE public.external_campaign (
  id bigint PRIMARY KEY,
  external_payment_meta_id bigint NOT NULL REFERENCES external_payment_meta(id),
  note varchar(64),
  weight numeric(12,2) NOT NULL,
  is_locked timestamptz
);

CREATE TABLE project_item (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  archived_policy_id bigint REFERENCES archived_policy(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  timezone varchar(64) NOT NULL,
  title boolean
);

-- staging_policy_item: 8 columns
CREATE TABLE staging_policy_item (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  name varchar(255) NOT NULL,
  expires_at smallint,
  note uuid,
  title boolean,
  UNIQUE (staging_department_history_id)
);

CREATE TABLE external_invoice_snapshot (
  id bigint PRIMARY KEY,
  discount_config_id bigint REFERENCES discount_config(id),
  title jsonb NOT NULL,
  currency boolean NOT NULL,
  metadata double precision,
  phone bigint,
  UNIQUE (metadata)
);
/* trailing block comment */

CREATE TABLE v2_account_line (
  id bigint PRIMARY KEY,
  discount_config_id bigint REFERENCES discount_config(id),
  timezone timestamptz NOT NULL,
  quantity jsonb NOT NULL,
  status jsonb,
  created_at jsonb,
  slug double precision NOT NULL,
  weight integer NOT NULL,
  phone smallint
);

CREATE TABLE carrier_config (
  id bigint PRIMARY KEY,
  booking_line_id bigint,
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  note inet,
  title double precision,
  is_active uuid,
  is_active_4 bigint NOT NULL,
  metadata varchar(255) NOT NULL,
  name inet
);

-- category_item: 6 columns
CREATE TABLE category_item (
  id bigint PRIMARY KEY,
  total bytea,
  version varchar(64),
  updated_at boolean,
  name bytea,
  total_5 bigint NOT NULL
);

CREATE TABLE legacy_order_history (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  is_default text,
  phone double precision NOT NULL,
  note text NOT NULL,
  phone_4 timestamp NOT NULL,
  note_5 timestamp,
  slug char(2),
  timezone uuid
);

-- legacy_message: 8 columns
CREATE TABLE legacy_message (
  id bigint PRIMARY KEY,
  template_line_id bigint NOT NULL REFERENCES template_line(id),
  total jsonb,
  updated_at bigint,
  email inet,
  updated_at_4 inet NOT NULL,
  updated_at_5 bigint,
  weight date
);
/* trailing block comment */

CREATE TABLE v2_customer_snapshot (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  starts_at varchar(255) NOT NULL,
  label numeric(12,2),
  price text NOT NULL
);

CREATE TABLE inventory_audit (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  product_id bigint NOT NULL REFERENCES product(id),
  price integer,
  email timestamp NOT NULL,
  note smallint,
  locale varchar(64),
  name inet,
  rate timestamptz NOT NULL
);

CREATE TABLE discount_snapshot (
  id bigint PRIMARY KEY,
  asset_detail_id bigint REFERENCES asset_detail(id),
  archived_session_id bigint,
  created_at boolean NOT NULL,
  code uuid,
  price jsonb,
  price_4 double precision
);

CREATE TABLE public.external_customer_line (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  version double precision NOT NULL,
  updated_at boolean NOT NULL,
  email double precision,
  checksum timestamp,
  is_locked char(2),
  kind date,
  updated_at_7 integer,
  timezone bytea NOT NULL
);

-- staging_customer_audit: 8 columns
CREATE TABLE "public"."staging_customer_audit" (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  v2_account_line_id bigint NOT NULL REFERENCES v2_account_line(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  weight timestamp,
  position bytea,
  weight_3 boolean,
  locale timestamp
);

CREATE TABLE carrier_line (
  id bigint PRIMARY KEY,
  refund_snapshot_id bigint REFERENCES refund_snapshot(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  starts_at date,
  starts_at_2 timestamp,
  metadata bytea NOT NULL,
  is_default date,
  is_active timestamp NOT NULL,
  weight timestamptz,
  kind timestamp
);

CREATE TABLE shipment_line (
  id bigint PRIMARY KEY,
  project_history_id bigint REFERENCES project_history(id),
  external_ref varchar(64),
  is_default varchar(64),
  is_default_3 char(2) NOT NULL,
  quantity char(2)
);

CREATE TABLE carrier (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  inventory_audit_id bigint NOT NULL,
  archived_policy_id bigint,
  name integer,
  starts_at timestamp,
  name_3 double precision NOT NULL,
  body timestamptz NOT NULL,
  body_5 double precision,
  code double precision,
  checksum bytea,
  created_at text,
  created_at_9 varchar(64)
);

CREATE TABLE legacy_campaign_link (
  id bigint PRIMARY KEY,
  archived_asset_id bigint NOT NULL REFERENCES archived_asset(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  v2_account_history_id bigint NOT NULL REFERENCES v2_account_history(id),
  total bytea NOT NULL,
  email char(2),
  updated_at varchar(64),
  slug numeric(12,2) NOT NULL,
  label inet,
  price smallint
);
/* trailing block comment */

CREATE TABLE v2_contract_history (
  id bigint PRIMARY KEY,
  metadata boolean,
  kind bytea NOT NULL,
  checksum jsonb NOT NULL
);

CREATE TABLE archived_order_audit (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  v2_inventory_config_id bigint,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  amount bigint,
  body text,
  total timestamp,
  email varchar(255)
);

CREATE TABLE archived_ticket (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  legacy_channel_id bigint NOT NULL REFERENCES legacy_channel(id),
  quantity date,
  version smallint NOT NULL,
  starts_at bigint NOT NULL,
  email double precision,
  phone jsonb,
  weight smallint NOT NULL,
  code char(2) NOT NULL,
  checksum char(2),
  UNIQUE (code)
);

CREATE TABLE v2_route_link (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint,
  legacy_payment_item_id bigint NOT NULL REFERENCES legacy_payment_item(id),
  booking_line_id bigint REFERENCES booking_line(id),
  currency boolean,
  total bytea NOT NULL,
  position uuid,
  slug bigint NOT NULL,
  external_ref bytea NOT NULL,
  position_6 jsonb,
  weight bytea,
  position_8 timestamp NOT NULL,
  deleted_at boolean NOT NULL
);
/* trailing block comment */

-- refund_line: 12 columns
CREATE TABLE "public"."refund_line" (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  label varchar(255) NOT NULL,
  checksum jsonb NOT NULL,
  currency date NOT NULL,
  name date NOT NULL,
  title timestamp,
  checksum_6 varchar(255),
  slug smallint,
  is_locked integer,
  code varchar(255)
);

CREATE TABLE archived_inventory_snapshot (
  id bigint PRIMARY KEY,
  version char(2),
  total numeric(12,2) NOT NULL,
  position boolean,
  title uuid,
  created_at varchar(64) NOT NULL,
  expires_at timestamptz,
  metadata timestamptz NOT NULL,
  email text NOT NULL,
  deleted_at varchar(64)
);

CREATE TABLE archived_review_audit (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  body date NOT NULL,
  code timestamptz,
  external_ref integer NOT NULL,
  UNIQUE (project_history_id)
);

CREATE TABLE category (
  id bigint PRIMARY KEY,
  amount date NOT NULL,
  rate varchar(64),
  checksum timestamptz NOT NULL,
  currency uuid NOT NULL,
  weight jsonb NOT NULL
);

CREATE TABLE external_review_audit (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  refund_audit_id bigint REFERENCES refund_audit(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  weight uuid NOT NULL,
  label numeric(12,2),
  starts_at timestamp NOT NULL,
  weight_4 bigint,
  amount text,
  title jsonb
);

-- staging_subscription_audit: 8 columns
CREATE TABLE staging_subscription_audit (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  expires_at inet NOT NULL,
  code integer,
  metadata date NOT NULL,
  name uuid NOT NULL,
  metadata_5 inet NOT NULL
);

CREATE TABLE public.message_item (
  id bigint PRIMARY KEY,
  external_discount_id bigint NOT NULL,
  warehouse_history_id bigint REFERENCES warehouse_history(id),
  account_line_id bigint NOT NULL REFERENCES account_line(id),
  booking_item_id bigint REFERENCES booking_item(id),
  name boolean,
  timezone char(2),
  price jsonb NOT NULL,
  email timestamp NOT NULL
);
/* trailing block comment */

CREATE TABLE customer_detail (
  id bigint PRIMARY KEY,
  staging_payment_audit_id bigint NOT NULL REFERENCES staging_payment_audit(id),
  legacy_channel_id bigint NOT NULL REFERENCES legacy_channel(id),
  legacy_project_audit_id bigint NOT NULL REFERENCES legacy_project_audit(id),
  external_payment_id bigint NOT NULL,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  booking_id bigint NOT NULL REFERENCES booking(id),
  archived_order_id bigint REFERENCES archived_order(id),
  amount varchar(255) NOT NULL,
  is_active text,
  deleted_at numeric(12,2) NOT NULL,
  weight jsonb NOT NULL,
  starts_at inet NOT NULL,
  phone varchar(255),
  amount_7 varchar(64),
  timezone jsonb NOT NULL
);

CREATE TABLE category_link (
  id bigint PRIMARY KEY,
  v2_ticket_detail_id bigint NOT NULL,
  timezone varchar(255),
  locale double precision,
  name date,
  starts_at smallint NOT NULL,
  is_default timestamptz NOT NULL,
  kind boolean,
  title uuid NOT NULL,
  is_active integer,
  metadata integer,
  checksum inet NOT NULL
);

CREATE TABLE inventory_line (
  id bigint PRIMARY KEY,
  archived_department_link_id bigint NOT NULL,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  code text,
  amount integer NOT NULL,
  deleted_at boolean,
  is_default jsonb NOT NULL,
  is_active jsonb,
  total uuid NOT NULL
);

CREATE TABLE staging_route_meta (
  id bigint PRIMARY KEY,
  note char(2),
  currency timestamptz NOT NULL,
  status date,
  quantity numeric(12,2) NOT NULL,
  label numeric(12,2),
  version bytea NOT NULL,
  email char(2) NOT NULL,
  currency_8 date NOT NULL
);

CREATE TABLE legacy_asset_audit (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  warehouse_audit_id bigint NOT NULL,
  legacy_message_line_id bigint NOT NULL REFERENCES legacy_message_line(id),
  refund_detail_id bigint REFERENCES refund_detail(id),
  email timestamp NOT NULL,
  label uuid NOT NULL,
  note integer
);

CREATE TABLE public.department_policy (
  id bigint PRIMARY KEY,
  external_category_detail_id bigint NOT NULL REFERENCES external_category_detail(id),
  external_tag_audit_id bigint NOT NULL REFERENCES external_tag_audit(id),
  external_category_item_id bigint NOT NULL REFERENCES external_category_item(id),
  staging_inventory_history_id bigint NOT NULL REFERENCES staging_inventory_history(id),
  amount boolean,
  locale bytea NOT NULL,
  price varchar(64) NOT NULL,
  label varchar(255)
);

CREATE TABLE external_notification_line (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  staging_session_meta_id bigint NOT NULL REFERENCES staging_session_meta(id),
  legacy_shipment_leg_id bigint REFERENCES legacy_shipment_leg(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  external_booking_line_id bigint REFERENCES external_booking_line(id),
  external_ref char(2),
  weight uuid,
  phone uuid NOT NULL
);

CREATE TABLE "public"."archived_attachment" (
  id bigint PRIMARY KEY,
  staging_notification_meta_id bigint NOT NULL REFERENCES staging_notification_meta(id),
  discount_id bigint REFERENCES discount(id),
  total uuid,
  status uuid
);

CREATE TABLE archived_warehouse (
  id bigint PRIMARY KEY,
  archived_category_id bigint NOT NULL REFERENCES archived_category(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  phone bytea,
  currency timestamp NOT NULL,
  external_ref date,
  amount timestamp
);

CREATE TABLE archived_invoice_meta (
  id bigint PRIMARY KEY,
  staging_notification_config_id bigint REFERENCES staging_notification_config(id),
  external_contract_audit_id bigint NOT NULL REFERENCES external_contract_audit(id),
  payment_config_id bigint REFERENCES payment_config(id),
  kind bytea,
  weight timestamp,
  note jsonb NOT NULL
);

CREATE TABLE claim (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  status boolean,
  is_active text,
  locale uuid,
  quantity varchar(255) NOT NULL,
  total uuid,
  price bytea,
  phone integer,
  UNIQUE (quantity)
);

CREATE TABLE archived_customer_meta (
  id bigint PRIMARY KEY,
  body numeric(12,2),
  starts_at uuid,
  quantity boolean,
  total varchar(255),
  amount inet,
  UNIQUE (quantity)
);

-- vendor_line: 14 columns
CREATE TABLE vendor_line (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  currency timestamptz,
  slug boolean,
  weight timestamptz NOT NULL,
  title numeric(12,2) NOT NULL,
  created_at jsonb NOT NULL,
  label bigint,
  locale timestamp,
  is_active jsonb,
  expires_at varchar(64),
  status integer
);
/* trailing block comment */

CREATE TABLE legacy_campaign_line (
  id bigint PRIMARY KEY,
  v2_customer_snapshot_id bigint,
  warehouse_history_id bigint REFERENCES warehouse_history(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  deleted_at varchar(255) NOT NULL,
  price smallint NOT NULL,
  name bytea,
  rate numeric(12,2),
  status date NOT NULL,
  expires_at text NOT NULL,
  version inet,
  body uuid
);

CREATE TABLE external_session (
  id bigint PRIMARY KEY,
  external_vendor_line_id bigint NOT NULL,
  legacy_tag_detail_id bigint REFERENCES legacy_tag_detail(id),
  phone bigint NOT NULL,
  status varchar(64),
  checksum timestamp NOT NULL,
  status_4 double precision,
  checksum_5 date NOT NULL,
  is_default smallint,
  UNIQUE (status)
);

CREATE TABLE v2_policy_snapshot (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  total inet NOT NULL,
  weight jsonb,
  rate timestamptz,
  phone timestamptz,
  kind numeric(12,2),
  code boolean,
  weight_7 timestamp,
  version bytea NOT NULL
);

CREATE TABLE external_channel_link (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  external_shipment_leg_line_id bigint REFERENCES external_shipment_leg_line(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  tag_detail_id bigint REFERENCES tag_detail(id),
  label varchar(64),
  amount numeric(12,2) NOT NULL,
  position varchar(255),
  updated_at integer,
  checksum date NOT NULL
);

CREATE TABLE external_department_history (
  id bigint PRIMARY KEY,
  discount_item_id bigint NOT NULL REFERENCES discount_item(id),
  updated_at jsonb,
  is_active timestamptz,
  external_ref numeric(12,2),
  price bytea NOT NULL,
  created_at jsonb NOT NULL,
  timezone smallint NOT NULL,
  weight uuid,
  starts_at smallint,
  UNIQUE (updated_at)
);

-- archived_warehouse_item: 11 columns
CREATE TABLE "public"."archived_warehouse_item" (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  v2_session_detail_id bigint REFERENCES v2_session_detail(id),
  asset_snapshot_id bigint NOT NULL REFERENCES asset_snapshot(id),
  project_audit_id bigint NOT NULL REFERENCES project_audit(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  updated_at text NOT NULL,
  rate text NOT NULL,
  code uuid,
  quantity char(2) NOT NULL,
  currency numeric(12,2)
);

CREATE TABLE policy_history (
  id bigint PRIMARY KEY,
  session_item_id bigint NOT NULL REFERENCES session_item(id),
  slug bytea,
  currency char(2),
  starts_at uuid NOT NULL
);

-- subscription_history: 8 columns
CREATE TABLE subscription_history (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL,
  weight varchar(255),
  weight_2 text NOT NULL,
  external_ref text,
  amount inet,
  total date NOT NULL,
  expires_at integer
);

CREATE TABLE "v2_order" (
  id bigint PRIMARY KEY,
  quantity timestamp,
  rate timestamptz,
  slug char(2),
  name varchar(255) NOT NULL,
  starts_at text NOT NULL,
  rate_6 varchar(64)
);

CREATE TABLE external_claim_detail (
  id bigint PRIMARY KEY,
  contract_snapshot_id bigint NOT NULL REFERENCES contract_snapshot(id),
  archived_policy_id bigint REFERENCES archived_policy(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  tag_snapshot_id bigint NOT NULL REFERENCES tag_snapshot(id),
  checksum bigint NOT NULL,
  metadata timestamptz,
  external_ref integer,
  name boolean NOT NULL,
  updated_at text NOT NULL,
  email varchar(64)
);

CREATE TABLE staging_session_config (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  expires_at numeric(12,2),
  is_default inet,
  checksum jsonb,
  version jsonb,
  code jsonb
);

CREATE TABLE vehicle_meta (
  id bigint PRIMARY KEY,
  legacy_account_id bigint REFERENCES legacy_account(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  phone smallint,
  price double precision NOT NULL,
  starts_at uuid NOT NULL,
  email numeric(12,2),
  is_default varchar(64),
  version inet
);

-- staging_category_detail: 11 columns
CREATE TABLE staging_category_detail (
  id bigint PRIMARY KEY,
  legacy_account_id bigint REFERENCES legacy_account(id),
  position boolean,
  price date,
  deleted_at double precision,
  phone char(2),
  title date,
  label text NOT NULL,
  is_default bigint,
  name date NOT NULL,
  starts_at bytea
);

-- staging_employee: 5 columns
CREATE TABLE staging_employee (
  id bigint PRIMARY KEY,
  status timestamptz NOT NULL,
  weight inet NOT NULL,
  title char(2),
  metadata inet NOT NULL
);

CREATE TABLE archived_route_line (
  id bigint PRIMARY KEY,
  legacy_review_config_id bigint REFERENCES legacy_review_config(id),
  expires_at varchar(64) NOT NULL,
  title char(2) NOT NULL,
  created_at date,
  is_locked inet NOT NULL
);
/* trailing block comment */

CREATE TABLE contract_detail (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  weight text,
  locale integer,
  external_ref integer,
  currency bigint NOT NULL,
  version numeric(12,2),
  updated_at char(2)
);

CREATE TABLE vendor_item (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  timezone char(2),
  metadata bytea,
  starts_at timestamp,
  updated_at timestamptz,
  version numeric(12,2) NOT NULL,
  updated_at_6 date,
  name timestamptz
);

-- contract_snapshot: 9 columns
CREATE TABLE contract_snapshot (
  id bigint PRIMARY KEY,
  legacy_account_meta_id bigint NOT NULL REFERENCES legacy_account_meta(id),
  invoice_link_id bigint NOT NULL,
  staging_policy_history_id bigint NOT NULL REFERENCES staging_policy_history(id),
  phone boolean,
  metadata varchar(255),
  updated_at timestamptz NOT NULL,
  currency jsonb NOT NULL,
  status inet
);

-- warehouse_item: 13 columns
CREATE TABLE warehouse_item (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  vehicle_link_id bigint NOT NULL REFERENCES vehicle_link(id),
  archived_session_line_id bigint NOT NULL REFERENCES archived_session_line(id),
  deleted_at bytea,
  phone bigint NOT NULL,
  code varchar(64),
  is_active text NOT NULL,
  expires_at timestamp NOT NULL,
  body boolean,
  is_default bigint NOT NULL,
  metadata smallint,
  currency bytea
);

CREATE TABLE staging_order_history (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  name boolean NOT NULL,
  slug numeric(12,2) NOT NULL,
  status timestamptz,
  kind timestamptz NOT NULL,
  currency integer,
  status_6 smallint
);

CREATE TABLE external_policy_link (
  id bigint PRIMARY KEY,
  archived_project_audit_id bigint REFERENCES archived_project_audit(id),
  created_at timestamp,
  locale date NOT NULL,
  is_active integer NOT NULL,
  currency integer,
  locale_5 smallint NOT NULL,
  title uuid,
  weight numeric(12,2),
  name double precision,
  checksum inet
);

CREATE TABLE external_project_history (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  staging_notification_id bigint REFERENCES staging_notification(id),
  kind char(2),
  price date,
  slug varchar(64) NOT NULL,
  is_locked bytea,
  label inet NOT NULL,
  UNIQUE (slug)
);

-- legacy_session_item: 8 columns
CREATE TABLE legacy_session_item (
  id bigint PRIMARY KEY,
  archived_policy_id bigint REFERENCES archived_policy(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  discount_id bigint NOT NULL,
  expires_at varchar(64),
  metadata smallint,
  created_at integer NOT NULL,
  UNIQUE (created_at)
);

CREATE TABLE document_detail (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  staging_vehicle_config_id bigint REFERENCES staging_vehicle_config(id),
  contract_config_id bigint REFERENCES contract_config(id),
  archived_shipment_id bigint NOT NULL REFERENCES archived_shipment(id),
  staging_employee_meta_id bigint NOT NULL REFERENCES staging_employee_meta(id),
  position jsonb,
  title integer NOT NULL,
  UNIQUE (archived_shipment_id)
);
/* trailing block comment */

CREATE TABLE "public"."legacy_project_line" (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  slug varchar(64),
  slug_2 text,
  note uuid,
  email timestamp,
  external_ref jsonb NOT NULL
);

CREATE TABLE staging_order (
  id bigint PRIMARY KEY,
  department_line_id bigint NOT NULL REFERENCES department_line(id),
  metadata boolean NOT NULL,
  updated_at timestamptz,
  label smallint NOT NULL,
  label_4 smallint
);

CREATE TABLE v2_tag_link (
  id bigint PRIMARY KEY,
  subscription_meta_id bigint,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  created_at bytea NOT NULL,
  deleted_at bytea NOT NULL,
  phone timestamptz NOT NULL,
  phone_4 bigint,
  starts_at numeric(12,2) NOT NULL
);

CREATE TABLE "public"."archived_ticket_snapshot" (
  id bigint PRIMARY KEY,
  campaign_audit_id bigint REFERENCES campaign_audit(id),
  phone boolean,
  quantity date NOT NULL,
  note timestamp NOT NULL,
  starts_at smallint NOT NULL,
  metadata timestamp NOT NULL,
  is_active timestamptz NOT NULL,
  email double precision,
  UNIQUE (metadata)
);

-- shipment_leg_detail: 6 columns
CREATE TABLE shipment_leg_detail (
  id bigint PRIMARY KEY,
  external_order_meta_id bigint NOT NULL REFERENCES external_order_meta(id),
  contract_item_id bigint NOT NULL REFERENCES contract_item(id),
  slug date,
  checksum varchar(64) NOT NULL,
  phone uuid,
  UNIQUE (contract_item_id)
);

CREATE TABLE archived_review_detail (
  id bigint PRIMARY KEY,
  staging_contract_audit_id bigint REFERENCES staging_contract_audit(id),
  created_at integer NOT NULL,
  is_active char(2) NOT NULL,
  version smallint
);

CREATE TABLE archived_booking (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  status numeric(12,2),
  expires_at bytea,
  rate double precision NOT NULL,
  quantity numeric(12,2) NOT NULL,
  rate_5 jsonb,
  currency uuid,
  label numeric(12,2),
  UNIQUE (v2_shipment_leg_meta_id)
);

CREATE TABLE external_refund_link (
  id bigint PRIMARY KEY,
  vendor_line_id bigint NOT NULL REFERENCES vendor_line(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  v2_task_item_id bigint,
  customer_snapshot_id bigint NOT NULL,
  metadata jsonb NOT NULL,
  currency smallint NOT NULL,
  kind numeric(12,2),
  version jsonb NOT NULL,
  is_default smallint
);

CREATE TABLE asset_line (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  currency char(2),
  created_at varchar(255) NOT NULL,
  label char(2),
  label_4 uuid NOT NULL,
  timezone boolean,
  version text,
  body jsonb,
  title jsonb NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_order_config (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  currency jsonb,
  name double precision,
  expires_at timestamp,
  slug inet,
  expires_at_5 smallint NOT NULL,
  body bigint NOT NULL,
  title integer NOT NULL,
  created_at bytea,
  amount inet,
  UNIQUE (discount_id)
);

CREATE TABLE v2_shipment_leg (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  v2_audit_item_id bigint NOT NULL,
  price inet NOT NULL,
  name bytea
);
/* trailing block comment */

CREATE TABLE archived_invoice (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL,
  is_default double precision NOT NULL,
  price timestamptz,
  position bigint,
  timezone uuid
);

CREATE TABLE external_document_history (
  id bigint PRIMARY KEY,
  external_invoice_snapshot_id bigint NOT NULL REFERENCES external_invoice_snapshot(id),
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  deleted_at varchar(255),
  is_active timestamptz,
  label timestamptz,
  quantity text,
  UNIQUE (quantity)
);

CREATE TABLE "staging_booking" (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  body bigint,
  currency integer NOT NULL,
  is_active timestamptz
);

CREATE TABLE legacy_shipment_leg (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  task_config_id bigint NOT NULL REFERENCES task_config(id),
  rate jsonb,
  checksum varchar(64)
);

CREATE TABLE v2_contract_item (
  id bigint PRIMARY KEY,
  staging_notification_meta_id bigint NOT NULL REFERENCES staging_notification_meta(id),
  v2_task_link_id bigint REFERENCES v2_task_link(id),
  title boolean,
  is_active date NOT NULL,
  external_ref timestamp NOT NULL,
  rate varchar(64) NOT NULL,
  expires_at smallint,
  is_locked varchar(255) NOT NULL
);

CREATE TABLE "contract_audit" (
  id bigint PRIMARY KEY,
  subscription_audit_id bigint REFERENCES subscription_audit(id),
  vehicle_item_id bigint REFERENCES vehicle_item(id),
  rate smallint NOT NULL,
  quantity varchar(255) NOT NULL,
  timezone uuid,
  rate_4 date,
  weight uuid,
  currency smallint NOT NULL
);

CREATE TABLE public.v2_policy_link (
  id bigint PRIMARY KEY,
  staging_campaign_history_id bigint NOT NULL REFERENCES staging_campaign_history(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  label date,
  starts_at integer,
  total text,
  checksum boolean,
  updated_at text
);
/* trailing block comment */

CREATE TABLE vehicle_snapshot (
  id bigint PRIMARY KEY,
  campaign_line_id bigint NOT NULL,
  name bigint,
  title date,
  body text,
  currency char(2) NOT NULL
);

-- route_link: 4 columns
CREATE TABLE route_link (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  amount jsonb,
  is_active inet
);

CREATE TABLE legacy_employee_snapshot (
  id bigint PRIMARY KEY,
  v2_refund_id bigint,
  title timestamp NOT NULL,
  slug timestamp NOT NULL,
  deleted_at inet NOT NULL
);

CREATE TABLE staging_policy_line (
  id bigint PRIMARY KEY,
  name varchar(255) NOT NULL,
  starts_at uuid,
  title bytea,
  currency bytea,
  phone uuid
);

CREATE TABLE staging_payment (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  discount_id bigint NOT NULL,
  kind timestamptz NOT NULL,
  code numeric(12,2) NOT NULL,
  title integer,
  currency text
);

CREATE TABLE public.review_detail (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  booking_line_id bigint REFERENCES booking_line(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  starts_at text,
  price integer NOT NULL,
  created_at timestamptz
);
/* trailing block comment */

CREATE TABLE employee_snapshot (
  id bigint PRIMARY KEY,
  quantity timestamp NOT NULL,
  email uuid,
  starts_at timestamptz,
  currency char(2) NOT NULL
);

CREATE TABLE external_warehouse_link (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  label char(2) NOT NULL,
  title bigint,
  version char(2) NOT NULL,
  slug timestamp,
  position varchar(255) NOT NULL,
  currency inet NOT NULL,
  note smallint NOT NULL,
  slug_8 inet,
  UNIQUE (slug)
);

CREATE TABLE staging_project_meta (
  id bigint PRIMARY KEY,
  legacy_account_meta_id bigint NOT NULL REFERENCES legacy_account_meta(id),
  timezone varchar(255),
  starts_at date,
  rate varchar(255),
  metadata bytea NOT NULL,
  name text NOT NULL,
  locale text,
  quantity jsonb NOT NULL,
  weight bytea NOT NULL,
  total integer,
  title varchar(64)
);

-- v2_payment: 9 columns
CREATE TABLE v2_payment (
  id bigint PRIMARY KEY,
  external_account_detail_id bigint NOT NULL REFERENCES external_account_detail(id),
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  created_at inet,
  deleted_at numeric(12,2),
  position smallint NOT NULL,
  status date NOT NULL,
  note double precision,
  version varchar(64)
);

CREATE TABLE archived_vehicle_link (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  external_payment_meta_id bigint NOT NULL REFERENCES external_payment_meta(id),
  quantity text,
  currency uuid,
  phone date,
  external_ref bigint NOT NULL,
  body smallint,
  weight bigint NOT NULL,
  deleted_at smallint,
  price varchar(64),
  checksum uuid
);

CREATE TABLE category_detail (
  id bigint PRIMARY KEY,
  account_detail_id bigint NOT NULL REFERENCES account_detail(id),
  v2_document_line_id bigint NOT NULL REFERENCES v2_document_line(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  email inet,
  note bytea NOT NULL,
  title timestamptz,
  is_active timestamp NOT NULL,
  quantity double precision NOT NULL,
  phone bigint NOT NULL,
  rate timestamp,
  code jsonb,
  label date NOT NULL
);

CREATE TABLE booking_history (
  id bigint PRIMARY KEY,
  v2_ticket_line_id bigint NOT NULL,
  timezone text,
  code bytea,
  weight jsonb NOT NULL,
  deleted_at smallint,
  amount smallint NOT NULL,
  email char(2) NOT NULL,
  kind char(2)
);

CREATE TABLE discount_item (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  v2_department_detail_id bigint,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  staging_department_history_id bigint NOT NULL,
  label timestamptz NOT NULL,
  title varchar(255),
  deleted_at boolean NOT NULL,
  is_active boolean,
  checksum bigint NOT NULL,
  updated_at boolean,
  kind bytea,
  UNIQUE (staging_department_history_id)
);

CREATE TABLE legacy_vehicle_history (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  note boolean,
  amount varchar(64) NOT NULL,
  label uuid NOT NULL,
  phone varchar(64) NOT NULL,
  note_5 varchar(64) NOT NULL,
  checksum timestamptz,
  is_locked double precision NOT NULL,
  updated_at boolean,
  created_at double precision
);

-- session_vehicle: 7 columns
CREATE TABLE session_vehicle (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  quantity integer,
  rate uuid NOT NULL,
  slug timestamptz,
  expires_at varchar(255)
);

CREATE TABLE external_department_detail (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  is_locked boolean NOT NULL,
  created_at text,
  note bytea,
  checksum boolean NOT NULL,
  currency boolean NOT NULL,
  updated_at uuid,
  deleted_at boolean NOT NULL,
  starts_at smallint,
  status char(2)
);

CREATE TABLE task_link (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  starts_at uuid NOT NULL,
  note timestamp NOT NULL
);

CREATE TABLE vehicle_line (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  booking_line_id bigint REFERENCES booking_line(id),
  vendor_history_id bigint REFERENCES vendor_history(id),
  amount char(2),
  status varchar(255),
  created_at inet NOT NULL,
  external_ref double precision NOT NULL,
  UNIQUE (status)
);

CREATE TABLE v2_claim_config (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  currency double precision NOT NULL,
  quantity boolean,
  starts_at timestamp NOT NULL,
  is_locked boolean,
  timezone smallint NOT NULL,
  slug smallint,
  slug_7 char(2),
  title boolean,
  quantity_9 varchar(64),
  timezone_10 bigint
);

CREATE TABLE v2_template (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  email varchar(64),
  created_at boolean,
  weight timestamp NOT NULL,
  status boolean,
  rate inet
);

CREATE TABLE channel_review (
  id bigint PRIMARY KEY,
  archived_policy_id bigint REFERENCES archived_policy(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  total char(2),
  created_at timestamptz,
  metadata integer NOT NULL
);
/* trailing block comment */

-- document: 13 columns
CREATE TABLE document (
  id bigint PRIMARY KEY,
  v2_tag_link_id bigint NOT NULL REFERENCES v2_tag_link(id),
  archived_contract_config_id bigint NOT NULL REFERENCES archived_contract_config(id),
  amount inet NOT NULL,
  slug jsonb,
  created_at uuid NOT NULL,
  locale bigint,
  position boolean,
  note timestamp,
  note_7 timestamp,
  timezone timestamp,
  version varchar(255),
  weight varchar(64) NOT NULL
);

-- archived_session_detail: 7 columns
CREATE TABLE public.archived_session_detail (
  id bigint PRIMARY KEY,
  archived_warehouse_item_id bigint NOT NULL REFERENCES archived_warehouse_item(id),
  quantity integer NOT NULL,
  checksum boolean,
  body timestamptz NOT NULL,
  timezone smallint,
  expires_at date
);
/* trailing block comment */

CREATE TABLE v2_invoice_meta (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  external_template_detail_id bigint REFERENCES external_template_detail(id),
  quantity double precision NOT NULL,
  title double precision NOT NULL,
  position boolean,
  updated_at timestamp
);

-- order_item: 5 columns
CREATE TABLE order_item (
  id bigint PRIMARY KEY,
  v2_session_line_id bigint NOT NULL REFERENCES v2_session_line(id),
  warehouse_id bigint NOT NULL REFERENCES warehouse(id),
  updated_at varchar(64),
  updated_at_2 jsonb NOT NULL,
  UNIQUE (v2_session_line_id)
);

CREATE TABLE legacy_audit_meta (
  id bigint PRIMARY KEY,
  campaign_id bigint NOT NULL,
  archived_order_config_id bigint NOT NULL REFERENCES archived_order_config(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  locale varchar(255) NOT NULL,
  expires_at timestamp NOT NULL,
  updated_at uuid NOT NULL,
  code inet,
  kind timestamptz,
  UNIQUE (locale)
);

-- notification_link: 10 columns
CREATE TABLE notification_link (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  note varchar(255) NOT NULL,
  quantity timestamptz NOT NULL,
  metadata bigint,
  deleted_at bigint,
  is_locked bigint,
  quantity_6 jsonb NOT NULL,
  slug date
);

CREATE TABLE external_document (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  locale smallint NOT NULL,
  currency bigint,
  kind smallint,
  version bytea,
  body uuid,
  currency_6 double precision NOT NULL,
  kind_7 numeric(12,2),
  slug timestamptz,
  UNIQUE (currency)
);

CREATE TABLE route_meta (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  archived_account_audit_id bigint,
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  is_active varchar(255),
  created_at bigint NOT NULL,
  locale bigint,
  amount double precision,
  status varchar(255)
);
/* trailing block comment */

CREATE TABLE "public"."legacy_department_snapshot" (
  id bigint PRIMARY KEY,
  starts_at timestamptz NOT NULL,
  note date NOT NULL,
  rate smallint NOT NULL,
  starts_at_4 smallint,
  body integer NOT NULL,
  label char(2),
  currency varchar(64),
  currency_8 timestamp NOT NULL
);

-- archived_booking_audit: 8 columns
CREATE TABLE archived_booking_audit (
  id bigint PRIMARY KEY,
  legacy_campaign_config_id bigint REFERENCES legacy_campaign_config(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  route_meta_id bigint NOT NULL,
  v2_customer_snapshot_id bigint NOT NULL REFERENCES v2_customer_snapshot(id),
  expires_at jsonb NOT NULL,
  is_default varchar(255),
  name varchar(64),
  UNIQUE (warehouse_audit_id)
);

CREATE TABLE staging_audit (
  id bigint PRIMARY KEY,
  account_line_id bigint NOT NULL REFERENCES account_line(id),
  external_discount_line_id bigint NOT NULL REFERENCES external_discount_line(id),
  v2_discount_config_id bigint,
  legacy_vehicle_link_id bigint,
  expires_at uuid,
  status date,
  slug jsonb NOT NULL,
  kind numeric(12,2),
  amount varchar(255)
);

-- legacy_booking_meta: 9 columns
CREATE TABLE legacy_booking_meta (
  id bigint PRIMARY KEY,
  created_at double precision,
  external_ref uuid NOT NULL,
  amount integer,
  slug numeric(12,2) NOT NULL,
  locale inet NOT NULL,
  is_active uuid NOT NULL,
  starts_at smallint NOT NULL,
  starts_at_8 smallint
);

-- legacy_policy_line: 13 columns
CREATE TABLE legacy_policy_line (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL,
  legacy_document_line_id bigint NOT NULL REFERENCES legacy_document_line(id),
  staging_shipment_leg_config_id bigint NOT NULL,
  policy_item_id bigint REFERENCES policy_item(id),
  metadata jsonb,
  position varchar(255),
  checksum boolean NOT NULL,
  is_locked date NOT NULL,
  note timestamp,
  total jsonb,
  starts_at smallint,
  starts_at_8 bigint NOT NULL
);

CREATE TABLE refund_config (
  id bigint PRIMARY KEY,
  legacy_carrier_link_id bigint NOT NULL REFERENCES legacy_carrier_link(id),
  legacy_shipment_leg_id bigint REFERENCES legacy_shipment_leg(id),
  staging_template_item_id bigint NOT NULL,
  body inet NOT NULL,
  note numeric(12,2) NOT NULL,
  quantity varchar(255) NOT NULL,
  label numeric(12,2),
  metadata timestamptz,
  updated_at bigint,
  UNIQUE (staging_template_item_id)
);

CREATE TABLE "public"."policy_meta" (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  staging_customer_item_id bigint REFERENCES staging_customer_item(id),
  weight double precision NOT NULL,
  checksum smallint
);

-- legacy_audit_history: 9 columns
CREATE TABLE "public"."legacy_audit_history" (
  id bigint PRIMARY KEY,
  discount_id bigint REFERENCES discount(id),
  is_locked date,
  phone uuid NOT NULL,
  name timestamp NOT NULL,
  phone_4 boolean,
  name_5 numeric(12,2),
  title boolean NOT NULL,
  note bigint NOT NULL
);

-- legacy_product_history: 12 columns
CREATE TABLE "public"."legacy_product_history" (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  note boolean,
  is_default bigint,
  title jsonb,
  price text,
  quantity double precision,
  code varchar(64),
  note_7 text,
  starts_at bigint,
  kind bigint
);

-- policy_claim: 5 columns
CREATE TABLE policy_claim (
  id bigint PRIMARY KEY,
  checksum varchar(255),
  quantity text,
  position uuid,
  checksum_4 integer,
  UNIQUE (checksum_4)
);

CREATE TABLE staging_ticket_meta (
  id bigint PRIMARY KEY,
  v2_warehouse_history_id bigint REFERENCES v2_warehouse_history(id),
  is_locked bytea NOT NULL,
  body integer NOT NULL,
  quantity numeric(12,2),
  amount text,
  name varchar(64),
  note timestamptz NOT NULL,
  created_at char(2),
  position integer,
  UNIQUE (amount)
);
/* trailing block comment */

CREATE TABLE "booking_snapshot" (
  id bigint PRIMARY KEY,
  external_asset_detail_id bigint NOT NULL REFERENCES external_asset_detail(id),
  booking_line_id bigint REFERENCES booking_line(id),
  rate timestamptz NOT NULL,
  quantity bigint NOT NULL,
  external_ref uuid NOT NULL,
  body text,
  currency inet,
  amount numeric(12,2),
  slug text,
  amount_8 varchar(64),
  expires_at varchar(64),
  UNIQUE (slug)
);

CREATE TABLE legacy_route_meta (
  id bigint PRIMARY KEY,
  staging_session_id bigint NOT NULL,
  booking_line_id bigint REFERENCES booking_line(id),
  slug bigint,
  deleted_at varchar(64),
  quantity boolean NOT NULL,
  locale varchar(255) NOT NULL
);

CREATE TABLE v2_discount (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  external_ref varchar(255),
  deleted_at date,
  starts_at date,
  deleted_at_4 integer,
  locale numeric(12,2),
  note char(2),
  position smallint,
  expires_at double precision NOT NULL
);

-- archived_department_detail: 14 columns
CREATE TABLE archived_department_detail (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  price numeric(12,2),
  starts_at smallint,
  is_active boolean,
  note text,
  external_ref bigint,
  amount jsonb,
  slug varchar(64) NOT NULL,
  total char(2),
  note_9 smallint NOT NULL,
  version numeric(12,2) NOT NULL,
  UNIQUE (slug)
);

CREATE TABLE vehicle_item (
  id bigint PRIMARY KEY,
  position varchar(255),
  is_default timestamptz,
  timezone char(2),
  code varchar(255) NOT NULL,
  is_active inet,
  code_6 jsonb NOT NULL,
  name smallint NOT NULL
);

-- v2_account_history: 6 columns
CREATE TABLE v2_account_history (
  id bigint PRIMARY KEY,
  archived_department_config_id bigint REFERENCES archived_department_config(id),
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  updated_at text,
  is_default timestamptz,
  total timestamptz
);

-- legacy_order_item: 9 columns
CREATE TABLE legacy_order_item (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  title text,
  code date,
  quantity varchar(255),
  external_ref timestamp NOT NULL,
  slug jsonb,
  kind varchar(64),
  title_7 timestamptz
);
/* trailing block comment */

CREATE TABLE legacy_session_audit (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  code inet NOT NULL,
  label timestamp,
  is_active bigint NOT NULL
);

CREATE TABLE carrier_snapshot (
  id bigint PRIMARY KEY,
  order_item_id bigint,
  price text NOT NULL,
  metadata bigint,
  body bigint,
  note jsonb,
  code uuid,
  label char(2) NOT NULL,
  deleted_at varchar(64),
  external_ref integer NOT NULL
);

CREATE TABLE attachment_audit (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  archived_order_id bigint NOT NULL,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  booking_line_id bigint NOT NULL,
  is_active text,
  status bigint NOT NULL,
  deleted_at numeric(12,2),
  title date,
  body varchar(64) NOT NULL,
  is_active_6 smallint,
  code timestamp
);

CREATE TABLE archived_session_history (
  id bigint PRIMARY KEY,
  external_asset_item_id bigint NOT NULL,
  legacy_account_config_id bigint NOT NULL REFERENCES legacy_account_config(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  project_history_id bigint NOT NULL,
  legacy_invoice_meta_id bigint,
  contract_item_id bigint NOT NULL,
  currency jsonb,
  code text NOT NULL,
  is_active varchar(255),
  rate date NOT NULL,
  weight boolean,
  email text
);

CREATE TABLE policy_line (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  legacy_asset_line_id bigint REFERENCES legacy_asset_line(id),
  amount text NOT NULL,
  expires_at smallint NOT NULL,
  name text
);

-- archived_shipment_leg_history: 8 columns
CREATE TABLE archived_shipment_leg_history (
  id bigint PRIMARY KEY,
  archived_template_detail_id bigint REFERENCES archived_template_detail(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  title integer,
  checksum integer NOT NULL,
  deleted_at numeric(12,2),
  version double precision,
  price inet
);
/* trailing block comment */

CREATE TABLE legacy_template_snapshot (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  external_project_history_id bigint NOT NULL REFERENCES external_project_history(id),
  metadata text,
  created_at integer,
  checksum varchar(255) NOT NULL,
  status jsonb NOT NULL,
  deleted_at uuid,
  label uuid NOT NULL
);

-- external_notification_item: 8 columns
CREATE TABLE external_notification_item (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  timezone jsonb NOT NULL,
  position smallint,
  version smallint NOT NULL,
  external_ref char(2) NOT NULL,
  label varchar(255),
  version_6 char(2)
);
/* trailing block comment */

-- archived_booking_line: 17 columns
CREATE TABLE archived_booking_line (
  id bigint PRIMARY KEY,
  external_employee_id bigint,
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  staging_attachment_config_id bigint NOT NULL REFERENCES staging_attachment_config(id),
  legacy_account_id bigint NOT NULL,
  external_notification_id bigint NOT NULL REFERENCES external_notification(id),
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  position numeric(12,2),
  status uuid NOT NULL,
  created_at text,
  code double precision,
  metadata text NOT NULL,
  external_ref numeric(12,2),
  version varchar(64),
  starts_at double precision,
  is_active double precision,
  locale smallint NOT NULL
);

CREATE TABLE "v2_task" (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  archived_contract_config_id bigint REFERENCES archived_contract_config(id),
  currency char(2),
  metadata numeric(12,2) NOT NULL,
  phone jsonb NOT NULL,
  phone_4 text,
  timezone char(2),
  is_active timestamp NOT NULL,
  kind varchar(255) NOT NULL
);

CREATE TABLE legacy_department_detail (
  id bigint PRIMARY KEY,
  rate varchar(255),
  checksum text,
  phone bigint NOT NULL,
  title inet,
  rate_5 text,
  position varchar(255) NOT NULL,
  UNIQUE (title)
);

CREATE TABLE ticket_snapshot (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  amount varchar(64) NOT NULL,
  position bytea,
  position_3 varchar(255) NOT NULL,
  updated_at text,
  name smallint NOT NULL,
  expires_at uuid NOT NULL,
  slug smallint,
  UNIQUE (expires_at)
);

CREATE TABLE staging_channel_snapshot (
  id bigint PRIMARY KEY,
  staging_department_snapshot_id bigint NOT NULL REFERENCES staging_department_snapshot(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  archived_policy_id bigint REFERENCES archived_policy(id),
  name jsonb,
  position bytea,
  email text NOT NULL,
  updated_at inet NOT NULL,
  version timestamp NOT NULL
);

CREATE TABLE external_audit (
  id bigint PRIMARY KEY,
  starts_at integer NOT NULL,
  name smallint,
  expires_at text,
  deleted_at integer
);

-- archived_campaign_meta: 13 columns
CREATE TABLE archived_campaign_meta (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  archived_order_id bigint,
  product_snapshot_id bigint NOT NULL,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  archived_refund_snapshot_id bigint REFERENCES archived_refund_snapshot(id),
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  note timestamptz,
  phone varchar(64),
  created_at timestamp,
  rate date,
  is_locked double precision NOT NULL,
  quantity timestamp NOT NULL
);

CREATE TABLE archived_warehouse_detail (
  id bigint PRIMARY KEY,
  project_audit_id bigint NOT NULL REFERENCES project_audit(id),
  version char(2),
  is_default double precision,
  label numeric(12,2) NOT NULL,
  version_4 jsonb NOT NULL,
  email bigint,
  created_at jsonb,
  slug double precision NOT NULL
);

CREATE TABLE discount_audit (
  id bigint PRIMARY KEY,
  tag_line_id bigint NOT NULL REFERENCES tag_line(id),
  shipment_leg_meta_id bigint NOT NULL REFERENCES shipment_leg_meta(id),
  position numeric(12,2),
  code smallint,
  note text,
  updated_at uuid,
  note_5 numeric(12,2) NOT NULL,
  updated_at_6 boolean NOT NULL,
  is_active numeric(12,2)
);

CREATE TABLE account_payment (
  id bigint PRIMARY KEY,
  project_line_id bigint NOT NULL,
  archived_policy_id bigint REFERENCES archived_policy(id),
  staging_tag_history_id bigint NOT NULL REFERENCES staging_tag_history(id),
  staging_inventory_item_id bigint NOT NULL,
  staging_template_item_id bigint,
  is_locked bytea NOT NULL,
  version varchar(255) NOT NULL,
  code integer,
  body bigint,
  price smallint NOT NULL,
  created_at timestamptz,
  name varchar(64) NOT NULL,
  currency numeric(12,2)
);

CREATE TABLE tag_meta (
  id bigint PRIMARY KEY,
  archived_category_audit_id bigint NOT NULL REFERENCES archived_category_audit(id),
  legacy_category_snapshot_id bigint NOT NULL REFERENCES legacy_category_snapshot(id),
  metadata timestamptz NOT NULL,
  note varchar(255) NOT NULL,
  status boolean NOT NULL,
  timezone varchar(255),
  phone smallint
);

CREATE TABLE v2_department_snapshot (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  booking_line_id bigint REFERENCES booking_line(id),
  archived_department_id bigint NOT NULL REFERENCES archived_department(id),
  v2_ticket_item_id bigint NOT NULL,
  locale inet,
  external_ref char(2),
  note text NOT NULL,
  is_default numeric(12,2) NOT NULL,
  position timestamp,
  checksum bigint,
  is_default_7 integer,
  is_locked boolean NOT NULL,
  note_9 timestamp,
  quantity numeric(12,2) NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_contract_meta (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL,
  timezone smallint,
  phone double precision NOT NULL,
  position integer,
  status jsonb,
  kind uuid NOT NULL,
  starts_at text NOT NULL,
  checksum uuid NOT NULL,
  external_ref numeric(12,2) NOT NULL
);

CREATE TABLE contract_history (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  is_default timestamptz,
  email text,
  slug smallint,
  total boolean NOT NULL,
  code integer,
  total_6 double precision NOT NULL
);

-- legacy_shipment_history: 6 columns
CREATE TABLE legacy_shipment_history (
  id bigint PRIMARY KEY,
  title inet,
  locale char(2),
  title_3 timestamptz,
  starts_at date NOT NULL,
  amount inet
);

CREATE TABLE notification_meta (
  id bigint PRIMARY KEY,
  archived_campaign_meta_id bigint NOT NULL,
  policy_item_id bigint REFERENCES policy_item(id),
  version timestamptz,
  currency bigint,
  price numeric(12,2) NOT NULL,
  currency_4 integer NOT NULL,
  is_locked smallint NOT NULL,
  is_active boolean,
  created_at date NOT NULL,
  price_8 text NOT NULL
);

CREATE TABLE v2_order_snapshot (
  id bigint PRIMARY KEY,
  legacy_review_audit_id bigint NOT NULL,
  discount_id bigint NOT NULL REFERENCES discount(id),
  total jsonb NOT NULL,
  title varchar(64) NOT NULL,
  phone bytea,
  starts_at jsonb,
  is_locked date,
  email jsonb
);

-- external_employee_meta: 12 columns
CREATE TABLE external_employee_meta (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  total timestamp NOT NULL,
  created_at smallint NOT NULL,
  name date,
  slug bytea NOT NULL,
  rate bytea NOT NULL,
  title integer NOT NULL,
  deleted_at varchar(255),
  checksum varchar(255) NOT NULL,
  price char(2),
  is_default bigint
);

CREATE TABLE legacy_customer_history (
  id bigint PRIMARY KEY,
  legacy_message_meta_id bigint REFERENCES legacy_message_meta(id),
  message_detail_id bigint NOT NULL REFERENCES message_detail(id),
  locale date NOT NULL,
  locale_2 integer,
  email numeric(12,2)
);

CREATE TABLE v2_task_snapshot (
  id bigint PRIMARY KEY,
  title uuid,
  position timestamp,
  email smallint,
  status inet,
  title_5 jsonb,
  quantity smallint
);

CREATE TABLE legacy_employee_audit (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  is_active uuid,
  version varchar(255),
  is_locked text,
  UNIQUE (is_locked)
);

CREATE TABLE archived_subscription (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  status timestamptz,
  updated_at varchar(255)
);

-- v2_booking_line: 10 columns
CREATE TABLE v2_booking_line (
  id bigint PRIMARY KEY,
  external_campaign_id bigint NOT NULL REFERENCES external_campaign(id),
  invoice_config_id bigint NOT NULL,
  name uuid,
  metadata integer,
  label bytea NOT NULL,
  checksum boolean NOT NULL,
  price char(2) NOT NULL,
  starts_at timestamp NOT NULL,
  name_7 timestamptz,
  UNIQUE (name)
);

CREATE TABLE employee_line (
  id bigint PRIMARY KEY,
  archived_category_id bigint REFERENCES archived_category(id),
  amount date NOT NULL,
  is_default double precision,
  is_locked smallint NOT NULL,
  external_ref integer,
  phone varchar(64) NOT NULL,
  name date NOT NULL,
  body varchar(255) NOT NULL,
  weight timestamp,
  weight_9 integer NOT NULL,
  created_at inet
);

CREATE TABLE account_audit (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  v2_shipment_leg_meta_id bigint NOT NULL,
  rate varchar(64) NOT NULL,
  phone double precision,
  title smallint NOT NULL,
  starts_at bigint,
  updated_at text NOT NULL,
  weight varchar(64),
  phone_7 varchar(255),
  version bytea,
  total smallint NOT NULL,
  total_10 inet,
  UNIQUE (updated_at)
);

CREATE TABLE legacy_tag_detail (
  id bigint PRIMARY KEY,
  legacy_account_link_id bigint NOT NULL REFERENCES legacy_account_link(id),
  expires_at jsonb,
  code timestamp,
  weight text,
  phone varchar(255),
  position double precision,
  slug bigint NOT NULL,
  label uuid NOT NULL,
  UNIQUE (expires_at)
);

CREATE TABLE legacy_employee_link (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  rate inet,
  version uuid,
  total varchar(255),
  amount inet
);

CREATE TABLE archived_template_detail (
  id bigint PRIMARY KEY,
  department_detail_id bigint NOT NULL REFERENCES department_detail(id),
  position bigint,
  metadata timestamptz,
  version smallint NOT NULL,
  is_default varchar(255),
  checksum smallint,
  position_6 uuid NOT NULL,
  deleted_at varchar(64) NOT NULL
);

CREATE TABLE v2_tag_item (
  id bigint PRIMARY KEY,
  archived_task_detail_id bigint REFERENCES archived_task_detail(id),
  kind bigint,
  total date,
  timezone timestamp
);

CREATE TABLE v2_ticket_item (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  staging_warehouse_audit_id bigint REFERENCES staging_warehouse_audit(id),
  weight date,
  version bigint,
  label bigint,
  label_4 char(2) NOT NULL,
  label_5 boolean,
  is_active jsonb
);
/* trailing block comment */

CREATE TABLE legacy_session_detail (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  external_account_item_id bigint,
  kind char(2) NOT NULL,
  is_default boolean,
  metadata bigint NOT NULL,
  expires_at char(2),
  rate double precision NOT NULL,
  created_at text,
  is_locked bytea NOT NULL,
  note text NOT NULL,
  body varchar(64) NOT NULL
);

CREATE TABLE legacy_asset_line (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL,
  v2_account_history_id bigint NOT NULL REFERENCES v2_account_history(id),
  note timestamptz NOT NULL,
  email numeric(12,2),
  position jsonb,
  phone bytea,
  position_5 jsonb NOT NULL
);

-- external_tag: 7 columns
CREATE TABLE external_tag (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  total double precision NOT NULL,
  currency bytea NOT NULL,
  total_3 numeric(12,2),
  quantity bigint
);

CREATE TABLE refund_snapshot (
  id bigint PRIMARY KEY,
  v2_department_snapshot_id bigint NOT NULL,
  legacy_document_meta_id bigint NOT NULL REFERENCES legacy_document_meta(id),
  external_document_id bigint NOT NULL REFERENCES external_document(id),
  amount char(2),
  version numeric(12,2) NOT NULL,
  label varchar(255),
  currency jsonb,
  phone date NOT NULL,
  body uuid,
  created_at date,
  slug bigint,
  code timestamptz
);

-- legacy_project_item: 5 columns
CREATE TABLE legacy_project_item (
  id bigint PRIMARY KEY,
  external_refund_link_id bigint NOT NULL REFERENCES external_refund_link(id),
  rate jsonb NOT NULL,
  created_at varchar(255) NOT NULL,
  phone jsonb
);

CREATE TABLE document_snapshot (
  id bigint PRIMARY KEY,
  external_channel_item_id bigint,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  external_ref double precision NOT NULL,
  updated_at numeric(12,2),
  version text,
  body uuid
);

CREATE TABLE public.legacy_employee (
  id bigint PRIMARY KEY,
  asset_config_id bigint REFERENCES asset_config(id),
  archived_order_id bigint NOT NULL,
  amount timestamp,
  quantity numeric(12,2),
  title boolean,
  name varchar(64),
  version varchar(255),
  updated_at smallint NOT NULL,
  updated_at_7 numeric(12,2) NOT NULL,
  total smallint
);

CREATE TABLE v2_refund_meta (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  created_at bigint NOT NULL,
  locale char(2),
  label jsonb NOT NULL,
  is_default uuid NOT NULL,
  updated_at uuid
);

-- v2_discount_detail: 5 columns
CREATE TABLE v2_discount_detail (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  rate timestamp,
  amount timestamptz,
  starts_at smallint NOT NULL,
  UNIQUE (amount)
);

CREATE TABLE external_shipment_leg (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  external_policy_id bigint NOT NULL REFERENCES external_policy(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  name bytea,
  amount char(2),
  price jsonb,
  phone bigint NOT NULL,
  name_5 varchar(255) NOT NULL
);

CREATE TABLE vendor_config (
  id bigint PRIMARY KEY,
  checksum bigint NOT NULL,
  note date,
  is_locked double precision NOT NULL,
  note_4 text,
  is_active boolean NOT NULL,
  updated_at inet,
  position uuid NOT NULL
);

CREATE TABLE task_audit (
  id bigint PRIMARY KEY,
  slug inet,
  timezone timestamptz,
  deleted_at varchar(64),
  rate uuid,
  title text
);
/* trailing block comment */

-- staging_attachment_config: 9 columns
CREATE TABLE staging_attachment_config (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  name inet,
  total double precision NOT NULL,
  phone char(2),
  code double precision NOT NULL,
  locale varchar(64),
  created_at numeric(12,2) NOT NULL,
  note boolean
);

-- document_audit: 10 columns
CREATE TABLE document_audit (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  external_category_item_id bigint REFERENCES external_category_item(id),
  deleted_at timestamptz,
  timezone text NOT NULL,
  rate char(2),
  total timestamp,
  price numeric(12,2) NOT NULL,
  timezone_6 inet NOT NULL,
  UNIQUE (price)
);

CREATE TABLE staging_claim_audit (
  id bigint PRIMARY KEY,
  status smallint,
  status_2 smallint NOT NULL,
  updated_at double precision,
  external_ref date NOT NULL,
  locale double precision NOT NULL,
  currency uuid NOT NULL,
  created_at double precision NOT NULL,
  price timestamp NOT NULL,
  UNIQUE (updated_at)
);

CREATE TABLE legacy_message_line (
  id bigint PRIMARY KEY,
  quantity varchar(255),
  total bytea NOT NULL,
  price inet,
  version jsonb,
  checksum jsonb,
  deleted_at timestamptz NOT NULL,
  quantity_7 integer NOT NULL,
  total_8 timestamptz,
  expires_at varchar(64)
);

CREATE TABLE "public"."shipment_meta" (
  id bigint PRIMARY KEY,
  staging_customer_item_id bigint REFERENCES staging_customer_item(id),
  locale bigint,
  created_at uuid NOT NULL,
  title char(2)
);

CREATE TABLE legacy_contract_item (
  id bigint PRIMARY KEY,
  is_locked boolean NOT NULL,
  is_default numeric(12,2) NOT NULL,
  version double precision NOT NULL,
  label text NOT NULL,
  code varchar(64),
  deleted_at uuid NOT NULL,
  kind inet,
  expires_at timestamp NOT NULL,
  locale timestamptz
);

-- route_project: 5 columns
CREATE TABLE route_project (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  slug jsonb NOT NULL,
  starts_at uuid NOT NULL,
  total timestamptz NOT NULL
);

CREATE TABLE archived_claim_meta (
  id bigint PRIMARY KEY,
  archived_route_item_id bigint,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  code text NOT NULL,
  checksum bigint NOT NULL,
  status jsonb NOT NULL,
  currency uuid,
  weight bigint,
  currency_6 uuid,
  label text NOT NULL,
  status_8 date,
  locale jsonb
);

-- v2_review_line: 12 columns
CREATE TABLE v2_review_line (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  title numeric(12,2) NOT NULL,
  name smallint NOT NULL,
  checksum smallint,
  checksum_4 numeric(12,2),
  is_active timestamptz NOT NULL,
  body inet NOT NULL,
  position varchar(255),
  total jsonb NOT NULL,
  version jsonb,
  note timestamptz NOT NULL
);
/* trailing block comment */

CREATE TABLE staging_order_detail (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  external_vendor_audit_id bigint NOT NULL REFERENCES external_vendor_audit(id),
  external_template_audit_id bigint NOT NULL REFERENCES external_template_audit(id),
  updated_at timestamp NOT NULL,
  created_at char(2),
  body varchar(255) NOT NULL
);

CREATE TABLE staging_project (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  amount boolean,
  checksum smallint,
  quantity varchar(64),
  quantity_4 jsonb,
  note numeric(12,2) NOT NULL,
  code timestamp,
  currency boolean,
  label date,
  quantity_9 date
);

CREATE TABLE staging_attachment (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  legacy_route_audit_id bigint NOT NULL REFERENCES legacy_route_audit(id),
  is_locked timestamptz NOT NULL,
  quantity jsonb,
  currency char(2),
  currency_4 boolean,
  label uuid
);

CREATE TABLE v2_session_line (
  id bigint PRIMARY KEY,
  label bigint,
  quantity inet,
  code jsonb NOT NULL,
  label_4 text NOT NULL,
  created_at char(2) NOT NULL,
  status numeric(12,2),
  is_default varchar(64) NOT NULL,
  expires_at varchar(255),
  kind bytea
);

CREATE TABLE attachment_meta (
  id bigint PRIMARY KEY,
  position smallint,
  kind timestamptz NOT NULL,
  rate boolean NOT NULL,
  rate_4 jsonb
);

CREATE TABLE legacy_claim_item (
  id bigint PRIMARY KEY,
  v2_route_history_id bigint REFERENCES v2_route_history(id),
  ticket_audit_id bigint REFERENCES ticket_audit(id),
  archived_policy_id bigint NOT NULL,
  timezone bytea NOT NULL,
  note timestamptz NOT NULL,
  currency integer,
  external_ref jsonb
);

CREATE TABLE v2_account_detail (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL,
  metadata numeric(12,2) NOT NULL,
  status char(2) NOT NULL,
  external_ref char(2),
  total varchar(255),
  weight varchar(64),
  code timestamp NOT NULL,
  is_default double precision,
  metadata_8 varchar(64)
);

CREATE TABLE v2_project_link (
  id bigint PRIMARY KEY,
  refund_id bigint REFERENCES refund(id),
  timezone char(2),
  name timestamp NOT NULL
);

-- session: 12 columns
CREATE TABLE session (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  campaign_id bigint NOT NULL REFERENCES campaign(id),
  name integer,
  version smallint,
  is_active timestamptz NOT NULL,
  external_ref text,
  quantity jsonb NOT NULL,
  weight jsonb,
  updated_at varchar(64) NOT NULL,
  metadata uuid NOT NULL,
  is_default varchar(64),
  UNIQUE (external_ref)
);

CREATE TABLE staging_message_snapshot (
  id bigint PRIMARY KEY,
  v2_contract_meta_id bigint REFERENCES v2_contract_meta(id),
  v2_refund_id bigint REFERENCES v2_refund(id),
  label timestamptz NOT NULL,
  is_locked numeric(12,2),
  starts_at date,
  kind inet,
  UNIQUE (starts_at)
);

CREATE TABLE notification_audit (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  email varchar(255) NOT NULL,
  body bytea NOT NULL,
  created_at inet,
  code integer,
  kind bytea,
  is_active double precision NOT NULL,
  price smallint,
  slug varchar(64) NOT NULL
);
/* trailing block comment */

-- legacy_claim_line: 11 columns
CREATE TABLE legacy_claim_line (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  expires_at boolean,
  metadata timestamptz NOT NULL,
  starts_at numeric(12,2),
  locale smallint,
  is_default jsonb NOT NULL,
  is_locked smallint,
  total jsonb NOT NULL,
  label smallint NOT NULL,
  body double precision
);

CREATE TABLE external_discount_audit (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  archived_review_link_id bigint NOT NULL REFERENCES archived_review_link(id),
  refund_audit_id bigint REFERENCES refund_audit(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  external_document_history_id bigint NOT NULL REFERENCES external_document_history(id),
  archived_order_id bigint NOT NULL,
  is_default inet,
  note date,
  metadata timestamp,
  locale date NOT NULL,
  checksum varchar(64) NOT NULL,
  quantity numeric(12,2) NOT NULL,
  checksum_7 date NOT NULL
);

CREATE TABLE booking_link (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  body smallint NOT NULL,
  phone timestamptz,
  status boolean,
  note varchar(64),
  timezone double precision NOT NULL,
  name double precision,
  is_active jsonb NOT NULL
);

CREATE TABLE archived_notification_config (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_account_history_id bigint,
  starts_at varchar(64),
  phone smallint,
  is_active jsonb,
  price integer,
  created_at jsonb,
  note varchar(255) NOT NULL,
  total timestamptz,
  email numeric(12,2) NOT NULL,
  created_at_9 text NOT NULL,
  UNIQUE (created_at)
);

CREATE TABLE archived_asset_config (
  id bigint PRIMARY KEY,
  legacy_account_id bigint,
  label numeric(12,2) NOT NULL,
  is_locked varchar(64) NOT NULL,
  is_locked_3 inet,
  expires_at bigint NOT NULL,
  phone inet NOT NULL,
  total timestamp
);

CREATE TABLE archived_session (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  created_at numeric(12,2),
  title smallint NOT NULL,
  total varchar(255)
);

CREATE TABLE external_discount_link (
  id bigint PRIMARY KEY,
  rate text,
  total jsonb,
  updated_at integer,
  deleted_at timestamptz,
  is_default varchar(64) NOT NULL
);

CREATE TABLE shipment_config (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL,
  archived_policy_id bigint REFERENCES archived_policy(id),
  version double precision,
  starts_at timestamptz NOT NULL,
  created_at jsonb,
  email integer
);

CREATE TABLE "public"."staging_attachment_line" (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  archived_order_id bigint,
  name uuid,
  rate integer NOT NULL,
  checksum integer NOT NULL,
  amount inet,
  is_active char(2) NOT NULL,
  currency boolean,
  starts_at bigint NOT NULL,
  updated_at uuid,
  note varchar(255) NOT NULL,
  UNIQUE (archived_order_id)
);

CREATE TABLE legacy_ticket_detail (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  discount_id bigint REFERENCES discount(id),
  shipment_meta_id bigint REFERENCES shipment_meta(id),
  price bytea NOT NULL,
  is_default varchar(255),
  starts_at varchar(64),
  status numeric(12,2)
);
/* trailing block comment */

-- legacy_document: 13 columns
CREATE TABLE legacy_document (
  id bigint PRIMARY KEY,
  external_order_history_id bigint NOT NULL,
  staging_order_history_id bigint REFERENCES staging_order_history(id),
  subscription_detail_id bigint NOT NULL REFERENCES subscription_detail(id),
  external_invoice_snapshot_id bigint REFERENCES external_invoice_snapshot(id),
  phone double precision,
  name char(2),
  metadata char(2),
  expires_at smallint NOT NULL,
  title double precision NOT NULL,
  note inet,
  metadata_7 char(2) NOT NULL,
  is_locked numeric(12,2) NOT NULL
);

CREATE TABLE policy_order (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  external_task_config_id bigint,
  rate text NOT NULL,
  is_active bytea,
  price text,
  slug uuid NOT NULL,
  quantity timestamp NOT NULL,
  slug_6 integer NOT NULL,
  note text,
  updated_at jsonb NOT NULL,
  body timestamptz,
  is_active_10 uuid,
  UNIQUE (slug)
);

CREATE TABLE "public"."asset_history" (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  deleted_at double precision,
  updated_at bytea,
  total bigint NOT NULL,
  checksum varchar(255) NOT NULL,
  currency double precision NOT NULL,
  checksum_6 jsonb NOT NULL
);

-- task: 13 columns
CREATE TABLE task (
  id bigint PRIMARY KEY,
  order_detail_id bigint NOT NULL,
  template_id bigint REFERENCES template(id),
  archived_booking_meta_id bigint NOT NULL REFERENCES archived_booking_meta(id),
  rate timestamp,
  total double precision,
  amount text,
  code numeric(12,2),
  slug bytea NOT NULL,
  quantity numeric(12,2) NOT NULL,
  version boolean,
  metadata jsonb NOT NULL,
  total_9 varchar(64) NOT NULL
);

CREATE TABLE campaign_audit (
  id bigint PRIMARY KEY,
  audit_config_id bigint REFERENCES audit_config(id),
  v2_refund_id bigint REFERENCES v2_refund(id),
  legacy_vehicle_id bigint REFERENCES legacy_vehicle(id),
  staging_channel_config_id bigint NOT NULL REFERENCES staging_channel_config(id),
  archived_audit_meta_id bigint REFERENCES archived_audit_meta(id),
  amount char(2) NOT NULL,
  body timestamp,
  position bigint NOT NULL,
  name smallint NOT NULL,
  amount_5 jsonb NOT NULL,
  is_locked date
);

CREATE TABLE staging_asset_line (
  id bigint PRIMARY KEY,
  v2_campaign_audit_id bigint NOT NULL REFERENCES v2_campaign_audit(id),
  legacy_project_id bigint REFERENCES legacy_project(id),
  legacy_policy_audit_id bigint NOT NULL REFERENCES legacy_policy_audit(id),
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  name timestamptz,
  body char(2),
  title inet NOT NULL,
  updated_at text
);
/* trailing block comment */

CREATE TABLE staging_vendor (
  id bigint PRIMARY KEY,
  employee_history_id bigint NOT NULL REFERENCES employee_history(id),
  attachment_audit_id bigint NOT NULL REFERENCES attachment_audit(id),
  updated_at inet NOT NULL,
  version char(2),
  currency integer
);

-- staging_customer: 7 columns
CREATE TABLE staging_customer (
  id bigint PRIMARY KEY,
  v2_session_history_id bigint NOT NULL REFERENCES v2_session_history(id),
  department_link_id bigint REFERENCES department_link(id),
  staging_shipment_leg_config_id bigint NOT NULL,
  deleted_at bytea,
  updated_at char(2),
  note uuid
);

CREATE TABLE legacy_subscription_history (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  metadata varchar(255),
  expires_at timestamp NOT NULL,
  updated_at timestamptz NOT NULL,
  kind bigint,
  kind_5 text,
  created_at uuid,
  title inet NOT NULL,
  price inet,
  name integer
);

CREATE TABLE v2_ticket_config (
  id bigint PRIMARY KEY,
  archived_asset_config_id bigint NOT NULL,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  policy_item_id bigint REFERENCES policy_item(id),
  updated_at timestamp,
  external_ref date,
  phone boolean NOT NULL,
  body jsonb NOT NULL
);

CREATE TABLE refund_link (
  id bigint PRIMARY KEY,
  legacy_subscription_line_id bigint NOT NULL REFERENCES legacy_subscription_line(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  is_active date,
  timezone varchar(64) NOT NULL
);

CREATE TABLE public.staging_customer_config (
  id bigint PRIMARY KEY,
  label text NOT NULL,
  version char(2)
);

CREATE TABLE external_notification (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  version inet,
  name timestamp,
  expires_at uuid,
  external_ref integer NOT NULL,
  amount uuid,
  email char(2) NOT NULL,
  updated_at numeric(12,2),
  kind timestamptz NOT NULL,
  note text NOT NULL,
  body integer NOT NULL,
  UNIQUE (note)
);
/* trailing block comment */

-- external_product: 9 columns
CREATE TABLE public.external_product (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  employee_detail_id bigint NOT NULL REFERENCES employee_detail(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  refund_audit_id bigint NOT NULL,
  attachment_id bigint NOT NULL REFERENCES attachment(id),
  weight char(2) NOT NULL,
  is_default numeric(12,2),
  locale date
);

-- legacy_booking_link: 8 columns
CREATE TABLE legacy_booking_link (
  id bigint PRIMARY KEY,
  document_snapshot_id bigint NOT NULL REFERENCES document_snapshot(id),
  email double precision,
  expires_at varchar(64) NOT NULL,
  slug bytea,
  created_at bytea NOT NULL,
  email_5 timestamptz,
  title timestamp NOT NULL
);

CREATE TABLE v2_review_history (
  id bigint PRIMARY KEY,
  slug smallint NOT NULL,
  code boolean NOT NULL,
  weight bigint,
  name numeric(12,2),
  kind char(2) NOT NULL,
  phone text,
  locale integer NOT NULL,
  currency varchar(64) NOT NULL,
  label date
);

CREATE TABLE archived_customer (
  id bigint PRIMARY KEY,
  contract_item_id bigint NOT NULL REFERENCES contract_item(id),
  v2_audit_item_id bigint NOT NULL,
  v2_refund_id bigint REFERENCES v2_refund(id),
  slug inet,
  is_default bytea,
  deleted_at double precision NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_department_detail (
  id bigint PRIMARY KEY,
  legacy_shipment_id bigint REFERENCES legacy_shipment(id),
  channel_id bigint NOT NULL REFERENCES channel(id),
  updated_at bigint,
  code char(2),
  version text,
  weight timestamptz NOT NULL,
  position uuid NOT NULL,
  is_default boolean NOT NULL,
  version_7 inet NOT NULL
);

CREATE TABLE v2_asset_config (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  external_ref numeric(12,2),
  title varchar(64) NOT NULL,
  checksum boolean,
  version bytea NOT NULL,
  starts_at bytea NOT NULL
);

CREATE TABLE legacy_template_link (
  id bigint PRIMARY KEY,
  shipment_config_id bigint REFERENCES shipment_config(id),
  legacy_message_line_id bigint REFERENCES legacy_message_line(id),
  staging_attachment_history_id bigint REFERENCES staging_attachment_history(id),
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  project_history_id bigint,
  title timestamptz NOT NULL,
  amount numeric(12,2) NOT NULL,
  updated_at jsonb,
  label text,
  locale uuid,
  position inet,
  expires_at bigint NOT NULL,
  updated_at_8 timestamptz NOT NULL
);

-- staging_session: 7 columns
CREATE TABLE staging_session (
  id bigint PRIMARY KEY,
  rate double precision NOT NULL,
  starts_at text,
  rate_3 varchar(64),
  price text,
  metadata smallint,
  label timestamptz
);

CREATE TABLE category_line (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  external_booking_id bigint REFERENCES external_booking(id),
  legacy_discount_id bigint NOT NULL REFERENCES legacy_discount(id),
  external_ref numeric(12,2) NOT NULL,
  is_default smallint,
  label numeric(12,2),
  position date NOT NULL,
  rate varchar(64),
  kind numeric(12,2)
);

-- payment_detail: 7 columns
CREATE TABLE payment_detail (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  attachment_id bigint NOT NULL REFERENCES attachment(id),
  slug numeric(12,2),
  metadata uuid,
  amount integer,
  updated_at text
);

CREATE TABLE session_meta (
  id bigint PRIMARY KEY,
  booking_snapshot_id bigint NOT NULL REFERENCES booking_snapshot(id),
  body inet,
  phone integer NOT NULL,
  note timestamp,
  created_at integer,
  slug bytea,
  amount varchar(64),
  external_ref smallint,
  version boolean,
  version_9 char(2) NOT NULL,
  UNIQUE (external_ref)
);

-- legacy_booking_item: 9 columns
CREATE TABLE "public"."legacy_booking_item" (
  id bigint PRIMARY KEY,
  archived_order_id bigint,
  locale inet,
  version timestamptz,
  code text,
  created_at jsonb NOT NULL,
  timezone char(2),
  is_locked bytea,
  is_active smallint
);

-- message: 10 columns
CREATE TABLE message (
  id bigint PRIMARY KEY,
  shipment_leg_detail_id bigint REFERENCES shipment_leg_detail(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  staging_order_line_id bigint NOT NULL REFERENCES staging_order_line(id),
  policy_item_id bigint REFERENCES policy_item(id),
  booking_line_id bigint REFERENCES booking_line(id),
  deleted_at date,
  currency bytea,
  checksum date NOT NULL,
  code boolean
);

CREATE TABLE archived_warehouse_meta (
  id bigint PRIMARY KEY,
  invoice_config_id bigint REFERENCES invoice_config(id),
  category_id bigint NOT NULL REFERENCES category(id),
  staging_notification_meta_id bigint REFERENCES staging_notification_meta(id),
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  kind timestamp NOT NULL,
  expires_at date,
  is_active varchar(64) NOT NULL,
  locale char(2),
  version timestamp,
  kind_6 double precision
);

CREATE TABLE archived_category (
  id bigint PRIMARY KEY,
  external_attachment_id bigint NOT NULL REFERENCES external_attachment(id),
  external_task_config_id bigint NOT NULL REFERENCES external_task_config(id),
  created_at double precision,
  code timestamp,
  updated_at inet,
  metadata char(2),
  created_at_5 boolean,
  deleted_at text
);

CREATE TABLE shipment_leg (
  id bigint PRIMARY KEY,
  legacy_shipment_line_id bigint,
  staging_carrier_snapshot_id bigint REFERENCES staging_carrier_snapshot(id),
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  attachment_snapshot_id bigint NOT NULL REFERENCES attachment_snapshot(id),
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  rate double precision NOT NULL,
  status varchar(64),
  note char(2),
  slug bytea NOT NULL,
  phone smallint NOT NULL,
  timezone numeric(12,2) NOT NULL,
  phone_7 uuid NOT NULL
);

-- attachment_discount: 9 columns
CREATE TABLE "attachment_discount" (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  name uuid NOT NULL,
  note timestamptz NOT NULL,
  created_at text NOT NULL,
  expires_at text,
  title varchar(255) NOT NULL,
  note_6 boolean NOT NULL,
  UNIQUE (expires_at)
);

CREATE TABLE staging_vehicle (
  id bigint PRIMARY KEY,
  rate integer,
  weight jsonb NOT NULL,
  position boolean NOT NULL
);

CREATE TABLE legacy_product (
  id bigint PRIMARY KEY,
  timezone double precision,
  title double precision NOT NULL,
  updated_at inet,
  version timestamp,
  external_ref timestamp NOT NULL,
  updated_at_6 uuid NOT NULL,
  name timestamptz
);

CREATE TABLE campaign (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  project_history_id bigint REFERENCES project_history(id),
  staging_attachment_history_id bigint NOT NULL REFERENCES staging_attachment_history(id),
  is_locked uuid NOT NULL,
  weight integer NOT NULL,
  kind jsonb
);

-- legacy_message_meta: 10 columns
CREATE TABLE legacy_message_meta (
  id bigint PRIMARY KEY,
  project_history_id bigint REFERENCES project_history(id),
  v2_carrier_detail_id bigint NOT NULL REFERENCES v2_carrier_detail(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  updated_at double precision NOT NULL,
  name timestamp,
  created_at bytea NOT NULL,
  deleted_at varchar(255) NOT NULL,
  email smallint NOT NULL
);

-- staging_contract_history: 14 columns
CREATE TABLE staging_contract_history (
  id bigint PRIMARY KEY,
  archived_invoice_id bigint REFERENCES archived_invoice(id),
  discount_id bigint,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  version varchar(255) NOT NULL,
  note date NOT NULL,
  email date NOT NULL,
  is_default jsonb,
  expires_at bytea,
  metadata text,
  label boolean NOT NULL,
  name uuid NOT NULL,
  code bigint,
  currency double precision NOT NULL
);

-- v2_notification_item: 7 columns
CREATE TABLE "public"."v2_notification_item" (
  id bigint PRIMARY KEY,
  email date NOT NULL,
  checksum text NOT NULL,
  locale timestamptz NOT NULL,
  kind timestamptz,
  starts_at bigint,
  checksum_6 timestamp,
  UNIQUE (checksum_6)
);

CREATE TABLE staging_project_audit (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL,
  legacy_subscription_line_id bigint REFERENCES legacy_subscription_line(id),
  discount_audit_id bigint NOT NULL REFERENCES discount_audit(id),
  locale date NOT NULL,
  price date,
  updated_at varchar(64) NOT NULL,
  version jsonb,
  position timestamptz NOT NULL,
  is_default inet NOT NULL,
  external_ref varchar(255)
);

CREATE TABLE legacy_invoice_meta (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  v2_booking_snapshot_id bigint NOT NULL REFERENCES v2_booking_snapshot(id),
  v2_customer_detail_id bigint,
  code varchar(64) NOT NULL,
  title boolean,
  is_active date,
  kind inet,
  position double precision,
  body char(2) NOT NULL,
  locale char(2),
  total numeric(12,2) NOT NULL,
  email inet,
  UNIQUE (total)
);
/* trailing block comment */

-- document_config: 12 columns
CREATE TABLE document_config (
  id bigint PRIMARY KEY,
  vendor_config_id bigint NOT NULL REFERENCES vendor_config(id),
  updated_at numeric(12,2),
  starts_at varchar(255),
  code varchar(255),
  price bytea NOT NULL,
  is_locked uuid NOT NULL,
  position numeric(12,2) NOT NULL,
  starts_at_7 bytea,
  body boolean,
  name double precision,
  code_10 double precision NOT NULL,
  UNIQUE (code_10)
);

CREATE TABLE product_history (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  is_active double precision NOT NULL,
  email smallint,
  created_at inet,
  external_ref timestamptz NOT NULL,
  name date NOT NULL,
  timezone boolean,
  label inet,
  total jsonb NOT NULL
);

-- external_account_detail: 7 columns
CREATE TABLE external_account_detail (
  id bigint PRIMARY KEY,
  contract_config_id bigint NOT NULL REFERENCES contract_config(id),
  route_line_id bigint REFERENCES route_line(id),
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  name jsonb NOT NULL,
  title varchar(64)
);

CREATE TABLE archived_campaign_history (
  id bigint PRIMARY KEY,
  external_category_id bigint NOT NULL REFERENCES external_category(id),
  order_link_id bigint NOT NULL REFERENCES order_link(id),
  archived_shipment_line_id bigint REFERENCES archived_shipment_line(id),
  project_history_id bigint REFERENCES project_history(id),
  booking_snapshot_id bigint NOT NULL REFERENCES booking_snapshot(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  is_default integer NOT NULL,
  slug jsonb,
  quantity timestamp,
  status bytea NOT NULL,
  starts_at boolean,
  currency uuid NOT NULL,
  email inet,
  phone double precision NOT NULL,
  name double precision
);
/* trailing block comment */

-- archived_contract_config: 9 columns
CREATE TABLE archived_contract_config (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  timezone timestamp,
  version integer,
  currency bytea NOT NULL,
  deleted_at numeric(12,2),
  label date NOT NULL,
  external_ref bytea NOT NULL,
  label_7 timestamptz
);

CREATE TABLE inventory_history (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  total varchar(255),
  updated_at timestamp NOT NULL,
  status varchar(255) NOT NULL,
  external_ref char(2) NOT NULL,
  amount bytea,
  position integer NOT NULL,
  metadata timestamp,
  locale char(2),
  locale_9 timestamp NOT NULL
);

CREATE TABLE v2_carrier (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  department_detail_id bigint NOT NULL REFERENCES department_detail(id),
  amount timestamp,
  deleted_at varchar(255) NOT NULL,
  metadata char(2) NOT NULL
);

CREATE TABLE "public"."v2_employee_config" (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  metadata integer,
  total inet,
  slug text,
  starts_at timestamptz,
  rate jsonb NOT NULL,
  body varchar(255),
  total_7 smallint,
  rate_8 varchar(64)
);

CREATE TABLE v2_session_link (
  id bigint PRIMARY KEY,
  name numeric(12,2),
  updated_at smallint,
  is_default jsonb,
  is_locked varchar(64) NOT NULL,
  title bytea,
  note double precision,
  label uuid
);

CREATE TABLE external_notification_link (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  legacy_invoice_meta_id bigint NOT NULL REFERENCES legacy_invoice_meta(id),
  invoice_link_id bigint NOT NULL REFERENCES invoice_link(id),
  rate char(2) NOT NULL,
  title integer NOT NULL,
  code date NOT NULL,
  phone date NOT NULL
);
/* trailing block comment */

-- legacy_discount_line: 12 columns
CREATE TABLE "public"."legacy_discount_line" (
  id bigint PRIMARY KEY,
  archived_product_item_id bigint NOT NULL REFERENCES archived_product_item(id),
  v2_notification_id bigint REFERENCES v2_notification(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  title inet,
  phone varchar(64) NOT NULL,
  quantity integer NOT NULL,
  note bytea,
  body bytea NOT NULL,
  locale inet,
  note_7 char(2) NOT NULL,
  amount varchar(255) NOT NULL
);

CREATE TABLE claim_meta (
  id bigint PRIMARY KEY,
  archived_task_history_id bigint REFERENCES archived_task_history(id),
  metadata timestamptz NOT NULL,
  metadata_2 bigint,
  rate varchar(255),
  name jsonb,
  label uuid,
  label_6 text NOT NULL,
  label_7 bytea,
  is_locked text,
  UNIQUE (label_6)
);
/* trailing block comment */

CREATE TABLE archived_tag (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  email smallint NOT NULL,
  kind boolean,
  is_default varchar(255) NOT NULL,
  label timestamptz,
  note char(2) NOT NULL,
  created_at varchar(64) NOT NULL,
  UNIQUE (policy_item_id)
);

-- staging_customer_link: 8 columns
CREATE TABLE staging_customer_link (
  id bigint PRIMARY KEY,
  archived_order_id bigint,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  email date,
  created_at inet,
  version bigint NOT NULL,
  created_at_4 integer NOT NULL,
  status inet
);

-- account_link: 9 columns
CREATE TABLE account_link (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  note numeric(12,2),
  kind timestamptz,
  external_ref uuid NOT NULL,
  slug jsonb NOT NULL,
  created_at date NOT NULL,
  position double precision,
  expires_at bytea NOT NULL
);

CREATE TABLE external_shipment_snapshot (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  label smallint,
  expires_at text NOT NULL
);

CREATE TABLE v2_claim (
  id bigint PRIMARY KEY,
  staging_claim_line_id bigint REFERENCES staging_claim_line(id),
  asset_item_id bigint REFERENCES asset_item(id),
  code text,
  name bigint NOT NULL,
  is_locked boolean,
  is_locked_4 text,
  quantity date NOT NULL,
  deleted_at varchar(64) NOT NULL,
  quantity_7 inet,
  metadata jsonb NOT NULL,
  deleted_at_9 smallint NOT NULL
);

-- staging_ticket_config: 6 columns
CREATE TABLE staging_ticket_config (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  archived_booking_line_id bigint,
  code varchar(255),
  name varchar(255),
  slug bigint
);

CREATE TABLE legacy_subscription_detail (
  id bigint PRIMARY KEY,
  archived_campaign_meta_id bigint,
  product_line_id bigint NOT NULL REFERENCES product_line(id),
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  discount_id bigint REFERENCES discount(id),
  updated_at jsonb,
  status bytea,
  expires_at bigint,
  UNIQUE (updated_at)
);

CREATE TABLE route_history (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  deleted_at boolean NOT NULL,
  quantity inet,
  timezone double precision NOT NULL,
  external_ref text
);
/* trailing block comment */

CREATE TABLE legacy_customer_link (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  email boolean,
  starts_at timestamp NOT NULL,
  checksum boolean,
  deleted_at timestamp NOT NULL,
  is_locked varchar(64) NOT NULL,
  is_default timestamp NOT NULL,
  email_7 timestamptz,
  metadata integer,
  UNIQUE (metadata)
);

CREATE TABLE "public"."v2_warehouse_history" (
  id bigint PRIMARY KEY,
  legacy_payment_item_id bigint NOT NULL REFERENCES legacy_payment_item(id),
  external_ref uuid NOT NULL,
  weight char(2) NOT NULL,
  is_locked date,
  UNIQUE (is_locked)
);

CREATE TABLE template_config (
  id bigint PRIMARY KEY,
  account_detail_id bigint NOT NULL REFERENCES account_detail(id),
  v2_vendor_audit_id bigint REFERENCES v2_vendor_audit(id),
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  staging_attachment_id bigint NOT NULL REFERENCES staging_attachment(id),
  starts_at uuid NOT NULL,
  quantity timestamptz NOT NULL,
  expires_at timestamptz NOT NULL,
  starts_at_4 bigint,
  metadata double precision NOT NULL
);
/* trailing block comment */

-- message_line: 11 columns
CREATE TABLE message_line (
  id bigint PRIMARY KEY,
  version date,
  locale timestamp,
  kind text,
  status text NOT NULL,
  amount boolean,
  version_6 varchar(255),
  checksum varchar(255),
  body boolean NOT NULL,
  created_at uuid NOT NULL,
  expires_at uuid NOT NULL
);
/* trailing block comment */

CREATE TABLE archived_product_line (
  id bigint PRIMARY KEY,
  v2_vendor_id bigint,
  external_shipment_leg_line_id bigint NOT NULL,
  external_ref integer,
  locale boolean NOT NULL,
  expires_at uuid NOT NULL,
  label varchar(64)
);

CREATE TABLE message_meta (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  external_ref jsonb,
  timezone varchar(64)
);

CREATE TABLE legacy_policy_audit (
  id bigint PRIMARY KEY,
  v2_vehicle_audit_id bigint NOT NULL REFERENCES v2_vehicle_audit(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  vendor_link_id bigint NOT NULL REFERENCES vendor_link(id),
  body timestamptz,
  rate timestamptz,
  expires_at char(2),
  currency inet NOT NULL,
  is_active varchar(64) NOT NULL,
  external_ref bigint,
  price inet
);

-- external_task_detail: 10 columns
CREATE TABLE external_task_detail (
  id bigint PRIMARY KEY,
  external_discount_link_id bigint REFERENCES external_discount_link(id),
  booking_line_id bigint,
  category_line_id bigint NOT NULL REFERENCES category_line(id),
  expires_at numeric(12,2),
  name smallint,
  is_active varchar(255),
  created_at varchar(64) NOT NULL,
  status bytea NOT NULL,
  checksum varchar(64) NOT NULL
);

CREATE TABLE legacy_inventory_meta (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  code boolean,
  is_default date
);
/* trailing block comment */

-- staging_task_config: 8 columns
CREATE TABLE staging_task_config (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  v2_shipment_leg_meta_id bigint NOT NULL,
  body integer NOT NULL,
  body_2 jsonb,
  email inet,
  label char(2) NOT NULL,
  deleted_at boolean NOT NULL
);

CREATE TABLE staging_account_meta (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL,
  staging_review_link_id bigint NOT NULL REFERENCES staging_review_link(id),
  updated_at date NOT NULL,
  label bigint NOT NULL,
  created_at varchar(64),
  total bytea NOT NULL,
  amount integer,
  is_default uuid,
  deleted_at char(2),
  title date,
  UNIQUE (is_default)
);

CREATE TABLE staging_tag (
  id bigint PRIMARY KEY,
  external_contract_audit_id bigint NOT NULL REFERENCES external_contract_audit(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  project_history_id bigint NOT NULL,
  discount_id bigint NOT NULL,
  title text,
  label integer NOT NULL,
  starts_at uuid NOT NULL,
  slug text,
  is_locked bytea NOT NULL,
  status inet,
  external_ref boolean,
  code timestamp,
  UNIQUE (project_history_id)
);
/* trailing block comment */

CREATE TABLE public.external_vendor_line (
  id bigint PRIMARY KEY,
  total numeric(12,2) NOT NULL,
  currency boolean NOT NULL,
  metadata text,
  quantity text,
  starts_at integer,
  checksum numeric(12,2) NOT NULL,
  weight smallint,
  email varchar(255),
  position integer
);

CREATE TABLE public.external_order_meta (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  archived_category_id bigint REFERENCES archived_category(id),
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  quantity jsonb,
  amount timestamp NOT NULL,
  label timestamp,
  checksum inet,
  version timestamp NOT NULL,
  currency char(2) NOT NULL
);

-- notification_config: 6 columns
CREATE TABLE notification_config (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  status integer,
  deleted_at char(2),
  rate text
);

CREATE TABLE "public"."v2_inventory_snapshot" (
  id bigint PRIMARY KEY,
  ticket_history_id bigint NOT NULL REFERENCES ticket_history(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  body timestamptz NOT NULL,
  metadata inet,
  position integer NOT NULL,
  code date,
  kind varchar(64) NOT NULL,
  price double precision NOT NULL,
  name double precision
);

CREATE TABLE public.staging_claim_history (
  id bigint PRIMARY KEY,
  booking_id bigint NOT NULL REFERENCES booking(id),
  name integer,
  is_active timestamptz NOT NULL,
  metadata varchar(64) NOT NULL,
  is_default bytea NOT NULL,
  is_locked timestamp,
  is_locked_6 bigint NOT NULL,
  version double precision,
  updated_at varchar(64)
);

CREATE TABLE channel_config (
  id bigint PRIMARY KEY,
  staging_policy_line_id bigint NOT NULL REFERENCES staging_policy_line(id),
  payment_detail_id bigint,
  rate boolean NOT NULL,
  quantity bigint NOT NULL,
  starts_at date NOT NULL,
  starts_at_4 varchar(64),
  label timestamp NOT NULL,
  locale timestamp
);

CREATE TABLE asset_snapshot (
  id bigint PRIMARY KEY,
  weight uuid NOT NULL,
  rate bigint NOT NULL,
  version integer,
  note timestamptz NOT NULL,
  slug bigint,
  amount uuid NOT NULL,
  timezone bigint NOT NULL,
  metadata boolean NOT NULL,
  email timestamp
);

CREATE TABLE inventory_link (
  id bigint PRIMARY KEY,
  notification_detail_id bigint NOT NULL REFERENCES notification_detail(id),
  staging_invoice_snapshot_id bigint NOT NULL REFERENCES staging_invoice_snapshot(id),
  kind uuid,
  checksum jsonb
);

CREATE TABLE legacy_discount_meta (
  id bigint PRIMARY KEY,
  legacy_document_meta_id bigint REFERENCES legacy_document_meta(id),
  quantity date NOT NULL,
  is_locked inet NOT NULL,
  locale double precision,
  created_at inet,
  kind integer NOT NULL
);

CREATE TABLE tag_history (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint NOT NULL,
  code timestamptz,
  body inet,
  timezone date NOT NULL,
  currency bigint,
  UNIQUE (body)
);

CREATE TABLE staging_notification_meta (
  id bigint PRIMARY KEY,
  timezone text NOT NULL,
  external_ref integer,
  currency inet NOT NULL,
  checksum timestamp NOT NULL,
  code smallint NOT NULL,
  deleted_at char(2),
  timezone_7 numeric(12,2)
);

CREATE TABLE external_category_detail (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint,
  asset_config_id bigint NOT NULL REFERENCES asset_config(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  archived_contract_meta_id bigint NOT NULL REFERENCES archived_contract_meta(id),
  position date,
  email double precision NOT NULL,
  deleted_at text NOT NULL,
  created_at numeric(12,2),
  phone boolean NOT NULL,
  is_default integer NOT NULL
);
/* trailing block comment */

CREATE TABLE external_booking_line (
  id bigint PRIMARY KEY,
  staging_policy_history_id bigint REFERENCES staging_policy_history(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  timezone smallint,
  starts_at jsonb NOT NULL,
  created_at boolean,
  phone numeric(12,2),
  created_at_5 timestamptz NOT NULL,
  UNIQUE (starts_at)
);

CREATE TABLE legacy_account_config (
  id bigint PRIMARY KEY,
  legacy_channel_line_id bigint NOT NULL REFERENCES legacy_channel_line(id),
  starts_at timestamptz,
  position text NOT NULL,
  total timestamp NOT NULL,
  amount uuid,
  created_at boolean NOT NULL
);

CREATE TABLE legacy_customer (
  id bigint PRIMARY KEY,
  staging_shipment_config_id bigint NOT NULL REFERENCES staging_shipment_config(id),
  booking_line_id bigint NOT NULL,
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  legacy_discount_meta_id bigint REFERENCES legacy_discount_meta(id),
  timezone boolean,
  updated_at timestamp NOT NULL,
  updated_at_3 numeric(12,2) NOT NULL,
  email integer,
  price timestamp,
  version char(2),
  UNIQUE (updated_at_3)
);

CREATE TABLE v2_tag_config (
  id bigint PRIMARY KEY,
  updated_at varchar(64),
  external_ref date NOT NULL,
  metadata uuid
);

-- archived_department_config: 10 columns
CREATE TABLE public.archived_department_config (
  id bigint PRIMARY KEY,
  staging_tag_id bigint REFERENCES staging_tag(id),
  external_shipment_leg_history_id bigint,
  name varchar(255),
  title double precision,
  label text NOT NULL,
  amount boolean NOT NULL,
  slug bigint NOT NULL,
  slug_6 jsonb,
  weight integer
);

-- shipment_history: 9 columns
CREATE TABLE shipment_history (
  id bigint PRIMARY KEY,
  is_active uuid NOT NULL,
  note double precision,
  price char(2) NOT NULL,
  title uuid NOT NULL,
  is_active_5 bytea,
  expires_at integer,
  timezone inet,
  is_active_8 bytea
);

CREATE TABLE asset_item (
  id bigint PRIMARY KEY,
  external_ref numeric(12,2) NOT NULL,
  code bytea,
  created_at varchar(255),
  is_active text NOT NULL
);
/* trailing block comment */

-- shipment_leg_meta: 6 columns
CREATE TABLE shipment_leg_meta (
  id bigint PRIMARY KEY,
  amount varchar(255),
  quantity text NOT NULL,
  price jsonb,
  kind bytea NOT NULL,
  name jsonb NOT NULL,
  UNIQUE (amount)
);
/* trailing block comment */

CREATE TABLE staging_employee_audit (
  id bigint PRIMARY KEY,
  v2_route_id bigint NOT NULL REFERENCES v2_route(id),
  employee_item_id bigint NOT NULL REFERENCES employee_item(id),
  note text,
  status char(2),
  name timestamp,
  note_4 uuid,
  note_5 numeric(12,2)
);

-- archived_campaign_snapshot: 5 columns
CREATE TABLE archived_campaign_snapshot (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  locale char(2),
  is_locked timestamp NOT NULL,
  expires_at numeric(12,2),
  UNIQUE (is_locked)
);

CREATE TABLE "public"."v2_claim_link" (
  id bigint PRIMARY KEY,
  legacy_account_config_id bigint NOT NULL REFERENCES legacy_account_config(id),
  weight bytea,
  title integer NOT NULL,
  created_at date
);

CREATE TABLE "public"."payment_config" (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  legacy_document_meta_id bigint NOT NULL REFERENCES legacy_document_meta(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  is_default text NOT NULL,
  position timestamptz,
  checksum smallint NOT NULL,
  created_at double precision,
  timezone varchar(64),
  kind numeric(12,2),
  weight uuid,
  currency timestamptz
);

-- v2_vendor_line: 8 columns
CREATE TABLE v2_vendor_line (
  id bigint PRIMARY KEY,
  policy_claim_id bigint REFERENCES policy_claim(id),
  archived_policy_id bigint NOT NULL,
  total timestamp,
  note bigint NOT NULL,
  phone bytea NOT NULL,
  status bytea,
  phone_5 bytea
);

CREATE TABLE staging_route (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  asset_line_id bigint NOT NULL REFERENCES asset_line(id),
  legacy_subscription_item_id bigint NOT NULL REFERENCES legacy_subscription_item(id),
  timezone double precision NOT NULL,
  kind bytea,
  slug timestamptz NOT NULL,
  weight numeric(12,2),
  checksum char(2) NOT NULL,
  name varchar(64),
  quantity double precision NOT NULL,
  is_locked varchar(64),
  email bytea
);

CREATE TABLE public.archived_route_meta (
  id bigint PRIMARY KEY,
  price numeric(12,2),
  rate varchar(64),
  name integer,
  is_active uuid NOT NULL,
  UNIQUE (is_active)
);

CREATE TABLE external_payment (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  v2_project_id bigint NOT NULL,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  currency char(2) NOT NULL,
  is_active char(2),
  UNIQUE (currency)
);
/* trailing block comment */

CREATE TABLE archived_customer_detail (
  id bigint PRIMARY KEY,
  archived_product_line_id bigint NOT NULL REFERENCES archived_product_line(id),
  policy_item_id bigint,
  archived_policy_id bigint,
  phone uuid,
  name timestamp,
  status char(2),
  slug inet
);

-- external_shipment_leg_meta: 10 columns
CREATE TABLE public.external_shipment_leg_meta (
  id bigint PRIMARY KEY,
  starts_at numeric(12,2) NOT NULL,
  metadata timestamptz,
  code inet NOT NULL,
  metadata_4 timestamp,
  starts_at_5 text NOT NULL,
  expires_at char(2) NOT NULL,
  label timestamptz,
  email inet,
  title smallint NOT NULL
);

CREATE TABLE "public"."vendor_meta" (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  is_locked uuid,
  external_ref char(2),
  updated_at timestamp NOT NULL,
  is_locked_4 numeric(12,2),
  is_active inet NOT NULL,
  is_locked_6 smallint
);

CREATE TABLE v2_shipment_link (
  id bigint PRIMARY KEY,
  archived_ticket_id bigint NOT NULL REFERENCES archived_ticket(id),
  v2_discount_config_id bigint NOT NULL,
  legacy_subscription_meta_id bigint NOT NULL REFERENCES legacy_subscription_meta(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  external_ref numeric(12,2),
  version uuid NOT NULL,
  code bigint,
  position bigint NOT NULL,
  deleted_at varchar(255) NOT NULL,
  deleted_at_6 varchar(255),
  is_active varchar(255) NOT NULL,
  is_locked timestamp NOT NULL
);

-- archived_refund: 10 columns
CREATE TABLE archived_refund (
  id bigint PRIMARY KEY,
  external_shipment_meta_id bigint REFERENCES external_shipment_meta(id),
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  locale smallint,
  total smallint NOT NULL,
  created_at text,
  timezone bytea NOT NULL,
  quantity integer,
  version numeric(12,2),
  is_active varchar(64)
);

CREATE TABLE department_detail (
  id bigint PRIMARY KEY,
  slug integer,
  timezone jsonb NOT NULL,
  body uuid,
  quantity varchar(255) NOT NULL,
  label uuid NOT NULL,
  currency numeric(12,2),
  checksum double precision,
  note smallint,
  amount integer,
  checksum_10 inet NOT NULL
);

CREATE TABLE v2_vendor_detail (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  review_snapshot_id bigint NOT NULL REFERENCES review_snapshot(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  label timestamptz,
  price char(2)
);

CREATE TABLE project_asset (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  code uuid NOT NULL,
  deleted_at varchar(255),
  name bytea
);

CREATE TABLE account_line (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  timezone double precision,
  deleted_at date,
  starts_at varchar(64),
  starts_at_4 numeric(12,2),
  is_locked varchar(64)
);

-- staging_notification_detail: 15 columns
CREATE TABLE "staging_notification_detail" (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  external_subscription_id bigint NOT NULL REFERENCES external_subscription(id),
  code boolean NOT NULL,
  kind inet,
  status smallint NOT NULL,
  updated_at integer,
  status_5 date,
  title bytea NOT NULL,
  is_default text,
  price jsonb NOT NULL,
  quantity uuid NOT NULL,
  expires_at bigint
);

CREATE TABLE staging_task_history (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  body bytea NOT NULL,
  code bytea NOT NULL,
  is_active text,
  is_default jsonb,
  currency timestamp,
  quantity jsonb NOT NULL
);

CREATE TABLE campaign_snapshot (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  discount_link_id bigint NOT NULL REFERENCES discount_link(id),
  v2_booking_meta_id bigint NOT NULL REFERENCES v2_booking_meta(id),
  amount smallint,
  weight boolean
);

CREATE TABLE staging_route_config (
  id bigint PRIMARY KEY,
  currency text,
  name jsonb NOT NULL,
  quantity inet,
  slug integer,
  is_active integer,
  amount inet,
  price varchar(64) NOT NULL,
  is_active_8 smallint,
  body bigint
);

-- invoice_snapshot: 10 columns
CREATE TABLE invoice_snapshot (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  staging_template_item_id bigint NOT NULL,
  booking_line_id bigint REFERENCES booking_line(id),
  version smallint,
  slug double precision,
  position varchar(64),
  is_default inet,
  deleted_at date NOT NULL,
  expires_at char(2)
);

CREATE TABLE legacy_claim_history (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  locale boolean,
  name date,
  body smallint,
  rate text,
  checksum date,
  rate_6 uuid NOT NULL,
  price double precision NOT NULL,
  version date NOT NULL
);

-- archived_account_snapshot: 10 columns
CREATE TABLE archived_account_snapshot (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  review_detail_id bigint NOT NULL REFERENCES review_detail(id),
  is_active timestamptz,
  is_active_2 char(2),
  deleted_at timestamptz NOT NULL,
  created_at double precision NOT NULL,
  created_at_5 char(2),
  weight boolean,
  is_active_7 text NOT NULL
);

CREATE TABLE staging_session_detail (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  discount_id bigint NOT NULL,
  v2_policy_link_id bigint NOT NULL REFERENCES v2_policy_link(id),
  label timestamptz NOT NULL,
  name inet,
  amount bytea,
  is_active char(2) NOT NULL,
  created_at varchar(64) NOT NULL,
  UNIQUE (label)
);

CREATE TABLE legacy_project (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  title bigint NOT NULL,
  created_at numeric(12,2) NOT NULL,
  price smallint,
  position double precision,
  phone varchar(64) NOT NULL
);

CREATE TABLE v2_subscription_detail (
  id bigint PRIMARY KEY,
  invoice_config_id bigint REFERENCES invoice_config(id),
  external_order_link_id bigint NOT NULL REFERENCES external_order_link(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  staging_review_item_id bigint REFERENCES staging_review_item(id),
  deleted_at bytea,
  checksum varchar(255) NOT NULL,
  quantity jsonb,
  starts_at smallint,
  starts_at_5 bigint NOT NULL,
  locale smallint,
  is_default text,
  created_at bytea,
  checksum_9 timestamp,
  UNIQUE (checksum)
);

CREATE TABLE archived_audit_meta (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  v2_department_history_id bigint NOT NULL REFERENCES v2_department_history(id),
  timezone double precision NOT NULL,
  title boolean,
  body text,
  is_locked varchar(255) NOT NULL,
  rate inet,
  currency smallint,
  price varchar(64),
  phone numeric(12,2),
  label integer,
  label_10 text NOT NULL,
  UNIQUE (timezone)
);

-- subscription_item: 13 columns
CREATE TABLE subscription_item (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  shipment_leg_shipment_id bigint NOT NULL REFERENCES shipment_leg_shipment(id),
  status timestamp,
  amount uuid NOT NULL,
  code uuid,
  starts_at inet,
  email timestamp NOT NULL,
  checksum bytea,
  timezone date,
  title uuid,
  quantity boolean NOT NULL,
  UNIQUE (v2_audit_item_id)
);

CREATE TABLE "public"."staging_inventory_item" (
  id bigint PRIMARY KEY,
  starts_at timestamptz NOT NULL,
  external_ref inet NOT NULL,
  phone boolean,
  is_active numeric(12,2),
  email double precision,
  kind bigint,
  label integer,
  quantity varchar(64) NOT NULL
);

CREATE TABLE archived_product_item (
  id bigint PRIMARY KEY,
  message_meta_id bigint REFERENCES message_meta(id),
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  v2_department_snapshot_id bigint REFERENCES v2_department_snapshot(id),
  quantity bigint,
  phone date NOT NULL,
  email inet NOT NULL
);

-- staging_category_item: 6 columns
CREATE TABLE staging_category_item (
  id bigint PRIMARY KEY,
  legacy_document_id bigint REFERENCES legacy_document(id),
  title smallint,
  external_ref text NOT NULL,
  code text,
  external_ref_4 date
);
/* trailing block comment */

CREATE TABLE public.staging_warehouse_snapshot (
  id bigint PRIMARY KEY,
  v2_route_history_id bigint REFERENCES v2_route_history(id),
  external_ticket_line_id bigint REFERENCES external_ticket_line(id),
  starts_at varchar(64),
  weight date NOT NULL,
  email varchar(255) NOT NULL,
  name uuid
);

-- contract_config: 13 columns
CREATE TABLE contract_config (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  account_link_id bigint NOT NULL REFERENCES account_link(id),
  inventory_detail_id bigint NOT NULL REFERENCES inventory_detail(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  position double precision NOT NULL,
  label bytea,
  metadata timestamp,
  is_active bigint NOT NULL,
  weight inet NOT NULL,
  weight_6 bytea NOT NULL,
  kind numeric(12,2),
  status uuid NOT NULL,
  UNIQUE (kind)
);

-- v2_asset_link: 15 columns
CREATE TABLE v2_asset_link (
  id bigint PRIMARY KEY,
  vendor_invoice_id bigint REFERENCES vendor_invoice(id),
  staging_order_history_id bigint REFERENCES staging_order_history(id),
  v2_task_item_id bigint NOT NULL,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  position varchar(255),
  rate text,
  kind boolean,
  rate_4 timestamptz NOT NULL,
  metadata numeric(12,2),
  slug timestamp,
  price bigint,
  expires_at integer NOT NULL,
  version bigint,
  rate_10 integer,
  UNIQUE (metadata)
);

-- audit_item: 8 columns
CREATE TABLE audit_item (
  id bigint PRIMARY KEY,
  locale bigint,
  locale_2 bytea,
  locale_3 uuid,
  title bigint NOT NULL,
  expires_at inet NOT NULL,
  title_6 bytea,
  deleted_at varchar(64) NOT NULL
);

CREATE TABLE external_campaign_link (
  id bigint PRIMARY KEY,
  legacy_claim_id bigint REFERENCES legacy_claim(id),
  label varchar(64),
  updated_at double precision NOT NULL,
  body bytea NOT NULL
);

CREATE TABLE external_department_link (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  policy_item_id bigint REFERENCES policy_item(id),
  refund_audit_id bigint REFERENCES refund_audit(id),
  created_at jsonb,
  total date NOT NULL,
  updated_at text NOT NULL,
  total_4 boolean,
  created_at_5 jsonb,
  note inet NOT NULL,
  quantity jsonb NOT NULL,
  updated_at_8 timestamp NOT NULL,
  starts_at date,
  kind varchar(64)
);

CREATE TABLE legacy_campaign_snapshot (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  staging_carrier_detail_id bigint REFERENCES staging_carrier_detail(id),
  kind numeric(12,2) NOT NULL,
  position timestamp,
  price double precision,
  external_ref bigint
);

CREATE TABLE archived_warehouse_config (
  id bigint PRIMARY KEY,
  legacy_message_line_id bigint REFERENCES legacy_message_line(id),
  title bigint NOT NULL,
  amount uuid NOT NULL,
  expires_at jsonb NOT NULL,
  body text,
  starts_at timestamp NOT NULL,
  locale inet,
  email smallint NOT NULL,
  UNIQUE (title)
);

CREATE TABLE "archived_vendor_history" (
  id bigint PRIMARY KEY,
  project_history_id bigint REFERENCES project_history(id),
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  status timestamp,
  total text NOT NULL,
  weight text NOT NULL,
  phone boolean,
  is_active varchar(255),
  rate date NOT NULL,
  name jsonb,
  price text,
  note timestamp,
  starts_at double precision
);

CREATE TABLE public.external_booking_audit (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  v2_ticket_audit_id bigint NOT NULL REFERENCES v2_ticket_audit(id),
  customer_snapshot_id bigint NOT NULL,
  starts_at varchar(255),
  is_default boolean NOT NULL
);

CREATE TABLE "public"."product_link" (
  id bigint PRIMARY KEY,
  v2_policy_line_id bigint NOT NULL REFERENCES v2_policy_line(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  code timestamptz,
  name text,
  updated_at boolean,
  weight timestamptz,
  title timestamp,
  amount timestamp,
  quantity inet,
  expires_at char(2) NOT NULL,
  title_9 uuid,
  name_10 bytea
);
/* trailing block comment */

CREATE TABLE archived_refund_snapshot (
  id bigint PRIMARY KEY,
  legacy_department_history_id bigint NOT NULL REFERENCES legacy_department_history(id),
  staging_booking_id bigint NOT NULL REFERENCES staging_booking(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  quantity varchar(255) NOT NULL,
  rate uuid,
  phone varchar(255),
  phone_4 inet,
  UNIQUE (phone)
);

CREATE TABLE claim_audit (
  id bigint PRIMARY KEY,
  body varchar(255),
  code date NOT NULL,
  checksum smallint,
  status integer NOT NULL,
  quantity char(2),
  name timestamptz NOT NULL,
  position inet,
  locale date,
  status_9 numeric(12,2)
);

CREATE TABLE contract_item (
  id bigint PRIMARY KEY,
  staging_review_id bigint NOT NULL REFERENCES staging_review(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  legacy_template_audit_id bigint NOT NULL REFERENCES legacy_template_audit(id),
  external_product_id bigint NOT NULL,
  email integer NOT NULL,
  currency inet NOT NULL,
  deleted_at uuid,
  metadata jsonb,
  price inet,
  rate date NOT NULL,
  title inet,
  note bytea NOT NULL,
  quantity boolean
);
/* trailing block comment */

CREATE TABLE legacy_booking_config (
  id bigint PRIMARY KEY,
  legacy_warehouse_item_id bigint NOT NULL,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  v2_notification_item_id bigint NOT NULL REFERENCES v2_notification_item(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  phone text NOT NULL,
  price uuid,
  starts_at text,
  label bigint NOT NULL,
  external_ref timestamp NOT NULL,
  metadata char(2)
);

CREATE TABLE subscription_detail (
  id bigint PRIMARY KEY,
  archived_order_id bigint,
  archived_account_audit_id bigint,
  status integer,
  locale timestamptz,
  expires_at date,
  amount uuid NOT NULL,
  quantity date,
  version text NOT NULL,
  rate text,
  locale_8 date NOT NULL
);

CREATE TABLE legacy_channel_history (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  staging_template_item_id bigint,
  status jsonb,
  name integer,
  weight varchar(255) NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_vehicle_history (
  id bigint PRIMARY KEY,
  legacy_campaign_item_id bigint,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  external_account_audit_id bigint NOT NULL REFERENCES external_account_audit(id),
  deleted_at inet NOT NULL,
  is_default uuid,
  starts_at varchar(255),
  weight bytea NOT NULL,
  quantity char(2),
  slug timestamptz
);
/* trailing block comment */

CREATE TABLE customer (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  checksum varchar(64) NOT NULL,
  total jsonb NOT NULL,
  name timestamptz NOT NULL,
  label text NOT NULL,
  total_5 text NOT NULL,
  rate uuid
);

-- legacy_review: 7 columns
CREATE TABLE public.legacy_review (
  id bigint PRIMARY KEY,
  legacy_discount_history_id bigint NOT NULL REFERENCES legacy_discount_history(id),
  route_detail_id bigint REFERENCES route_detail(id),
  is_active timestamp NOT NULL,
  status integer,
  deleted_at inet,
  quantity date
);
/* trailing block comment */

-- staging_payment_line: 4 columns
CREATE TABLE staging_payment_line (
  id bigint PRIMARY KEY,
  quantity boolean,
  external_ref timestamp,
  metadata numeric(12,2) NOT NULL
);

CREATE TABLE "legacy_product_item" (
  id bigint PRIMARY KEY,
  archived_policy_id bigint REFERENCES archived_policy(id),
  is_default numeric(12,2) NOT NULL,
  amount date,
  quantity varchar(64) NOT NULL
);

-- invoice_audit: 11 columns
CREATE TABLE "public"."invoice_audit" (
  id bigint PRIMARY KEY,
  legacy_booking_meta_id bigint NOT NULL REFERENCES legacy_booking_meta(id),
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  v2_refund_id bigint,
  label timestamp,
  currency numeric(12,2) NOT NULL,
  label_3 boolean,
  weight uuid,
  slug timestamptz NOT NULL,
  email smallint NOT NULL,
  currency_7 bytea
);

CREATE TABLE invoice_line (
  id bigint PRIMARY KEY,
  archived_order_id bigint REFERENCES archived_order(id),
  version timestamp NOT NULL,
  kind smallint,
  code uuid,
  checksum uuid NOT NULL,
  expires_at integer
);

CREATE TABLE v2_ticket_history (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  external_category_detail_id bigint REFERENCES external_category_detail(id),
  slug smallint NOT NULL,
  is_default smallint,
  kind date NOT NULL,
  label timestamp NOT NULL,
  is_active jsonb,
  created_at double precision,
  name integer
);

CREATE TABLE archived_product (
  id bigint PRIMARY KEY,
  is_default smallint,
  currency timestamp NOT NULL,
  checksum varchar(255),
  email date,
  code timestamptz,
  expires_at smallint,
  deleted_at bytea,
  expires_at_8 integer
);

CREATE TABLE archived_subscription_link (
  id bigint PRIMARY KEY,
  task_audit_id bigint REFERENCES task_audit(id),
  created_at integer,
  body uuid,
  timezone char(2) NOT NULL
);

-- legacy_department: 10 columns
CREATE TABLE "legacy_department" (
  id bigint PRIMARY KEY,
  archived_order_id bigint REFERENCES archived_order(id),
  v2_refund_id bigint NOT NULL,
  archived_route_config_id bigint NOT NULL,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  external_ref uuid,
  locale numeric(12,2) NOT NULL,
  timezone varchar(255),
  code text NOT NULL,
  status varchar(255) NOT NULL
);

CREATE TABLE archived_document_history (
  id bigint PRIMARY KEY,
  booking_line_id bigint REFERENCES booking_line(id),
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  archived_customer_meta_id bigint REFERENCES archived_customer_meta(id),
  email inet,
  status timestamp NOT NULL,
  body char(2),
  weight varchar(255) NOT NULL,
  label jsonb,
  rate bigint,
  phone inet NOT NULL,
  phone_8 timestamp,
  email_9 jsonb,
  slug bytea
);

CREATE TABLE archived_message (
  id bigint PRIMARY KEY,
  label timestamp,
  slug varchar(64) NOT NULL,
  version inet NOT NULL,
  weight inet NOT NULL,
  position inet,
  currency varchar(64) NOT NULL,
  UNIQUE (currency)
);

CREATE TABLE public.staging_category_config (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL,
  category_config_id bigint,
  vehicle_meta_id bigint NOT NULL REFERENCES vehicle_meta(id),
  rate bytea,
  note smallint NOT NULL,
  starts_at text NOT NULL,
  name integer NOT NULL,
  label varchar(255),
  is_locked numeric(12,2),
  external_ref bigint NOT NULL
);

-- order_meta: 8 columns
CREATE TABLE order_meta (
  id bigint PRIMARY KEY,
  is_locked uuid NOT NULL,
  created_at varchar(64),
  amount char(2),
  rate timestamptz,
  updated_at boolean,
  total boolean,
  title timestamptz
);

CREATE TABLE public.external_discount_line (
  id bigint PRIMARY KEY,
  archived_notification_snapshot_id bigint NOT NULL REFERENCES archived_notification_snapshot(id),
  archived_order_id bigint REFERENCES archived_order(id),
  expires_at timestamptz NOT NULL,
  email date NOT NULL,
  phone varchar(255) NOT NULL,
  quantity smallint,
  kind bytea NOT NULL
);

-- external_employee_link: 5 columns
CREATE TABLE external_employee_link (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  legacy_contract_item_id bigint NOT NULL REFERENCES legacy_contract_item(id),
  deleted_at varchar(64) NOT NULL,
  code inet
);

-- v2_shipment_detail: 12 columns
CREATE TABLE "public"."v2_shipment_detail" (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_template_detail_id bigint NOT NULL,
  archived_order_config_id bigint REFERENCES archived_order_config(id),
  amount numeric(12,2),
  kind char(2),
  label integer,
  body char(2),
  code smallint NOT NULL,
  created_at timestamp,
  phone boolean,
  expires_at timestamp
);

CREATE TABLE staging_inventory (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  legacy_carrier_id bigint NOT NULL REFERENCES legacy_carrier(id),
  is_default inet,
  created_at uuid,
  body uuid,
  slug date,
  code uuid,
  metadata uuid,
  price timestamptz NOT NULL,
  metadata_8 text NOT NULL,
  starts_at bigint
);

CREATE TABLE staging_tag_meta (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  product_meta_id bigint REFERENCES product_meta(id),
  deleted_at varchar(64) NOT NULL,
  checksum char(2),
  deleted_at_3 varchar(64),
  deleted_at_4 varchar(255) NOT NULL,
  quantity smallint,
  title uuid NOT NULL,
  rate inet NOT NULL,
  timezone double precision NOT NULL,
  body smallint NOT NULL,
  UNIQUE (discount_id)
);

CREATE TABLE "public"."v2_inventory" (
  id bigint PRIMARY KEY,
  booking_line_id bigint REFERENCES booking_line(id),
  template_history_id bigint NOT NULL,
  expires_at text NOT NULL,
  position bigint NOT NULL,
  rate boolean,
  is_active text
);
/* trailing block comment */

CREATE TABLE archived_notification_history (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  label boolean,
  deleted_at bigint,
  created_at jsonb
);

-- legacy_session_config: 16 columns
CREATE TABLE legacy_session_config (
  id bigint PRIMARY KEY,
  inventory_message_id bigint NOT NULL REFERENCES inventory_message(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  booking_item_id bigint NOT NULL REFERENCES booking_item(id),
  legacy_campaign_item_id bigint NOT NULL REFERENCES legacy_campaign_item(id),
  legacy_audit_snapshot_id bigint NOT NULL REFERENCES legacy_audit_snapshot(id),
  legacy_warehouse_id bigint REFERENCES legacy_warehouse(id),
  v2_shipment_leg_meta_id bigint,
  starts_at boolean,
  amount integer,
  amount_3 text NOT NULL,
  name jsonb NOT NULL,
  timezone integer,
  slug varchar(255),
  is_default jsonb,
  metadata date
);

CREATE TABLE staging_ticket_link (
  id bigint PRIMARY KEY,
  audit_id bigint NOT NULL REFERENCES audit(id),
  version smallint NOT NULL,
  note bigint,
  kind text,
  checksum boolean NOT NULL,
  timezone inet,
  created_at numeric(12,2),
  locale jsonb NOT NULL,
  weight date,
  deleted_at jsonb NOT NULL,
  UNIQUE (locale)
);
/* trailing block comment */

-- external_booking_meta: 8 columns
CREATE TABLE external_booking_meta (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  legacy_shipment_id bigint NOT NULL REFERENCES legacy_shipment(id),
  metadata smallint,
  updated_at integer,
  weight timestamptz,
  expires_at char(2),
  code double precision NOT NULL
);

-- booking_detail: 6 columns
CREATE TABLE booking_detail (
  id bigint PRIMARY KEY,
  expires_at timestamp NOT NULL,
  email date,
  code timestamptz NOT NULL,
  external_ref text,
  currency char(2)
);

CREATE TABLE legacy_ticket (
  id bigint PRIMARY KEY,
  staging_vehicle_item_id bigint,
  archived_subscription_id bigint NOT NULL REFERENCES archived_subscription(id),
  price boolean NOT NULL,
  currency integer NOT NULL,
  metadata uuid NOT NULL,
  external_ref numeric(12,2) NOT NULL,
  quantity date,
  title varchar(255),
  amount integer,
  is_default varchar(255) NOT NULL,
  note boolean
);

CREATE TABLE subscription_line (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL,
  is_default numeric(12,2),
  deleted_at numeric(12,2),
  weight integer,
  phone double precision NOT NULL,
  currency timestamp,
  metadata timestamptz,
  checksum numeric(12,2),
  deleted_at_8 bigint NOT NULL,
  rate double precision,
  locale varchar(255) NOT NULL,
  UNIQUE (deleted_at)
);

CREATE TABLE public.employee_item (
  id bigint PRIMARY KEY,
  legacy_asset_line_id bigint REFERENCES legacy_asset_line(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  slug smallint NOT NULL,
  weight varchar(255) NOT NULL
);
/* trailing block comment */

CREATE TABLE inventory_message (
  id bigint PRIMARY KEY,
  v2_vendor_link_id bigint NOT NULL,
  staging_warehouse_snapshot_id bigint REFERENCES staging_warehouse_snapshot(id),
  code timestamptz,
  amount varchar(64) NOT NULL,
  note char(2) NOT NULL,
  code_4 bigint NOT NULL,
  version smallint NOT NULL,
  updated_at timestamp
);

CREATE TABLE "public"."external_attachment_history" (
  id bigint PRIMARY KEY,
  phone varchar(255),
  rate jsonb,
  currency integer,
  title smallint,
  updated_at numeric(12,2),
  kind jsonb
);

CREATE TABLE legacy_task_config (
  id bigint PRIMARY KEY,
  external_inventory_id bigint REFERENCES external_inventory(id),
  external_ref varchar(64) NOT NULL,
  note date,
  deleted_at inet,
  name numeric(12,2) NOT NULL,
  timezone double precision,
  is_locked varchar(64),
  rate bigint,
  checksum varchar(255) NOT NULL,
  position varchar(255)
);

CREATE TABLE archived_route_snapshot (
  id bigint PRIMARY KEY,
  project_audit_id bigint NOT NULL REFERENCES project_audit(id),
  carrier_config_id bigint REFERENCES carrier_config(id),
  channel_link_id bigint NOT NULL REFERENCES channel_link(id),
  phone jsonb NOT NULL,
  timezone smallint,
  external_ref inet NOT NULL,
  amount double precision NOT NULL,
  UNIQUE (phone)
);

-- legacy_vehicle_item: 8 columns
CREATE TABLE legacy_vehicle_item (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL,
  v2_task_snapshot_id bigint REFERENCES v2_task_snapshot(id),
  v2_refund_history_id bigint NOT NULL REFERENCES v2_refund_history(id),
  is_locked double precision NOT NULL,
  weight bytea,
  phone numeric(12,2),
  created_at inet NOT NULL
);

CREATE TABLE asset_config (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  label varchar(255),
  checksum uuid,
  expires_at inet NOT NULL,
  version timestamp,
  name timestamptz,
  kind char(2) NOT NULL,
  version_7 jsonb,
  kind_8 boolean NOT NULL
);

CREATE TABLE order_audit (
  id bigint PRIMARY KEY,
  document_id bigint NOT NULL REFERENCES document(id),
  archived_shipment_leg_history_id bigint,
  amount bytea NOT NULL,
  total timestamptz,
  body bytea NOT NULL,
  deleted_at uuid,
  weight smallint NOT NULL,
  total_6 boolean NOT NULL,
  price smallint,
  kind integer,
  kind_9 integer NOT NULL,
  is_active date NOT NULL
);

-- archived_policy_line: 7 columns
CREATE TABLE archived_policy_line (
  id bigint PRIMARY KEY,
  expires_at text,
  timezone integer NOT NULL,
  is_locked inet,
  locale double precision,
  phone date,
  slug jsonb
);
/* trailing block comment */

-- ticket_link: 14 columns
CREATE TABLE ticket_link (
  id bigint PRIMARY KEY,
  archived_notification_config_id bigint REFERENCES archived_notification_config(id),
  warehouse_audit_id bigint NOT NULL,
  booking_line_id bigint NOT NULL,
  note uuid,
  is_default inet NOT NULL,
  price date,
  weight text NOT NULL,
  position smallint,
  price_6 double precision,
  external_ref smallint,
  email date,
  total char(2),
  expires_at timestamp NOT NULL,
  UNIQUE (position)
);

-- archived_payment: 8 columns
CREATE TABLE archived_payment (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  warehouse_audit_id bigint,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  title bytea,
  status timestamp,
  status_3 smallint,
  currency varchar(64),
  UNIQUE (archived_order_id)
);

CREATE TABLE legacy_vehicle_audit (
  id bigint PRIMARY KEY,
  carrier_audit_id bigint,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  amount inet NOT NULL,
  external_ref varchar(255) NOT NULL,
  expires_at numeric(12,2),
  deleted_at char(2) NOT NULL,
  note uuid NOT NULL,
  starts_at bigint,
  rate bytea,
  note_8 text NOT NULL,
  UNIQUE (carrier_audit_id)
);

CREATE TABLE tag_detail (
  id bigint PRIMARY KEY,
  v2_customer_detail_id bigint NOT NULL REFERENCES v2_customer_detail(id),
  amount char(2),
  is_active timestamp NOT NULL,
  deleted_at inet,
  created_at char(2) NOT NULL,
  amount_5 inet
);

-- external_warehouse_item: 5 columns
CREATE TABLE "public"."external_warehouse_item" (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  body varchar(64),
  external_ref smallint,
  is_active numeric(12,2) NOT NULL
);
/* trailing block comment */

-- external_template_detail: 5 columns
CREATE TABLE external_template_detail (
  id bigint PRIMARY KEY,
  route_message_id bigint NOT NULL REFERENCES route_message(id),
  v2_refund_id bigint REFERENCES v2_refund(id),
  starts_at boolean,
  quantity inet
);

-- v2_account_item: 12 columns
CREATE TABLE v2_account_item (
  id bigint PRIMARY KEY,
  attachment_discount_id bigint,
  label varchar(64) NOT NULL,
  currency timestamptz,
  starts_at varchar(255) NOT NULL,
  locale date NOT NULL,
  code bytea NOT NULL,
  label_6 timestamptz,
  metadata varchar(255) NOT NULL,
  code_8 date NOT NULL,
  label_9 timestamptz,
  code_10 boolean NOT NULL
);

CREATE TABLE "public"."legacy_discount" (
  id bigint PRIMARY KEY,
  is_active bytea,
  kind bytea,
  price timestamptz,
  note date,
  kind_5 date,
  metadata double precision NOT NULL,
  weight uuid,
  checksum varchar(255)
);

CREATE TABLE "public"."archived_project_audit" (
  id bigint PRIMARY KEY,
  archived_warehouse_config_id bigint NOT NULL REFERENCES archived_warehouse_config(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  session_meta_id bigint REFERENCES session_meta(id),
  warehouse_history_id bigint NOT NULL REFERENCES warehouse_history(id),
  discount_id bigint REFERENCES discount(id),
  body smallint NOT NULL,
  locale timestamptz,
  phone varchar(255)
);

-- staging_asset_history: 10 columns
CREATE TABLE staging_asset_history (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  payment_audit_id bigint NOT NULL,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  is_locked char(2),
  deleted_at smallint NOT NULL,
  position numeric(12,2) NOT NULL,
  deleted_at_4 timestamp,
  metadata date NOT NULL,
  weight numeric(12,2) NOT NULL
);

CREATE TABLE notification_line (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  policy_item_id bigint REFERENCES policy_item(id),
  phone varchar(64),
  is_active varchar(64),
  created_at timestamp,
  note inet NOT NULL,
  slug inet NOT NULL,
  status timestamp NOT NULL
);

-- external_message: 12 columns
CREATE TABLE external_message (
  id bigint PRIMARY KEY,
  warehouse_line_id bigint NOT NULL REFERENCES warehouse_line(id),
  invoice_audit_id bigint REFERENCES invoice_audit(id),
  code timestamptz,
  locale uuid,
  code_3 integer NOT NULL,
  checksum double precision NOT NULL,
  quantity char(2) NOT NULL,
  amount inet NOT NULL,
  phone timestamptz,
  amount_8 uuid NOT NULL,
  checksum_9 numeric(12,2)
);

CREATE TABLE legacy_shipment_audit (
  id bigint PRIMARY KEY,
  expires_at text NOT NULL,
  deleted_at date,
  status jsonb,
  version timestamp,
  deleted_at_5 uuid,
  title char(2),
  checksum smallint,
  weight varchar(64),
  updated_at jsonb NOT NULL
);

CREATE TABLE v2_contract (
  id bigint PRIMARY KEY,
  legacy_audit_meta_id bigint REFERENCES legacy_audit_meta(id),
  policy_history_id bigint REFERENCES policy_history(id),
  slug boolean NOT NULL,
  amount numeric(12,2),
  is_active varchar(255),
  currency date,
  checksum inet NOT NULL
);

CREATE TABLE "discount_meta" (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  session_detail_id bigint NOT NULL,
  version timestamp,
  timezone timestamptz,
  amount timestamptz NOT NULL,
  created_at varchar(255),
  kind inet NOT NULL,
  note char(2)
);

CREATE TABLE "public"."external_refund_audit" (
  id bigint PRIMARY KEY,
  archived_asset_config_id bigint REFERENCES archived_asset_config(id),
  external_campaign_link_id bigint NOT NULL REFERENCES external_campaign_link(id),
  checksum bytea,
  weight inet NOT NULL,
  phone double precision NOT NULL
);

CREATE TABLE legacy_shipment (
  id bigint PRIMARY KEY,
  archived_order_audit_id bigint NOT NULL REFERENCES archived_order_audit(id),
  v2_refund_audit_id bigint NOT NULL,
  expires_at numeric(12,2),
  deleted_at jsonb,
  label boolean,
  note timestamp,
  total boolean NOT NULL,
  title bigint NOT NULL,
  body char(2)
);
/* trailing block comment */

-- v2_product_item: 6 columns
CREATE TABLE v2_product_item (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  expires_at timestamp NOT NULL,
  total text,
  code varchar(255),
  locale smallint NOT NULL
);

CREATE TABLE legacy_project_snapshot (
  id bigint PRIMARY KEY,
  customer_id bigint REFERENCES customer(id),
  rate integer,
  external_ref numeric(12,2) NOT NULL
);

CREATE TABLE product_snapshot (
  id bigint PRIMARY KEY,
  booking_config_id bigint REFERENCES booking_config(id),
  is_locked jsonb,
  price date,
  slug integer,
  is_locked_4 varchar(64),
  expires_at jsonb,
  name jsonb NOT NULL,
  locale integer NOT NULL
);

CREATE TABLE v2_template_detail (
  id bigint PRIMARY KEY,
  v2_order_id bigint NOT NULL,
  inventory_line_id bigint REFERENCES inventory_line(id),
  metadata inet,
  is_active date NOT NULL,
  checksum varchar(64),
  starts_at text NOT NULL,
  status jsonb,
  rate text,
  expires_at char(2) NOT NULL,
  locale text NOT NULL,
  title varchar(64)
);

CREATE TABLE warehouse_line (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  external_warehouse_line_id bigint REFERENCES external_warehouse_line(id),
  position timestamp NOT NULL,
  title numeric(12,2),
  locale text,
  metadata varchar(255),
  rate inet
);
/* trailing block comment */

CREATE TABLE v2_task_audit (
  id bigint PRIMARY KEY,
  legacy_message_line_id bigint NOT NULL REFERENCES legacy_message_line(id),
  staging_department_history_id bigint,
  quantity numeric(12,2),
  checksum date,
  version bigint NOT NULL,
  quantity_4 boolean,
  position date,
  note timestamp,
  title bytea NOT NULL,
  timezone date NOT NULL,
  locale varchar(64) NOT NULL
);
/* trailing block comment */

-- legacy_document_meta: 6 columns
CREATE TABLE legacy_document_meta (
  id bigint PRIMARY KEY,
  v2_vendor_config_id bigint NOT NULL REFERENCES v2_vendor_config(id),
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  name smallint,
  deleted_at char(2) NOT NULL,
  price timestamp
);

CREATE TABLE staging_booking_config (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  timezone smallint,
  currency timestamptz,
  metadata text NOT NULL,
  title date
);

CREATE TABLE staging_carrier_item (
  id bigint PRIMARY KEY,
  kind inet,
  updated_at date
);

CREATE TABLE "external_task_audit" (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  employee_id bigint REFERENCES employee(id),
  currency bytea,
  total char(2) NOT NULL,
  kind double precision,
  external_ref jsonb,
  title varchar(64),
  rate jsonb NOT NULL,
  status inet,
  phone text,
  timezone double precision
);

CREATE TABLE product_detail (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  external_ref uuid NOT NULL,
  label inet
);

CREATE TABLE staging_campaign_snapshot (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  name text NOT NULL,
  email double precision NOT NULL,
  UNIQUE (v2_shipment_leg_meta_id)
);

CREATE TABLE "public"."external_project_config" (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  legacy_claim_history_id bigint REFERENCES legacy_claim_history(id),
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  rate bytea NOT NULL,
  price bigint,
  kind smallint NOT NULL,
  starts_at integer NOT NULL,
  locale varchar(64),
  UNIQUE (legacy_claim_history_id)
);

CREATE TABLE v2_carrier_detail (
  id bigint PRIMARY KEY,
  v2_discount_detail_id bigint NOT NULL,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  timezone varchar(64),
  title integer NOT NULL,
  UNIQUE (title)
);

CREATE TABLE task_item (
  id bigint PRIMARY KEY,
  discount_meta_id bigint NOT NULL,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  policy_item_id bigint REFERENCES policy_item(id),
  note integer,
  is_active timestamptz NOT NULL,
  body double precision NOT NULL,
  deleted_at uuid NOT NULL,
  kind text,
  currency varchar(255),
  created_at timestamptz,
  metadata char(2) NOT NULL
);

CREATE TABLE staging_review_line (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  deleted_at double precision NOT NULL,
  body varchar(64),
  kind timestamptz NOT NULL,
  expires_at varchar(255) NOT NULL,
  amount integer
);

-- legacy_audit: 7 columns
CREATE TABLE legacy_audit (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  amount varchar(64),
  total smallint NOT NULL,
  is_default uuid,
  name jsonb,
  position date NOT NULL
);

CREATE TABLE "public"."v2_employee_detail" (
  id bigint PRIMARY KEY,
  employee_snapshot_id bigint,
  archived_order_id bigint REFERENCES archived_order(id),
  slug date NOT NULL,
  version jsonb NOT NULL
);

CREATE TABLE document_item (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  checksum numeric(12,2) NOT NULL,
  updated_at bigint,
  amount bytea,
  version smallint NOT NULL,
  position varchar(255) NOT NULL,
  price boolean,
  external_ref bytea
);

CREATE TABLE staging_tag_item (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  timezone text,
  phone text,
  currency varchar(255) NOT NULL,
  kind jsonb NOT NULL
);

CREATE TABLE v2_template_snapshot (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  policy_item_id bigint REFERENCES policy_item(id),
  external_ref timestamp NOT NULL,
  timezone boolean NOT NULL,
  is_active inet NOT NULL,
  quantity inet,
  amount inet NOT NULL,
  updated_at smallint,
  name varchar(64),
  code text NOT NULL
);

CREATE TABLE v2_order_audit (
  id bigint PRIMARY KEY,
  staging_asset_line_id bigint REFERENCES staging_asset_line(id),
  contract_detail_id bigint REFERENCES contract_detail(id),
  legacy_account_id bigint NOT NULL,
  external_ref smallint NOT NULL,
  external_ref_2 numeric(12,2) NOT NULL,
  currency text NOT NULL,
  position double precision,
  updated_at smallint,
  is_default text NOT NULL,
  slug smallint NOT NULL,
  UNIQUE (legacy_account_id)
);

CREATE TABLE employee_config (
  id bigint PRIMARY KEY,
  archived_policy_line_id bigint NOT NULL REFERENCES archived_policy_line(id),
  is_default double precision,
  quantity text NOT NULL,
  total timestamptz,
  currency date,
  name jsonb,
  UNIQUE (name)
);

CREATE TABLE legacy_shipment_line (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  is_default double precision,
  note numeric(12,2),
  email smallint,
  body boolean NOT NULL,
  deleted_at bytea NOT NULL,
  timezone bigint NOT NULL
);

CREATE TABLE archived_vehicle (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  total jsonb,
  status date NOT NULL,
  note numeric(12,2),
  kind bigint,
  quantity timestamp NOT NULL
);

CREATE TABLE "public"."legacy_tag" (
  id bigint PRIMARY KEY,
  staging_category_id bigint REFERENCES staging_category(id),
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  archived_review_link_id bigint NOT NULL,
  amount inet,
  created_at varchar(255),
  status varchar(255) NOT NULL
);

-- external_warehouse_config: 8 columns
CREATE TABLE "external_warehouse_config" (
  id bigint PRIMARY KEY,
  phone bytea,
  locale double precision,
  starts_at char(2),
  is_default bytea,
  name varchar(64),
  total varchar(64) NOT NULL,
  body smallint NOT NULL,
  UNIQUE (total)
);

CREATE TABLE legacy_contract_audit (
  id bigint PRIMARY KEY,
  vehicle_id bigint,
  archived_order_id bigint NOT NULL,
  created_at timestamptz NOT NULL,
  is_default numeric(12,2),
  rate timestamp,
  position char(2) NOT NULL,
  kind char(2) NOT NULL,
  status bigint,
  status_7 timestamptz,
  is_locked numeric(12,2),
  currency numeric(12,2) NOT NULL
);

CREATE TABLE v2_document_item (
  id bigint PRIMARY KEY,
  external_ticket_id bigint NOT NULL REFERENCES external_ticket(id),
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  v2_tag_link_id bigint NOT NULL,
  invoice_config_id bigint REFERENCES invoice_config(id),
  external_refund_audit_id bigint NOT NULL REFERENCES external_refund_audit(id),
  template_config_id bigint NOT NULL REFERENCES template_config(id),
  metadata timestamp,
  deleted_at integer,
  expires_at integer,
  created_at timestamptz,
  starts_at date NOT NULL
);

CREATE TABLE route_message (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  archived_order_id bigint NOT NULL,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  expires_at bytea,
  body date,
  rate bigint NOT NULL,
  checksum text NOT NULL,
  is_default double precision,
  timezone smallint,
  deleted_at uuid NOT NULL
);

-- external_attachment: 15 columns
CREATE TABLE external_attachment (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  archived_account_audit_id bigint,
  legacy_channel_line_id bigint,
  booking_line_id bigint REFERENCES booking_line(id),
  external_ref uuid,
  starts_at jsonb NOT NULL,
  rate numeric(12,2) NOT NULL,
  currency varchar(64),
  metadata timestamptz,
  label varchar(64),
  weight timestamptz NOT NULL,
  weight_8 numeric(12,2) NOT NULL,
  created_at jsonb NOT NULL,
  email numeric(12,2) NOT NULL
);

-- staging_policy_history: 6 columns
CREATE TABLE staging_policy_history (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  legacy_invoice_meta_id bigint REFERENCES legacy_invoice_meta(id),
  deleted_at varchar(255),
  note char(2),
  is_active numeric(12,2) NOT NULL
);

CREATE TABLE legacy_account_audit (
  id bigint PRIMARY KEY,
  v2_channel_meta_id bigint,
  updated_at bytea NOT NULL,
  total integer,
  name varchar(64) NOT NULL,
  position smallint,
  title integer NOT NULL,
  timezone inet,
  checksum jsonb
);

CREATE TABLE external_project_audit (
  id bigint PRIMARY KEY,
  legacy_account_id bigint REFERENCES legacy_account(id),
  is_active smallint NOT NULL,
  deleted_at numeric(12,2) NOT NULL,
  is_locked double precision NOT NULL
);

CREATE TABLE project_invoice (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL,
  external_policy_config_id bigint NOT NULL REFERENCES external_policy_config(id),
  note inet,
  title integer,
  name uuid,
  note_4 boolean,
  rate uuid,
  expires_at timestamptz NOT NULL,
  rate_7 timestamptz,
  metadata date,
  rate_9 double precision,
  name_10 timestamptz,
  UNIQUE (note_4)
);

CREATE TABLE "public"."legacy_asset_history" (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint,
  refund_audit_id bigint REFERENCES refund_audit(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  project_history_id bigint REFERENCES project_history(id),
  staging_tag_id bigint REFERENCES staging_tag(id),
  external_ref varchar(64),
  version boolean,
  created_at timestamptz,
  rate jsonb NOT NULL,
  is_default text,
  timezone timestamp NOT NULL,
  code bigint NOT NULL
);

CREATE TABLE "public"."session_history" (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  refund_snapshot_id bigint NOT NULL,
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  updated_at text,
  email jsonb,
  created_at jsonb,
  UNIQUE (email)
);

CREATE TABLE legacy_department_history (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  vendor_invoice_id bigint NOT NULL,
  v2_vehicle_history_id bigint,
  label varchar(255),
  code smallint NOT NULL,
  status boolean,
  is_locked bigint
);

CREATE TABLE external_refund (
  id bigint PRIMARY KEY,
  body smallint,
  timezone varchar(255)
);

-- category_snapshot: 4 columns
CREATE TABLE "category_snapshot" (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  is_locked char(2),
  title date
);

-- v2_refund_history: 10 columns
CREATE TABLE v2_refund_history (
  id bigint PRIMARY KEY,
  external_ref bigint,
  deleted_at text NOT NULL,
  code bytea NOT NULL,
  position uuid,
  phone bigint NOT NULL,
  expires_at timestamp,
  body double precision NOT NULL,
  external_ref_8 bigint,
  is_default integer
);

-- external_refund_line: 12 columns
CREATE TABLE external_refund_line (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  metadata boolean NOT NULL,
  metadata_2 timestamptz NOT NULL,
  kind numeric(12,2) NOT NULL,
  total inet NOT NULL,
  locale bytea,
  amount bigint NOT NULL,
  expires_at integer,
  rate text,
  status double precision,
  status_10 integer,
  UNIQUE (project_history_id)
);

CREATE TABLE order_link (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  vendor_config_id bigint,
  refund_audit_id bigint REFERENCES refund_audit(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  slug bigint NOT NULL,
  total char(2) NOT NULL,
  deleted_at date NOT NULL,
  name text,
  position date,
  title inet
);

CREATE TABLE public.external_category (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  legacy_route_item_id bigint NOT NULL REFERENCES legacy_route_item(id),
  customer_snapshot_id bigint NOT NULL,
  quantity integer NOT NULL,
  is_locked jsonb,
  slug double precision,
  rate jsonb NOT NULL
);

CREATE TABLE "public"."v2_review_audit" (
  id bigint PRIMARY KEY,
  position varchar(255),
  name double precision NOT NULL
);

CREATE TABLE order_snapshot (
  id bigint PRIMARY KEY,
  project_history_id bigint REFERENCES project_history(id),
  archived_inventory_line_id bigint,
  v2_review_audit_id bigint NOT NULL REFERENCES v2_review_audit(id),
  is_active smallint NOT NULL,
  is_default text,
  slug inet,
  expires_at smallint,
  deleted_at smallint,
  slug_6 uuid,
  name boolean
);
/* trailing block comment */

CREATE TABLE payment_audit (
  id bigint PRIMARY KEY,
  archived_vehicle_snapshot_id bigint REFERENCES archived_vehicle_snapshot(id),
  position date,
  updated_at numeric(12,2),
  email inet,
  code double precision,
  body timestamp,
  version text,
  quantity bytea NOT NULL,
  title uuid
);

-- archived_vehicle_snapshot: 14 columns
CREATE TABLE archived_vehicle_snapshot (
  id bigint PRIMARY KEY,
  archived_order_id bigint REFERENCES archived_order(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  v2_warehouse_link_id bigint NOT NULL,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  rate smallint NOT NULL,
  is_active uuid,
  price inet,
  code inet,
  currency numeric(12,2),
  currency_6 text,
  timezone numeric(12,2) NOT NULL,
  amount smallint,
  expires_at timestamptz NOT NULL
);

CREATE TABLE external_asset_item (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  checksum boolean,
  metadata numeric(12,2) NOT NULL,
  locale jsonb,
  checksum_4 numeric(12,2) NOT NULL,
  email varchar(255),
  title bytea
);

CREATE TABLE legacy_invoice_config (
  id bigint PRIMARY KEY,
  updated_at bytea,
  deleted_at varchar(64),
  created_at timestamp,
  is_active jsonb
);

CREATE TABLE staging_inventory_config (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  locale smallint,
  note inet,
  position inet NOT NULL,
  name bytea NOT NULL,
  is_locked double precision,
  slug numeric(12,2) NOT NULL,
  is_locked_7 boolean,
  total text,
  body numeric(12,2),
  total_10 timestamp,
  UNIQUE (body)
);

-- session_audit: 6 columns
CREATE TABLE session_audit (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  archived_ticket_snapshot_id bigint NOT NULL REFERENCES archived_ticket_snapshot(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  price bytea,
  amount numeric(12,2)
);

-- legacy_campaign_item: 5 columns
CREATE TABLE legacy_campaign_item (
  id bigint PRIMARY KEY,
  staging_subscription_detail_id bigint NOT NULL REFERENCES staging_subscription_detail(id),
  status varchar(64) NOT NULL,
  weight double precision,
  total double precision
);
/* trailing block comment */

CREATE TABLE payment_line (
  id bigint PRIMARY KEY,
  starts_at timestamptz NOT NULL,
  code uuid,
  is_active integer,
  email timestamptz NOT NULL,
  rate double precision NOT NULL,
  kind timestamp,
  phone timestamp NOT NULL,
  updated_at text NOT NULL,
  phone_9 boolean,
  created_at date NOT NULL
);

CREATE TABLE archived_route_config (
  id bigint PRIMARY KEY,
  staging_category_item_id bigint NOT NULL REFERENCES staging_category_item(id),
  account_id bigint REFERENCES account(id),
  name bytea,
  total timestamptz,
  currency uuid,
  position uuid NOT NULL,
  rate char(2) NOT NULL,
  phone inet,
  UNIQUE (rate)
);

CREATE TABLE "v2_tag_history" (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  starts_at integer,
  position timestamp NOT NULL,
  is_active timestamp,
  kind char(2),
  status char(2) NOT NULL,
  timezone varchar(64),
  amount date,
  UNIQUE (status)
);

CREATE TABLE department_line (
  id bigint PRIMARY KEY,
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  is_active timestamptz,
  total boolean,
  rate inet,
  checksum smallint,
  timezone varchar(64),
  timezone_6 boolean,
  checksum_7 varchar(255),
  updated_at double precision,
  name numeric(12,2) NOT NULL,
  UNIQUE (is_active)
);

CREATE TABLE public.staging_message_item (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  archived_order_id bigint REFERENCES archived_order(id),
  starts_at varchar(255) NOT NULL,
  expires_at jsonb,
  code smallint,
  UNIQUE (archived_order_id)
);

-- v2_booking_history: 7 columns
CREATE TABLE v2_booking_history (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  invoice_meta_id bigint NOT NULL REFERENCES invoice_meta(id),
  kind uuid NOT NULL,
  total integer NOT NULL,
  price integer,
  price_4 char(2)
);
/* trailing block comment */

CREATE TABLE archived_order_config (
  id bigint PRIMARY KEY,
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  project_audit_id bigint REFERENCES project_audit(id),
  staging_message_link_id bigint REFERENCES staging_message_link(id),
  metadata double precision,
  version date,
  UNIQUE (version)
);

-- staging_channel: 5 columns
CREATE TABLE staging_channel (
  id bigint PRIMARY KEY,
  weight smallint,
  starts_at inet NOT NULL,
  code uuid NOT NULL,
  timezone text
);

-- external_ticket_line: 10 columns
CREATE TABLE external_ticket_line (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  external_ref bytea,
  updated_at boolean NOT NULL,
  phone integer,
  position char(2),
  external_ref_5 integer NOT NULL,
  status timestamp,
  weight smallint NOT NULL
);

-- legacy_warehouse_item: 5 columns
CREATE TABLE "legacy_warehouse_item" (
  id bigint PRIMARY KEY,
  position bigint NOT NULL,
  version text NOT NULL,
  name char(2) NOT NULL,
  expires_at text,
  UNIQUE (position)
);
/* trailing block comment */

CREATE TABLE staging_document (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  route_project_id bigint REFERENCES route_project(id),
  slug bigint,
  rate varchar(255),
  label varchar(64),
  weight timestamptz,
  status timestamptz NOT NULL,
  timezone smallint,
  title timestamp NOT NULL,
  price smallint NOT NULL
);
/* trailing block comment */

CREATE TABLE "public"."booking_item" (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  warehouse_audit_id bigint NOT NULL,
  archived_product_line_id bigint NOT NULL REFERENCES archived_product_line(id),
  locale char(2),
  starts_at bytea,
  is_locked double precision,
  name smallint,
  amount timestamp
);

CREATE TABLE v2_category_line (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  archived_payment_id bigint NOT NULL REFERENCES archived_payment(id),
  price inet NOT NULL,
  locale varchar(64),
  currency inet,
  is_active double precision NOT NULL,
  checksum bytea,
  starts_at varchar(255),
  deleted_at char(2),
  updated_at char(2)
);

-- v2_task_item: 5 columns
CREATE TABLE v2_task_item (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  version date,
  deleted_at integer,
  kind text
);

-- message_vendor: 14 columns
CREATE TABLE "public"."message_vendor" (
  id bigint PRIMARY KEY,
  external_contract_id bigint REFERENCES external_contract(id),
  contract_id bigint REFERENCES contract(id),
  archived_document_id bigint REFERENCES archived_document(id),
  legacy_review_config_id bigint NOT NULL REFERENCES legacy_review_config(id),
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  status bytea NOT NULL,
  weight bytea NOT NULL,
  slug jsonb,
  expires_at varchar(255),
  starts_at double precision,
  expires_at_6 char(2),
  phone timestamptz,
  phone_8 timestamp NOT NULL
);

CREATE TABLE staging_employee_config (
  id bigint PRIMARY KEY,
  rate boolean NOT NULL,
  starts_at uuid,
  amount varchar(64) NOT NULL,
  is_default timestamp NOT NULL,
  created_at integer NOT NULL,
  updated_at uuid,
  starts_at_7 bigint NOT NULL
);

CREATE TABLE staging_shipment_config (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  archived_booking_line_id bigint,
  carrier_snapshot_id bigint NOT NULL REFERENCES carrier_snapshot(id),
  is_active boolean,
  name boolean,
  position jsonb,
  checksum bytea,
  is_default varchar(255) NOT NULL,
  is_locked boolean,
  note text NOT NULL,
  kind char(2) NOT NULL
);

-- external_template_audit: 4 columns
CREATE TABLE external_template_audit (
  id bigint PRIMARY KEY,
  quantity bigint NOT NULL,
  checksum bytea NOT NULL,
  label date
);

-- external_tag_audit: 12 columns
CREATE TABLE external_tag_audit (
  id bigint PRIMARY KEY,
  archived_category_audit_id bigint NOT NULL REFERENCES archived_category_audit(id),
  v2_refund_id bigint REFERENCES v2_refund(id),
  timezone varchar(64),
  starts_at bigint,
  label numeric(12,2),
  is_active bigint NOT NULL,
  quantity uuid,
  title jsonb,
  quantity_7 integer,
  title_8 text,
  checksum jsonb,
  UNIQUE (is_active)
);

CREATE TABLE customer_meta (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  external_invoice_snapshot_id bigint REFERENCES external_invoice_snapshot(id),
  external_ref boolean,
  created_at timestamptz,
  locale char(2),
  email timestamptz,
  name integer NOT NULL,
  amount double precision,
  email_7 bytea,
  note numeric(12,2) NOT NULL
);

CREATE TABLE public.legacy_carrier_link (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  external_ref text,
  phone bigint,
  currency varchar(64),
  is_default boolean,
  status double precision,
  locale varchar(255) NOT NULL,
  expires_at uuid,
  position integer
);

-- v2_document_config: 4 columns
CREATE TABLE v2_document_config (
  id bigint PRIMARY KEY,
  currency varchar(64),
  deleted_at smallint NOT NULL,
  position timestamp NOT NULL
);

CREATE TABLE public.staging_message (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  warehouse_audit_id bigint REFERENCES warehouse_audit(id),
  metadata text,
  locale bytea,
  quantity bytea NOT NULL,
  is_default timestamp NOT NULL
);

-- v2_session_detail: 9 columns
CREATE TABLE v2_session_detail (
  id bigint PRIMARY KEY,
  account_config_id bigint REFERENCES account_config(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  is_default varchar(64),
  is_default_2 varchar(255),
  phone varchar(255) NOT NULL,
  metadata date NOT NULL,
  note double precision
);

CREATE TABLE staging_subscription_detail (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint,
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  staging_invoice_snapshot_id bigint NOT NULL REFERENCES staging_invoice_snapshot(id),
  external_campaign_id bigint NOT NULL REFERENCES external_campaign(id),
  v2_order_snapshot_id bigint,
  amount jsonb,
  checksum text NOT NULL,
  status jsonb,
  created_at smallint NOT NULL,
  slug varchar(64),
  UNIQUE (status)
);

-- external_shipment_leg_history: 5 columns
CREATE TABLE "public"."external_shipment_leg_history" (
  id bigint PRIMARY KEY,
  code text,
  note smallint,
  slug text NOT NULL,
  body numeric(12,2)
);

CREATE TABLE legacy_notification (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  staging_session_link_id bigint NOT NULL REFERENCES staging_session_link(id),
  total double precision,
  timezone timestamptz NOT NULL,
  metadata smallint,
  is_active varchar(255) NOT NULL,
  price smallint NOT NULL,
  status jsonb,
  metadata_7 timestamp,
  timezone_8 timestamptz NOT NULL,
  starts_at bytea,
  version bigint
);

-- archived_task_history: 8 columns
CREATE TABLE "public"."archived_task_history" (
  id bigint PRIMARY KEY,
  archived_notification_snapshot_id bigint NOT NULL REFERENCES archived_notification_snapshot(id),
  starts_at numeric(12,2),
  created_at char(2) NOT NULL,
  body varchar(255) NOT NULL,
  updated_at boolean NOT NULL,
  kind uuid,
  code varchar(255) NOT NULL,
  UNIQUE (starts_at)
);

CREATE TABLE archived_claim_item (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  channel_id bigint REFERENCES channel(id),
  external_ref boolean,
  kind timestamp,
  is_locked smallint NOT NULL,
  position bigint NOT NULL,
  updated_at char(2) NOT NULL,
  expires_at integer,
  title bigint
);

CREATE TABLE "public"."external_invoice" (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  archived_policy_id bigint REFERENCES archived_policy(id),
  total jsonb NOT NULL,
  body timestamp,
  checksum timestamptz,
  UNIQUE (checksum)
);
/* trailing block comment */

CREATE TABLE external_shipment_meta (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  v2_refund_audit_id bigint,
  v2_contract_item_id bigint NOT NULL REFERENCES v2_contract_item(id),
  metadata timestamptz,
  email timestamptz,
  note bigint
);

-- external_route_line: 8 columns
CREATE TABLE external_route_line (
  id bigint PRIMARY KEY,
  amount integer,
  note numeric(12,2),
  starts_at timestamp NOT NULL,
  amount_4 timestamp NOT NULL,
  deleted_at timestamptz,
  total numeric(12,2),
  external_ref jsonb
);

CREATE TABLE staging_claim_line (
  id bigint PRIMARY KEY,
  code date,
  slug text,
  position inet NOT NULL,
  label bytea,
  timezone timestamp,
  price boolean NOT NULL,
  created_at double precision NOT NULL,
  UNIQUE (price)
);

CREATE TABLE audit_config (
  id bigint PRIMARY KEY,
  archived_route_id bigint NOT NULL REFERENCES archived_route(id),
  amount char(2),
  weight text NOT NULL,
  label date,
  slug inet NOT NULL,
  weight_5 bigint NOT NULL,
  email integer
);

CREATE TABLE public.v2_document_meta (
  id bigint PRIMARY KEY,
  title text NOT NULL,
  amount smallint,
  external_ref inet NOT NULL,
  position char(2)
);

CREATE TABLE v2_vehicle_audit (
  id bigint PRIMARY KEY,
  archived_order_snapshot_id bigint NOT NULL REFERENCES archived_order_snapshot(id),
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  version text NOT NULL,
  price inet,
  status boolean NOT NULL,
  total timestamptz,
  total_5 varchar(255),
  rate numeric(12,2) NOT NULL,
  label timestamp,
  version_8 date NOT NULL
);

CREATE TABLE "public"."staging_customer_meta" (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  employee_line_id bigint REFERENCES employee_line(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  v2_department_detail_id bigint REFERENCES v2_department_detail(id),
  version bytea,
  title text,
  phone bytea,
  note bigint NOT NULL,
  updated_at timestamp NOT NULL,
  UNIQUE (note)
);
/* trailing block comment */

CREATE TABLE v2_campaign (
  id bigint PRIMARY KEY,
  phone boolean,
  checksum inet,
  expires_at bigint NOT NULL,
  deleted_at bigint,
  starts_at double precision NOT NULL,
  email char(2),
  status bigint,
  price uuid,
  UNIQUE (email)
);

CREATE TABLE v2_department_history (
  id bigint PRIMARY KEY,
  checksum char(2) NOT NULL,
  checksum_2 uuid
);

CREATE TABLE legacy_inventory (
  id bigint PRIMARY KEY,
  updated_at char(2),
  status numeric(12,2),
  total numeric(12,2),
  external_ref text NOT NULL,
  external_ref_5 jsonb NOT NULL,
  phone timestamptz,
  price double precision NOT NULL,
  UNIQUE (external_ref)
);

CREATE TABLE external_ticket (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  label varchar(255),
  external_ref numeric(12,2),
  created_at integer,
  is_locked uuid,
  rate uuid,
  email smallint,
  quantity uuid,
  is_locked_8 boolean,
  timezone varchar(255) NOT NULL
);

CREATE TABLE staging_review_snapshot (
  id bigint PRIMARY KEY,
  quantity char(2),
  is_active uuid NOT NULL,
  external_ref double precision,
  total varchar(64),
  position double precision,
  quantity_6 boolean,
  name inet NOT NULL,
  status smallint
);
/* trailing block comment */

-- external_inventory_detail: 13 columns
CREATE TABLE external_inventory_detail (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  slug bigint,
  deleted_at jsonb,
  version varchar(64) NOT NULL,
  version_4 numeric(12,2),
  status timestamptz NOT NULL,
  expires_at boolean NOT NULL,
  external_ref inet,
  checksum date NOT NULL,
  updated_at jsonb,
  note boolean
);

CREATE TABLE "public"."v2_shipment_leg_detail" (
  id bigint PRIMARY KEY,
  audit_detail_id bigint REFERENCES audit_detail(id),
  timezone numeric(12,2) NOT NULL,
  expires_at timestamp,
  timezone_3 smallint,
  code smallint
);

-- staging_task_link: 10 columns
CREATE TABLE staging_task_link (
  id bigint PRIMARY KEY,
  staging_warehouse_snapshot_id bigint REFERENCES staging_warehouse_snapshot(id),
  archived_account_audit_id bigint NOT NULL,
  archived_policy_id bigint REFERENCES archived_policy(id),
  staging_notification_detail_id bigint REFERENCES staging_notification_detail(id),
  slug bigint NOT NULL,
  quantity timestamptz,
  is_active jsonb,
  checksum integer NOT NULL,
  note numeric(12,2)
);

CREATE TABLE external_inventory_history (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  body double precision,
  amount varchar(255),
  timezone varchar(255),
  updated_at integer,
  title timestamptz,
  locale text,
  name jsonb,
  name_8 timestamptz NOT NULL
);

CREATE TABLE vendor_invoice (
  id bigint PRIMARY KEY,
  task_meta_id bigint NOT NULL REFERENCES task_meta(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  code numeric(12,2) NOT NULL,
  price uuid NOT NULL,
  title varchar(255) NOT NULL,
  is_locked bytea NOT NULL,
  created_at varchar(64) NOT NULL,
  label integer NOT NULL
);

-- asset_link: 12 columns
CREATE TABLE asset_link (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  kind timestamp,
  price char(2),
  body varchar(255) NOT NULL,
  checksum jsonb,
  expires_at text,
  quantity numeric(12,2),
  starts_at uuid NOT NULL,
  quantity_8 timestamptz,
  amount varchar(255),
  UNIQUE (price)
);

CREATE TABLE staging_payment_audit (
  id bigint PRIMARY KEY,
  review_link_id bigint NOT NULL REFERENCES review_link(id),
  expires_at timestamptz,
  created_at text NOT NULL,
  label uuid,
  is_active boolean,
  metadata integer,
  deleted_at integer NOT NULL,
  title integer NOT NULL,
  amount jsonb NOT NULL,
  updated_at double precision,
  UNIQUE (metadata)
);

CREATE TABLE external_order (
  id bigint PRIMARY KEY,
  v2_vendor_item_id bigint NOT NULL REFERENCES v2_vendor_item(id),
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  is_default inet,
  starts_at timestamptz,
  quantity boolean NOT NULL,
  is_active varchar(64) NOT NULL,
  weight char(2) NOT NULL,
  weight_6 varchar(64),
  locale smallint,
  UNIQUE (v2_vendor_item_id)
);
/* trailing block comment */

-- tag_snapshot: 11 columns
CREATE TABLE tag_snapshot (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  locale bytea,
  title numeric(12,2),
  weight jsonb NOT NULL,
  phone text NOT NULL,
  timezone integer NOT NULL,
  is_locked jsonb,
  phone_7 uuid,
  rate text,
  price timestamp
);

-- external_review_history: 9 columns
CREATE TABLE external_review_history (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  code text NOT NULL,
  phone char(2),
  weight varchar(64),
  email inet,
  title integer NOT NULL,
  deleted_at smallint
);
/* trailing block comment */

CREATE TABLE public.archived_carrier (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  code timestamptz NOT NULL,
  checksum timestamptz,
  body timestamptz NOT NULL,
  price varchar(64),
  is_active bigint,
  slug date,
  updated_at numeric(12,2),
  email timestamptz NOT NULL,
  UNIQUE (body)
);

CREATE TABLE product_meta (
  id bigint PRIMARY KEY,
  external_audit_detail_id bigint NOT NULL REFERENCES external_audit_detail(id),
  booking_link_id bigint NOT NULL REFERENCES booking_link(id),
  legacy_policy_audit_id bigint NOT NULL REFERENCES legacy_policy_audit(id),
  v2_vendor_meta_id bigint REFERENCES v2_vendor_meta(id),
  is_active text,
  updated_at timestamp,
  metadata timestamptz
);

-- tag_item: 8 columns
CREATE TABLE tag_item (
  id bigint PRIMARY KEY,
  v2_refund_id bigint REFERENCES v2_refund(id),
  is_active double precision,
  name text,
  rate smallint,
  label timestamp NOT NULL,
  metadata smallint,
  position uuid,
  UNIQUE (rate)
);

CREATE TABLE archived_claim_history (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  external_account_item_id bigint NOT NULL REFERENCES external_account_item(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  shipment_leg_line_id bigint REFERENCES shipment_leg_line(id),
  archived_inventory_line_id bigint REFERENCES archived_inventory_line(id),
  quantity jsonb,
  status smallint,
  is_locked integer NOT NULL,
  weight timestamp NOT NULL,
  locale numeric(12,2) NOT NULL
);

CREATE TABLE staging_vehicle_link (
  id bigint PRIMARY KEY,
  v2_audit_item_id bigint REFERENCES v2_audit_item(id),
  product_item_id bigint REFERENCES product_item(id),
  code timestamp NOT NULL,
  deleted_at varchar(64),
  code_3 uuid
);

-- staging_attachment_history: 11 columns
CREATE TABLE staging_attachment_history (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  staging_invoice_snapshot_id bigint,
  v2_refund_id bigint NOT NULL,
  booking_line_id bigint NOT NULL,
  body double precision,
  email integer NOT NULL,
  currency integer NOT NULL,
  phone double precision,
  body_5 bigint NOT NULL,
  title timestamptz NOT NULL
);

CREATE TABLE v2_route_history (
  id bigint PRIMARY KEY,
  v2_order_snapshot_id bigint NOT NULL REFERENCES v2_order_snapshot(id),
  discount_id bigint,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  code inet,
  name timestamp NOT NULL
);

-- archived_campaign_link: 5 columns
CREATE TABLE archived_campaign_link (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  kind varchar(64),
  expires_at double precision NOT NULL,
  version uuid NOT NULL
);

CREATE TABLE archived_contract_meta (
  id bigint PRIMARY KEY,
  v2_refund_meta_id bigint NOT NULL REFERENCES v2_refund_meta(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  is_default char(2),
  quantity smallint,
  rate varchar(255) NOT NULL
);

CREATE TABLE v2_customer_history (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  external_warehouse_config_id bigint NOT NULL REFERENCES external_warehouse_config(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  kind date,
  starts_at jsonb NOT NULL,
  version numeric(12,2) NOT NULL,
  locale timestamptz,
  is_active jsonb,
  name numeric(12,2) NOT NULL,
  metadata integer,
  amount double precision NOT NULL
);

CREATE TABLE staging_tag_snapshot (
  id bigint PRIMARY KEY,
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  is_locked numeric(12,2) NOT NULL,
  slug char(2),
  weight timestamp,
  checksum jsonb NOT NULL,
  external_ref jsonb,
  UNIQUE (archived_order_id)
);

-- legacy_category: 7 columns
CREATE TABLE legacy_category (
  id bigint PRIMARY KEY,
  archived_policy_id bigint,
  body numeric(12,2),
  starts_at varchar(64),
  email bigint NOT NULL,
  note numeric(12,2),
  version double precision,
  UNIQUE (body)
);

CREATE TABLE public.shipment_leg_history (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  currency numeric(12,2) NOT NULL,
  created_at timestamp NOT NULL
);
/* trailing block comment */

CREATE TABLE staging_order_line (
  id bigint PRIMARY KEY,
  timezone varchar(255),
  status double precision NOT NULL,
  note boolean NOT NULL,
  position timestamp,
  price bytea,
  total numeric(12,2) NOT NULL,
  is_locked uuid,
  metadata boolean NOT NULL,
  deleted_at numeric(12,2) NOT NULL,
  UNIQUE (timezone)
);

-- staging_employee_history: 11 columns
CREATE TABLE staging_employee_history (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  v2_shipment_detail_id bigint NOT NULL REFERENCES v2_shipment_detail(id),
  currency numeric(12,2) NOT NULL,
  expires_at varchar(64),
  slug double precision NOT NULL,
  body uuid NOT NULL,
  amount varchar(255) NOT NULL,
  slug_6 smallint,
  rate char(2) NOT NULL,
  note bigint
);
/* trailing block comment */

CREATE TABLE department_audit (
  id bigint PRIMARY KEY,
  price uuid,
  is_default bigint,
  is_default_3 char(2) NOT NULL,
  is_locked varchar(64),
  position smallint,
  deleted_at inet NOT NULL,
  is_locked_7 date
);

CREATE TABLE staging_shipment_leg_meta (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL,
  staging_template_item_id bigint REFERENCES staging_template_item(id),
  discount_line_id bigint NOT NULL REFERENCES discount_line(id),
  starts_at inet NOT NULL,
  body boolean NOT NULL,
  is_default text,
  kind char(2) NOT NULL,
  deleted_at timestamptz NOT NULL
);

CREATE TABLE v2_route_detail (
  id bigint PRIMARY KEY,
  legacy_route_audit_id bigint REFERENCES legacy_route_audit(id),
  asset_history_id bigint NOT NULL REFERENCES asset_history(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  rate inet,
  locale numeric(12,2) NOT NULL,
  UNIQUE (locale)
);

CREATE TABLE external_vehicle (
  id bigint PRIMARY KEY,
  locale text,
  name double precision,
  version inet NOT NULL
);

CREATE TABLE v2_document_detail (
  id bigint PRIMARY KEY,
  v2_document_item_id bigint REFERENCES v2_document_item(id),
  v2_shipment_leg_meta_id bigint NOT NULL,
  timezone char(2) NOT NULL,
  is_active inet,
  is_default char(2)
);

-- staging_employee_meta: 10 columns
CREATE TABLE "public"."staging_employee_meta" (
  id bigint PRIMARY KEY,
  archived_vendor_history_id bigint NOT NULL REFERENCES archived_vendor_history(id),
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  expires_at varchar(255),
  is_locked varchar(64),
  locale numeric(12,2) NOT NULL,
  quantity date NOT NULL,
  phone boolean,
  version smallint,
  total bigint
);

CREATE TABLE warehouse_history (
  id bigint PRIMARY KEY,
  position varchar(255) NOT NULL,
  title inet,
  deleted_at bigint
);

-- shipment_leg_line: 10 columns
CREATE TABLE shipment_leg_line (
  id bigint PRIMARY KEY,
  archived_invoice_line_id bigint REFERENCES archived_invoice_line(id),
  archived_message_audit_id bigint NOT NULL REFERENCES archived_message_audit(id),
  locale double precision NOT NULL,
  status uuid,
  label varchar(64) NOT NULL,
  checksum integer NOT NULL,
  is_active date NOT NULL,
  is_active_6 text,
  total text
);

CREATE TABLE legacy_discount_history (
  id bigint PRIMARY KEY,
  invoice_policy_id bigint NOT NULL REFERENCES invoice_policy(id),
  legacy_account_id bigint NOT NULL,
  total varchar(255),
  updated_at bytea,
  locale varchar(255),
  total_4 bytea,
  external_ref timestamp NOT NULL,
  price bigint NOT NULL,
  phone timestamp NOT NULL,
  version bigint
);

CREATE TABLE "public"."v2_inventory_config" (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  code inet NOT NULL,
  locale char(2) NOT NULL,
  expires_at varchar(255),
  locale_4 varchar(255),
  label jsonb
);

CREATE TABLE legacy_audit_link (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  archived_policy_id bigint REFERENCES archived_policy(id),
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  expires_at bytea NOT NULL,
  currency varchar(64),
  created_at integer,
  metadata timestamp NOT NULL
);

CREATE TABLE channel_link (
  id bigint PRIMARY KEY,
  external_ticket_line_id bigint REFERENCES external_ticket_line(id),
  warehouse_history_id bigint NOT NULL REFERENCES warehouse_history(id),
  warehouse_audit_id bigint NOT NULL,
  staging_notification_meta_id bigint REFERENCES staging_notification_meta(id),
  archived_order_id bigint NOT NULL REFERENCES archived_order(id),
  external_ref integer,
  version char(2),
  starts_at text NOT NULL,
  starts_at_4 jsonb,
  slug timestamptz,
  amount date NOT NULL,
  weight boolean NOT NULL,
  label timestamp
);

CREATE TABLE "public"."archived_asset" (
  id bigint PRIMARY KEY,
  is_locked char(2),
  position date,
  phone integer,
  locale varchar(64),
  code numeric(12,2),
  body date NOT NULL,
  expires_at integer
);

CREATE TABLE v2_department_link (
  id bigint PRIMARY KEY,
  archived_account_audit_id bigint REFERENCES archived_account_audit(id),
  external_shipment_leg_id bigint REFERENCES external_shipment_leg(id),
  legacy_account_id bigint NOT NULL,
  version text NOT NULL,
  updated_at varchar(64),
  note varchar(255) NOT NULL,
  code varchar(255) NOT NULL,
  quantity timestamp,
  total boolean NOT NULL
);
/* trailing block comment */

-- v2_category: 9 columns
CREATE TABLE v2_category (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  staging_session_link_id bigint NOT NULL REFERENCES staging_session_link(id),
  is_default jsonb NOT NULL,
  title text NOT NULL,
  label bigint,
  price integer,
  updated_at smallint NOT NULL,
  note text NOT NULL
);
/* trailing block comment */

CREATE TABLE public.v2_session_audit (
  id bigint PRIMARY KEY,
  archived_policy_id bigint REFERENCES archived_policy(id),
  legacy_campaign_config_id bigint NOT NULL REFERENCES legacy_campaign_config(id),
  phone numeric(12,2) NOT NULL,
  expires_at uuid,
  total double precision NOT NULL,
  title uuid,
  label bytea,
  metadata integer,
  price inet NOT NULL
);

CREATE TABLE v2_task_link (
  id bigint PRIMARY KEY,
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  external_vendor_line_id bigint REFERENCES external_vendor_line(id),
  price text NOT NULL,
  metadata varchar(255),
  locale numeric(12,2) NOT NULL
);

-- claim_snapshot: 5 columns
CREATE TABLE claim_snapshot (
  id bigint PRIMARY KEY,
  staging_review_link_id bigint NOT NULL REFERENCES staging_review_link(id),
  deleted_at smallint NOT NULL,
  quantity numeric(12,2),
  amount text
);

CREATE TABLE "public"."archived_shipment_line" (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  v2_policy_id bigint REFERENCES v2_policy(id),
  locale numeric(12,2) NOT NULL,
  kind date,
  amount numeric(12,2),
  checksum smallint NOT NULL,
  external_ref numeric(12,2) NOT NULL,
  total smallint,
  UNIQUE (policy_item_id)
);

CREATE TABLE "product_carrier" (
  id bigint PRIMARY KEY,
  amount varchar(64),
  label char(2),
  is_locked uuid NOT NULL,
  phone double precision,
  UNIQUE (amount)
);

CREATE TABLE staging_employee_detail (
  id bigint PRIMARY KEY,
  legacy_review_audit_id bigint NOT NULL REFERENCES legacy_review_audit(id),
  is_default timestamp,
  kind text NOT NULL,
  updated_at numeric(12,2) NOT NULL,
  UNIQUE (legacy_review_audit_id)
);

CREATE TABLE legacy_account_detail (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL,
  staging_department_history_id bigint NOT NULL REFERENCES staging_department_history(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  version text NOT NULL,
  title smallint
);

CREATE TABLE campaign_link (
  id bigint PRIMARY KEY,
  account_detail_id bigint REFERENCES account_detail(id),
  total timestamptz,
  created_at bytea NOT NULL,
  code inet
);

-- external_order_history: 3 columns
CREATE TABLE external_order_history (
  id bigint PRIMARY KEY,
  is_active numeric(12,2),
  is_active_2 jsonb
);

CREATE TABLE archived_audit_snapshot (
  id bigint PRIMARY KEY,
  legacy_channel_history_id bigint NOT NULL REFERENCES legacy_channel_history(id),
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  body varchar(64),
  total smallint,
  position uuid,
  metadata inet NOT NULL
);

-- v2_attachment_snapshot: 10 columns
CREATE TABLE "public"."v2_attachment_snapshot" (
  id bigint PRIMARY KEY,
  warehouse_history_id bigint REFERENCES warehouse_history(id),
  external_booking_audit_id bigint NOT NULL REFERENCES external_booking_audit(id),
  expires_at char(2) NOT NULL,
  currency numeric(12,2),
  created_at integer,
  is_locked timestamptz NOT NULL,
  starts_at varchar(255) NOT NULL,
  quantity jsonb,
  currency_7 varchar(64)
);

CREATE TABLE v2_refund_config (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint NOT NULL REFERENCES staging_shipment_leg_config(id),
  staging_warehouse_audit_id bigint NOT NULL,
  legacy_order_id bigint REFERENCES legacy_order(id),
  v2_category_id bigint REFERENCES v2_category(id),
  code integer,
  amount varchar(255),
  timezone jsonb,
  body bigint NOT NULL,
  checksum double precision,
  external_ref date,
  kind timestamptz,
  status bigint,
  currency text NOT NULL,
  position varchar(64) NOT NULL,
  UNIQUE (staging_warehouse_audit_id)
);

CREATE TABLE archived_order_meta (
  id bigint PRIMARY KEY,
  project_history_id bigint,
  warehouse_history_id bigint REFERENCES warehouse_history(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  created_at double precision NOT NULL,
  total uuid,
  updated_at text NOT NULL,
  quantity text NOT NULL,
  email date NOT NULL,
  label char(2),
  position boolean,
  external_ref numeric(12,2),
  kind smallint NOT NULL
);

-- ticket_booking: 7 columns
CREATE TABLE ticket_booking (
  id bigint PRIMARY KEY,
  staging_shipment_leg_config_id bigint REFERENCES staging_shipment_leg_config(id),
  weight date NOT NULL,
  position date,
  timezone integer NOT NULL,
  is_active bigint,
  is_default boolean
);

-- tag_link: 12 columns
CREATE TABLE tag_link (
  id bigint PRIMARY KEY,
  archived_review_audit_id bigint NOT NULL REFERENCES archived_review_audit(id),
  warehouse_audit_id bigint NOT NULL,
  external_ref timestamp,
  currency integer NOT NULL,
  total varchar(64),
  is_default numeric(12,2) NOT NULL,
  price bytea NOT NULL,
  price_6 bigint,
  is_locked double precision,
  weight numeric(12,2),
  timezone varchar(255),
  UNIQUE (total)
);

CREATE TABLE policy_snapshot (
  id bigint PRIMARY KEY,
  kind numeric(12,2),
  quantity inet NOT NULL,
  slug numeric(12,2) NOT NULL
);

-- legacy_channel_line: 6 columns
CREATE TABLE legacy_channel_line (
  id bigint PRIMARY KEY,
  legacy_account_id bigint REFERENCES legacy_account(id),
  timezone uuid NOT NULL,
  external_ref timestamp,
  email bigint,
  status uuid
);

CREATE TABLE staging_vendor_detail (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  title timestamp NOT NULL,
  timezone numeric(12,2) NOT NULL,
  phone date
);

CREATE TABLE external_claim_meta (
  id bigint PRIMARY KEY,
  legacy_account_id bigint REFERENCES legacy_account(id),
  body smallint,
  metadata timestamptz NOT NULL,
  name date,
  is_default uuid NOT NULL,
  UNIQUE (legacy_account_id)
);
/* trailing block comment */

CREATE TABLE public.archived_notification_item (
  id bigint PRIMARY KEY,
  v2_shipment_line_id bigint NOT NULL REFERENCES v2_shipment_line(id),
  rate uuid,
  expires_at timestamp,
  is_locked char(2),
  UNIQUE (expires_at)
);

CREATE TABLE external_contract_audit (
  id bigint PRIMARY KEY,
  external_inventory_detail_id bigint NOT NULL REFERENCES external_inventory_detail(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  checksum bigint NOT NULL,
  email date NOT NULL,
  rate uuid,
  weight timestamptz,
  code smallint NOT NULL,
  updated_at numeric(12,2),
  UNIQUE (code)
);
/* trailing block comment */

CREATE TABLE employee_payment (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  slug varchar(64),
  body timestamp,
  quantity integer
);

CREATE TABLE audit_history (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  archived_account_audit_id bigint NOT NULL REFERENCES archived_account_audit(id),
  timezone inet,
  locale inet,
  timezone_3 double precision,
  code char(2) NOT NULL,
  version boolean,
  amount varchar(64) NOT NULL,
  email smallint
);

CREATE TABLE inventory_detail (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  kind bytea NOT NULL,
  phone date,
  is_default timestamptz NOT NULL,
  expires_at varchar(255) NOT NULL,
  UNIQUE (is_default)
);

CREATE TABLE external_asset_meta (
  id bigint PRIMARY KEY,
  invoice_config_id bigint NOT NULL REFERENCES invoice_config(id),
  archived_ticket_snapshot_id bigint NOT NULL REFERENCES archived_ticket_snapshot(id),
  v2_product_item_id bigint,
  is_active varchar(255) NOT NULL,
  version timestamp NOT NULL,
  is_locked varchar(255),
  version_4 varchar(255),
  weight bigint,
  quantity integer,
  phone double precision NOT NULL
);

-- external_channel: 4 columns
CREATE TABLE "public"."external_channel" (
  id bigint PRIMARY KEY,
  checksum double precision,
  body integer,
  timezone uuid,
  UNIQUE (body)
);

CREATE TABLE external_category_item (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  project_history_id bigint NOT NULL,
  external_ref timestamptz NOT NULL,
  body varchar(255) NOT NULL,
  body_3 timestamp,
  locale varchar(64),
  email inet,
  code uuid
);

CREATE TABLE external_inventory_audit (
  id bigint PRIMARY KEY,
  title integer,
  label jsonb,
  is_active bigint,
  is_locked smallint,
  metadata numeric(12,2) NOT NULL,
  timezone smallint
);
/* trailing block comment */

CREATE TABLE archived_audit (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  v2_discount_config_id bigint REFERENCES v2_discount_config(id),
  v2_vendor_config_id bigint REFERENCES v2_vendor_config(id),
  code double precision NOT NULL,
  external_ref boolean,
  currency integer
);
/* trailing block comment */

CREATE TABLE review_link (
  id bigint PRIMARY KEY,
  refund_audit_id bigint REFERENCES refund_audit(id),
  discount_id bigint NOT NULL REFERENCES discount(id),
  starts_at boolean,
  status boolean,
  price smallint NOT NULL,
  position varchar(255),
  price_5 varchar(64),
  external_ref char(2) NOT NULL
);

CREATE TABLE archived_invoice_line (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL REFERENCES refund_audit(id),
  external_refund_link_id bigint NOT NULL,
  review_snapshot_id bigint REFERENCES review_snapshot(id),
  staging_order_history_id bigint,
  discount_id bigint NOT NULL REFERENCES discount(id),
  kind bytea,
  price char(2) NOT NULL
);

CREATE TABLE v2_document (
  id bigint PRIMARY KEY,
  staging_attachment_id bigint REFERENCES staging_attachment(id),
  name jsonb,
  label uuid,
  price integer NOT NULL,
  name_4 double precision NOT NULL,
  starts_at integer,
  code inet NOT NULL,
  email numeric(12,2),
  position text
);

-- external_session_line: 11 columns
CREATE TABLE external_session_line (
  id bigint PRIMARY KEY,
  v2_vendor_line_id bigint NOT NULL REFERENCES v2_vendor_line(id),
  invoice_config_id bigint REFERENCES invoice_config(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  external_vendor_line_id bigint NOT NULL,
  body boolean,
  checksum timestamptz NOT NULL,
  created_at text,
  kind double precision NOT NULL,
  metadata timestamp,
  body_6 bigint
);

CREATE TABLE policy_detail (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  warehouse_audit_id bigint NOT NULL REFERENCES warehouse_audit(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  staging_employee_id bigint REFERENCES staging_employee(id),
  external_customer_id bigint NOT NULL REFERENCES external_customer(id),
  updated_at text NOT NULL,
  created_at char(2),
  price boolean NOT NULL,
  position integer,
  UNIQUE (staging_employee_id)
);

-- v2_vendor_meta: 7 columns
CREATE TABLE v2_vendor_meta (
  id bigint PRIMARY KEY,
  shipment_history_id bigint NOT NULL REFERENCES shipment_history(id),
  archived_order_config_id bigint REFERENCES archived_order_config(id),
  starts_at timestamp NOT NULL,
  expires_at double precision,
  updated_at timestamp NOT NULL,
  weight double precision,
  UNIQUE (updated_at)
);

CREATE TABLE public.legacy_vendor (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  discount_id bigint REFERENCES discount(id),
  staging_department_history_id bigint REFERENCES staging_department_history(id),
  v2_audit_item_id bigint NOT NULL REFERENCES v2_audit_item(id),
  archived_order_id bigint REFERENCES archived_order(id),
  timezone jsonb NOT NULL,
  total numeric(12,2),
  metadata uuid,
  code integer,
  created_at jsonb NOT NULL,
  locale double precision NOT NULL,
  quantity smallint NOT NULL,
  code_8 boolean NOT NULL,
  status jsonb,
  metadata_10 char(2)
);

CREATE TABLE staging_review (
  id bigint PRIMARY KEY,
  v2_document_id bigint NOT NULL REFERENCES v2_document(id),
  external_channel_link_id bigint NOT NULL REFERENCES external_channel_link(id),
  checksum timestamptz,
  created_at bytea,
  price varchar(64),
  price_4 double precision NOT NULL,
  external_ref numeric(12,2) NOT NULL,
  phone timestamptz NOT NULL,
  email char(2) NOT NULL
);

CREATE TABLE archived_vendor_meta (
  id bigint PRIMARY KEY,
  external_audit_id bigint REFERENCES external_audit(id),
  phone uuid,
  expires_at integer NOT NULL,
  rate varchar(64),
  price inet,
  kind timestamptz,
  slug boolean NOT NULL
);

CREATE TABLE campaign_line (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  archived_account_audit_id bigint NOT NULL,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  message_line_id bigint NOT NULL REFERENCES message_line(id),
  timezone uuid,
  expires_at varchar(64),
  is_default bigint NOT NULL
);

CREATE TABLE "public"."external_department" (
  id bigint PRIMARY KEY,
  staging_shipment_leg_meta_id bigint NOT NULL,
  staging_category_line_id bigint NOT NULL REFERENCES staging_category_line(id),
  v2_claim_detail_id bigint NOT NULL,
  weight varchar(64) NOT NULL,
  email inet,
  body numeric(12,2),
  note char(2),
  rate smallint NOT NULL,
  position jsonb,
  label numeric(12,2),
  UNIQUE (staging_shipment_leg_meta_id)
);

CREATE TABLE public.employee_meta (
  id bigint PRIMARY KEY,
  vehicle_audit_id bigint REFERENCES vehicle_audit(id),
  is_default bytea NOT NULL,
  amount boolean NOT NULL,
  metadata timestamp NOT NULL,
  metadata_4 integer,
  slug uuid,
  title char(2) NOT NULL,
  locale varchar(255),
  is_default_8 text
);

CREATE TABLE archived_inventory_config (
  id bigint PRIMARY KEY,
  external_subscription_id bigint NOT NULL REFERENCES external_subscription(id),
  refund_audit_id bigint NOT NULL,
  title uuid NOT NULL,
  checksum bigint,
  version integer NOT NULL,
  created_at char(2),
  status jsonb
);
/* trailing block comment */

CREATE TABLE invoice_link (
  id bigint PRIMARY KEY,
  refund_audit_id bigint NOT NULL,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  staging_shipment_leg_config_id bigint,
  checksum timestamptz NOT NULL,
  email bigint,
  price varchar(255) NOT NULL,
  phone varchar(64) NOT NULL,
  status uuid,
  position jsonb,
  is_active bytea,
  created_at double precision NOT NULL
);

CREATE TABLE v2_subscription_config (
  id bigint PRIMARY KEY,
  v2_account_id bigint NOT NULL REFERENCES v2_account(id),
  staging_template_item_id bigint NOT NULL,
  label date,
  checksum char(2),
  checksum_3 jsonb NOT NULL,
  status char(2),
  price numeric(12,2) NOT NULL,
  amount varchar(64),
  deleted_at text,
  title bigint
);

-- v2_booking_snapshot: 8 columns
CREATE TABLE "v2_booking_snapshot" (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  code boolean,
  rate double precision,
  weight text,
  phone inet NOT NULL,
  updated_at varchar(255),
  note smallint
);

CREATE TABLE staging_ticket (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  legacy_account_id bigint REFERENCES legacy_account(id),
  legacy_contract_audit_id bigint REFERENCES legacy_contract_audit(id),
  archived_order_id bigint REFERENCES archived_order(id),
  staging_department_history_id bigint NOT NULL,
  weight bytea,
  title timestamptz,
  rate char(2),
  created_at char(2)
);

CREATE TABLE public.staging_payment_snapshot (
  id bigint PRIMARY KEY,
  project_history_id bigint REFERENCES project_history(id),
  legacy_account_id bigint,
  deleted_at inet,
  amount bigint NOT NULL,
  price boolean,
  starts_at date,
  is_active date NOT NULL,
  note double precision,
  metadata bigint,
  amount_8 varchar(255),
  label inet
);

CREATE TABLE staging_booking_audit (
  id bigint PRIMARY KEY,
  email jsonb NOT NULL,
  position bytea NOT NULL,
  metadata varchar(255),
  locale bytea,
  locale_5 inet NOT NULL,
  note char(2),
  total varchar(64) NOT NULL,
  is_locked jsonb NOT NULL
);

CREATE TABLE campaign_meta (
  id bigint PRIMARY KEY,
  discount_id bigint NOT NULL REFERENCES discount(id),
  rate timestamptz,
  checksum bigint,
  is_locked numeric(12,2) NOT NULL,
  version numeric(12,2),
  starts_at date,
  is_active bytea,
  quantity varchar(64),
  starts_at_8 timestamptz,
  quantity_9 bytea NOT NULL
);

CREATE TABLE v2_vehicle (
  id bigint PRIMARY KEY,
  v2_discount_config_id bigint NOT NULL REFERENCES v2_discount_config(id),
  invoice_meta_id bigint NOT NULL REFERENCES invoice_meta(id),
  staging_message_snapshot_id bigint NOT NULL,
  version varchar(255),
  metadata numeric(12,2),
  starts_at uuid
);

CREATE TABLE legacy_notification_link (
  id bigint PRIMARY KEY,
  legacy_account_id bigint,
  tag_link_id bigint NOT NULL REFERENCES tag_link(id),
  warehouse_audit_id bigint,
  staging_message_id bigint NOT NULL REFERENCES staging_message(id),
  deleted_at bytea NOT NULL,
  is_locked bytea NOT NULL,
  price integer,
  title uuid,
  body inet NOT NULL,
  starts_at date
);

CREATE TABLE v2_account (
  id bigint PRIMARY KEY,
  legacy_account_id bigint NOT NULL REFERENCES legacy_account(id),
  position numeric(12,2) NOT NULL,
  label numeric(12,2) NOT NULL,
  locale timestamptz NOT NULL,
  external_ref text NOT NULL,
  position_5 char(2) NOT NULL,
  timezone bigint,
  locale_7 bytea NOT NULL,
  title smallint NOT NULL,
  status inet NOT NULL,
  UNIQUE (locale_7)
);

-- v2_category_audit: 7 columns
CREATE TABLE v2_category_audit (
  id bigint PRIMARY KEY,
  archived_order_id bigint REFERENCES archived_order(id),
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  label timestamptz,
  name boolean,
  checksum bytea,
  note smallint
);

-- archived_route: 8 columns
CREATE TABLE archived_route (
  id bigint PRIMARY KEY,
  external_policy_config_id bigint REFERENCES external_policy_config(id),
  weight char(2) NOT NULL,
  kind varchar(255),
  timezone integer,
  code smallint,
  amount timestamptz NOT NULL,
  label date NOT NULL,
  UNIQUE (amount)
);

CREATE TABLE staging_customer_item (
  id bigint PRIMARY KEY,
  v2_refund_audit_id bigint REFERENCES v2_refund_audit(id),
  legacy_tag_id bigint REFERENCES legacy_tag(id),
  v2_notification_id bigint NOT NULL REFERENCES v2_notification(id),
  body varchar(64) NOT NULL,
  body_2 double precision,
  is_locked date,
  starts_at boolean NOT NULL
);

-- legacy_subscription_meta: 9 columns
CREATE TABLE legacy_subscription_meta (
  id bigint PRIMARY KEY,
  booking_line_id bigint NOT NULL REFERENCES booking_line(id),
  timezone date NOT NULL,
  rate timestamp,
  quantity smallint NOT NULL,
  kind integer,
  code date,
  body uuid,
  metadata uuid NOT NULL
);

CREATE TABLE external_task_config (
  id bigint PRIMARY KEY,
  name double precision NOT NULL,
  kind varchar(255) NOT NULL,
  is_locked char(2)
);

CREATE TABLE public.external_booking (
  id bigint PRIMARY KEY,
  v2_inventory_id bigint NOT NULL,
  archived_account_audit_id bigint NOT NULL,
  v2_shipment_leg_meta_id bigint NOT NULL REFERENCES v2_shipment_leg_meta(id),
  legacy_account_id bigint,
  currency bigint,
  kind integer NOT NULL,
  email integer,
  label inet NOT NULL,
  price varchar(255),
  UNIQUE (archived_account_audit_id)
);
/* trailing block comment */

CREATE TABLE v2_ticket_audit (
  id bigint PRIMARY KEY,
  legacy_payment_history_id bigint REFERENCES legacy_payment_history(id),
  channel_item_id bigint,
  v2_ticket_item_id bigint NOT NULL REFERENCES v2_ticket_item(id),
  archived_policy_id bigint NOT NULL REFERENCES archived_policy(id),
  v2_refund_audit_id bigint NOT NULL REFERENCES v2_refund_audit(id),
  notification_item_id bigint REFERENCES notification_item(id),
  quantity varchar(255),
  timezone date,
  version text NOT NULL,
  total text
);

CREATE TABLE staging_invoice_snapshot (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint REFERENCES v2_shipment_leg_meta(id),
  customer_snapshot_id bigint REFERENCES customer_snapshot(id),
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  created_at text,
  kind uuid NOT NULL,
  checksum text NOT NULL,
  created_at_4 jsonb,
  code date NOT NULL,
  name timestamp NOT NULL,
  amount bigint NOT NULL,
  total bytea,
  currency bytea NOT NULL
);

CREATE TABLE v2_document_line (
  id bigint PRIMARY KEY,
  v2_vendor_detail_id bigint REFERENCES v2_vendor_detail(id),
  staging_message_meta_id bigint,
  project_history_id bigint,
  v2_refund_id bigint REFERENCES v2_refund(id),
  external_session_link_id bigint NOT NULL REFERENCES external_session_link(id),
  label double precision,
  is_default timestamp,
  locale timestamp,
  is_default_4 boolean NOT NULL,
  label_5 numeric(12,2) NOT NULL,
  title date,
  is_locked text,
  label_8 date NOT NULL,
  phone timestamptz NOT NULL,
  UNIQUE (label)
);

CREATE TABLE staging_refund_line (
  id bigint PRIMARY KEY,
  v2_attachment_meta_id bigint NOT NULL REFERENCES v2_attachment_meta(id),
  archived_session_detail_id bigint NOT NULL REFERENCES archived_session_detail(id),
  v2_document_config_id bigint REFERENCES v2_document_config(id),
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  v2_template_id bigint REFERENCES v2_template(id),
  version bigint,
  code text,
  label text,
  weight date NOT NULL,
  amount timestamptz NOT NULL
);

-- discount_line: 8 columns
CREATE TABLE discount_line (
  id bigint PRIMARY KEY,
  v2_shipment_leg_meta_id bigint,
  amount timestamptz NOT NULL,
  quantity bigint,
  starts_at smallint,
  locale smallint,
  starts_at_5 double precision NOT NULL,
  position double precision NOT NULL
);

-- legacy_account_link: 9 columns
CREATE TABLE legacy_account_link (
  id bigint PRIMARY KEY,
  v2_refund_id bigint NOT NULL REFERENCES v2_refund(id),
  is_default timestamp,
  deleted_at timestamp,
  price smallint NOT NULL,
  body bytea,
  email numeric(12,2),
  body_6 timestamp,
  weight double precision NOT NULL
);

CREATE TABLE "public"."v2_channel_item" (
  id bigint PRIMARY KEY,
  external_audit_id bigint NOT NULL REFERENCES external_audit(id),
  v2_policy_item_id bigint NOT NULL REFERENCES v2_policy_item(id),
  quantity double precision,
  body varchar(255) NOT NULL,
  metadata timestamp NOT NULL,
  kind smallint NOT NULL,
  version timestamptz,
  note double precision,
  rate double precision,
  name inet,
  is_default timestamptz
);

CREATE TABLE archived_document_config (
  id bigint PRIMARY KEY,
  legacy_audit_id bigint NOT NULL REFERENCES legacy_audit(id),
  name timestamptz NOT NULL,
  price text,
  locale boolean,
  status double precision NOT NULL,
  external_ref numeric(12,2),
  locale_6 bigint,
  status_7 numeric(12,2),
  rate varchar(64)
);

-- staging_message_meta: 11 columns
CREATE TABLE staging_message_meta (
  id bigint PRIMARY KEY,
  customer_snapshot_id bigint NOT NULL REFERENCES customer_snapshot(id),
  staging_warehouse_snapshot_id bigint REFERENCES staging_warehouse_snapshot(id),
  payment_id bigint NOT NULL,
  v2_refund_snapshot_id bigint NOT NULL REFERENCES v2_refund_snapshot(id),
  is_default jsonb NOT NULL,
  is_active varchar(64),
  label timestamp,
  created_at numeric(12,2),
  locale bytea,
  weight smallint
);

-- v2_customer_detail: 12 columns
CREATE TABLE v2_customer_detail (
  id bigint PRIMARY KEY,
  v2_document_id bigint REFERENCES v2_document(id),
  email varchar(64) NOT NULL,
  currency boolean,
  starts_at inet,
  title jsonb,
  amount bytea,
  deleted_at double precision,
  updated_at char(2) NOT NULL,
  is_active char(2) NOT NULL,
  title_9 bigint,
  is_locked numeric(12,2) NOT NULL,
  UNIQUE (updated_at)
);

CREATE TABLE external_account_audit (
  id bigint PRIMARY KEY,
  staging_template_item_id bigint NOT NULL REFERENCES staging_template_item(id),
  v2_discount_config_id bigint NOT NULL,
  legacy_review_audit_id bigint,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_claim_detail_id bigint NOT NULL REFERENCES v2_claim_detail(id),
  is_active smallint NOT NULL,
  position text,
  phone uuid,
  updated_at smallint NOT NULL,
  rate bytea,
  position_6 inet NOT NULL
);

CREATE TABLE public.v2_refund_snapshot (
  id bigint PRIMARY KEY,
  title char(2),
  external_ref inet NOT NULL,
  email char(2),
  weight timestamptz NOT NULL,
  updated_at timestamp NOT NULL,
  rate bytea,
  version bytea,
  updated_at_8 text,
  weight_9 smallint
);

-- staging_account_link: 5 columns
CREATE TABLE staging_account_link (
  id bigint PRIMARY KEY,
  project_history_id bigint NOT NULL REFERENCES project_history(id),
  phone bigint,
  version numeric(12,2) NOT NULL,
  label double precision NOT NULL
);

ALTER TABLE ONLY public.legacy_template_link ADD CONSTRAINT legacy_template_link_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.subscription_link ADD CONSTRAINT subscription_link_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.subscription_line ADD CONSTRAINT subscription_line_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.route ADD CONSTRAINT route_staging_category_item_id_fkey FOREIGN KEY (staging_category_item_id) REFERENCES public.staging_category_item(id);
ALTER TABLE ONLY public.staging_review_link ADD CONSTRAINT staging_review_link_payment_detail_id_fkey FOREIGN KEY (payment_detail_id) REFERENCES public.payment_detail(id);
ALTER TABLE ONLY public.v2_refund_audit ADD CONSTRAINT v2_refund_audit_booking_detail_id_fkey FOREIGN KEY (booking_detail_id) REFERENCES public.booking_detail(id);
ALTER TABLE ONLY public.employee_audit ADD CONSTRAINT employee_audit_contract_detail_id_fkey FOREIGN KEY (contract_detail_id) REFERENCES public.contract_detail(id);
ALTER TABLE ONLY public.archived_session_history ADD CONSTRAINT archived_session_history_contract_item_id_fkey FOREIGN KEY (contract_item_id) REFERENCES public.contract_item(id);
ALTER TABLE ONLY public.staging_tag ADD CONSTRAINT staging_tag_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.legacy_contract_audit ADD CONSTRAINT legacy_contract_audit_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.external_session_line ADD CONSTRAINT external_session_line_external_vendor_line_id_fkey FOREIGN KEY (external_vendor_line_id) REFERENCES public.external_vendor_line(id);
ALTER TABLE ONLY public.v2_department_link ADD CONSTRAINT v2_department_link_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.legacy_discount_history ADD CONSTRAINT legacy_discount_history_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.staging_tag ADD CONSTRAINT staging_tag_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.legacy_session_item ADD CONSTRAINT legacy_session_item_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.employee_history ADD CONSTRAINT employee_history_subscription_line_id_fkey FOREIGN KEY (subscription_line_id) REFERENCES public.subscription_line(id);
ALTER TABLE ONLY public.v2_task_detail ADD CONSTRAINT v2_task_detail_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.invoice_link ADD CONSTRAINT invoice_link_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.legacy_carrier ADD CONSTRAINT legacy_carrier_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.archived_project_config ADD CONSTRAINT archived_project_config_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.message_config ADD CONSTRAINT message_config_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.staging_booking_snapshot ADD CONSTRAINT staging_booking_snapshot_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.v2_inventory ADD CONSTRAINT v2_inventory_template_history_id_fkey FOREIGN KEY (template_history_id) REFERENCES public.template_history(id);
ALTER TABLE ONLY public.warehouse ADD CONSTRAINT warehouse_legacy_order_item_id_fkey FOREIGN KEY (legacy_order_item_id) REFERENCES public.legacy_order_item(id);
ALTER TABLE ONLY public.v2_order_audit ADD CONSTRAINT v2_order_audit_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.staging_claim ADD CONSTRAINT staging_claim_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.external_refund_link ADD CONSTRAINT external_refund_link_customer_snapshot_id_fkey FOREIGN KEY (customer_snapshot_id) REFERENCES public.customer_snapshot(id);
ALTER TABLE ONLY public.v2_policy_line ADD CONSTRAINT v2_policy_line_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.legacy_shipment ADD CONSTRAINT legacy_shipment_v2_refund_audit_id_fkey FOREIGN KEY (v2_refund_audit_id) REFERENCES public.v2_refund_audit(id);
ALTER TABLE ONLY public.external_asset_meta ADD CONSTRAINT external_asset_meta_v2_product_item_id_fkey FOREIGN KEY (v2_product_item_id) REFERENCES public.v2_product_item(id);
ALTER TABLE ONLY public.external_booking_audit ADD CONSTRAINT external_booking_audit_customer_snapshot_id_fkey FOREIGN KEY (customer_snapshot_id) REFERENCES public.customer_snapshot(id);
ALTER TABLE ONLY public.employee_history ADD CONSTRAINT employee_history_v2_invoice_meta_id_fkey FOREIGN KEY (v2_invoice_meta_id) REFERENCES public.v2_invoice_meta(id);
ALTER TABLE ONLY public.legacy_route_audit ADD CONSTRAINT legacy_route_audit_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.v2_vendor ADD CONSTRAINT v2_vendor_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.v2_department_snapshot ADD CONSTRAINT v2_department_snapshot_v2_ticket_item_id_fkey FOREIGN KEY (v2_ticket_item_id) REFERENCES public.v2_ticket_item(id);
ALTER TABLE ONLY public.staging_customer ADD CONSTRAINT staging_customer_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.archived_inventory ADD CONSTRAINT archived_inventory_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.staging_asset_history ADD CONSTRAINT staging_asset_history_payment_audit_id_fkey FOREIGN KEY (payment_audit_id) REFERENCES public.payment_audit(id);
ALTER TABLE ONLY public.document_snapshot ADD CONSTRAINT document_snapshot_external_channel_item_id_fkey FOREIGN KEY (external_channel_item_id) REFERENCES public.external_channel_item(id);
ALTER TABLE ONLY public.legacy_discount_config ADD CONSTRAINT legacy_discount_config_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.policy_order ADD CONSTRAINT policy_order_external_task_config_id_fkey FOREIGN KEY (external_task_config_id) REFERENCES public.external_task_config(id);
ALTER TABLE ONLY public.legacy_inventory_history ADD CONSTRAINT legacy_inventory_history_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.account_payment ADD CONSTRAINT account_payment_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.v2_inventory_line ADD CONSTRAINT v2_inventory_line_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.account_payment ADD CONSTRAINT account_payment_staging_inventory_item_id_fkey FOREIGN KEY (staging_inventory_item_id) REFERENCES public.staging_inventory_item(id);
ALTER TABLE ONLY public.staging_message_meta ADD CONSTRAINT staging_message_meta_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payment(id);
ALTER TABLE ONLY public.external_booking ADD CONSTRAINT external_booking_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.ticket_history ADD CONSTRAINT ticket_history_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.invoice_link ADD CONSTRAINT invoice_link_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.archived_invoice_line ADD CONSTRAINT archived_invoice_line_staging_order_history_id_fkey FOREIGN KEY (staging_order_history_id) REFERENCES public.staging_order_history(id);
ALTER TABLE ONLY public.archived_customer_detail ADD CONSTRAINT archived_customer_detail_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.ticket_link ADD CONSTRAINT ticket_link_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.refund_config ADD CONSTRAINT refund_config_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.staging_ticket ADD CONSTRAINT staging_ticket_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.staging_payment_snapshot ADD CONSTRAINT staging_payment_snapshot_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.channel_history ADD CONSTRAINT channel_history_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.archived_template_audit ADD CONSTRAINT archived_template_audit_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.vehicle_detail ADD CONSTRAINT vehicle_detail_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.subscription_detail ADD CONSTRAINT subscription_detail_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.campaign_config ADD CONSTRAINT campaign_config_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.account_audit ADD CONSTRAINT account_audit_v2_shipment_leg_meta_id_fkey FOREIGN KEY (v2_shipment_leg_meta_id) REFERENCES public.v2_shipment_leg_meta(id);
ALTER TABLE ONLY public.legacy_booking_item ADD CONSTRAINT legacy_booking_item_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.refund_meta ADD CONSTRAINT refund_meta_external_warehouse_link_id_fkey FOREIGN KEY (external_warehouse_link_id) REFERENCES public.external_warehouse_link(id);
ALTER TABLE ONLY public.external_category ADD CONSTRAINT external_category_customer_snapshot_id_fkey FOREIGN KEY (customer_snapshot_id) REFERENCES public.customer_snapshot(id);
ALTER TABLE ONLY public.legacy_session_detail ADD CONSTRAINT legacy_session_detail_external_account_item_id_fkey FOREIGN KEY (external_account_item_id) REFERENCES public.external_account_item(id);
ALTER TABLE ONLY public.external_shipment_meta ADD CONSTRAINT external_shipment_meta_v2_refund_audit_id_fkey FOREIGN KEY (v2_refund_audit_id) REFERENCES public.v2_refund_audit(id);
ALTER TABLE ONLY public.legacy_claim_item ADD CONSTRAINT legacy_claim_item_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.archived_notification_snapshot ADD CONSTRAINT archived_notification_snapshot_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id);
ALTER TABLE ONLY public.legacy_session_config ADD CONSTRAINT legacy_session_config_v2_shipment_leg_meta_id_fkey FOREIGN KEY (v2_shipment_leg_meta_id) REFERENCES public.v2_shipment_leg_meta(id);
ALTER TABLE ONLY public.payment_link ADD CONSTRAINT payment_link_campaign_audit_id_fkey FOREIGN KEY (campaign_audit_id) REFERENCES public.campaign_audit(id);
ALTER TABLE ONLY public.tag_link ADD CONSTRAINT tag_link_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.claim_contract ADD CONSTRAINT claim_contract_staging_customer_audit_id_fkey FOREIGN KEY (staging_customer_audit_id) REFERENCES public.staging_customer_audit(id);
ALTER TABLE ONLY public.v2_shipment_link ADD CONSTRAINT v2_shipment_link_v2_discount_config_id_fkey FOREIGN KEY (v2_discount_config_id) REFERENCES public.v2_discount_config(id);
ALTER TABLE ONLY public.legacy_tag ADD CONSTRAINT legacy_tag_archived_review_link_id_fkey FOREIGN KEY (archived_review_link_id) REFERENCES public.archived_review_link(id);
ALTER TABLE ONLY public.discount_item ADD CONSTRAINT discount_item_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.archived_shipment_leg_item ADD CONSTRAINT archived_shipment_leg_item_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.legacy_contract_audit ADD CONSTRAINT legacy_contract_audit_vehicle_id_fkey FOREIGN KEY (vehicle_id) REFERENCES public.vehicle(id);
ALTER TABLE ONLY public.archived_notification_config ADD CONSTRAINT archived_notification_config_v2_account_history_id_fkey FOREIGN KEY (v2_account_history_id) REFERENCES public.v2_account_history(id);
ALTER TABLE ONLY public.staging_audit ADD CONSTRAINT staging_audit_legacy_vehicle_link_id_fkey FOREIGN KEY (legacy_vehicle_link_id) REFERENCES public.legacy_vehicle_link(id);
ALTER TABLE ONLY public.contract_item ADD CONSTRAINT contract_item_external_product_id_fkey FOREIGN KEY (external_product_id) REFERENCES public.external_product(id);
ALTER TABLE ONLY public.external_discount_audit ADD CONSTRAINT external_discount_audit_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.archived_booking_line ADD CONSTRAINT archived_booking_line_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.legacy_category ADD CONSTRAINT legacy_category_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.staging_shipment_config ADD CONSTRAINT staging_shipment_config_archived_booking_line_id_fkey FOREIGN KEY (archived_booking_line_id) REFERENCES public.archived_booking_line(id);
ALTER TABLE ONLY public.staging_payment ADD CONSTRAINT staging_payment_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.staging_session_detail ADD CONSTRAINT staging_session_detail_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.external_category_item ADD CONSTRAINT external_category_item_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.legacy_department_history ADD CONSTRAINT legacy_department_history_v2_vehicle_history_id_fkey FOREIGN KEY (v2_vehicle_history_id) REFERENCES public.v2_vehicle_history(id);
ALTER TABLE ONLY public.v2_subscription_config ADD CONSTRAINT v2_subscription_config_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.legacy_policy_line ADD CONSTRAINT legacy_policy_line_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.staging_subscription_detail ADD CONSTRAINT staging_subscription_detail_v2_order_snapshot_id_fkey FOREIGN KEY (v2_order_snapshot_id) REFERENCES public.v2_order_snapshot(id);
ALTER TABLE ONLY public.v2_route ADD CONSTRAINT v2_route_v2_vendor_meta_id_fkey FOREIGN KEY (v2_vendor_meta_id) REFERENCES public.v2_vendor_meta(id);
ALTER TABLE ONLY public.staging_task_link ADD CONSTRAINT staging_task_link_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.legacy_document_line ADD CONSTRAINT legacy_document_line_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.route ADD CONSTRAINT route_staging_booking_history_id_fkey FOREIGN KEY (staging_booking_history_id) REFERENCES public.staging_booking_history(id);
ALTER TABLE ONLY public.customer_snapshot ADD CONSTRAINT customer_snapshot_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.attachment_audit ADD CONSTRAINT attachment_audit_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.legacy_invoice_meta ADD CONSTRAINT legacy_invoice_meta_v2_customer_detail_id_fkey FOREIGN KEY (v2_customer_detail_id) REFERENCES public.v2_customer_detail(id);
ALTER TABLE ONLY public.route_meta ADD CONSTRAINT route_meta_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.legacy_department ADD CONSTRAINT legacy_department_archived_route_config_id_fkey FOREIGN KEY (archived_route_config_id) REFERENCES public.archived_route_config(id);
ALTER TABLE ONLY public.v2_ticket_config ADD CONSTRAINT v2_ticket_config_archived_asset_config_id_fkey FOREIGN KEY (archived_asset_config_id) REFERENCES public.archived_asset_config(id);
ALTER TABLE ONLY public.subscription_config ADD CONSTRAINT subscription_config_customer_snapshot_id_fkey FOREIGN KEY (customer_snapshot_id) REFERENCES public.customer_snapshot(id);
ALTER TABLE ONLY public.discount ADD CONSTRAINT discount_shipment_history_id_fkey FOREIGN KEY (shipment_history_id) REFERENCES public.shipment_history(id);
ALTER TABLE ONLY public.policy_audit ADD CONSTRAINT policy_audit_contract_item_id_fkey FOREIGN KEY (contract_item_id) REFERENCES public.contract_item(id);
ALTER TABLE ONLY public.carrier ADD CONSTRAINT carrier_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.staging_audit ADD CONSTRAINT staging_audit_v2_discount_config_id_fkey FOREIGN KEY (v2_discount_config_id) REFERENCES public.v2_discount_config(id);
ALTER TABLE ONLY public.legacy_asset_audit ADD CONSTRAINT legacy_asset_audit_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.carrier ADD CONSTRAINT carrier_inventory_audit_id_fkey FOREIGN KEY (inventory_audit_id) REFERENCES public.inventory_audit(id);
ALTER TABLE ONLY public.v2_task_audit ADD CONSTRAINT v2_task_audit_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.legacy_document_line ADD CONSTRAINT legacy_document_line_v2_discount_config_id_fkey FOREIGN KEY (v2_discount_config_id) REFERENCES public.v2_discount_config(id);
ALTER TABLE ONLY public.invoice_item ADD CONSTRAINT invoice_item_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.v2_document_detail ADD CONSTRAINT v2_document_detail_v2_shipment_leg_meta_id_fkey FOREIGN KEY (v2_shipment_leg_meta_id) REFERENCES public.v2_shipment_leg_meta(id);
ALTER TABLE ONLY public.external_product ADD CONSTRAINT external_product_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.v2_shipment_detail ADD CONSTRAINT v2_shipment_detail_v2_template_detail_id_fkey FOREIGN KEY (v2_template_detail_id) REFERENCES public.v2_template_detail(id);
ALTER TABLE ONLY public.inventory_message ADD CONSTRAINT inventory_message_v2_vendor_link_id_fkey FOREIGN KEY (v2_vendor_link_id) REFERENCES public.v2_vendor_link(id);
ALTER TABLE ONLY public.v2_vehicle ADD CONSTRAINT v2_vehicle_staging_message_snapshot_id_fkey FOREIGN KEY (staging_message_snapshot_id) REFERENCES public.staging_message_snapshot(id);
ALTER TABLE ONLY public.legacy_employee_snapshot ADD CONSTRAINT legacy_employee_snapshot_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.archived_route_item ADD CONSTRAINT archived_route_item_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.v2_vendor_line ADD CONSTRAINT v2_vendor_line_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.attachment ADD CONSTRAINT attachment_account_config_id_fkey FOREIGN KEY (account_config_id) REFERENCES public.account_config(id);
ALTER TABLE ONLY public.subscription_config ADD CONSTRAINT subscription_config_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.staging_channel_config ADD CONSTRAINT staging_channel_config_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.staging_inventory_detail ADD CONSTRAINT staging_inventory_detail_customer_snapshot_id_fkey FOREIGN KEY (customer_snapshot_id) REFERENCES public.customer_snapshot(id);
ALTER TABLE ONLY public.route_snapshot ADD CONSTRAINT route_snapshot_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.message(id);
ALTER TABLE ONLY public.external_refund_link ADD CONSTRAINT external_refund_link_v2_task_item_id_fkey FOREIGN KEY (v2_task_item_id) REFERENCES public.v2_task_item(id);
ALTER TABLE ONLY public.legacy_account_meta ADD CONSTRAINT legacy_account_meta_staging_category_id_fkey FOREIGN KEY (staging_category_id) REFERENCES public.staging_category(id);
ALTER TABLE ONLY public.archived_session_history ADD CONSTRAINT archived_session_history_legacy_invoice_meta_id_fkey FOREIGN KEY (legacy_invoice_meta_id) REFERENCES public.legacy_invoice_meta(id);
ALTER TABLE ONLY public.booking_config ADD CONSTRAINT booking_config_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.notification ADD CONSTRAINT notification_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.v2_document_line ADD CONSTRAINT v2_document_line_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.channel_config ADD CONSTRAINT channel_config_payment_detail_id_fkey FOREIGN KEY (payment_detail_id) REFERENCES public.payment_detail(id);
ALTER TABLE ONLY public.invoice_audit ADD CONSTRAINT invoice_audit_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.external_subscription ADD CONSTRAINT external_subscription_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.order_audit ADD CONSTRAINT order_audit_archived_shipment_leg_history_id_fkey FOREIGN KEY (archived_shipment_leg_history_id) REFERENCES public.archived_shipment_leg_history(id);
ALTER TABLE ONLY public.external_route_item ADD CONSTRAINT external_route_item_external_refund_audit_id_fkey FOREIGN KEY (external_refund_audit_id) REFERENCES public.external_refund_audit(id);
ALTER TABLE ONLY public.external_account_item ADD CONSTRAINT external_account_item_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.archived_attachment_config ADD CONSTRAINT archived_attachment_config_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.booking_history ADD CONSTRAINT booking_history_v2_ticket_line_id_fkey FOREIGN KEY (v2_ticket_line_id) REFERENCES public.v2_ticket_line(id);
ALTER TABLE ONLY public.staging_contract_history ADD CONSTRAINT staging_contract_history_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.project_line ADD CONSTRAINT project_line_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.external_attachment ADD CONSTRAINT external_attachment_legacy_channel_line_id_fkey FOREIGN KEY (legacy_channel_line_id) REFERENCES public.legacy_channel_line(id);
ALTER TABLE ONLY public.v2_claim_detail ADD CONSTRAINT v2_claim_detail_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.subscription_detail ADD CONSTRAINT subscription_detail_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.archived_tag ADD CONSTRAINT archived_tag_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.v2_document_line ADD CONSTRAINT v2_document_line_staging_message_meta_id_fkey FOREIGN KEY (staging_message_meta_id) REFERENCES public.staging_message_meta(id);
ALTER TABLE ONLY public.invoice_snapshot ADD CONSTRAINT invoice_snapshot_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.staging_session_meta ADD CONSTRAINT staging_session_meta_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.order_snapshot ADD CONSTRAINT order_snapshot_archived_inventory_line_id_fkey FOREIGN KEY (archived_inventory_line_id) REFERENCES public.archived_inventory_line(id);
ALTER TABLE ONLY public.archived_campaign_meta ADD CONSTRAINT archived_campaign_meta_product_snapshot_id_fkey FOREIGN KEY (product_snapshot_id) REFERENCES public.product_snapshot(id);
ALTER TABLE ONLY public.archived_customer ADD CONSTRAINT archived_customer_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.legacy_account_audit ADD CONSTRAINT legacy_account_audit_v2_channel_meta_id_fkey FOREIGN KEY (v2_channel_meta_id) REFERENCES public.v2_channel_meta(id);
ALTER TABLE ONLY public.inventory ADD CONSTRAINT inventory_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.discount_line ADD CONSTRAINT discount_line_v2_shipment_leg_meta_id_fkey FOREIGN KEY (v2_shipment_leg_meta_id) REFERENCES public.v2_shipment_leg_meta(id);
ALTER TABLE ONLY public.staging_task_config ADD CONSTRAINT staging_task_config_v2_shipment_leg_meta_id_fkey FOREIGN KEY (v2_shipment_leg_meta_id) REFERENCES public.v2_shipment_leg_meta(id);
ALTER TABLE ONLY public.legacy_department_history ADD CONSTRAINT legacy_department_history_vendor_invoice_id_fkey FOREIGN KEY (vendor_invoice_id) REFERENCES public.vendor_invoice(id);
ALTER TABLE ONLY public.archived_claim_meta ADD CONSTRAINT archived_claim_meta_archived_route_item_id_fkey FOREIGN KEY (archived_route_item_id) REFERENCES public.archived_route_item(id);
ALTER TABLE ONLY public.customer_audit ADD CONSTRAINT customer_audit_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.customer_detail ADD CONSTRAINT customer_detail_external_payment_id_fkey FOREIGN KEY (external_payment_id) REFERENCES public.external_payment(id);
ALTER TABLE ONLY public.archived_order_audit ADD CONSTRAINT archived_order_audit_v2_inventory_config_id_fkey FOREIGN KEY (v2_inventory_config_id) REFERENCES public.v2_inventory_config(id);
ALTER TABLE ONLY public.shipment_config ADD CONSTRAINT shipment_config_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.staging_shipment_leg_meta ADD CONSTRAINT staging_shipment_leg_meta_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.ticket_link ADD CONSTRAINT ticket_link_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.v2_vehicle_history ADD CONSTRAINT v2_vehicle_history_legacy_campaign_item_id_fkey FOREIGN KEY (legacy_campaign_item_id) REFERENCES public.legacy_campaign_item(id);
ALTER TABLE ONLY public.route ADD CONSTRAINT route_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.v2_shipment_leg ADD CONSTRAINT v2_shipment_leg_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.legacy_department ADD CONSTRAINT legacy_department_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.v2_vendor ADD CONSTRAINT v2_vendor_legacy_discount_snapshot_id_fkey FOREIGN KEY (legacy_discount_snapshot_id) REFERENCES public.legacy_discount_snapshot(id);
ALTER TABLE ONLY public.channel_link ADD CONSTRAINT channel_link_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.legacy_asset_history ADD CONSTRAINT legacy_asset_history_v2_refund_audit_id_fkey FOREIGN KEY (v2_refund_audit_id) REFERENCES public.v2_refund_audit(id);
ALTER TABLE ONLY public.legacy_subscription ADD CONSTRAINT legacy_subscription_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.archived_vehicle_snapshot ADD CONSTRAINT archived_vehicle_snapshot_v2_warehouse_link_id_fkey FOREIGN KEY (v2_warehouse_link_id) REFERENCES public.v2_warehouse_link(id);
ALTER TABLE ONLY public.discount_item ADD CONSTRAINT discount_item_v2_department_detail_id_fkey FOREIGN KEY (v2_department_detail_id) REFERENCES public.v2_department_detail(id);
ALTER TABLE ONLY public.message_link ADD CONSTRAINT message_link_staging_notification_config_id_fkey FOREIGN KEY (staging_notification_config_id) REFERENCES public.staging_notification_config(id);
ALTER TABLE ONLY public.archived_campaign_meta ADD CONSTRAINT archived_campaign_meta_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.v2_employee_detail ADD CONSTRAINT v2_employee_detail_employee_snapshot_id_fkey FOREIGN KEY (employee_snapshot_id) REFERENCES public.employee_snapshot(id);
ALTER TABLE ONLY public.archived_session_history ADD CONSTRAINT archived_session_history_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.archived_payment_meta ADD CONSTRAINT archived_payment_meta_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.ticket_audit ADD CONSTRAINT ticket_audit_v2_shipment_leg_detail_id_fkey FOREIGN KEY (v2_shipment_leg_detail_id) REFERENCES public.v2_shipment_leg_detail(id);
ALTER TABLE ONLY public.staging_review_line ADD CONSTRAINT staging_review_line_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.staging_ticket_config ADD CONSTRAINT staging_ticket_config_archived_booking_line_id_fkey FOREIGN KEY (archived_booking_line_id) REFERENCES public.archived_booking_line(id);
ALTER TABLE ONLY public.v2_asset_link ADD CONSTRAINT v2_asset_link_v2_task_item_id_fkey FOREIGN KEY (v2_task_item_id) REFERENCES public.v2_task_item(id);
ALTER TABLE ONLY public.archived_account ADD CONSTRAINT archived_account_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.carrier_config ADD CONSTRAINT carrier_config_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.staging_customer_link ADD CONSTRAINT staging_customer_link_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.legacy_ticket ADD CONSTRAINT legacy_ticket_staging_vehicle_item_id_fkey FOREIGN KEY (staging_vehicle_item_id) REFERENCES public.staging_vehicle_item(id);
ALTER TABLE ONLY public.legacy_channel_history ADD CONSTRAINT legacy_channel_history_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.archived_booking_audit ADD CONSTRAINT archived_booking_audit_route_meta_id_fkey FOREIGN KEY (route_meta_id) REFERENCES public.route_meta(id);
ALTER TABLE ONLY public.notification_config ADD CONSTRAINT notification_config_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.v2_booking_line ADD CONSTRAINT v2_booking_line_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.staging_notification_config ADD CONSTRAINT staging_notification_config_legacy_customer_link_id_fkey FOREIGN KEY (legacy_customer_link_id) REFERENCES public.legacy_customer_link(id);
ALTER TABLE ONLY public.legacy_vehicle_audit ADD CONSTRAINT legacy_vehicle_audit_carrier_audit_id_fkey FOREIGN KEY (carrier_audit_id) REFERENCES public.carrier_audit(id);
ALTER TABLE ONLY public.legacy_account_detail ADD CONSTRAINT legacy_account_detail_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.refund_item ADD CONSTRAINT refund_item_archived_order_snapshot_id_fkey FOREIGN KEY (archived_order_snapshot_id) REFERENCES public.archived_order_snapshot(id);
ALTER TABLE ONLY public.legacy_audit_meta ADD CONSTRAINT legacy_audit_meta_campaign_id_fkey FOREIGN KEY (campaign_id) REFERENCES public.campaign(id);
ALTER TABLE ONLY public.archived_session_line ADD CONSTRAINT archived_session_line_category_customer_id_fkey FOREIGN KEY (category_customer_id) REFERENCES public.category_customer(id);
ALTER TABLE ONLY public.campaign_detail ADD CONSTRAINT campaign_detail_staging_review_item_id_fkey FOREIGN KEY (staging_review_item_id) REFERENCES public.staging_review_item(id);
ALTER TABLE ONLY public.archived_payment ADD CONSTRAINT archived_payment_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.customer_audit ADD CONSTRAINT customer_audit_v2_refund_audit_id_fkey FOREIGN KEY (v2_refund_audit_id) REFERENCES public.v2_refund_audit(id);
ALTER TABLE ONLY public.archived_template_audit ADD CONSTRAINT archived_template_audit_notification_audit_id_fkey FOREIGN KEY (notification_audit_id) REFERENCES public.notification_audit(id);
ALTER TABLE ONLY public.archived_order_meta ADD CONSTRAINT archived_order_meta_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.staging_attachment_history ADD CONSTRAINT staging_attachment_history_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.external_employee ADD CONSTRAINT external_employee_employee_audit_id_fkey FOREIGN KEY (employee_audit_id) REFERENCES public.employee_audit(id);
ALTER TABLE ONLY public.attachment_audit ADD CONSTRAINT attachment_audit_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.external_task_detail ADD CONSTRAINT external_task_detail_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.staging_attachment_history ADD CONSTRAINT staging_attachment_history_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.v2_project ADD CONSTRAINT v2_project_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.legacy_customer ADD CONSTRAINT legacy_customer_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.archived_asset_config ADD CONSTRAINT archived_asset_config_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.staging_account_meta ADD CONSTRAINT staging_account_meta_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.v2_template_meta ADD CONSTRAINT v2_template_meta_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.legacy_employee ADD CONSTRAINT legacy_employee_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.booking_item ADD CONSTRAINT booking_item_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.archived_customer_detail ADD CONSTRAINT archived_customer_detail_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.staging_attachment_history ADD CONSTRAINT staging_attachment_history_staging_invoice_snapshot_id_fkey FOREIGN KEY (staging_invoice_snapshot_id) REFERENCES public.staging_invoice_snapshot(id);
ALTER TABLE ONLY public.archived_inventory_config ADD CONSTRAINT archived_inventory_config_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.v2_product_history ADD CONSTRAINT v2_product_history_staging_route_id_fkey FOREIGN KEY (staging_route_id) REFERENCES public.staging_route(id);
ALTER TABLE ONLY public.route_message ADD CONSTRAINT route_message_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.department_history ADD CONSTRAINT department_history_v2_document_id_fkey FOREIGN KEY (v2_document_id) REFERENCES public.v2_document(id);
ALTER TABLE ONLY public.external_customer ADD CONSTRAINT external_customer_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.external_account_audit ADD CONSTRAINT external_account_audit_legacy_review_audit_id_fkey FOREIGN KEY (legacy_review_audit_id) REFERENCES public.legacy_review_audit(id);
ALTER TABLE ONLY public.account ADD CONSTRAINT account_v2_account_detail_id_fkey FOREIGN KEY (v2_account_detail_id) REFERENCES public.v2_account_detail(id);
ALTER TABLE ONLY public.policy_item ADD CONSTRAINT policy_item_legacy_task_id_fkey FOREIGN KEY (legacy_task_id) REFERENCES public.legacy_task(id);
ALTER TABLE ONLY public.archived_project_meta ADD CONSTRAINT archived_project_meta_staging_session_config_id_fkey FOREIGN KEY (staging_session_config_id) REFERENCES public.staging_session_config(id);
ALTER TABLE ONLY public.staging_project_audit ADD CONSTRAINT staging_project_audit_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.archived_template_audit ADD CONSTRAINT archived_template_audit_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.legacy_vehicle_link ADD CONSTRAINT legacy_vehicle_link_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.asset_detail ADD CONSTRAINT asset_detail_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.vehicle_snapshot ADD CONSTRAINT vehicle_snapshot_campaign_line_id_fkey FOREIGN KEY (campaign_line_id) REFERENCES public.campaign_line(id);
ALTER TABLE ONLY public.booking_audit ADD CONSTRAINT booking_audit_v2_shipment_leg_meta_id_fkey FOREIGN KEY (v2_shipment_leg_meta_id) REFERENCES public.v2_shipment_leg_meta(id);
ALTER TABLE ONLY public.shipment_detail ADD CONSTRAINT shipment_detail_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.carrier_audit ADD CONSTRAINT carrier_audit_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.staging_template ADD CONSTRAINT staging_template_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.legacy_vehicle_item ADD CONSTRAINT legacy_vehicle_item_v2_refund_audit_id_fkey FOREIGN KEY (v2_refund_audit_id) REFERENCES public.v2_refund_audit(id);
ALTER TABLE ONLY public.v2_account_item ADD CONSTRAINT v2_account_item_attachment_discount_id_fkey FOREIGN KEY (attachment_discount_id) REFERENCES public.attachment_discount(id);
ALTER TABLE ONLY public.archived_invoice ADD CONSTRAINT archived_invoice_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.discount_snapshot ADD CONSTRAINT discount_snapshot_archived_session_id_fkey FOREIGN KEY (archived_session_id) REFERENCES public.archived_session(id);
ALTER TABLE ONLY public.external_department ADD CONSTRAINT external_department_v2_claim_detail_id_fkey FOREIGN KEY (v2_claim_detail_id) REFERENCES public.v2_claim_detail(id);
ALTER TABLE ONLY public.external_document ADD CONSTRAINT external_document_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.v2_task ADD CONSTRAINT v2_task_project_history_id_fkey FOREIGN KEY (project_history_id) REFERENCES public.project_history(id);
ALTER TABLE ONLY public.staging_document ADD CONSTRAINT staging_document_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.v2_claim_item ADD CONSTRAINT v2_claim_item_staging_channel_meta_id_fkey FOREIGN KEY (staging_channel_meta_id) REFERENCES public.staging_channel_meta(id);
ALTER TABLE ONLY public.external_payment ADD CONSTRAINT external_payment_v2_project_id_fkey FOREIGN KEY (v2_project_id) REFERENCES public.v2_project(id);
ALTER TABLE ONLY public.v2_carrier_detail ADD CONSTRAINT v2_carrier_detail_v2_discount_detail_id_fkey FOREIGN KEY (v2_discount_detail_id) REFERENCES public.v2_discount_detail(id);
ALTER TABLE ONLY public.staging_warehouse_audit ADD CONSTRAINT staging_warehouse_audit_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.external_discount_meta ADD CONSTRAINT external_discount_meta_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.project_invoice ADD CONSTRAINT project_invoice_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.refund_snapshot ADD CONSTRAINT refund_snapshot_v2_department_snapshot_id_fkey FOREIGN KEY (v2_department_snapshot_id) REFERENCES public.v2_department_snapshot(id);
ALTER TABLE ONLY public.payment_channel ADD CONSTRAINT payment_channel_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.inventory_line ADD CONSTRAINT inventory_line_archived_department_link_id_fkey FOREIGN KEY (archived_department_link_id) REFERENCES public.archived_department_link(id);
ALTER TABLE ONLY public.order_link ADD CONSTRAINT order_link_vendor_config_id_fkey FOREIGN KEY (vendor_config_id) REFERENCES public.vendor_config(id);
ALTER TABLE ONLY public.task_meta ADD CONSTRAINT task_meta_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.v2_claim_snapshot ADD CONSTRAINT v2_claim_snapshot_tag_link_id_fkey FOREIGN KEY (tag_link_id) REFERENCES public.tag_link(id);
ALTER TABLE ONLY public.attachment_item ADD CONSTRAINT attachment_item_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.v2_ticket_line ADD CONSTRAINT v2_ticket_line_message_meta_id_fkey FOREIGN KEY (message_meta_id) REFERENCES public.message_meta(id);
ALTER TABLE ONLY public.external_discount ADD CONSTRAINT external_discount_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.v2_route_history ADD CONSTRAINT v2_route_history_discount_id_fkey FOREIGN KEY (discount_id) REFERENCES public.discount(id);
ALTER TABLE ONLY public.customer_history ADD CONSTRAINT customer_history_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.subscription_history ADD CONSTRAINT subscription_history_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.external_session ADD CONSTRAINT external_session_external_vendor_line_id_fkey FOREIGN KEY (external_vendor_line_id) REFERENCES public.external_vendor_line(id);
ALTER TABLE ONLY public.external_shipment_detail ADD CONSTRAINT external_shipment_detail_staging_message_id_fkey FOREIGN KEY (staging_message_id) REFERENCES public.staging_message(id);
ALTER TABLE ONLY public.session_history ADD CONSTRAINT session_history_refund_snapshot_id_fkey FOREIGN KEY (refund_snapshot_id) REFERENCES public.refund_snapshot(id);
ALTER TABLE ONLY public.legacy_notification_link ADD CONSTRAINT legacy_notification_link_warehouse_audit_id_fkey FOREIGN KEY (warehouse_audit_id) REFERENCES public.warehouse_audit(id);
ALTER TABLE ONLY public.archived_department_config ADD CONSTRAINT archived_department_config_external_shipment_leg_history_id_fkey FOREIGN KEY (external_shipment_leg_history_id) REFERENCES public.external_shipment_leg_history(id);
ALTER TABLE ONLY public.tag_history ADD CONSTRAINT tag_history_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.archived_invoice_line ADD CONSTRAINT archived_invoice_line_external_refund_link_id_fkey FOREIGN KEY (external_refund_link_id) REFERENCES public.external_refund_link(id);
ALTER TABLE ONLY public.archived_product_line ADD CONSTRAINT archived_product_line_external_shipment_leg_line_id_fkey FOREIGN KEY (external_shipment_leg_line_id) REFERENCES public.external_shipment_leg_line(id);
ALTER TABLE ONLY public.subscription_config ADD CONSTRAINT subscription_config_archived_claim_history_id_fkey FOREIGN KEY (archived_claim_history_id) REFERENCES public.archived_claim_history(id);
ALTER TABLE ONLY public.external_attachment ADD CONSTRAINT external_attachment_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.staging_contract_audit ADD CONSTRAINT staging_contract_audit_external_message_detail_id_fkey FOREIGN KEY (external_message_detail_id) REFERENCES public.external_message_detail(id);
ALTER TABLE ONLY public.staging_vehicle_config ADD CONSTRAINT staging_vehicle_config_v2_discount_config_id_fkey FOREIGN KEY (v2_discount_config_id) REFERENCES public.v2_discount_config(id);
ALTER TABLE ONLY public.campaign_line ADD CONSTRAINT campaign_line_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.staging_contract_audit ADD CONSTRAINT staging_contract_audit_external_warehouse_id_fkey FOREIGN KEY (external_warehouse_id) REFERENCES public.external_warehouse(id);
ALTER TABLE ONLY public.message_item ADD CONSTRAINT message_item_external_discount_id_fkey FOREIGN KEY (external_discount_id) REFERENCES public.external_discount(id);
ALTER TABLE ONLY public.staging_attachment_line ADD CONSTRAINT staging_attachment_line_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.legacy_policy_line ADD CONSTRAINT legacy_policy_line_customer_snapshot_id_fkey FOREIGN KEY (customer_snapshot_id) REFERENCES public.customer_snapshot(id);
ALTER TABLE ONLY public.v2_refund_config ADD CONSTRAINT v2_refund_config_staging_warehouse_audit_id_fkey FOREIGN KEY (staging_warehouse_audit_id) REFERENCES public.staging_warehouse_audit(id);
ALTER TABLE ONLY public.v2_account_detail ADD CONSTRAINT v2_account_detail_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.external_contract ADD CONSTRAINT external_contract_v2_tag_link_id_fkey FOREIGN KEY (v2_tag_link_id) REFERENCES public.v2_tag_link(id);
ALTER TABLE ONLY public.discount_meta ADD CONSTRAINT discount_meta_session_detail_id_fkey FOREIGN KEY (session_detail_id) REFERENCES public.session_detail(id);
ALTER TABLE ONLY public.staging_session_item ADD CONSTRAINT staging_session_item_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.contract_snapshot ADD CONSTRAINT contract_snapshot_invoice_link_id_fkey FOREIGN KEY (invoice_link_id) REFERENCES public.invoice_link(id);
ALTER TABLE ONLY public.external_discount ADD CONSTRAINT external_discount_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.archived_account_history ADD CONSTRAINT archived_account_history_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.v2_booking_meta ADD CONSTRAINT v2_booking_meta_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.legacy_campaign_line ADD CONSTRAINT legacy_campaign_line_v2_customer_snapshot_id_fkey FOREIGN KEY (v2_customer_snapshot_id) REFERENCES public.v2_customer_snapshot(id);
ALTER TABLE ONLY public.account_payment ADD CONSTRAINT account_payment_project_line_id_fkey FOREIGN KEY (project_line_id) REFERENCES public.project_line(id);
ALTER TABLE ONLY public.notification_meta ADD CONSTRAINT notification_meta_archived_campaign_meta_id_fkey FOREIGN KEY (archived_campaign_meta_id) REFERENCES public.archived_campaign_meta(id);
ALTER TABLE ONLY public.shipment_snapshot ADD CONSTRAINT shipment_snapshot_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.staging_subscription_detail ADD CONSTRAINT staging_subscription_detail_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.staging_session_link ADD CONSTRAINT staging_session_link_archived_order_id_fkey FOREIGN KEY (archived_order_id) REFERENCES public.archived_order(id);
ALTER TABLE ONLY public.archived_order ADD CONSTRAINT archived_order_staging_vehicle_line_id_fkey FOREIGN KEY (staging_vehicle_line_id) REFERENCES public.staging_vehicle_line(id);
ALTER TABLE ONLY public.external_booking ADD CONSTRAINT external_booking_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.external_shipment ADD CONSTRAINT external_shipment_archived_product_id_fkey FOREIGN KEY (archived_product_id) REFERENCES public.archived_product(id);
ALTER TABLE ONLY public.archived_product_line ADD CONSTRAINT archived_product_line_v2_vendor_id_fkey FOREIGN KEY (v2_vendor_id) REFERENCES public.v2_vendor(id);
ALTER TABLE ONLY public.campaign_history ADD CONSTRAINT campaign_history_staging_department_history_id_fkey FOREIGN KEY (staging_department_history_id) REFERENCES public.staging_department_history(id);
ALTER TABLE ONLY public.v2_task_detail ADD CONSTRAINT v2_task_detail_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.document_history ADD CONSTRAINT document_history_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.v2_carrier_item ADD CONSTRAINT v2_carrier_item_legacy_invoice_config_id_fkey FOREIGN KEY (legacy_invoice_config_id) REFERENCES public.legacy_invoice_config(id);
ALTER TABLE ONLY public.archived_review_link ADD CONSTRAINT archived_review_link_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.external_tag ADD CONSTRAINT external_tag_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.v2_inventory_detail ADD CONSTRAINT v2_inventory_detail_v2_refund_id_fkey FOREIGN KEY (v2_refund_id) REFERENCES public.v2_refund(id);
ALTER TABLE ONLY public.archived_channel ADD CONSTRAINT archived_channel_v2_shipment_leg_meta_id_fkey FOREIGN KEY (v2_shipment_leg_meta_id) REFERENCES public.v2_shipment_leg_meta(id);
ALTER TABLE ONLY public.staging_category_config ADD CONSTRAINT staging_category_config_category_config_id_fkey FOREIGN KEY (category_config_id) REFERENCES public.category_config(id);
ALTER TABLE ONLY public.staging_tag_history ADD CONSTRAINT staging_tag_history_v2_session_item_id_fkey FOREIGN KEY (v2_session_item_id) REFERENCES public.v2_session_item(id);
ALTER TABLE ONLY public.v2_order_snapshot ADD CONSTRAINT v2_order_snapshot_legacy_review_audit_id_fkey FOREIGN KEY (legacy_review_audit_id) REFERENCES public.legacy_review_audit(id);
ALTER TABLE ONLY public.customer_line ADD CONSTRAINT customer_line_archived_document_audit_id_fkey FOREIGN KEY (archived_document_audit_id) REFERENCES public.archived_document_audit(id);
ALTER TABLE ONLY public.external_category_detail ADD CONSTRAINT external_category_detail_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.v2_vehicle_snapshot ADD CONSTRAINT v2_vehicle_snapshot_archived_policy_id_fkey FOREIGN KEY (archived_policy_id) REFERENCES public.archived_policy(id);
ALTER TABLE ONLY public.notification_history ADD CONSTRAINT notification_history_policy_history_id_fkey FOREIGN KEY (policy_history_id) REFERENCES public.policy_history(id);
ALTER TABLE ONLY public.v2_ticket_detail ADD CONSTRAINT v2_ticket_detail_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.category_link ADD CONSTRAINT category_link_v2_ticket_detail_id_fkey FOREIGN KEY (v2_ticket_detail_id) REFERENCES public.v2_ticket_detail(id);
ALTER TABLE ONLY public.archived_vehicle ADD CONSTRAINT archived_vehicle_booking_line_id_fkey FOREIGN KEY (booking_line_id) REFERENCES public.booking_line(id);
ALTER TABLE ONLY public.v2_document_item ADD CONSTRAINT v2_document_item_v2_tag_link_id_fkey FOREIGN KEY (v2_tag_link_id) REFERENCES public.v2_tag_link(id);
ALTER TABLE ONLY public.v2_vendor_item ADD CONSTRAINT v2_vendor_item_archived_template_audit_id_fkey FOREIGN KEY (archived_template_audit_id) REFERENCES public.archived_template_audit(id);
ALTER TABLE ONLY public.legacy_booking_config ADD CONSTRAINT legacy_booking_config_legacy_warehouse_item_id_fkey FOREIGN KEY (legacy_warehouse_item_id) REFERENCES public.legacy_warehouse_item(id);
ALTER TABLE ONLY public.v2_ticket_audit ADD CONSTRAINT v2_ticket_audit_channel_item_id_fkey FOREIGN KEY (channel_item_id) REFERENCES public.channel_item(id);
ALTER TABLE ONLY public.policy_audit ADD CONSTRAINT policy_audit_staging_session_meta_id_fkey FOREIGN KEY (staging_session_meta_id) REFERENCES public.staging_session_meta(id);
ALTER TABLE ONLY public.external_account_item ADD CONSTRAINT external_account_item_v2_booking_history_id_fkey FOREIGN KEY (v2_booking_history_id) REFERENCES public.v2_booking_history(id);
ALTER TABLE ONLY public.legacy_asset_line ADD CONSTRAINT legacy_asset_line_v2_refund_audit_id_fkey FOREIGN KEY (v2_refund_audit_id) REFERENCES public.v2_refund_audit(id);
ALTER TABLE ONLY public.v2_contract_meta ADD CONSTRAINT v2_contract_meta_invoice_config_id_fkey FOREIGN KEY (invoice_config_id) REFERENCES public.invoice_config(id);
ALTER TABLE ONLY public.archived_task ADD CONSTRAINT archived_task_external_category_id_fkey FOREIGN KEY (external_category_id) REFERENCES public.external_category(id);
ALTER TABLE ONLY public.task_item ADD CONSTRAINT task_item_discount_meta_id_fkey FOREIGN KEY (discount_meta_id) REFERENCES public.discount_meta(id);
ALTER TABLE ONLY public.legacy_notification_link ADD CONSTRAINT legacy_notification_link_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.archived_booking_line ADD CONSTRAINT archived_booking_line_external_employee_id_fkey FOREIGN KEY (external_employee_id) REFERENCES public.external_employee(id);
ALTER TABLE ONLY public.external_booking ADD CONSTRAINT external_booking_v2_inventory_id_fkey FOREIGN KEY (v2_inventory_id) REFERENCES public.v2_inventory(id);
ALTER TABLE ONLY public.external_account_audit ADD CONSTRAINT external_account_audit_v2_discount_config_id_fkey FOREIGN KEY (v2_discount_config_id) REFERENCES public.v2_discount_config(id);
ALTER TABLE ONLY public.v2_contract_config ADD CONSTRAINT v2_contract_config_archived_vendor_item_id_fkey FOREIGN KEY (archived_vendor_item_id) REFERENCES public.archived_vendor_item(id);
ALTER TABLE ONLY public.external_policy_config ADD CONSTRAINT external_policy_config_refund_audit_id_fkey FOREIGN KEY (refund_audit_id) REFERENCES public.refund_audit(id);
ALTER TABLE ONLY public.staging_invoice ADD CONSTRAINT staging_invoice_v2_shipment_leg_meta_id_fkey FOREIGN KEY (v2_shipment_leg_meta_id) REFERENCES public.v2_shipment_leg_meta(id);
ALTER TABLE ONLY public.legacy_subscription_detail ADD CONSTRAINT legacy_subscription_detail_archived_campaign_meta_id_fkey FOREIGN KEY (archived_campaign_meta_id) REFERENCES public.archived_campaign_meta(id);
ALTER TABLE ONLY public.v2_template_detail ADD CONSTRAINT v2_template_detail_v2_order_id_fkey FOREIGN KEY (v2_order_id) REFERENCES public.v2_order(id);
ALTER TABLE ONLY public.legacy_document ADD CONSTRAINT legacy_document_external_order_history_id_fkey FOREIGN KEY (external_order_history_id) REFERENCES public.external_order_history(id);
ALTER TABLE ONLY public.external_inventory ADD CONSTRAINT external_inventory_inventory_audit_id_fkey FOREIGN KEY (inventory_audit_id) REFERENCES public.inventory_audit(id);
ALTER TABLE ONLY public.notification ADD CONSTRAINT notification_staging_template_item_id_fkey FOREIGN KEY (staging_template_item_id) REFERENCES public.staging_template_item(id);
ALTER TABLE ONLY public.shipment_leg ADD CONSTRAINT shipment_leg_legacy_shipment_line_id_fkey FOREIGN KEY (legacy_shipment_line_id) REFERENCES public.legacy_shipment_line(id);
ALTER TABLE ONLY public.task ADD CONSTRAINT task_order_detail_id_fkey FOREIGN KEY (order_detail_id) REFERENCES public.order_detail(id);
ALTER TABLE ONLY public.attachment ADD CONSTRAINT attachment_product_audit_id_fkey FOREIGN KEY (product_audit_id) REFERENCES public.product_audit(id);
ALTER TABLE ONLY public.task_snapshot ADD CONSTRAINT task_snapshot_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.channel_history ADD CONSTRAINT channel_history_v2_shipment_detail_id_fkey FOREIGN KEY (v2_shipment_detail_id) REFERENCES public.v2_shipment_detail(id);
ALTER TABLE ONLY public.project_audit ADD CONSTRAINT project_audit_v2_refund_audit_id_fkey FOREIGN KEY (v2_refund_audit_id) REFERENCES public.v2_refund_audit(id);
ALTER TABLE ONLY public.v2_vendor ADD CONSTRAINT v2_vendor_staging_refund_line_id_fkey FOREIGN KEY (staging_refund_line_id) REFERENCES public.staging_refund_line(id);
ALTER TABLE ONLY public.staging_tag_history ADD CONSTRAINT staging_tag_history_v2_audit_item_id_fkey FOREIGN KEY (v2_audit_item_id) REFERENCES public.v2_audit_item(id);
ALTER TABLE ONLY public.v2_discount_config ADD CONSTRAINT v2_discount_config_archived_account_audit_id_fkey FOREIGN KEY (archived_account_audit_id) REFERENCES public.archived_account_audit(id);
ALTER TABLE ONLY public.archived_session_history ADD CONSTRAINT archived_session_history_external_asset_item_id_fkey FOREIGN KEY (external_asset_item_id) REFERENCES public.external_asset_item(id);
ALTER TABLE ONLY public.carrier_snapshot ADD CONSTRAINT carrier_snapshot_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.order_item(id);
ALTER TABLE ONLY public.legacy_route_meta ADD CONSTRAINT legacy_route_meta_staging_session_id_fkey FOREIGN KEY (staging_session_id) REFERENCES public.staging_session(id);
ALTER TABLE ONLY public.external_department ADD CONSTRAINT external_department_staging_shipment_leg_meta_id_fkey FOREIGN KEY (staging_shipment_leg_meta_id) REFERENCES public.staging_shipment_leg_meta(id);
ALTER TABLE ONLY public.v2_tag_link ADD CONSTRAINT v2_tag_link_subscription_meta_id_fkey FOREIGN KEY (subscription_meta_id) REFERENCES public.subscription_meta(id);
ALTER TABLE ONLY public.external_discount ADD CONSTRAINT external_discount_legacy_account_id_fkey FOREIGN KEY (legacy_account_id) REFERENCES public.legacy_account(id);
ALTER TABLE ONLY public.v2_route_link ADD CONSTRAINT v2_route_link_v2_refund_audit_id_fkey FOREIGN KEY (v2_refund_audit_id) REFERENCES public.v2_refund_audit(id);
ALTER TABLE ONLY public.staging_category_config ADD CONSTRAINT staging_category_config_staging_shipment_leg_config_id_fkey FOREIGN KEY (staging_shipment_leg_config_id) REFERENCES public.staging_shipment_leg_config(id);
ALTER TABLE ONLY public.external_order_link ADD CONSTRAINT external_order_link_archived_notification_config_id_fkey FOREIGN KEY (archived_notification_config_id) REFERENCES public.archived_notification_config(id);
