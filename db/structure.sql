SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: btree_gist; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;


--
-- Name: EXTENSION btree_gist; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gist IS 'support for indexing common datatypes in GiST';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: availability_windows; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.availability_windows (
    id bigint NOT NULL,
    shared_resource_id bigint NOT NULL,
    weekday integer NOT NULL,
    starts_minute integer NOT NULL,
    ends_minute integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT availability_windows_end_range CHECK (((ends_minute >= 1) AND (ends_minute <= 1440))),
    CONSTRAINT availability_windows_positive_duration CHECK ((starts_minute < ends_minute)),
    CONSTRAINT availability_windows_start_range CHECK (((starts_minute >= 0) AND (starts_minute <= 1439))),
    CONSTRAINT availability_windows_weekday_range CHECK (((weekday >= 0) AND (weekday <= 6)))
);


--
-- Name: availability_windows_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.availability_windows_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: availability_windows_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.availability_windows_id_seq OWNED BY public.availability_windows.id;


--
-- Name: blackout_periods; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blackout_periods (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    shared_resource_id bigint,
    created_by_id bigint NOT NULL,
    reason character varying(150) NOT NULL,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    all_day boolean DEFAULT false NOT NULL,
    time_zone character varying(100) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT blackout_periods_positive_duration CHECK ((ends_at > starts_at)),
    CONSTRAINT blackout_periods_reason_length CHECK (((char_length(btrim((reason)::text)) >= 1) AND (char_length(btrim((reason)::text)) <= 150))),
    CONSTRAINT blackout_periods_time_zone_length CHECK (((char_length(btrim((time_zone)::text)) >= 1) AND (char_length(btrim((time_zone)::text)) <= 100)))
);


--
-- Name: blackout_periods_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.blackout_periods_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: blackout_periods_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.blackout_periods_id_seq OWNED BY public.blackout_periods.id;


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    user_id bigint NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT memberships_role_value CHECK ((role = ANY (ARRAY[0, 1, 2])))
);


--
-- Name: memberships_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.memberships_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: memberships_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.memberships_id_seq OWNED BY public.memberships.id;


--
-- Name: reservation_reminders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation_reminders (
    id bigint NOT NULL,
    reservation_id bigint NOT NULL,
    scheduled_for timestamp(6) without time zone NOT NULL,
    delivered_at timestamp(6) without time zone,
    skipped_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT reservation_reminders_single_terminal_state CHECK (((delivered_at IS NULL) OR (skipped_at IS NULL)))
);


--
-- Name: reservation_reminders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservation_reminders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservation_reminders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservation_reminders_id_seq OWNED BY public.reservation_reminders.id;


--
-- Name: reservation_series; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation_series (
    id bigint NOT NULL,
    shared_resource_id bigint NOT NULL,
    user_id bigint NOT NULL,
    purpose character varying NOT NULL,
    notes text,
    first_starts_at timestamp(6) without time zone NOT NULL,
    first_ends_at timestamp(6) without time zone NOT NULL,
    time_zone character varying NOT NULL,
    interval_weeks integer DEFAULT 1 NOT NULL,
    occurrence_count integer NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    reminder_minutes integer,
    CONSTRAINT reservation_series_interval_weeks CHECK (((interval_weeks >= 1) AND (interval_weeks <= 12))),
    CONSTRAINT reservation_series_maximum_duration CHECK ((first_ends_at <= (first_starts_at + '12:00:00'::interval))),
    CONSTRAINT reservation_series_notes_length CHECK (((notes IS NULL) OR (char_length(notes) <= 1000))),
    CONSTRAINT reservation_series_occurrence_count CHECK (((occurrence_count >= 2) AND (occurrence_count <= 26))),
    CONSTRAINT reservation_series_positive_duration CHECK ((first_ends_at > first_starts_at)),
    CONSTRAINT reservation_series_purpose_length CHECK (((char_length(btrim((purpose)::text)) >= 1) AND (char_length(btrim((purpose)::text)) <= 150))),
    CONSTRAINT reservation_series_reminder_minutes CHECK (((reminder_minutes IS NULL) OR (reminder_minutes = ANY (ARRAY[60, 240, 1440, 2880])))),
    CONSTRAINT reservation_series_time_zone_length CHECK (((char_length((time_zone)::text) >= 1) AND (char_length((time_zone)::text) <= 100)))
);


--
-- Name: reservation_series_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservation_series_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservation_series_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservation_series_id_seq OWNED BY public.reservation_series.id;


--
-- Name: reservations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservations (
    id bigint NOT NULL,
    shared_resource_id bigint NOT NULL,
    user_id bigint NOT NULL,
    purpose character varying NOT NULL,
    notes text,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    status character varying DEFAULT 'confirmed'::character varying NOT NULL,
    cancelled_at timestamp(6) without time zone,
    cancelled_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    reservation_series_id bigint,
    occurrence_number integer,
    reminder_minutes integer,
    CONSTRAINT reservations_cancellation_state CHECK (((((status)::text = 'confirmed'::text) AND (cancelled_at IS NULL) AND (cancelled_by_id IS NULL)) OR (((status)::text = 'cancelled'::text) AND (cancelled_at IS NOT NULL) AND (cancelled_by_id IS NOT NULL)))),
    CONSTRAINT reservations_maximum_duration CHECK ((ends_at <= (starts_at + '12:00:00'::interval))),
    CONSTRAINT reservations_notes_length CHECK (((notes IS NULL) OR (char_length(notes) <= 1000))),
    CONSTRAINT reservations_occurrence_number CHECK (((occurrence_number IS NULL) OR ((occurrence_number >= 1) AND (occurrence_number <= 26)))),
    CONSTRAINT reservations_positive_duration CHECK ((ends_at > starts_at)),
    CONSTRAINT reservations_purpose_length CHECK (((char_length(btrim((purpose)::text)) >= 1) AND (char_length(btrim((purpose)::text)) <= 150))),
    CONSTRAINT reservations_reminder_minutes CHECK (((reminder_minutes IS NULL) OR (reminder_minutes = ANY (ARRAY[60, 240, 1440, 2880])))),
    CONSTRAINT reservations_series_occurrence_pair CHECK ((((reservation_series_id IS NULL) AND (occurrence_number IS NULL)) OR ((reservation_series_id IS NOT NULL) AND (occurrence_number IS NOT NULL)))),
    CONSTRAINT reservations_status_value CHECK (((status)::text = ANY ((ARRAY['confirmed'::character varying, 'cancelled'::character varying])::text[])))
);


--
-- Name: reservations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservations_id_seq OWNED BY public.reservations.id;


--
-- Name: schedule_blocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schedule_blocks (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    shared_resource_id bigint,
    reservation_id bigint,
    blackout_period_id bigint,
    starts_at timestamp(6) without time zone NOT NULL,
    ends_at timestamp(6) without time zone NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT schedule_blocks_one_source CHECK ((num_nonnulls(reservation_id, blackout_period_id) = 1)),
    CONSTRAINT schedule_blocks_positive_duration CHECK ((ends_at > starts_at)),
    CONSTRAINT schedule_blocks_reservations_require_resource CHECK (((reservation_id IS NULL) OR (shared_resource_id IS NOT NULL)))
);


--
-- Name: schedule_blocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.schedule_blocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schedule_blocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.schedule_blocks_id_seq OWNED BY public.schedule_blocks.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: shared_resources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shared_resources (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    name character varying NOT NULL,
    category character varying NOT NULL,
    location character varying,
    capacity integer,
    description text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    minimum_booking_notice_minutes integer,
    maximum_advance_booking_days integer,
    maximum_reservation_duration_minutes integer,
    cancellation_cutoff_minutes integer,
    CONSTRAINT shared_resources_cancellation_cutoff_minutes_range CHECK (((cancellation_cutoff_minutes IS NULL) OR ((cancellation_cutoff_minutes >= 0) AND (cancellation_cutoff_minutes <= 10080)))),
    CONSTRAINT shared_resources_category_value CHECK (((category)::text = ANY ((ARRAY['room'::character varying, 'equipment'::character varying])::text[]))),
    CONSTRAINT shared_resources_maximum_advance_booking_days_range CHECK (((maximum_advance_booking_days IS NULL) OR ((maximum_advance_booking_days >= 1) AND (maximum_advance_booking_days <= 3650)))),
    CONSTRAINT shared_resources_maximum_reservation_duration_minutes_range CHECK (((maximum_reservation_duration_minutes IS NULL) OR ((maximum_reservation_duration_minutes >= 15) AND (maximum_reservation_duration_minutes <= 1440)))),
    CONSTRAINT shared_resources_minimum_booking_notice_minutes_range CHECK (((minimum_booking_notice_minutes IS NULL) OR ((minimum_booking_notice_minutes >= 0) AND (minimum_booking_notice_minutes <= 10080)))),
    CONSTRAINT shared_resources_name_length CHECK (((char_length(btrim((name)::text)) >= 1) AND (char_length(btrim((name)::text)) <= 100))),
    CONSTRAINT shared_resources_positive_capacity CHECK (((capacity IS NULL) OR (capacity > 0)))
);


--
-- Name: shared_resources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shared_resources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shared_resources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shared_resources_id_seq OWNED BY public.shared_resources.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    name character varying NOT NULL
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: workspace_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workspace_invitations (
    id bigint NOT NULL,
    workspace_id bigint NOT NULL,
    invited_by_id bigint NOT NULL,
    email_address character varying NOT NULL,
    role integer DEFAULT 0 NOT NULL,
    token_digest character varying,
    expires_at timestamp(6) without time zone NOT NULL,
    accepted_at timestamp(6) without time zone,
    accepted_by_id bigint,
    revoked_at timestamp(6) without time zone,
    revoked_by_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT workspace_invitations_email_length CHECK (((char_length(btrim((email_address)::text)) >= 3) AND (char_length(btrim((email_address)::text)) <= 254))),
    CONSTRAINT workspace_invitations_positive_expiration CHECK ((expires_at > created_at)),
    CONSTRAINT workspace_invitations_role_value CHECK ((role = ANY (ARRAY[0, 1]))),
    CONSTRAINT workspace_invitations_terminal_state CHECK ((((accepted_at IS NULL) AND (accepted_by_id IS NULL) AND (revoked_at IS NULL) AND (revoked_by_id IS NULL) AND (token_digest IS NOT NULL)) OR ((accepted_at IS NOT NULL) AND (accepted_by_id IS NOT NULL) AND (revoked_at IS NULL) AND (revoked_by_id IS NULL) AND (token_digest IS NULL)) OR ((accepted_at IS NULL) AND (accepted_by_id IS NULL) AND (revoked_at IS NOT NULL) AND (revoked_by_id IS NOT NULL) AND (token_digest IS NULL))))
);


--
-- Name: workspace_invitations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.workspace_invitations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspace_invitations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workspace_invitations_id_seq OWNED BY public.workspace_invitations.id;


--
-- Name: workspaces; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workspaces (
    id bigint NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    time_zone character varying DEFAULT 'Etc/UTC'::character varying NOT NULL,
    minimum_booking_notice_minutes integer DEFAULT 0 NOT NULL,
    maximum_advance_booking_days integer DEFAULT 365 NOT NULL,
    maximum_reservation_duration_minutes integer DEFAULT 720 NOT NULL,
    cancellation_cutoff_minutes integer DEFAULT 0 NOT NULL,
    CONSTRAINT workspaces_cancellation_cutoff_minutes_range CHECK (((cancellation_cutoff_minutes >= 0) AND (cancellation_cutoff_minutes <= 10080))),
    CONSTRAINT workspaces_maximum_advance_booking_days_range CHECK (((maximum_advance_booking_days >= 1) AND (maximum_advance_booking_days <= 3650))),
    CONSTRAINT workspaces_maximum_reservation_duration_minutes_range CHECK (((maximum_reservation_duration_minutes >= 15) AND (maximum_reservation_duration_minutes <= 1440))),
    CONSTRAINT workspaces_minimum_booking_notice_minutes_range CHECK (((minimum_booking_notice_minutes >= 0) AND (minimum_booking_notice_minutes <= 10080))),
    CONSTRAINT workspaces_name_length CHECK (((char_length(btrim((name)::text)) >= 1) AND (char_length(btrim((name)::text)) <= 100))),
    CONSTRAINT workspaces_time_zone_length CHECK (((char_length((time_zone)::text) >= 1) AND (char_length((time_zone)::text) <= 100)))
);


--
-- Name: workspaces_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.workspaces_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: workspaces_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.workspaces_id_seq OWNED BY public.workspaces.id;


--
-- Name: availability_windows id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_windows ALTER COLUMN id SET DEFAULT nextval('public.availability_windows_id_seq'::regclass);


--
-- Name: blackout_periods id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blackout_periods ALTER COLUMN id SET DEFAULT nextval('public.blackout_periods_id_seq'::regclass);


--
-- Name: memberships id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships ALTER COLUMN id SET DEFAULT nextval('public.memberships_id_seq'::regclass);


--
-- Name: reservation_reminders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_reminders ALTER COLUMN id SET DEFAULT nextval('public.reservation_reminders_id_seq'::regclass);


--
-- Name: reservation_series id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_series ALTER COLUMN id SET DEFAULT nextval('public.reservation_series_id_seq'::regclass);


--
-- Name: reservations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations ALTER COLUMN id SET DEFAULT nextval('public.reservations_id_seq'::regclass);


--
-- Name: schedule_blocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_blocks ALTER COLUMN id SET DEFAULT nextval('public.schedule_blocks_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: shared_resources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_resources ALTER COLUMN id SET DEFAULT nextval('public.shared_resources_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: workspace_invitations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations ALTER COLUMN id SET DEFAULT nextval('public.workspace_invitations_id_seq'::regclass);


--
-- Name: workspaces id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces ALTER COLUMN id SET DEFAULT nextval('public.workspaces_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: availability_windows availability_windows_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_windows
    ADD CONSTRAINT availability_windows_no_overlap EXCLUDE USING gist (shared_resource_id WITH =, weekday WITH =, int4range(starts_minute, ends_minute, '[)'::text) WITH &&);


--
-- Name: availability_windows availability_windows_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_windows
    ADD CONSTRAINT availability_windows_pkey PRIMARY KEY (id);


--
-- Name: blackout_periods blackout_periods_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blackout_periods
    ADD CONSTRAINT blackout_periods_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: reservation_reminders reservation_reminders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_reminders
    ADD CONSTRAINT reservation_reminders_pkey PRIMARY KEY (id);


--
-- Name: reservation_series reservation_series_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_series
    ADD CONSTRAINT reservation_series_pkey PRIMARY KEY (id);


--
-- Name: reservations reservations_no_confirmed_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_no_confirmed_overlap EXCLUDE USING gist (shared_resource_id WITH =, tsrange(starts_at, ends_at, '[)'::text) WITH &&) WHERE (((status)::text = 'confirmed'::text));


--
-- Name: reservations reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_pkey PRIMARY KEY (id);


--
-- Name: schedule_blocks schedule_blocks_no_overlap; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_blocks
    ADD CONSTRAINT schedule_blocks_no_overlap EXCLUDE USING gist (workspace_id WITH =, int8range(shared_resource_id, shared_resource_id, '[]'::text) WITH &&, tsrange(starts_at, ends_at, '[)'::text) WITH &&) WHERE (active);


--
-- Name: schedule_blocks schedule_blocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_blocks
    ADD CONSTRAINT schedule_blocks_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: shared_resources shared_resources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_resources
    ADD CONSTRAINT shared_resources_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: workspace_invitations workspace_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations
    ADD CONSTRAINT workspace_invitations_pkey PRIMARY KEY (id);


--
-- Name: workspaces workspaces_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspaces
    ADD CONSTRAINT workspaces_pkey PRIMARY KEY (id);


--
-- Name: index_active_schedule_blocks_on_workspace_and_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_schedule_blocks_on_workspace_and_start ON public.schedule_blocks USING btree (workspace_id, starts_at) WHERE active;


--
-- Name: index_availability_windows_on_resource_and_weekday; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_availability_windows_on_resource_and_weekday ON public.availability_windows USING btree (shared_resource_id, weekday);


--
-- Name: index_availability_windows_on_shared_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_availability_windows_on_shared_resource_id ON public.availability_windows USING btree (shared_resource_id);


--
-- Name: index_blackout_periods_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blackout_periods_on_created_by_id ON public.blackout_periods USING btree (created_by_id);


--
-- Name: index_blackout_periods_on_resource_and_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blackout_periods_on_resource_and_start ON public.blackout_periods USING btree (shared_resource_id, starts_at);


--
-- Name: index_blackout_periods_on_shared_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blackout_periods_on_shared_resource_id ON public.blackout_periods USING btree (shared_resource_id);


--
-- Name: index_blackout_periods_on_workspace_and_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blackout_periods_on_workspace_and_start ON public.blackout_periods USING btree (workspace_id, starts_at);


--
-- Name: index_blackout_periods_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_blackout_periods_on_workspace_id ON public.blackout_periods USING btree (workspace_id);


--
-- Name: index_memberships_on_unique_workspace_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_unique_workspace_owner ON public.memberships USING btree (workspace_id) WHERE (role = 2);


--
-- Name: index_memberships_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_user_id ON public.memberships USING btree (user_id);


--
-- Name: index_memberships_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_workspace_id ON public.memberships USING btree (workspace_id);


--
-- Name: index_memberships_on_workspace_id_and_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_workspace_id_and_user_id ON public.memberships USING btree (workspace_id, user_id);


--
-- Name: index_pending_invitations_on_workspace_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_pending_invitations_on_workspace_and_email ON public.workspace_invitations USING btree (workspace_id, lower((email_address)::text)) WHERE ((accepted_at IS NULL) AND (revoked_at IS NULL));


--
-- Name: index_pending_reservation_reminders_on_schedule; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_pending_reservation_reminders_on_schedule ON public.reservation_reminders USING btree (scheduled_for) WHERE ((delivered_at IS NULL) AND (skipped_at IS NULL));


--
-- Name: index_reservation_reminders_on_reservation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservation_reminders_on_reservation_id ON public.reservation_reminders USING btree (reservation_id);


--
-- Name: index_reservation_series_on_shared_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservation_series_on_shared_resource_id ON public.reservation_series USING btree (shared_resource_id);


--
-- Name: index_reservation_series_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservation_series_on_user_id ON public.reservation_series USING btree (user_id);


--
-- Name: index_reservations_on_cancelled_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_cancelled_by_id ON public.reservations USING btree (cancelled_by_id);


--
-- Name: index_reservations_on_reservation_series_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_reservation_series_id ON public.reservations USING btree (reservation_series_id);


--
-- Name: index_reservations_on_resource_and_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_resource_and_start ON public.reservations USING btree (shared_resource_id, starts_at);


--
-- Name: index_reservations_on_series_and_occurrence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_reservations_on_series_and_occurrence ON public.reservations USING btree (reservation_series_id, occurrence_number) WHERE (reservation_series_id IS NOT NULL);


--
-- Name: index_reservations_on_shared_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_shared_resource_id ON public.reservations USING btree (shared_resource_id);


--
-- Name: index_reservations_on_status_and_starts_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_status_and_starts_at ON public.reservations USING btree (status, starts_at);


--
-- Name: index_reservations_on_user_and_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_user_and_start ON public.reservations USING btree (user_id, starts_at);


--
-- Name: index_reservations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_reservations_on_user_id ON public.reservations USING btree (user_id);


--
-- Name: index_schedule_blocks_on_blackout_period_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_schedule_blocks_on_blackout_period_id ON public.schedule_blocks USING btree (blackout_period_id) WHERE (blackout_period_id IS NOT NULL);


--
-- Name: index_schedule_blocks_on_reservation_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_schedule_blocks_on_reservation_id ON public.schedule_blocks USING btree (reservation_id) WHERE (reservation_id IS NOT NULL);


--
-- Name: index_schedule_blocks_on_shared_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_blocks_on_shared_resource_id ON public.schedule_blocks USING btree (shared_resource_id);


--
-- Name: index_schedule_blocks_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schedule_blocks_on_workspace_id ON public.schedule_blocks USING btree (workspace_id);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_shared_resources_on_workspace_and_lower_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_shared_resources_on_workspace_and_lower_name ON public.shared_resources USING btree (workspace_id, lower((name)::text));


--
-- Name: index_shared_resources_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shared_resources_on_workspace_id ON public.shared_resources USING btree (workspace_id);


--
-- Name: index_shared_resources_on_workspace_id_and_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shared_resources_on_workspace_id_and_active ON public.shared_resources USING btree (workspace_id, active);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: index_workspace_invitations_on_accepted_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspace_invitations_on_accepted_by_id ON public.workspace_invitations USING btree (accepted_by_id);


--
-- Name: index_workspace_invitations_on_invited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspace_invitations_on_invited_by_id ON public.workspace_invitations USING btree (invited_by_id);


--
-- Name: index_workspace_invitations_on_revoked_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspace_invitations_on_revoked_by_id ON public.workspace_invitations USING btree (revoked_by_id);


--
-- Name: index_workspace_invitations_on_token_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_workspace_invitations_on_token_digest ON public.workspace_invitations USING btree (token_digest) WHERE (token_digest IS NOT NULL);


--
-- Name: index_workspace_invitations_on_workspace_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspace_invitations_on_workspace_and_created_at ON public.workspace_invitations USING btree (workspace_id, created_at);


--
-- Name: index_workspace_invitations_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspace_invitations_on_workspace_id ON public.workspace_invitations USING btree (workspace_id);


--
-- Name: reservation_series fk_rails_04579ab441; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_series
    ADD CONSTRAINT fk_rails_04579ab441 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: schedule_blocks fk_rails_10c0ca0d84; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_blocks
    ADD CONSTRAINT fk_rails_10c0ca0d84 FOREIGN KEY (reservation_id) REFERENCES public.reservations(id);


--
-- Name: reservations fk_rails_1c204685ca; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_rails_1c204685ca FOREIGN KEY (cancelled_by_id) REFERENCES public.users(id);


--
-- Name: reservations fk_rails_28394de527; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_rails_28394de527 FOREIGN KEY (shared_resource_id) REFERENCES public.shared_resources(id);


--
-- Name: blackout_periods fk_rails_33d79ce13f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blackout_periods
    ADD CONSTRAINT fk_rails_33d79ce13f FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: reservations fk_rails_48a92fce51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_rails_48a92fce51 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: reservations fk_rails_604bc8b218; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_rails_604bc8b218 FOREIGN KEY (reservation_series_id) REFERENCES public.reservation_series(id);


--
-- Name: workspace_invitations fk_rails_627a78e220; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations
    ADD CONSTRAINT fk_rails_627a78e220 FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: schedule_blocks fk_rails_68be193fcc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_blocks
    ADD CONSTRAINT fk_rails_68be193fcc FOREIGN KEY (shared_resource_id) REFERENCES public.shared_resources(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: workspace_invitations fk_rails_759aefbfd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations
    ADD CONSTRAINT fk_rails_759aefbfd2 FOREIGN KEY (invited_by_id) REFERENCES public.users(id);


--
-- Name: reservation_series fk_rails_8b46ea6485; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_series
    ADD CONSTRAINT fk_rails_8b46ea6485 FOREIGN KEY (shared_resource_id) REFERENCES public.shared_resources(id);


--
-- Name: shared_resources fk_rails_8e7921fad0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shared_resources
    ADD CONSTRAINT fk_rails_8e7921fad0 FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: workspace_invitations fk_rails_aa0ff4982f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations
    ADD CONSTRAINT fk_rails_aa0ff4982f FOREIGN KEY (accepted_by_id) REFERENCES public.users(id);


--
-- Name: blackout_periods fk_rails_ac38ff54af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blackout_periods
    ADD CONSTRAINT fk_rails_ac38ff54af FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: availability_windows fk_rails_ade8306986; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.availability_windows
    ADD CONSTRAINT fk_rails_ade8306986 FOREIGN KEY (shared_resource_id) REFERENCES public.shared_resources(id);


--
-- Name: workspace_invitations fk_rails_b7eb338f7c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations
    ADD CONSTRAINT fk_rails_b7eb338f7c FOREIGN KEY (revoked_by_id) REFERENCES public.users(id);


--
-- Name: schedule_blocks fk_rails_c962bc4f8f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_blocks
    ADD CONSTRAINT fk_rails_c962bc4f8f FOREIGN KEY (blackout_period_id) REFERENCES public.blackout_periods(id);


--
-- Name: reservation_reminders fk_rails_cc4e8a5102; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_reminders
    ADD CONSTRAINT fk_rails_cc4e8a5102 FOREIGN KEY (reservation_id) REFERENCES public.reservations(id);


--
-- Name: blackout_periods fk_rails_e347c4f19c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blackout_periods
    ADD CONSTRAINT fk_rails_e347c4f19c FOREIGN KEY (shared_resource_id) REFERENCES public.shared_resources(id);


--
-- Name: memberships fk_rails_e7b442f67c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_e7b442f67c FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- Name: schedule_blocks fk_rails_ec129a6bb0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schedule_blocks
    ADD CONSTRAINT fk_rails_ec129a6bb0 FOREIGN KEY (workspace_id) REFERENCES public.workspaces(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260802214000'),
('20260802171000'),
('20260801212500'),
('20260801195500'),
('20260801150000'),
('20260801110000'),
('20260801002500'),
('20260731233200'),
('20260731233100'),
('20260731233000'),
('20260731203747'),
('20260731203743'),
('20260731203741');

