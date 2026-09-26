-- Generated fixture. Do not edit by hand; see fixtures/gen/gen.mjs.
-- Comments here are deliberate: the parser must blank them to
-- equal-length whitespace so byte offsets stay valid.

CREATE TABLE staging_task_snapshot (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  currency uuid NOT NULL,
  slug timestamptz
);
/* trailing block comment */

CREATE TABLE policy_item (
  id bigint PRIMARY KEY,
  inventory_link_id bigint REFERENCES inventory_link(id),
  status integer,
  expires_at inet,
  currency timestamptz NOT NULL
);

CREATE TABLE archived_document (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  is_default text,
  timezone numeric(12,2),
  amount jsonb NOT NULL,
  title jsonb,
  price char(2) NOT NULL,
  locale boolean NOT NULL
);

CREATE TABLE v2_warehouse (
  id bigint PRIMARY KEY,
  legacy_vehicle_audit_id bigint NOT NULL REFERENCES legacy_vehicle_audit(id),
  quantity timestamp,
  metadata timestamptz NOT NULL,
  label integer
);

-- v2_vehicle: 5 columns
CREATE TABLE v2_vehicle (
  id bigint PRIMARY KEY,
  name uuid,
  external_ref timestamptz,
  external_ref_3 double precision NOT NULL,
  position timestamptz
);

CREATE TABLE archived_order_meta (
  id bigint PRIMARY KEY,
  metadata date NOT NULL,
  rate smallint,
  email date,
  note smallint,
  deleted_at integer NOT NULL,
  updated_at smallint,
  email_7 date NOT NULL,
  weight timestamptz NOT NULL
);

CREATE TABLE invoice (
  id bigint PRIMARY KEY,
  v2_notification_line_id bigint NOT NULL REFERENCES v2_notification_line(id),
  v2_vehicle_id bigint NOT NULL,
  product_item_id bigint NOT NULL REFERENCES product_item(id),
  shipment_leg_history_id bigint REFERENCES shipment_leg_history(id),
  policy_item_id bigint REFERENCES policy_item(id),
  amount integer,
  label timestamp NOT NULL,
  UNIQUE (amount)
);

CREATE TABLE staging_order (
  id bigint PRIMARY KEY,
  v2_audit_audit_id bigint NOT NULL,
  timezone timestamptz
);

CREATE TABLE "public"."legacy_attachment_item" (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  timezone boolean,
  deleted_at timestamptz NOT NULL,
  amount smallint,
  metadata uuid,
  note varchar(64)
);

CREATE TABLE invoice_audit (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  title inet,
  code varchar(64),
  updated_at text NOT NULL,
  position inet,
  title_5 varchar(64) NOT NULL,
  title_6 varchar(255)
);
/* trailing block comment */

CREATE TABLE session (
  id bigint PRIMARY KEY,
  legacy_tag_id bigint NOT NULL REFERENCES legacy_tag(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  price smallint NOT NULL
);

CREATE TABLE v2_category_audit (
  id bigint PRIMARY KEY,
  body inet NOT NULL,
  total uuid NOT NULL
);

CREATE TABLE warehouse (
  id bigint PRIMARY KEY,
  updated_at jsonb NOT NULL,
  locale timestamp NOT NULL,
  position jsonb NOT NULL,
  status integer,
  is_default boolean,
  slug varchar(64) NOT NULL,
  version varchar(64) NOT NULL
);

CREATE TABLE v2_notification_config (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL,
  template_line_id bigint NOT NULL REFERENCES template_line(id),
  weight varchar(64) NOT NULL,
  starts_at numeric(12,2),
  is_locked bigint NOT NULL,
  weight_4 jsonb NOT NULL,
  checksum numeric(12,2),
  expires_at date,
  UNIQUE (weight_4)
);

CREATE TABLE "public"."external_project_config" (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  staging_document_audit_id bigint NOT NULL REFERENCES staging_document_audit(id),
  archived_document_id bigint REFERENCES archived_document(id),
  policy_item_id bigint NOT NULL,
  task_snapshot_id bigint,
  name uuid NOT NULL,
  phone double precision
);

-- account_line: 4 columns
CREATE TABLE account_line (
  id bigint PRIMARY KEY,
  customer_template_id bigint NOT NULL REFERENCES customer_template(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  locale double precision NOT NULL
);

CREATE TABLE staging_refund (
  id bigint PRIMARY KEY,
  email timestamptz NOT NULL
);

-- external_inventory_link: 13 columns
CREATE TABLE external_inventory_link (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  external_shipment_leg_line_id bigint NOT NULL,
  legacy_contract_snapshot_id bigint NOT NULL REFERENCES legacy_contract_snapshot(id),
  v2_campaign_item_id bigint REFERENCES v2_campaign_item(id),
  campaign_id bigint REFERENCES campaign(id),
  invoice_link_id bigint REFERENCES invoice_link(id),
  price varchar(64) NOT NULL,
  timezone char(2) NOT NULL,
  locale varchar(64) NOT NULL,
  external_ref char(2),
  timezone_5 smallint
);

CREATE TABLE staging_tag (
  id bigint PRIMARY KEY,
  is_locked varchar(255),
  locale timestamp,
  amount integer,
  email bigint,
  starts_at timestamp,
  label jsonb NOT NULL,
  is_active smallint NOT NULL,
  status timestamptz NOT NULL
);

CREATE TABLE staging_refund_history (
  id bigint PRIMARY KEY,
  staging_refund_line_id bigint NOT NULL REFERENCES staging_refund_line(id),
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  position integer,
  name integer,
  code bytea NOT NULL,
  UNIQUE (code)
);

CREATE TABLE public.vehicle_item (
  id bigint PRIMARY KEY,
  staging_refund_snapshot_id bigint NOT NULL REFERENCES staging_refund_snapshot(id),
  v2_warehouse_id bigint,
  note date,
  phone jsonb
);

CREATE TABLE task_snapshot (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL,
  staging_ticket_config_id bigint NOT NULL REFERENCES staging_ticket_config(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  starts_at timestamptz NOT NULL,
  starts_at_2 inet NOT NULL,
  code char(2)
);

CREATE TABLE external_discount_history (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  code date,
  created_at bytea NOT NULL
);

CREATE TABLE "shipment_link" (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  rate smallint,
  phone jsonb,
  starts_at timestamptz NOT NULL,
  amount bytea NOT NULL,
  is_default uuid,
  slug char(2),
  position uuid NOT NULL
);

CREATE TABLE archived_refund (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  staging_contract_history_id bigint REFERENCES staging_contract_history(id),
  legacy_project_history_id bigint NOT NULL REFERENCES legacy_project_history(id),
  policy_item_id bigint REFERENCES policy_item(id),
  discount_line_id bigint NOT NULL REFERENCES discount_line(id),
  expires_at bigint NOT NULL,
  is_active char(2) NOT NULL,
  deleted_at varchar(64),
  status varchar(255),
  kind smallint NOT NULL,
  version smallint NOT NULL,
  external_ref timestamptz NOT NULL,
  UNIQUE (expires_at)
);
/* trailing block comment */

CREATE TABLE archived_customer_config (
  id bigint PRIMARY KEY,
  v2_discount_item_id bigint NOT NULL REFERENCES v2_discount_item(id),
  staging_task_snapshot_id bigint NOT NULL,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  expires_at jsonb
);

CREATE TABLE v2_notification (
  id bigint PRIMARY KEY,
  external_attachment_id bigint REFERENCES external_attachment(id),
  staging_audit_detail_id bigint,
  starts_at bytea NOT NULL
);

CREATE TABLE session_line (
  id bigint PRIMARY KEY,
  invoice_id bigint REFERENCES invoice(id),
  external_asset_snapshot_id bigint NOT NULL REFERENCES external_asset_snapshot(id),
  code timestamptz NOT NULL,
  expires_at varchar(64) NOT NULL,
  weight boolean,
  weight_4 inet,
  position date,
  starts_at smallint,
  UNIQUE (weight_4)
);

CREATE TABLE "public"."v2_discount_item" (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  code boolean,
  rate date,
  amount timestamp NOT NULL,
  locale varchar(255) NOT NULL,
  position date NOT NULL,
  is_locked varchar(64),
  starts_at char(2)
);

-- legacy_customer_snapshot: 4 columns
CREATE TABLE legacy_customer_snapshot (
  id bigint PRIMARY KEY,
  invoice_id bigint REFERENCES invoice(id),
  price varchar(64),
  position timestamp
);

-- template_meta: 6 columns
CREATE TABLE template_meta (
  id bigint PRIMARY KEY,
  order_detail_id bigint NOT NULL REFERENCES order_detail(id),
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  code date,
  updated_at jsonb,
  UNIQUE (v2_vehicle_id)
);

CREATE TABLE external_ticket_meta (
  id bigint PRIMARY KEY,
  staging_vehicle_snapshot_id bigint NOT NULL REFERENCES staging_vehicle_snapshot(id),
  is_default timestamptz NOT NULL,
  note double precision NOT NULL,
  price uuid NOT NULL,
  external_ref jsonb,
  created_at integer NOT NULL
);

-- order_link: 6 columns
CREATE TABLE order_link (
  id bigint PRIMARY KEY,
  vendor_item_id bigint NOT NULL,
  v2_warehouse_id bigint,
  timezone inet NOT NULL,
  position bigint,
  is_locked numeric(12,2) NOT NULL,
  UNIQUE (is_locked)
);

CREATE TABLE "public"."inventory_line" (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  v2_ticket_item_id bigint NOT NULL REFERENCES v2_ticket_item(id),
  slug integer NOT NULL,
  title inet,
  note bigint NOT NULL,
  phone uuid,
  email boolean,
  email_6 jsonb NOT NULL,
  metadata integer,
  deleted_at varchar(64)
);

-- carrier_audit: 4 columns
CREATE TABLE carrier_audit (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  currency smallint,
  version jsonb
);

CREATE TABLE payment_audit (
  id bigint PRIMARY KEY,
  staging_inventory_audit_id bigint NOT NULL REFERENCES staging_inventory_audit(id),
  ticket_history_id bigint NOT NULL REFERENCES ticket_history(id),
  starts_at date,
  kind text NOT NULL,
  total smallint NOT NULL,
  kind_4 char(2) NOT NULL
);

CREATE TABLE legacy_project_history (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  archived_booking_snapshot_id bigint NOT NULL REFERENCES archived_booking_snapshot(id),
  v2_message_item_id bigint NOT NULL REFERENCES v2_message_item(id),
  is_default timestamptz,
  checksum integer,
  email double precision NOT NULL,
  created_at varchar(64),
  is_default_5 timestamp NOT NULL,
  UNIQUE (v2_message_item_id)
);

CREATE TABLE legacy_contract_snapshot (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  price timestamptz NOT NULL,
  code text,
  kind inet NOT NULL,
  body date NOT NULL,
  is_default smallint NOT NULL
);

-- legacy_vehicle_audit: 4 columns
CREATE TABLE legacy_vehicle_audit (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  is_locked jsonb,
  quantity boolean
);

-- vendor_item: 6 columns
CREATE TABLE vendor_item (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  v2_booking_line_id bigint NOT NULL REFERENCES v2_booking_line(id),
  v2_notification_audit_id bigint REFERENCES v2_notification_audit(id),
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  version text NOT NULL
);

CREATE TABLE v2_ticket (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  staging_task_snapshot_id bigint,
  subscription_audit_id bigint NOT NULL,
  amount varchar(64)
);

-- product_item: 10 columns
CREATE TABLE product_item (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  v2_account_link_id bigint NOT NULL REFERENCES v2_account_link(id),
  body text NOT NULL,
  note char(2) NOT NULL,
  title text NOT NULL,
  external_ref varchar(64),
  slug timestamptz,
  is_default numeric(12,2)
);

-- staging_ticket_history: 12 columns
CREATE TABLE public.staging_ticket_history (
  id bigint PRIMARY KEY,
  session_audit_id bigint REFERENCES session_audit(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  legacy_task_id bigint REFERENCES legacy_task(id),
  archived_document_id bigint REFERENCES archived_document(id),
  code numeric(12,2),
  is_default inet,
  locale text,
  quantity varchar(255) NOT NULL,
  status inet,
  label jsonb,
  title double precision,
  UNIQUE (label)
);

CREATE TABLE v2_refund_detail (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  policy_item_id bigint,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  v2_discount_detail_id bigint NOT NULL REFERENCES v2_discount_detail(id),
  version double precision
);

CREATE TABLE public.category_audit (
  id bigint PRIMARY KEY,
  legacy_tag_id bigint NOT NULL REFERENCES legacy_tag(id),
  booking_link_id bigint REFERENCES booking_link(id),
  session_snapshot_id bigint NOT NULL REFERENCES session_snapshot(id),
  external_document_history_id bigint REFERENCES external_document_history(id),
  v2_vehicle_id bigint,
  rate smallint NOT NULL,
  weight integer,
  deleted_at bigint,
  total smallint
);

CREATE TABLE external_task (
  id bigint PRIMARY KEY,
  body smallint NOT NULL
);

CREATE TABLE archived_ticket_line (
  id bigint PRIMARY KEY,
  name jsonb,
  email date NOT NULL,
  starts_at varchar(255),
  name_4 varchar(255),
  external_ref inet NOT NULL,
  starts_at_6 smallint NOT NULL
);

CREATE TABLE external_asset_snapshot (
  id bigint PRIMARY KEY,
  shipment_leg_link_id bigint NOT NULL REFERENCES shipment_leg_link(id),
  department_tag_id bigint REFERENCES department_tag(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  kind date NOT NULL,
  is_locked timestamptz,
  email inet,
  deleted_at text,
  position boolean,
  UNIQUE (department_tag_id)
);

CREATE TABLE v2_invoice (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  total varchar(255),
  phone inet,
  updated_at uuid NOT NULL,
  kind bigint NOT NULL
);

CREATE TABLE staging_audit_detail (
  id bigint PRIMARY KEY,
  staging_tag_meta_id bigint REFERENCES staging_tag_meta(id),
  policy_item_id bigint REFERENCES policy_item(id),
  ticket_config_id bigint REFERENCES ticket_config(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  updated_at char(2) NOT NULL,
  body bytea NOT NULL,
  rate varchar(255),
  weight bigint,
  weight_5 varchar(255) NOT NULL,
  position timestamp,
  phone varchar(64)
);

CREATE TABLE archived_booking_snapshot (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  staging_document_audit_id bigint NOT NULL,
  external_ref integer
);

CREATE TABLE "public"."staging_contract_history" (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  archived_document_id bigint REFERENCES archived_document(id),
  slug uuid,
  total char(2)
);

CREATE TABLE v2_contract_config (
  id bigint PRIMARY KEY,
  session_id bigint REFERENCES session(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  policy_item_id bigint REFERENCES policy_item(id),
  archived_ticket_audit_id bigint NOT NULL REFERENCES archived_ticket_audit(id),
  metadata timestamp,
  starts_at smallint,
  total integer,
  email bigint NOT NULL,
  metadata_5 smallint
);
/* trailing block comment */

-- shipment_meta: 10 columns
CREATE TABLE public.shipment_meta (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  price varchar(255),
  price_2 inet NOT NULL,
  total text,
  code char(2),
  created_at varchar(64),
  updated_at double precision,
  starts_at timestamp NOT NULL
);

-- inventory: 3 columns
CREATE TABLE inventory (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  weight uuid
);

CREATE TABLE task_audit (
  id bigint PRIMARY KEY,
  v2_route_line_id bigint REFERENCES v2_route_line(id),
  version date,
  external_ref double precision NOT NULL,
  note jsonb,
  is_default timestamptz,
  rate text,
  title inet NOT NULL,
  starts_at jsonb,
  locale timestamp NOT NULL,
  UNIQUE (external_ref)
);
/* trailing block comment */

CREATE TABLE archived_message (
  id bigint PRIMARY KEY,
  v2_review_item_id bigint NOT NULL REFERENCES v2_review_item(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  staging_refund_snapshot_id bigint NOT NULL REFERENCES staging_refund_snapshot(id),
  code date NOT NULL,
  code_2 double precision
);

CREATE TABLE staging_task_history (
  id bigint PRIMARY KEY,
  session_meta_id bigint NOT NULL REFERENCES session_meta(id),
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  weight smallint NOT NULL,
  starts_at smallint NOT NULL,
  code integer NOT NULL
);

-- legacy_vendor_item: 3 columns
CREATE TABLE legacy_vendor_item (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  is_locked bigint
);

CREATE TABLE "public"."staging_inventory_audit" (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  checksum integer NOT NULL,
  deleted_at timestamptz,
  body double precision,
  UNIQUE (archived_document_id)
);

CREATE TABLE v2_task (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  code timestamp NOT NULL,
  phone integer NOT NULL,
  UNIQUE (archived_order_meta_id)
);

CREATE TABLE "public"."customer_review" (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  updated_at bytea,
  total date NOT NULL,
  timezone bigint,
  position numeric(12,2),
  deleted_at smallint
);

CREATE TABLE category_history (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint,
  external_template_config_id bigint NOT NULL REFERENCES external_template_config(id),
  route_snapshot_id bigint NOT NULL REFERENCES route_snapshot(id),
  code smallint NOT NULL,
  title boolean,
  is_active text NOT NULL,
  label varchar(64),
  rate uuid
);

CREATE TABLE notification_audit (
  id bigint PRIMARY KEY,
  v2_vehicle_item_id bigint NOT NULL REFERENCES v2_vehicle_item(id),
  weight numeric(12,2) NOT NULL,
  expires_at text NOT NULL,
  version boolean,
  expires_at_4 inet,
  name char(2),
  deleted_at bytea,
  deleted_at_7 date NOT NULL
);
/* trailing block comment */

CREATE TABLE external_channel_meta (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  price inet,
  position inet NOT NULL,
  created_at text,
  position_4 varchar(255),
  amount numeric(12,2) NOT NULL,
  is_locked char(2),
  is_active jsonb
);

-- staging_attachment_audit: 6 columns
CREATE TABLE staging_attachment_audit (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  notification_meta_id bigint REFERENCES notification_meta(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  is_active jsonb,
  kind varchar(64),
  UNIQUE (is_active)
);

CREATE TABLE shipment (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  price jsonb,
  status boolean,
  total integer NOT NULL,
  is_locked char(2),
  quantity date NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_audit_audit (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL,
  is_locked double precision,
  locale jsonb NOT NULL,
  deleted_at bytea,
  kind double precision NOT NULL,
  weight varchar(255),
  UNIQUE (weight)
);

CREATE TABLE department_line (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  v2_task_id bigint NOT NULL REFERENCES v2_task(id),
  v2_notification_id bigint REFERENCES v2_notification(id),
  status jsonb
);

CREATE TABLE archived_policy (
  id bigint PRIMARY KEY,
  task_link_id bigint NOT NULL REFERENCES task_link(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  name bytea,
  is_active jsonb NOT NULL,
  note varchar(64) NOT NULL
);

CREATE TABLE "public"."external_inventory_audit" (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  employee_link_id bigint,
  archived_order_meta_id bigint,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  created_at smallint,
  rate bigint NOT NULL,
  status boolean NOT NULL,
  status_4 timestamptz,
  status_5 inet,
  deleted_at integer NOT NULL,
  amount double precision,
  UNIQUE (status_5)
);

CREATE TABLE external_audit_audit (
  id bigint PRIMARY KEY,
  v2_booking_line_id bigint REFERENCES v2_booking_line(id),
  total numeric(12,2),
  deleted_at double precision NOT NULL,
  is_default varchar(64),
  is_default_4 char(2),
  phone integer NOT NULL
);

CREATE TABLE asset_detail (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  archived_asset_id bigint NOT NULL REFERENCES archived_asset(id),
  email bigint,
  label inet,
  currency varchar(64),
  checksum timestamp,
  label_5 boolean NOT NULL
);

CREATE TABLE v2_claim_audit (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  archived_document_id bigint NOT NULL,
  created_at uuid,
  kind bytea,
  is_active char(2) NOT NULL,
  label varchar(64),
  slug timestamp NOT NULL,
  phone date
);

CREATE TABLE external_channel_item (
  id bigint PRIMARY KEY,
  staging_refund_line_id bigint,
  staging_task_snapshot_id bigint,
  name double precision,
  body bigint NOT NULL,
  UNIQUE (staging_task_snapshot_id)
);

-- v2_category_line: 10 columns
CREATE TABLE v2_category_line (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  is_active timestamptz,
  amount timestamptz,
  slug date NOT NULL,
  label varchar(255) NOT NULL,
  title boolean,
  slug_6 boolean NOT NULL,
  total inet NOT NULL
);

CREATE TABLE "public"."discount_line" (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  staging_task_snapshot_id bigint,
  title timestamp NOT NULL,
  note date,
  version numeric(12,2),
  status varchar(255),
  is_locked uuid NOT NULL,
  is_default char(2),
  checksum varchar(255) NOT NULL,
  UNIQUE (staging_task_snapshot_id)
);

CREATE TABLE staging_tag_meta (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  policy_item_id bigint,
  ticket_config_id bigint NOT NULL REFERENCES ticket_config(id),
  updated_at integer NOT NULL,
  checksum bytea NOT NULL,
  expires_at inet NOT NULL,
  weight timestamp,
  version bytea,
  status bigint
);

CREATE TABLE v2_customer_item (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  phone numeric(12,2) NOT NULL,
  body bytea NOT NULL,
  is_locked integer NOT NULL,
  weight integer NOT NULL,
  is_locked_5 boolean,
  code jsonb NOT NULL
);

-- legacy_inventory_meta: 10 columns
CREATE TABLE legacy_inventory_meta (
  id bigint PRIMARY KEY,
  external_ticket_meta_id bigint REFERENCES external_ticket_meta(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  archived_ticket_id bigint NOT NULL REFERENCES archived_ticket(id),
  staging_task_snapshot_id bigint,
  status timestamp NOT NULL,
  timezone date NOT NULL,
  external_ref varchar(64),
  position bigint NOT NULL,
  is_active bigint,
  UNIQUE (timezone)
);
/* trailing block comment */

-- external_claim_history: 9 columns
CREATE TABLE "public"."external_claim_history" (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  external_campaign_link_id bigint REFERENCES external_campaign_link(id),
  price text,
  label text NOT NULL,
  status jsonb NOT NULL,
  is_locked timestamptz,
  slug bytea,
  checksum inet
);

-- legacy_discount_link: 5 columns
CREATE TABLE "legacy_discount_link" (
  id bigint PRIMARY KEY,
  archived_document_id bigint,
  legacy_booking_link_id bigint REFERENCES legacy_booking_link(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  amount date
);

CREATE TABLE legacy_booking_link (
  id bigint PRIMARY KEY,
  customer_review_id bigint NOT NULL REFERENCES customer_review(id),
  legacy_shipment_leg_audit_id bigint NOT NULL,
  status timestamptz
);
/* trailing block comment */

-- payment: 7 columns
CREATE TABLE payment (
  id bigint PRIMARY KEY,
  external_discount_history_id bigint NOT NULL,
  phone smallint,
  expires_at smallint NOT NULL,
  total varchar(255),
  starts_at smallint,
  quantity varchar(64) NOT NULL
);

CREATE TABLE legacy_tag_snapshot (
  id bigint PRIMARY KEY,
  legacy_contract_snapshot_id bigint NOT NULL REFERENCES legacy_contract_snapshot(id),
  archived_document_id bigint NOT NULL,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  locale varchar(64) NOT NULL,
  external_ref integer,
  amount boolean NOT NULL,
  deleted_at uuid NOT NULL,
  timezone varchar(64),
  locale_6 uuid NOT NULL
);

CREATE TABLE order_item (
  id bigint PRIMARY KEY,
  legacy_audit_id bigint NOT NULL REFERENCES legacy_audit(id),
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  expires_at char(2),
  position varchar(255) NOT NULL,
  checksum boolean NOT NULL,
  code inet NOT NULL,
  currency text NOT NULL,
  amount jsonb
);

CREATE TABLE category_meta (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  department_line_id bigint REFERENCES department_line(id),
  category_id bigint NOT NULL,
  external_document_id bigint NOT NULL,
  starts_at numeric(12,2),
  is_default uuid NOT NULL,
  version timestamp NOT NULL
);

CREATE TABLE external_contract (
  id bigint PRIMARY KEY,
  v2_account_link_id bigint NOT NULL,
  external_ref numeric(12,2) NOT NULL,
  note jsonb NOT NULL,
  expires_at inet,
  created_at double precision,
  currency timestamp NOT NULL,
  position integer NOT NULL,
  updated_at double precision NOT NULL
);

CREATE TABLE document_item (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  position integer,
  phone integer NOT NULL,
  title text,
  locale double precision,
  metadata integer NOT NULL,
  UNIQUE (locale)
);

CREATE TABLE v2_policy_history (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  title double precision,
  name timestamp,
  note text NOT NULL
);

CREATE TABLE message_link (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  currency boolean,
  code text,
  slug bytea,
  position bigint NOT NULL,
  is_active double precision,
  kind varchar(64)
);

-- ticket_config: 3 columns
CREATE TABLE ticket_config (
  id bigint PRIMARY KEY,
  staging_tag_meta_id bigint NOT NULL,
  currency integer
);

CREATE TABLE archived_contract_meta (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  archived_ticket_id bigint,
  is_default text,
  kind varchar(64)
);

CREATE TABLE public.v2_attachment_line (
  id bigint PRIMARY KEY,
  customer_meta_id bigint REFERENCES customer_meta(id),
  updated_at smallint,
  position smallint NOT NULL,
  starts_at varchar(64),
  version varchar(255) NOT NULL
);

CREATE TABLE archived_asset (
  id bigint PRIMARY KEY,
  route_snapshot_id bigint NOT NULL REFERENCES route_snapshot(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_vehicle_id bigint NOT NULL,
  title inet,
  note inet,
  body varchar(255) NOT NULL,
  kind bigint NOT NULL,
  email smallint NOT NULL,
  version bytea,
  updated_at integer
);

-- archived_project_snapshot: 7 columns
CREATE TABLE archived_project_snapshot (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  locale date NOT NULL,
  is_active integer,
  label varchar(64),
  price smallint,
  note inet NOT NULL,
  UNIQUE (note)
);
/* trailing block comment */

CREATE TABLE legacy_shipment_leg (
  id bigint PRIMARY KEY,
  legacy_tag_snapshot_id bigint NOT NULL,
  v2_warehouse_id bigint,
  department_tag_id bigint,
  status bigint NOT NULL,
  position varchar(64) NOT NULL,
  phone uuid,
  is_active bytea NOT NULL,
  code text
);

-- staging_audit: 10 columns
CREATE TABLE staging_audit (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  v2_policy_history_id bigint,
  email inet NOT NULL,
  body jsonb,
  is_locked timestamp,
  phone integer NOT NULL,
  starts_at inet NOT NULL,
  kind uuid NOT NULL,
  code text NOT NULL
);

CREATE TABLE customer_meta (
  id bigint PRIMARY KEY,
  subscription_audit_id bigint REFERENCES subscription_audit(id),
  body varchar(64),
  is_locked date,
  rate jsonb,
  price uuid,
  price_5 jsonb
);

-- staging_ticket_config: 3 columns
CREATE TABLE staging_ticket_config (
  id bigint PRIMARY KEY,
  asset_detail_id bigint NOT NULL REFERENCES asset_detail(id),
  checksum varchar(64)
);

CREATE TABLE "public"."v2_order_config" (
  id bigint PRIMARY KEY,
  weight timestamp,
  phone varchar(64) NOT NULL,
  is_default timestamp NOT NULL,
  version uuid NOT NULL,
  email numeric(12,2),
  expires_at date NOT NULL,
  price varchar(255) NOT NULL
);

-- archived_campaign_snapshot: 8 columns
CREATE TABLE "public"."archived_campaign_snapshot" (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL,
  v2_customer_item_id bigint REFERENCES v2_customer_item(id),
  total inet,
  body uuid,
  locale text NOT NULL,
  version boolean,
  body_5 inet
);

CREATE TABLE session_audit (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  carrier_config_id bigint,
  legacy_invoice_detail_id bigint NOT NULL REFERENCES legacy_invoice_detail(id),
  starts_at double precision NOT NULL,
  created_at numeric(12,2),
  name integer,
  rate numeric(12,2) NOT NULL
);
/* trailing block comment */

CREATE TABLE archived_shipment (
  id bigint PRIMARY KEY,
  external_route_id bigint NOT NULL REFERENCES external_route(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  external_document_history_id bigint NOT NULL REFERENCES external_document_history(id),
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  v2_attachment_meta_id bigint NOT NULL,
  external_ref integer NOT NULL,
  quantity timestamp
);

CREATE TABLE "document_audit" (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL,
  external_ref varchar(64) NOT NULL
);

CREATE TABLE legacy_audit (
  id bigint PRIMARY KEY,
  expires_at date,
  name double precision NOT NULL,
  status varchar(255),
  note bytea NOT NULL
);

-- archived_contract: 6 columns
CREATE TABLE archived_contract (
  id bigint PRIMARY KEY,
  v2_route_item_id bigint NOT NULL REFERENCES v2_route_item(id),
  external_category_config_id bigint REFERENCES external_category_config(id),
  locale numeric(12,2),
  weight timestamptz,
  expires_at char(2) NOT NULL,
  UNIQUE (external_category_config_id)
);

-- archived_task_history: 4 columns
CREATE TABLE "public"."archived_task_history" (
  id bigint PRIMARY KEY,
  carrier_audit_id bigint NOT NULL REFERENCES carrier_audit(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  status timestamp
);

CREATE TABLE legacy_order_snapshot (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint,
  v2_inventory_snapshot_id bigint NOT NULL REFERENCES v2_inventory_snapshot(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  campaign_config_id bigint NOT NULL REFERENCES campaign_config(id),
  email double precision NOT NULL,
  starts_at integer NOT NULL,
  price integer
);

-- legacy_campaign_audit: 6 columns
CREATE TABLE legacy_campaign_audit (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL,
  version numeric(12,2) NOT NULL,
  quantity char(2),
  position bytea,
  is_default timestamp NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_invoice_snapshot (
  id bigint PRIMARY KEY,
  subscription_id bigint NOT NULL,
  external_ref timestamp,
  metadata date,
  starts_at timestamptz NOT NULL,
  note bytea,
  starts_at_5 boolean,
  quantity boolean NOT NULL
);

CREATE TABLE v2_attachment (
  id bigint PRIMARY KEY,
  rate timestamptz NOT NULL,
  label inet
);

CREATE TABLE staging_document_audit (
  id bigint PRIMARY KEY,
  legacy_vehicle_snapshot_id bigint REFERENCES legacy_vehicle_snapshot(id),
  archived_document_id bigint REFERENCES archived_document(id),
  staging_template_link_id bigint REFERENCES staging_template_link(id),
  staging_task_snapshot_id bigint,
  staging_contract_history_id bigint REFERENCES staging_contract_history(id),
  legacy_category_snapshot_id bigint NOT NULL REFERENCES legacy_category_snapshot(id),
  is_locked bigint,
  quantity double precision,
  email numeric(12,2),
  is_active varchar(255),
  UNIQUE (legacy_vehicle_snapshot_id)
);

CREATE TABLE legacy_route (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  amount timestamptz,
  checksum inet NOT NULL,
  total boolean
);

CREATE TABLE audit (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  legacy_vendor_item_id bigint,
  name numeric(12,2),
  is_default timestamptz,
  note inet NOT NULL,
  is_active timestamptz,
  currency timestamp NOT NULL,
  metadata text NOT NULL
);

CREATE TABLE "v2_review_item" (
  id bigint PRIMARY KEY,
  external_notification_history_id bigint NOT NULL REFERENCES external_notification_history(id),
  name text,
  title timestamptz,
  title_3 integer NOT NULL,
  external_ref bytea,
  label date,
  email timestamp,
  UNIQUE (email)
);

CREATE TABLE external_document (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  version timestamp,
  title date,
  quantity inet,
  code varchar(255),
  timezone double precision NOT NULL,
  weight char(2) NOT NULL,
  external_ref inet
);

CREATE TABLE legacy_task_history (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  metadata varchar(255)
);

-- notification_meta: 13 columns
CREATE TABLE notification_meta (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint,
  v2_notification_id bigint NOT NULL,
  v2_vehicle_id bigint NOT NULL,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  is_default boolean NOT NULL,
  price integer,
  expires_at date NOT NULL,
  body text,
  updated_at char(2),
  note bytea,
  label varchar(255),
  metadata timestamp
);

CREATE TABLE policy_history (
  id bigint PRIMARY KEY,
  campaign_detail_id bigint NOT NULL REFERENCES campaign_detail(id),
  staging_task_history_id bigint REFERENCES staging_task_history(id),
  v2_warehouse_id bigint NOT NULL,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  currency varchar(64) NOT NULL,
  position inet NOT NULL,
  metadata timestamp
);

CREATE TABLE "public"."staging_vehicle_snapshot" (
  id bigint PRIMARY KEY,
  starts_at smallint NOT NULL,
  version date,
  version_3 timestamptz,
  external_ref inet,
  currency varchar(64)
);

CREATE TABLE external_carrier_config (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL,
  external_channel_meta_id bigint NOT NULL REFERENCES external_channel_meta(id),
  updated_at date NOT NULL,
  currency varchar(255),
  kind varchar(64) NOT NULL
);

CREATE TABLE external_attachment (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  legacy_template_id bigint REFERENCES legacy_template(id),
  ticket_config_id bigint NOT NULL REFERENCES ticket_config(id),
  code char(2) NOT NULL,
  email inet,
  UNIQUE (email)
);

CREATE TABLE public.external_order_history (
  id bigint PRIMARY KEY,
  template_line_id bigint NOT NULL REFERENCES template_line(id),
  archived_tag_link_id bigint REFERENCES archived_tag_link(id),
  external_asset_meta_id bigint,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  total varchar(64),
  status bytea,
  version bigint NOT NULL,
  created_at varchar(64),
  timezone numeric(12,2),
  starts_at varchar(64),
  slug timestamptz NOT NULL,
  code char(2)
);

CREATE TABLE v2_message_item (
  id bigint PRIMARY KEY,
  external_inventory_link_id bigint NOT NULL REFERENCES external_inventory_link(id),
  legacy_booking_link_id bigint NOT NULL REFERENCES legacy_booking_link(id),
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  archived_document_id bigint REFERENCES archived_document(id),
  phone text,
  checksum integer,
  phone_3 integer,
  metadata date
);

CREATE TABLE legacy_review_meta (
  id bigint PRIMARY KEY,
  price timestamptz,
  note bytea NOT NULL,
  timezone boolean NOT NULL,
  quantity bytea NOT NULL,
  metadata varchar(255)
);

CREATE TABLE employee_link (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  archived_document_id bigint REFERENCES archived_document(id),
  updated_at text NOT NULL,
  label bigint NOT NULL,
  kind integer,
  position numeric(12,2)
);
/* trailing block comment */

CREATE TABLE campaign_meta (
  id bigint PRIMARY KEY,
  shipment_leg_link_id bigint,
  booking_audit_id bigint NOT NULL REFERENCES booking_audit(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  external_ref smallint,
  note smallint,
  starts_at timestamptz,
  status numeric(12,2) NOT NULL,
  code char(2),
  body bytea,
  status_7 char(2) NOT NULL,
  UNIQUE (booking_audit_id)
);

CREATE TABLE v2_carrier_line (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  is_default bytea NOT NULL,
  updated_at uuid NOT NULL,
  note numeric(12,2),
  UNIQUE (note)
);

CREATE TABLE v2_account_link (
  id bigint PRIMARY KEY,
  department_id bigint NOT NULL,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  legacy_channel_id bigint REFERENCES legacy_channel(id),
  price numeric(12,2),
  total boolean,
  email timestamp,
  status uuid NOT NULL,
  name uuid
);

CREATE TABLE vehicle_snapshot (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  name uuid NOT NULL,
  status char(2)
);

-- legacy_tag_meta: 7 columns
CREATE TABLE "public"."legacy_tag_meta" (
  id bigint PRIMARY KEY,
  department_tag_id bigint NOT NULL REFERENCES department_tag(id),
  archived_policy_meta_id bigint NOT NULL REFERENCES archived_policy_meta(id),
  timezone varchar(255) NOT NULL,
  slug smallint NOT NULL,
  updated_at double precision,
  quantity bigint
);
/* trailing block comment */

CREATE TABLE legacy_policy_config (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  name inet NOT NULL,
  name_2 jsonb,
  starts_at inet,
  is_active numeric(12,2) NOT NULL
);

CREATE TABLE staging_invoice_meta (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  session_line_id bigint REFERENCES session_line(id),
  invoice_history_id bigint REFERENCES invoice_history(id),
  checksum timestamptz
);

CREATE TABLE public.legacy_vehicle_snapshot (
  id bigint PRIMARY KEY,
  starts_at varchar(255) NOT NULL
);

CREATE TABLE staging_payment_config (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  archived_order_meta_id bigint,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  body date,
  price smallint,
  external_ref uuid,
  currency integer,
  is_default char(2) NOT NULL
);

CREATE TABLE "public"."v2_notification_audit" (
  id bigint PRIMARY KEY,
  external_shipment_leg_line_id bigint REFERENCES external_shipment_leg_line(id),
  version jsonb,
  external_ref char(2),
  status timestamptz,
  body inet NOT NULL
);

CREATE TABLE v2_discount_detail (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  v2_warehouse_id bigint,
  timezone varchar(64),
  is_active jsonb NOT NULL,
  total inet,
  kind timestamp
);

CREATE TABLE invoice_shipment (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  position date
);

-- external_account: 8 columns
CREATE TABLE external_account (
  id bigint PRIMARY KEY,
  order_link_id bigint REFERENCES order_link(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  note boolean,
  label jsonb,
  rate varchar(64) NOT NULL,
  label_4 jsonb,
  deleted_at date
);

-- channel_meta: 4 columns
CREATE TABLE public.channel_meta (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  v2_account_link_id bigint NOT NULL REFERENCES v2_account_link(id),
  email text NOT NULL
);

CREATE TABLE department_tag (
  id bigint PRIMARY KEY,
  email inet,
  weight varchar(255),
  currency timestamp
);

CREATE TABLE subscription_link (
  id bigint PRIMARY KEY,
  archived_booking_snapshot_id bigint NOT NULL REFERENCES archived_booking_snapshot(id),
  body text,
  is_locked timestamptz,
  currency timestamp NOT NULL
);

-- booking_meta: 10 columns
CREATE TABLE booking_meta (
  id bigint PRIMARY KEY,
  legacy_category_snapshot_id bigint NOT NULL REFERENCES legacy_category_snapshot(id),
  contract_meta_id bigint NOT NULL REFERENCES contract_meta(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  legacy_shipment_leg_detail_id bigint NOT NULL REFERENCES legacy_shipment_leg_detail(id),
  legacy_vendor_item_id bigint NOT NULL REFERENCES legacy_vendor_item(id),
  expires_at bigint NOT NULL,
  quantity timestamptz NOT NULL,
  weight jsonb,
  is_locked integer NOT NULL
);

CREATE TABLE staging_project_meta (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  v2_account_link_id bigint NOT NULL REFERENCES v2_account_link(id),
  locale timestamp
);

-- staging_subscription: 10 columns
CREATE TABLE "staging_subscription" (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  price bytea,
  starts_at text,
  expires_at text,
  currency uuid NOT NULL,
  quantity uuid NOT NULL,
  currency_6 varchar(255),
  title timestamptz NOT NULL,
  metadata char(2)
);

CREATE TABLE v2_inventory_config (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  version date,
  locale varchar(255) NOT NULL
);

CREATE TABLE legacy_vehicle_line (
  id bigint PRIMARY KEY,
  message_link_id bigint REFERENCES message_link(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  external_attachment_id bigint,
  v2_attachment_line_id bigint NOT NULL,
  amount bigint,
  total timestamp,
  email varchar(64),
  quantity varchar(64),
  UNIQUE (v2_attachment_line_id)
);

CREATE TABLE external_discount_link (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  code numeric(12,2) NOT NULL,
  timezone jsonb NOT NULL,
  deleted_at double precision NOT NULL,
  email timestamp NOT NULL,
  UNIQUE (email)
);

CREATE TABLE "public"."external_asset_config" (
  id bigint PRIMARY KEY,
  department_line_id bigint,
  archived_order_config_id bigint REFERENCES archived_order_config(id),
  is_default jsonb NOT NULL,
  UNIQUE (is_default)
);

-- vendor_config: 4 columns
CREATE TABLE vendor_config (
  id bigint PRIMARY KEY,
  v2_notification_audit_id bigint,
  title char(2) NOT NULL,
  version jsonb NOT NULL,
  UNIQUE (title)
);

CREATE TABLE external_account_meta (
  id bigint PRIMARY KEY,
  external_template_config_id bigint NOT NULL REFERENCES external_template_config(id),
  legacy_audit_id bigint NOT NULL REFERENCES legacy_audit(id),
  title varchar(64),
  amount varchar(255),
  locale bytea NOT NULL
);

-- external_campaign_config: 4 columns
CREATE TABLE external_campaign_config (
  id bigint PRIMARY KEY,
  category_id bigint NOT NULL REFERENCES category(id),
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  metadata timestamp
);

CREATE TABLE external_warehouse_audit (
  id bigint PRIMARY KEY,
  is_active char(2),
  version numeric(12,2),
  metadata bigint,
  checksum varchar(255)
);

CREATE TABLE warehouse_config (
  id bigint PRIMARY KEY,
  is_default timestamptz NOT NULL
);

CREATE TABLE asset_line (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  inventory_id bigint NOT NULL,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  amount text,
  is_active integer,
  price bytea,
  updated_at char(2)
);

-- route_snapshot: 6 columns
CREATE TABLE route_snapshot (
  id bigint PRIMARY KEY,
  label boolean,
  is_default timestamptz NOT NULL,
  version varchar(64) NOT NULL,
  kind varchar(64),
  body char(2),
  UNIQUE (is_default)
);

CREATE TABLE staging_discount_meta (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  v2_message_item_id bigint NOT NULL REFERENCES v2_message_item(id),
  version text NOT NULL,
  code jsonb,
  external_ref smallint,
  timezone bigint NOT NULL,
  rate date NOT NULL
);

CREATE TABLE legacy_booking_history (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  contract_meta_id bigint REFERENCES contract_meta(id),
  timezone timestamp,
  label varchar(64) NOT NULL,
  code integer,
  code_4 text NOT NULL
);

CREATE TABLE v2_booking_line (
  id bigint PRIMARY KEY,
  timezone char(2),
  weight uuid NOT NULL,
  email numeric(12,2),
  created_at date,
  amount double precision
);

CREATE TABLE notification_line (
  id bigint PRIMARY KEY,
  campaign_detail_id bigint REFERENCES campaign_detail(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  staging_task_snapshot_id bigint NOT NULL,
  timezone bigint NOT NULL,
  locale uuid,
  deleted_at double precision NOT NULL,
  label numeric(12,2),
  weight text NOT NULL,
  quantity jsonb
);

CREATE TABLE product_meta (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  v2_warehouse_id bigint NOT NULL,
  updated_at uuid
);

-- task_link: 8 columns
CREATE TABLE "public"."task_link" (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  total smallint NOT NULL,
  title integer NOT NULL,
  note date NOT NULL,
  email jsonb,
  is_default timestamp,
  timezone smallint,
  UNIQUE (note)
);

-- v2_ticket_item: 9 columns
CREATE TABLE v2_ticket_item (
  id bigint PRIMARY KEY,
  external_channel_meta_id bigint,
  department_tag_id bigint REFERENCES department_tag(id),
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  order_id bigint REFERENCES order(id),
  timezone uuid NOT NULL,
  weight timestamp NOT NULL,
  metadata boolean NOT NULL,
  title boolean
);

CREATE TABLE contract_meta (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL,
  rate numeric(12,2),
  UNIQUE (policy_item_id)
);

-- external_category_config: 9 columns
CREATE TABLE "public"."external_category_config" (
  id bigint PRIMARY KEY,
  external_payment_audit_id bigint NOT NULL REFERENCES external_payment_audit(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  is_locked timestamp,
  starts_at boolean,
  email integer NOT NULL,
  slug date NOT NULL,
  version varchar(64) NOT NULL
);
/* trailing block comment */

CREATE TABLE session_meta (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  timezone varchar(255),
  slug date,
  status varchar(64) NOT NULL
);

-- external_department_line: 4 columns
CREATE TABLE external_department_line (
  id bigint PRIMARY KEY,
  v2_booking_line_id bigint NOT NULL REFERENCES v2_booking_line(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  position text
);

CREATE TABLE external_route (
  id bigint PRIMARY KEY,
  legacy_attachment_id bigint REFERENCES legacy_attachment(id),
  starts_at timestamp NOT NULL,
  UNIQUE (starts_at)
);

-- archived_shipment_audit: 6 columns
CREATE TABLE archived_shipment_audit (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  tag_line_id bigint NOT NULL REFERENCES tag_line(id),
  version varchar(255) NOT NULL,
  is_default numeric(12,2),
  locale bigint NOT NULL
);

CREATE TABLE "public"."staging_carrier_audit" (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  external_attachment_id bigint REFERENCES external_attachment(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  is_locked double precision,
  UNIQUE (external_attachment_id)
);
/* trailing block comment */

CREATE TABLE staging_refund_snapshot (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  deleted_at double precision,
  phone text NOT NULL
);

-- refund_line: 6 columns
CREATE TABLE refund_line (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  archived_order_meta_id bigint NOT NULL,
  name date,
  amount bigint NOT NULL,
  metadata boolean
);

CREATE TABLE staging_task_item (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  kind smallint,
  total uuid,
  email bytea NOT NULL
);

CREATE TABLE session_snapshot (
  id bigint PRIMARY KEY,
  weight smallint,
  deleted_at jsonb NOT NULL,
  UNIQUE (weight)
);
/* trailing block comment */

CREATE TABLE vehicle_history (
  id bigint PRIMARY KEY,
  staging_shipment_item_id bigint REFERENCES staging_shipment_item(id),
  is_locked date,
  checksum jsonb NOT NULL,
  position bytea NOT NULL,
  label timestamp,
  locale char(2),
  phone varchar(255)
);

CREATE TABLE v2_route_line (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  status inet NOT NULL,
  timezone timestamptz NOT NULL,
  amount double precision NOT NULL,
  position timestamptz
);

CREATE TABLE project (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  archived_campaign_snapshot_id bigint NOT NULL REFERENCES archived_campaign_snapshot(id),
  status uuid,
  total integer NOT NULL,
  is_default jsonb NOT NULL,
  quantity jsonb NOT NULL
);

-- product_line: 11 columns
CREATE TABLE product_line (
  id bigint PRIMARY KEY,
  legacy_booking_history_id bigint REFERENCES legacy_booking_history(id),
  external_template_snapshot_id bigint REFERENCES external_template_snapshot(id),
  version varchar(255),
  slug boolean,
  price timestamp,
  weight bytea NOT NULL,
  price_5 timestamp,
  email char(2) NOT NULL,
  position jsonb,
  phone timestamp,
  UNIQUE (position)
);

-- staging_task_line: 5 columns
CREATE TABLE staging_task_line (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  timezone smallint
);

CREATE TABLE v2_task_line (
  id bigint PRIMARY KEY,
  document_audit_id bigint NOT NULL REFERENCES document_audit(id),
  staging_refund_id bigint REFERENCES staging_refund(id),
  position date,
  external_ref text NOT NULL,
  title timestamptz,
  created_at bytea,
  weight uuid,
  rate jsonb NOT NULL,
  is_default char(2) NOT NULL,
  external_ref_8 inet
);

CREATE TABLE route_item (
  id bigint PRIMARY KEY,
  v2_account_link_id bigint NOT NULL,
  archived_document_id bigint NOT NULL,
  is_default integer,
  slug uuid,
  expires_at timestamptz,
  email varchar(64) NOT NULL,
  starts_at date,
  title varchar(255) NOT NULL,
  UNIQUE (is_default)
);

CREATE TABLE archived_employee (
  id bigint PRIMARY KEY,
  archived_booking_snapshot_id bigint,
  v2_ticket_id bigint,
  external_warehouse_item_id bigint REFERENCES external_warehouse_item(id),
  price inet,
  title numeric(12,2) NOT NULL,
  updated_at jsonb
);

-- channel_audit: 14 columns
CREATE TABLE channel_audit (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  notification_line_id bigint,
  discount_config_id bigint REFERENCES discount_config(id),
  archived_shipment_audit_id bigint NOT NULL,
  v2_vehicle_id bigint NOT NULL,
  payment_id bigint NOT NULL REFERENCES payment(id),
  locale integer NOT NULL,
  updated_at date,
  title date,
  slug char(2) NOT NULL,
  updated_at_5 bigint,
  title_6 jsonb NOT NULL,
  phone text NOT NULL
);

CREATE TABLE staging_discount (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  weight timestamp NOT NULL,
  expires_at timestamptz NOT NULL,
  timezone inet,
  status uuid,
  note double precision,
  amount char(2) NOT NULL
);

CREATE TABLE shipment_leg_history (
  id bigint PRIMARY KEY,
  kind boolean,
  body inet
);

CREATE TABLE department (
  id bigint PRIMARY KEY,
  legacy_customer_snapshot_id bigint NOT NULL REFERENCES legacy_customer_snapshot(id),
  audit_id bigint NOT NULL REFERENCES audit(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  phone boolean,
  title timestamp,
  UNIQUE (title)
);

CREATE TABLE legacy_department (
  id bigint PRIMARY KEY,
  category_meta_id bigint NOT NULL REFERENCES category_meta(id),
  starts_at numeric(12,2),
  locale timestamp,
  external_ref uuid,
  note jsonb,
  rate char(2),
  metadata boolean NOT NULL
);

CREATE TABLE archived_ticket (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL,
  rate bigint,
  starts_at text NOT NULL,
  is_default date,
  label inet,
  slug numeric(12,2) NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_message_config (
  id bigint PRIMARY KEY,
  external_carrier_config_id bigint NOT NULL REFERENCES external_carrier_config(id),
  v2_notification_id bigint REFERENCES v2_notification(id),
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  policy_config_id bigint REFERENCES policy_config(id),
  slug jsonb NOT NULL
);

CREATE TABLE external_campaign_link (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  staging_task_snapshot_id bigint,
  v2_vehicle_id bigint,
  weight timestamp,
  expires_at inet NOT NULL
);

CREATE TABLE external_review (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  v2_order_config_id bigint NOT NULL REFERENCES v2_order_config(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  policy_item_id bigint NOT NULL,
  total boolean NOT NULL,
  currency text
);

-- shipment_leg_link: 6 columns
CREATE TABLE shipment_leg_link (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  price bytea,
  kind smallint,
  metadata numeric(12,2) NOT NULL,
  locale date,
  UNIQUE (metadata)
);

CREATE TABLE "public"."booking_link" (
  id bigint PRIMARY KEY,
  staging_discount_meta_id bigint NOT NULL REFERENCES staging_discount_meta(id),
  shipment_link_id bigint NOT NULL REFERENCES shipment_link(id),
  starts_at char(2)
);

CREATE TABLE category (
  id bigint PRIMARY KEY,
  v2_discount_item_id bigint,
  archived_order_meta_id bigint,
  rate bigint NOT NULL,
  phone double precision NOT NULL,
  total numeric(12,2) NOT NULL
);

CREATE TABLE shipment_item (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  policy_item_id bigint REFERENCES policy_item(id),
  note double precision,
  created_at boolean NOT NULL,
  created_at_3 integer NOT NULL
);

CREATE TABLE external_claim (
  id bigint PRIMARY KEY,
  code date,
  deleted_at inet,
  quantity timestamp NOT NULL,
  UNIQUE (quantity)
);

CREATE TABLE archived_order_config (
  id bigint PRIMARY KEY,
  task_link_id bigint NOT NULL REFERENCES task_link(id),
  policy_item_id bigint REFERENCES policy_item(id),
  code text,
  note bigint NOT NULL
);
/* trailing block comment */

CREATE TABLE external_shipment_leg_detail (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  legacy_project_item_id bigint REFERENCES legacy_project_item(id),
  external_asset_config_id bigint NOT NULL REFERENCES external_asset_config(id),
  note double precision NOT NULL,
  amount integer NOT NULL,
  is_active bytea NOT NULL
);

CREATE TABLE staging_vehicle_meta (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  contract_meta_id bigint REFERENCES contract_meta(id),
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  metadata inet NOT NULL,
  amount jsonb
);

CREATE TABLE discount_link (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL,
  v2_ticket_item_id bigint NOT NULL REFERENCES v2_ticket_item(id),
  session_audit_id bigint REFERENCES session_audit(id),
  policy_item_id bigint REFERENCES policy_item(id),
  external_channel_id bigint NOT NULL REFERENCES external_channel(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  body smallint,
  rate bytea
);

CREATE TABLE legacy_attachment (
  id bigint PRIMARY KEY,
  price char(2) NOT NULL,
  status timestamp,
  rate boolean,
  slug uuid
);

CREATE TABLE review (
  id bigint PRIMARY KEY,
  discount_line_id bigint REFERENCES discount_line(id),
  external_channel_item_id bigint REFERENCES external_channel_item(id),
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  position varchar(64),
  rate jsonb NOT NULL,
  code bigint,
  slug bigint,
  label double precision,
  body integer NOT NULL,
  price uuid
);

CREATE TABLE staging_vehicle_audit (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  archived_order_meta_id bigint,
  is_default varchar(64),
  total numeric(12,2),
  updated_at jsonb NOT NULL,
  title numeric(12,2),
  starts_at jsonb,
  name integer,
  note uuid,
  deleted_at text,
  UNIQUE (updated_at)
);

CREATE TABLE legacy_contract_history (
  id bigint PRIMARY KEY,
  v2_refund_detail_id bigint,
  v2_warehouse_id bigint,
  v2_message_config_id bigint,
  created_at bytea NOT NULL,
  email numeric(12,2),
  checksum date NOT NULL,
  body inet,
  label boolean,
  created_at_6 numeric(12,2) NOT NULL,
  title varchar(255) NOT NULL
);

CREATE TABLE external_category_history (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  rate varchar(255),
  UNIQUE (archived_document_id)
);

CREATE TABLE task_meta (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  discount_line_id bigint NOT NULL,
  expires_at date,
  amount text NOT NULL,
  slug inet,
  created_at date NOT NULL,
  note text NOT NULL,
  total bytea,
  name smallint
);

CREATE TABLE carrier_config (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  currency integer NOT NULL,
  UNIQUE (currency)
);

CREATE TABLE external_refund (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  version timestamptz,
  metadata smallint,
  status uuid,
  is_locked jsonb,
  price text,
  UNIQUE (is_locked)
);

CREATE TABLE public.archived_inventory_history (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  external_task_id bigint NOT NULL REFERENCES external_task(id),
  created_at jsonb,
  code inet,
  timezone date,
  phone integer NOT NULL,
  phone_5 varchar(255)
);

-- template_line: 9 columns
CREATE TABLE template_line (
  id bigint PRIMARY KEY,
  external_inventory_audit_id bigint NOT NULL REFERENCES external_inventory_audit(id),
  is_locked inet,
  total double precision,
  created_at uuid,
  label char(2) NOT NULL,
  external_ref text NOT NULL,
  body text,
  price double precision
);

CREATE TABLE order_detail (
  id bigint PRIMARY KEY,
  slug date,
  expires_at varchar(255),
  quantity uuid NOT NULL
);

CREATE TABLE v2_claim_history (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL,
  policy_item_id bigint NOT NULL,
  vehicle_history_id bigint NOT NULL REFERENCES vehicle_history(id),
  quantity char(2),
  updated_at varchar(255),
  UNIQUE (vehicle_history_id)
);

CREATE TABLE v2_vehicle_item (
  id bigint PRIMARY KEY,
  legacy_department_id bigint NOT NULL REFERENCES legacy_department(id),
  external_ref boolean,
  external_ref_2 uuid,
  quantity integer NOT NULL,
  rate bytea NOT NULL,
  code char(2),
  created_at char(2) NOT NULL
);

-- archived_template_meta: 8 columns
CREATE TABLE "archived_template_meta" (
  id bigint PRIMARY KEY,
  code bigint,
  position varchar(64),
  is_active date,
  starts_at date NOT NULL,
  currency timestamptz,
  slug jsonb NOT NULL,
  version timestamp
);

-- vehicle_config: 7 columns
CREATE TABLE vehicle_config (
  id bigint PRIMARY KEY,
  archived_ticket_line_id bigint REFERENCES archived_ticket_line(id),
  external_order_history_id bigint NOT NULL REFERENCES external_order_history(id),
  archived_document_id bigint,
  external_template_config_id bigint NOT NULL REFERENCES external_template_config(id),
  updated_at timestamp NOT NULL,
  locale integer,
  UNIQUE (archived_document_id)
);

CREATE TABLE legacy_project_item (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  policy_item_id bigint REFERENCES policy_item(id),
  phone bigint,
  status uuid,
  weight varchar(255) NOT NULL,
  metadata uuid
);

CREATE TABLE subscription_meta (
  id bigint PRIMARY KEY,
  archived_inventory_detail_id bigint NOT NULL REFERENCES archived_inventory_detail(id),
  code numeric(12,2) NOT NULL,
  note timestamptz NOT NULL,
  rate inet NOT NULL,
  amount char(2) NOT NULL
);

CREATE TABLE "staging_carrier_snapshot" (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  currency numeric(12,2),
  UNIQUE (archived_document_id)
);

CREATE TABLE staging_asset_line (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  deleted_at smallint,
  locale inet,
  body numeric(12,2),
  timezone boolean,
  timezone_5 varchar(255) NOT NULL,
  phone numeric(12,2) NOT NULL,
  position bigint NOT NULL
);

CREATE TABLE invoice_meta (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  v2_message_item_id bigint REFERENCES v2_message_item(id),
  label varchar(64),
  title double precision,
  expires_at text,
  UNIQUE (label)
);

CREATE TABLE customer_template (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  order_id bigint NOT NULL REFERENCES order(id),
  locale numeric(12,2) NOT NULL,
  total inet NOT NULL,
  slug uuid NOT NULL,
  price inet,
  checksum bytea,
  kind bigint NOT NULL
);

CREATE TABLE campaign (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  v2_vehicle_id bigint NOT NULL,
  checksum varchar(255) NOT NULL,
  version varchar(64) NOT NULL,
  created_at jsonb NOT NULL,
  expires_at jsonb,
  created_at_5 varchar(255),
  name integer,
  UNIQUE (checksum)
);

CREATE TABLE external_document_link (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  v2_vehicle_id bigint,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  archived_document_id bigint NOT NULL,
  rate uuid,
  weight numeric(12,2) NOT NULL,
  note smallint
);

CREATE TABLE archived_inventory_detail (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  status inet NOT NULL
);

CREATE TABLE "public"."invoice_link" (
  id bigint PRIMARY KEY,
  policy_item_id bigint REFERENCES policy_item(id),
  v2_warehouse_id bigint,
  body uuid NOT NULL,
  created_at text
);

CREATE TABLE external_asset_item (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  legacy_department_id bigint NOT NULL REFERENCES legacy_department(id),
  policy_item_id bigint REFERENCES policy_item(id),
  deleted_at char(2),
  currency inet,
  title timestamptz,
  checksum timestamptz NOT NULL,
  kind timestamp,
  is_locked timestamptz,
  rate varchar(255),
  price double precision NOT NULL
);

CREATE TABLE v2_inventory_snapshot (
  id bigint PRIMARY KEY,
  body double precision,
  is_default bytea NOT NULL
);

CREATE TABLE v2_booking_audit (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  v2_message_config_id bigint REFERENCES v2_message_config(id),
  label boolean,
  note varchar(64),
  code double precision,
  rate bytea,
  position numeric(12,2) NOT NULL,
  UNIQUE (v2_vehicle_id)
);

CREATE TABLE legacy_shipment_leg_detail (
  id bigint PRIMARY KEY,
  currency smallint
);

-- external_template_snapshot: 6 columns
CREATE TABLE external_template_snapshot (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  v2_route_item_id bigint REFERENCES v2_route_item(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  external_ref inet NOT NULL,
  phone inet NOT NULL
);

CREATE TABLE tag_line (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  weight varchar(255),
  phone timestamp NOT NULL,
  amount inet,
  email jsonb NOT NULL,
  UNIQUE (staging_task_snapshot_id)
);

CREATE TABLE archived_department_line (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  archived_document_id bigint NOT NULL,
  external_discount_history_id bigint REFERENCES external_discount_history(id),
  note varchar(255),
  code text,
  position timestamp,
  phone varchar(255),
  is_default char(2) NOT NULL,
  UNIQUE (note)
);

CREATE TABLE staging_policy (
  id bigint PRIMARY KEY,
  is_locked varchar(255) NOT NULL,
  rate smallint
);
/* trailing block comment */

CREATE TABLE "public"."external_warehouse_item" (
  id bigint PRIMARY KEY,
  created_at boolean,
  deleted_at numeric(12,2) NOT NULL,
  external_ref double precision,
  quantity inet NOT NULL,
  UNIQUE (quantity)
);

-- v2_campaign_item: 6 columns
CREATE TABLE v2_campaign_item (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  refund_line_id bigint NOT NULL REFERENCES refund_line(id),
  created_at bigint,
  deleted_at smallint NOT NULL,
  price numeric(12,2) NOT NULL
);
/* trailing block comment */

-- discount_config: 12 columns
CREATE TABLE discount_config (
  id bigint PRIMARY KEY,
  order_item_id bigint REFERENCES order_item(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  staging_task_snapshot_id bigint,
  policy_item_id bigint REFERENCES policy_item(id),
  is_default text,
  title timestamptz,
  price varchar(255),
  body integer,
  quantity boolean,
  note bytea
);
/* trailing block comment */

CREATE TABLE "public"."legacy_channel" (
  id bigint PRIMARY KEY,
  legacy_contract_history_id bigint NOT NULL REFERENCES legacy_contract_history(id),
  is_default integer,
  UNIQUE (legacy_contract_history_id)
);

CREATE TABLE legacy_asset_meta (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL,
  archived_carrier_id bigint REFERENCES archived_carrier(id),
  body date NOT NULL,
  currency uuid NOT NULL,
  status uuid,
  checksum integer NOT NULL
);

CREATE TABLE v2_attachment_meta (
  id bigint PRIMARY KEY,
  timezone double precision,
  is_default timestamptz,
  status boolean,
  slug integer,
  checksum timestamptz,
  code bigint,
  amount char(2) NOT NULL
);

CREATE TABLE "payment_snapshot" (
  id bigint PRIMARY KEY,
  quantity inet NOT NULL,
  checksum timestamptz
);

CREATE TABLE staging_channel_item (
  id bigint PRIMARY KEY,
  total varchar(64),
  name jsonb,
  metadata date NOT NULL,
  status integer,
  name_5 uuid,
  expires_at date,
  quantity uuid
);

CREATE TABLE legacy_invoice_detail (
  id bigint PRIMARY KEY,
  ticket_history_id bigint REFERENCES ticket_history(id),
  notification_line_id bigint NOT NULL,
  deleted_at double precision,
  status varchar(64) NOT NULL,
  metadata varchar(255),
  phone timestamp
);

-- booking_audit: 10 columns
CREATE TABLE booking_audit (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  policy_item_id bigint REFERENCES policy_item(id),
  v2_route_line_id bigint REFERENCES v2_route_line(id),
  v2_carrier_detail_id bigint,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  status integer NOT NULL,
  checksum numeric(12,2),
  is_active integer,
  body varchar(64)
);

CREATE TABLE archived_carrier (
  id bigint PRIMARY KEY,
  label char(2),
  name uuid,
  is_locked char(2) NOT NULL,
  amount inet
);

CREATE TABLE tag_message (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  session_line_id bigint NOT NULL REFERENCES session_line(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  kind uuid NOT NULL,
  external_ref integer,
  timezone double precision,
  price smallint,
  is_locked boolean NOT NULL,
  version char(2),
  phone varchar(64)
);

CREATE TABLE staging_shipment_item (
  id bigint PRIMARY KEY,
  body smallint,
  amount timestamptz
);
/* trailing block comment */

-- staging_template_link: 8 columns
CREATE TABLE staging_template_link (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  v2_message_item_id bigint NOT NULL REFERENCES v2_message_item(id),
  archived_document_id bigint REFERENCES archived_document(id),
  expires_at uuid,
  email double precision NOT NULL,
  title uuid NOT NULL,
  starts_at boolean,
  UNIQUE (archived_document_id)
);

CREATE TABLE legacy_category_snapshot (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  position text NOT NULL,
  locale text
);

CREATE TABLE staging_booking_item (
  id bigint PRIMARY KEY,
  title double precision NOT NULL
);

CREATE TABLE external_template_config (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  legacy_contract_snapshot_id bigint NOT NULL REFERENCES legacy_contract_snapshot(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  amount timestamptz,
  updated_at double precision,
  created_at varchar(255) NOT NULL
);

CREATE TABLE "archived_invoice_item" (
  id bigint PRIMARY KEY,
  metadata double precision NOT NULL
);
/* trailing block comment */

CREATE TABLE v2_carrier_detail (
  id bigint PRIMARY KEY,
  slug double precision
);

-- archived_carrier_detail: 3 columns
CREATE TABLE archived_carrier_detail (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  updated_at bytea
);

CREATE TABLE staging_refund_line (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  version timestamp,
  body numeric(12,2) NOT NULL,
  amount bigint,
  name double precision,
  created_at text,
  external_ref bytea,
  name_7 char(2)
);

-- employee: 3 columns
CREATE TABLE employee (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  deleted_at jsonb NOT NULL
);

CREATE TABLE account (
  id bigint PRIMARY KEY,
  external_asset_meta_id bigint NOT NULL REFERENCES external_asset_meta(id),
  campaign_meta_id bigint NOT NULL REFERENCES campaign_meta(id),
  code date NOT NULL,
  body numeric(12,2),
  updated_at timestamptz,
  is_default inet,
  updated_at_5 smallint NOT NULL
);

CREATE TABLE "public"."external_shipment_leg_line" (
  id bigint PRIMARY KEY,
  legacy_discount_link_id bigint NOT NULL REFERENCES legacy_discount_link(id),
  rate jsonb,
  starts_at double precision,
  is_default jsonb NOT NULL,
  expires_at boolean,
  name inet,
  metadata timestamptz
);

CREATE TABLE external_channel (
  id bigint PRIMARY KEY,
  vehicle_item_id bigint REFERENCES vehicle_item(id),
  starts_at inet
);

CREATE TABLE archived_tag_link (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL,
  external_channel_meta_id bigint NOT NULL REFERENCES external_channel_meta(id),
  is_active timestamptz NOT NULL,
  currency bigint NOT NULL,
  UNIQUE (is_active)
);

CREATE TABLE external_payment_audit (
  id bigint PRIMARY KEY,
  session_snapshot_id bigint REFERENCES session_snapshot(id),
  slug bigint,
  code smallint NOT NULL,
  kind integer,
  is_default varchar(255),
  quantity varchar(255),
  kind_6 varchar(255),
  deleted_at inet,
  UNIQUE (session_snapshot_id)
);

-- refund_config: 10 columns
CREATE TABLE refund_config (
  id bigint PRIMARY KEY,
  claim_config_id bigint NOT NULL,
  v2_vehicle_id bigint REFERENCES v2_vehicle(id),
  code uuid,
  name date NOT NULL,
  total jsonb,
  title boolean,
  price varchar(64),
  deleted_at bigint,
  quantity text
);

CREATE TABLE subscription_audit (
  id bigint PRIMARY KEY,
  position bigint NOT NULL,
  is_active char(2) NOT NULL,
  label integer,
  is_locked bytea NOT NULL
);

CREATE TABLE public.legacy_tag (
  id bigint PRIMARY KEY,
  kind double precision
);

CREATE TABLE staging_department (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  status text,
  quantity char(2),
  checksum double precision NOT NULL,
  is_default boolean,
  expires_at double precision,
  total double precision
);

CREATE TABLE public.archived_subscription (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  legacy_channel_id bigint,
  external_contract_id bigint REFERENCES external_contract(id),
  expires_at integer NOT NULL
);

CREATE TABLE campaign_config (
  id bigint PRIMARY KEY,
  body text,
  note bigint NOT NULL,
  is_default timestamptz NOT NULL
);

CREATE TABLE public.legacy_asset_item (
  id bigint PRIMARY KEY,
  archived_document_id bigint REFERENCES archived_document(id),
  staging_payment_config_id bigint REFERENCES staging_payment_config(id),
  external_warehouse_item_id bigint NOT NULL,
  kind uuid NOT NULL,
  quantity double precision,
  slug text NOT NULL,
  email bigint,
  weight bytea,
  kind_6 timestamptz NOT NULL
);

CREATE TABLE inventory_link (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  policy_item_id bigint REFERENCES policy_item(id),
  email varchar(64) NOT NULL,
  email_2 boolean NOT NULL,
  email_3 integer NOT NULL,
  locale jsonb NOT NULL,
  price jsonb,
  body boolean NOT NULL,
  slug numeric(12,2) NOT NULL,
  version jsonb NOT NULL
);
/* trailing block comment */

-- legacy_shipment_leg_audit: 8 columns
CREATE TABLE legacy_shipment_leg_audit (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  slug bytea NOT NULL,
  price boolean,
  starts_at uuid,
  starts_at_4 timestamptz,
  updated_at text NOT NULL,
  code date,
  UNIQUE (policy_item_id)
);

CREATE TABLE "public"."external_asset_meta" (
  id bigint PRIMARY KEY,
  document_audit_id bigint NOT NULL REFERENCES document_audit(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  legacy_vehicle_line_id bigint REFERENCES legacy_vehicle_line(id),
  discount_config_id bigint NOT NULL REFERENCES discount_config(id),
  email bytea,
  price char(2),
  total text,
  metadata smallint NOT NULL
);

CREATE TABLE claim_config (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  name boolean,
  note varchar(64),
  deleted_at bigint,
  email date NOT NULL,
  phone varchar(255),
  phone_6 smallint,
  phone_7 date,
  UNIQUE (archived_order_meta_id)
);

CREATE TABLE "public"."ticket_history" (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  external_ref varchar(255) NOT NULL,
  external_ref_2 timestamptz,
  weight date,
  updated_at varchar(64) NOT NULL,
  slug boolean
);
/* trailing block comment */

CREATE TABLE legacy_template (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  policy_item_id bigint REFERENCES policy_item(id),
  version timestamptz,
  external_ref boolean,
  phone text,
  updated_at bigint NOT NULL,
  code date,
  slug varchar(64)
);

-- external_booking_line: 10 columns
CREATE TABLE external_booking_line (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  archived_order_meta_id bigint,
  staging_attachment_audit_id bigint REFERENCES staging_attachment_audit(id),
  label varchar(64) NOT NULL,
  label_2 numeric(12,2),
  is_active uuid,
  locale inet,
  external_ref bytea,
  external_ref_6 uuid
);

CREATE TABLE refund (
  id bigint PRIMARY KEY,
  starts_at inet,
  slug double precision NOT NULL
);
/* trailing block comment */

CREATE TABLE "public"."archived_policy_meta" (
  id bigint PRIMARY KEY,
  shipment_leg_history_id bigint NOT NULL,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  checksum char(2) NOT NULL
);

-- v2_route_item: 8 columns
CREATE TABLE v2_route_item (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  created_at bigint,
  checksum bigint NOT NULL,
  checksum_3 bytea,
  weight inet,
  updated_at inet,
  UNIQUE (v2_warehouse_id)
);

-- employee_history: 10 columns
CREATE TABLE employee_history (
  id bigint PRIMARY KEY,
  v2_invoice_id bigint,
  code jsonb NOT NULL,
  amount uuid NOT NULL,
  is_active numeric(12,2) NOT NULL,
  is_locked date,
  position inet,
  name inet,
  label text NOT NULL,
  body timestamp
);

CREATE TABLE legacy_contract (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  refund_id bigint NOT NULL,
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  v2_category_line_id bigint NOT NULL,
  is_locked bytea NOT NULL
);

CREATE TABLE campaign_detail (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint,
  staging_template_link_id bigint REFERENCES staging_template_link(id),
  archived_carrier_id bigint,
  v2_task_line_id bigint REFERENCES v2_task_line(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  slug integer NOT NULL,
  updated_at varchar(64),
  email integer,
  metadata numeric(12,2) NOT NULL,
  UNIQUE (slug)
);

CREATE TABLE claim (
  id bigint PRIMARY KEY,
  booking_meta_id bigint NOT NULL REFERENCES booking_meta(id),
  staging_task_snapshot_id bigint NOT NULL,
  total jsonb,
  timezone double precision,
  status double precision,
  status_4 bytea NOT NULL,
  version integer
);

-- archived_ticket_audit: 9 columns
CREATE TABLE archived_ticket_audit (
  id bigint PRIMARY KEY,
  policy_item_id bigint NOT NULL,
  archived_order_meta_id bigint REFERENCES archived_order_meta(id),
  slug text,
  rate char(2),
  currency timestamptz,
  note timestamptz,
  body smallint NOT NULL,
  body_6 integer,
  UNIQUE (body_6)
);

CREATE TABLE archived_route_history (
  id bigint PRIMARY KEY,
  payment_id bigint,
  is_active inet,
  is_default text,
  status uuid,
  label numeric(12,2),
  metadata jsonb NOT NULL,
  status_6 smallint NOT NULL,
  UNIQUE (status_6)
);

-- external_review_detail: 7 columns
CREATE TABLE external_review_detail (
  id bigint PRIMARY KEY,
  v2_discount_item_id bigint NOT NULL REFERENCES v2_discount_item(id),
  archived_document_id bigint REFERENCES archived_document(id),
  external_asset_config_id bigint NOT NULL REFERENCES external_asset_config(id),
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  body double precision NOT NULL,
  label bytea NOT NULL
);

CREATE TABLE "v2_subscription" (
  id bigint PRIMARY KEY,
  amount inet NOT NULL,
  checksum boolean,
  price text,
  expires_at date
);

-- external_notification_history: 4 columns
CREATE TABLE external_notification_history (
  id bigint PRIMARY KEY,
  v2_category_line_id bigint REFERENCES v2_category_line(id),
  email smallint,
  kind boolean
);

CREATE TABLE legacy_carrier_snapshot (
  id bigint PRIMARY KEY,
  archived_order_meta_id bigint,
  starts_at bigint,
  total bigint,
  metadata varchar(255),
  position bytea NOT NULL,
  code date,
  status varchar(64)
);

CREATE TABLE policy_config (
  id bigint PRIMARY KEY,
  archived_document_id bigint,
  external_ref uuid,
  updated_at boolean NOT NULL,
  phone bigint NOT NULL,
  created_at smallint,
  is_locked timestamptz,
  locale jsonb
);

CREATE TABLE invoice_history (
  id bigint PRIMARY KEY,
  v2_vehicle_id bigint NOT NULL REFERENCES v2_vehicle(id),
  archived_document_id bigint REFERENCES archived_document(id),
  checksum smallint NOT NULL,
  kind char(2),
  label uuid NOT NULL,
  weight bigint,
  label_5 text
);

CREATE TABLE archived_category_meta (
  id bigint PRIMARY KEY,
  employee_id bigint NOT NULL REFERENCES employee(id),
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  is_default smallint NOT NULL,
  amount inet NOT NULL,
  price boolean NOT NULL,
  name integer
);

-- external_contract_meta: 11 columns
CREATE TABLE external_contract_meta (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL REFERENCES staging_task_snapshot(id),
  external_shipment_leg_line_id bigint REFERENCES external_shipment_leg_line(id),
  policy_item_id bigint REFERENCES policy_item(id),
  is_locked uuid,
  slug smallint,
  is_default double precision,
  amount text,
  slug_5 timestamp,
  title timestamp NOT NULL,
  starts_at jsonb NOT NULL
);

-- legacy_attachment_link: 7 columns
CREATE TABLE legacy_attachment_link (
  id bigint PRIMARY KEY,
  contract_meta_id bigint NOT NULL REFERENCES contract_meta(id),
  policy_item_id bigint NOT NULL REFERENCES policy_item(id),
  policy_config_id bigint NOT NULL REFERENCES policy_config(id),
  v2_vehicle_id bigint NOT NULL,
  external_ref bytea NOT NULL,
  code text
);
/* trailing block comment */

CREATE TABLE subscription (
  id bigint PRIMARY KEY,
  archived_subscription_id bigint NOT NULL REFERENCES archived_subscription(id),
  archived_document_id bigint REFERENCES archived_document(id),
  code uuid,
  slug numeric(12,2),
  price double precision,
  name inet,
  weight char(2),
  UNIQUE (weight)
);
/* trailing block comment */

-- message_audit: 5 columns
CREATE TABLE message_audit (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint NOT NULL,
  external_channel_item_id bigint NOT NULL REFERENCES external_channel_item(id),
  v2_warehouse_id bigint NOT NULL REFERENCES v2_warehouse(id),
  updated_at varchar(64)
);

-- external_booking_link: 6 columns
CREATE TABLE external_booking_link (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL,
  v2_task_id bigint NOT NULL REFERENCES v2_task(id),
  archived_order_meta_id bigint NOT NULL REFERENCES archived_order_meta(id),
  email text,
  total char(2)
);

CREATE TABLE order (
  id bigint PRIMARY KEY,
  v2_warehouse_id bigint REFERENCES v2_warehouse(id),
  timezone varchar(64) NOT NULL,
  metadata char(2) NOT NULL,
  updated_at inet,
  is_locked double precision NOT NULL,
  label jsonb,
  metadata_6 char(2),
  total timestamptz NOT NULL
);

CREATE TABLE "public"."legacy_task" (
  id bigint PRIMARY KEY,
  staging_task_snapshot_id bigint REFERENCES staging_task_snapshot(id),
  external_audit_audit_id bigint,
  legacy_contract_history_id bigint NOT NULL REFERENCES legacy_contract_history(id),
  price numeric(12,2),
  phone date NOT NULL
);

CREATE TABLE external_document_history (
  id bigint PRIMARY KEY,
  category_history_id bigint NOT NULL REFERENCES category_history(id),
  quantity char(2),
  kind numeric(12,2),
  starts_at boolean,
  name double precision,
  expires_at text,
  quantity_6 inet NOT NULL,
  UNIQUE (quantity)
);

-- v2_notification_line: 7 columns
CREATE TABLE v2_notification_line (
  id bigint PRIMARY KEY,
  archived_document_id bigint NOT NULL REFERENCES archived_document(id),
  external_ticket_meta_id bigint NOT NULL REFERENCES external_ticket_meta(id),
  external_asset_config_id bigint NOT NULL REFERENCES external_asset_config(id),
  archived_order_meta_id bigint,
  name boolean NOT NULL,
  metadata boolean NOT NULL
);

ALTER TABLE ONLY public.legacy_invoice_detail ADD CONSTRAINT legacy_invoice_detail_notification_line_id_fkey FOREIGN KEY (notification_line_id) REFERENCES public.notification_line(id);
ALTER TABLE ONLY public.external_document_link ADD CONSTRAINT external_document_link_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.legacy_shipment_leg ADD CONSTRAINT legacy_shipment_leg_department_tag_id_fkey FOREIGN KEY (department_tag_id) REFERENCES public.department_tag(id);
ALTER TABLE ONLY public.route_item ADD CONSTRAINT route_item_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.v2_claim_audit ADD CONSTRAINT v2_claim_audit_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.legacy_inventory_meta ADD CONSTRAINT legacy_inventory_meta_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.archived_ticket ADD CONSTRAINT archived_ticket_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.external_campaign_link ADD CONSTRAINT external_campaign_link_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.archived_contract_meta ADD CONSTRAINT archived_contract_meta_archived_ticket_id_fkey FOREIGN KEY (archived_ticket_id) REFERENCES public.archived_ticket(id);
ALTER TABLE ONLY public.external_review ADD CONSTRAINT external_review_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.legacy_shipment_leg ADD CONSTRAINT legacy_shipment_leg_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.v2_claim_history ADD CONSTRAINT v2_claim_history_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.legacy_carrier_snapshot ADD CONSTRAINT legacy_carrier_snapshot_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.archived_shipment ADD CONSTRAINT archived_shipment_v2_attachment_meta_id_fkey FOREIGN KEY (v2_attachment_meta_id) REFERENCES public.v2_attachment_meta(id);
ALTER TABLE ONLY public.external_project_config ADD CONSTRAINT external_project_config_task_snapshot_id_fkey FOREIGN KEY (task_snapshot_id) REFERENCES public.task_snapshot(id);
ALTER TABLE ONLY public.external_inventory_audit ADD CONSTRAINT external_inventory_audit_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.archived_subscription ADD CONSTRAINT archived_subscription_legacy_channel_id_fkey FOREIGN KEY (legacy_channel_id) REFERENCES public.legacy_channel(id);
ALTER TABLE ONLY public.discount_config ADD CONSTRAINT discount_config_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.legacy_contract_history ADD CONSTRAINT legacy_contract_history_v2_message_config_id_fkey FOREIGN KEY (v2_message_config_id) REFERENCES public.v2_message_config(id);
ALTER TABLE ONLY public.discount_line ADD CONSTRAINT discount_line_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.session_audit ADD CONSTRAINT session_audit_carrier_config_id_fkey FOREIGN KEY (carrier_config_id) REFERENCES public.carrier_config(id);
ALTER TABLE ONLY public.invoice_link ADD CONSTRAINT invoice_link_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.v2_discount_detail ADD CONSTRAINT v2_discount_detail_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.policy_history ADD CONSTRAINT policy_history_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.staging_payment_config ADD CONSTRAINT staging_payment_config_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.legacy_task ADD CONSTRAINT legacy_task_external_audit_audit_id_fkey FOREIGN KEY (external_audit_audit_id) REFERENCES public.external_audit_audit(id);
ALTER TABLE ONLY public.vehicle_config ADD CONSTRAINT vehicle_config_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.notification_line ADD CONSTRAINT notification_line_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.channel_audit ADD CONSTRAINT channel_audit_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.product_meta ADD CONSTRAINT product_meta_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.channel_audit ADD CONSTRAINT channel_audit_archived_shipment_audit_id_fkey FOREIGN KEY (archived_shipment_audit_id) REFERENCES public.archived_shipment_audit(id);
ALTER TABLE ONLY public.external_project_config ADD CONSTRAINT external_project_config_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.v2_ticket ADD CONSTRAINT v2_ticket_subscription_audit_id_fkey FOREIGN KEY (subscription_audit_id) REFERENCES public.subscription_audit(id);
ALTER TABLE ONLY public.legacy_contract_history ADD CONSTRAINT legacy_contract_history_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.external_booking_line ADD CONSTRAINT external_booking_line_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.staging_vehicle_audit ADD CONSTRAINT staging_vehicle_audit_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.v2_invoice_snapshot ADD CONSTRAINT v2_invoice_snapshot_subscription_id_fkey FOREIGN KEY (subscription_id) REFERENCES public.subscription(id);
ALTER TABLE ONLY public.refund_line ADD CONSTRAINT refund_line_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.external_channel_item ADD CONSTRAINT external_channel_item_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.legacy_shipment_leg ADD CONSTRAINT legacy_shipment_leg_legacy_tag_snapshot_id_fkey FOREIGN KEY (legacy_tag_snapshot_id) REFERENCES public.legacy_tag_snapshot(id);
ALTER TABLE ONLY public.staging_audit ADD CONSTRAINT staging_audit_v2_policy_history_id_fkey FOREIGN KEY (v2_policy_history_id) REFERENCES public.v2_policy_history(id);
ALTER TABLE ONLY public.vehicle_item ADD CONSTRAINT vehicle_item_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.archived_asset ADD CONSTRAINT archived_asset_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.route_item ADD CONSTRAINT route_item_v2_account_link_id_fkey FOREIGN KEY (v2_account_link_id) REFERENCES public.v2_account_link(id);
ALTER TABLE ONLY public.staging_tag_meta ADD CONSTRAINT staging_tag_meta_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.legacy_attachment_link ADD CONSTRAINT legacy_attachment_link_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.v2_audit_audit ADD CONSTRAINT v2_audit_audit_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.task_meta ADD CONSTRAINT task_meta_discount_line_id_fkey FOREIGN KEY (discount_line_id) REFERENCES public.discount_line(id);
ALTER TABLE ONLY public.category_audit ADD CONSTRAINT category_audit_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.order_link ADD CONSTRAINT order_link_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.claim ADD CONSTRAINT claim_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.staging_order ADD CONSTRAINT staging_order_v2_audit_audit_id_fkey FOREIGN KEY (v2_audit_audit_id) REFERENCES public.v2_audit_audit(id);
ALTER TABLE ONLY public.archived_department_line ADD CONSTRAINT archived_department_line_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.v2_ticket ADD CONSTRAINT v2_ticket_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.legacy_vehicle_line ADD CONSTRAINT legacy_vehicle_line_v2_attachment_line_id_fkey FOREIGN KEY (v2_attachment_line_id) REFERENCES public.v2_attachment_line(id);
ALTER TABLE ONLY public.audit ADD CONSTRAINT audit_legacy_vendor_item_id_fkey FOREIGN KEY (legacy_vendor_item_id) REFERENCES public.legacy_vendor_item(id);
ALTER TABLE ONLY public.channel_audit ADD CONSTRAINT channel_audit_notification_line_id_fkey FOREIGN KEY (notification_line_id) REFERENCES public.notification_line(id);
ALTER TABLE ONLY public.policy_config ADD CONSTRAINT policy_config_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.vendor_config ADD CONSTRAINT vendor_config_v2_notification_audit_id_fkey FOREIGN KEY (v2_notification_audit_id) REFERENCES public.v2_notification_audit(id);
ALTER TABLE ONLY public.archived_employee ADD CONSTRAINT archived_employee_v2_ticket_id_fkey FOREIGN KEY (v2_ticket_id) REFERENCES public.v2_ticket(id);
ALTER TABLE ONLY public.v2_category_line ADD CONSTRAINT v2_category_line_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.asset_line ADD CONSTRAINT asset_line_inventory_id_fkey FOREIGN KEY (inventory_id) REFERENCES public.inventory(id);
ALTER TABLE ONLY public.legacy_asset_item ADD CONSTRAINT legacy_asset_item_external_warehouse_item_id_fkey FOREIGN KEY (external_warehouse_item_id) REFERENCES public.external_warehouse_item(id);
ALTER TABLE ONLY public.category ADD CONSTRAINT category_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.v2_notification_line ADD CONSTRAINT v2_notification_line_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.booking_audit ADD CONSTRAINT booking_audit_v2_carrier_detail_id_fkey FOREIGN KEY (v2_carrier_detail_id) REFERENCES public.v2_carrier_detail(id);
ALTER TABLE ONLY public.external_inventory_link ADD CONSTRAINT external_inventory_link_external_shipment_leg_line_id_fkey FOREIGN KEY (external_shipment_leg_line_id) REFERENCES public.external_shipment_leg_line(id);
ALTER TABLE ONLY public.external_order_history ADD CONSTRAINT external_order_history_external_asset_meta_id_fkey FOREIGN KEY (external_asset_meta_id) REFERENCES public.external_asset_meta(id);
ALTER TABLE ONLY public.ticket_config ADD CONSTRAINT ticket_config_staging_tag_meta_id_fkey FOREIGN KEY (staging_tag_meta_id) REFERENCES public.staging_tag_meta(id);
ALTER TABLE ONLY public.legacy_vehicle_line ADD CONSTRAINT legacy_vehicle_line_external_attachment_id_fkey FOREIGN KEY (external_attachment_id) REFERENCES public.external_attachment(id);
ALTER TABLE ONLY public.v2_notification_config ADD CONSTRAINT v2_notification_config_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.category_meta ADD CONSTRAINT category_meta_external_document_id_fkey FOREIGN KEY (external_document_id) REFERENCES public.external_document(id);
ALTER TABLE ONLY public.staging_tag_meta ADD CONSTRAINT staging_tag_meta_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.message_audit ADD CONSTRAINT message_audit_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.payment ADD CONSTRAINT payment_external_discount_history_id_fkey FOREIGN KEY (external_discount_history_id) REFERENCES public.external_discount_history(id);
ALTER TABLE ONLY public.discount_line ADD CONSTRAINT discount_line_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.legacy_tag_snapshot ADD CONSTRAINT legacy_tag_snapshot_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.v2_notification ADD CONSTRAINT v2_notification_staging_audit_detail_id_fkey FOREIGN KEY (staging_audit_detail_id) REFERENCES public.staging_audit_detail(id);
ALTER TABLE ONLY public.staging_discount ADD CONSTRAINT staging_discount_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.external_contract ADD CONSTRAINT external_contract_v2_account_link_id_fkey FOREIGN KEY (v2_account_link_id) REFERENCES public.v2_account_link(id);
ALTER TABLE ONLY public.legacy_asset_meta ADD CONSTRAINT legacy_asset_meta_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.archived_customer_config ADD CONSTRAINT archived_customer_config_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.v2_ticket_item ADD CONSTRAINT v2_ticket_item_external_channel_meta_id_fkey FOREIGN KEY (external_channel_meta_id) REFERENCES public.external_channel_meta(id);
ALTER TABLE ONLY public.archived_employee ADD CONSTRAINT archived_employee_archived_booking_snapshot_id_fkey FOREIGN KEY (archived_booking_snapshot_id) REFERENCES public.archived_booking_snapshot(id);
ALTER TABLE ONLY public.invoice ADD CONSTRAINT invoice_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.staging_payment_config ADD CONSTRAINT staging_payment_config_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.notification_meta ADD CONSTRAINT notification_meta_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.campaign_detail ADD CONSTRAINT campaign_detail_archived_carrier_id_fkey FOREIGN KEY (archived_carrier_id) REFERENCES public.archived_carrier(id);
ALTER TABLE ONLY public.employee_history ADD CONSTRAINT employee_history_v2_invoice_id_fkey FOREIGN KEY (v2_invoice_id) REFERENCES public.v2_invoice(id);
ALTER TABLE ONLY public.staging_document_audit ADD CONSTRAINT staging_document_audit_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.archived_tag_link ADD CONSTRAINT archived_tag_link_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.legacy_contract_history ADD CONSTRAINT legacy_contract_history_v2_refund_detail_id_fkey FOREIGN KEY (v2_refund_detail_id) REFERENCES public.v2_refund_detail(id);
ALTER TABLE ONLY public.archived_booking_snapshot ADD CONSTRAINT archived_booking_snapshot_staging_document_audit_id_fkey FOREIGN KEY (staging_document_audit_id) REFERENCES public.staging_document_audit(id);
ALTER TABLE ONLY public.v2_refund_detail ADD CONSTRAINT v2_refund_detail_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.external_booking_link ADD CONSTRAINT external_booking_link_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.category_meta ADD CONSTRAINT category_meta_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.category(id);
ALTER TABLE ONLY public.legacy_booking_link ADD CONSTRAINT legacy_booking_link_legacy_shipment_leg_audit_id_fkey FOREIGN KEY (legacy_shipment_leg_audit_id) REFERENCES public.legacy_shipment_leg_audit(id);
ALTER TABLE ONLY public.external_document_link ADD CONSTRAINT external_document_link_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.external_campaign_link ADD CONSTRAINT external_campaign_link_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.legacy_campaign_audit ADD CONSTRAINT legacy_campaign_audit_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.legacy_contract ADD CONSTRAINT legacy_contract_v2_category_line_id_fkey FOREIGN KEY (v2_category_line_id) REFERENCES public.v2_category_line(id);
ALTER TABLE ONLY public.archived_campaign_snapshot ADD CONSTRAINT archived_campaign_snapshot_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.contract_meta ADD CONSTRAINT contract_meta_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.refund_config ADD CONSTRAINT refund_config_claim_config_id_fkey FOREIGN KEY (claim_config_id) REFERENCES public.claim_config(id);
ALTER TABLE ONLY public.order_link ADD CONSTRAINT order_link_vendor_item_id_fkey FOREIGN KEY (vendor_item_id) REFERENCES public.vendor_item(id);
ALTER TABLE ONLY public.invoice_meta ADD CONSTRAINT invoice_meta_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.campaign ADD CONSTRAINT campaign_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.task_snapshot ADD CONSTRAINT task_snapshot_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.v2_claim_history ADD CONSTRAINT v2_claim_history_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.legacy_discount_link ADD CONSTRAINT legacy_discount_link_archived_document_id_fkey FOREIGN KEY (archived_document_id) REFERENCES public.archived_document(id);
ALTER TABLE ONLY public.archived_route_history ADD CONSTRAINT archived_route_history_payment_id_fkey FOREIGN KEY (payment_id) REFERENCES public.payment(id);
ALTER TABLE ONLY public.legacy_contract ADD CONSTRAINT legacy_contract_refund_id_fkey FOREIGN KEY (refund_id) REFERENCES public.refund(id);
ALTER TABLE ONLY public.external_carrier_config ADD CONSTRAINT external_carrier_config_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.external_inventory_audit ADD CONSTRAINT external_inventory_audit_employee_link_id_fkey FOREIGN KEY (employee_link_id) REFERENCES public.employee_link(id);
ALTER TABLE ONLY public.archived_policy_meta ADD CONSTRAINT archived_policy_meta_shipment_leg_history_id_fkey FOREIGN KEY (shipment_leg_history_id) REFERENCES public.shipment_leg_history(id);
ALTER TABLE ONLY public.v2_account_link ADD CONSTRAINT v2_account_link_department_id_fkey FOREIGN KEY (department_id) REFERENCES public.department(id);
ALTER TABLE ONLY public.category_history ADD CONSTRAINT category_history_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.external_asset_config ADD CONSTRAINT external_asset_config_department_line_id_fkey FOREIGN KEY (department_line_id) REFERENCES public.department_line(id);
ALTER TABLE ONLY public.external_channel_item ADD CONSTRAINT external_channel_item_staging_refund_line_id_fkey FOREIGN KEY (staging_refund_line_id) REFERENCES public.staging_refund_line(id);
ALTER TABLE ONLY public.campaign_detail ADD CONSTRAINT campaign_detail_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.document_audit ADD CONSTRAINT document_audit_v2_warehouse_id_fkey FOREIGN KEY (v2_warehouse_id) REFERENCES public.v2_warehouse(id);
ALTER TABLE ONLY public.notification_meta ADD CONSTRAINT notification_meta_v2_notification_id_fkey FOREIGN KEY (v2_notification_id) REFERENCES public.v2_notification(id);
ALTER TABLE ONLY public.archived_ticket_audit ADD CONSTRAINT archived_ticket_audit_policy_item_id_fkey FOREIGN KEY (policy_item_id) REFERENCES public.policy_item(id);
ALTER TABLE ONLY public.campaign_meta ADD CONSTRAINT campaign_meta_shipment_leg_link_id_fkey FOREIGN KEY (shipment_leg_link_id) REFERENCES public.shipment_leg_link(id);
ALTER TABLE ONLY public.notification_meta ADD CONSTRAINT notification_meta_staging_task_snapshot_id_fkey FOREIGN KEY (staging_task_snapshot_id) REFERENCES public.staging_task_snapshot(id);
ALTER TABLE ONLY public.legacy_order_snapshot ADD CONSTRAINT legacy_order_snapshot_archived_order_meta_id_fkey FOREIGN KEY (archived_order_meta_id) REFERENCES public.archived_order_meta(id);
ALTER TABLE ONLY public.discount_link ADD CONSTRAINT discount_link_v2_vehicle_id_fkey FOREIGN KEY (v2_vehicle_id) REFERENCES public.v2_vehicle(id);
ALTER TABLE ONLY public.category ADD CONSTRAINT category_v2_discount_item_id_fkey FOREIGN KEY (v2_discount_item_id) REFERENCES public.v2_discount_item(id);
