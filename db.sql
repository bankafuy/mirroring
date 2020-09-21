--
-- PostgreSQL database dump
--

-- Dumped from database version 10.4
-- Dumped by pg_dump version 10.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'SQL_ASCII';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: compliance; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA compliance;


ALTER SCHEMA compliance OWNER TO postgres;

--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: 
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


--
-- Name: add_mapping_user_employee(); Type: FUNCTION; Schema: compliance; Owner: postgres
--

CREATE FUNCTION compliance.add_mapping_user_employee() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	user_id integer;
	exist integer;
BEGIN
	SELECT 1 FROM compliance.wf_employee WHERE employee_id = NEW.id_employee_cc_to_slt INTO exist;

	IF (exist is null AND NEW.id_employee_cc_to_slt IS NOT NULL) THEN
	
		INSERT INTO compliance.wf_user(name, email, phone, created, modified) 
		VALUES(NEW.cc_to_slt, '-', '-',  EXTRACT(EPOCH FROM CURRENT_TIMESTAMP), EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)) 
		RETURNING id INTO user_id;

		INSERT INTO compliance.wf_employee VALUES (NEW.id_employee_cc_to_slt, user_id);
	END IF;
-- 	IF NEW.last_name <> OLD.last_name THEN
-- 		 INSERT INTO employee_audits(employee_id,last_name,changed_on)
-- 		 VALUES(OLD.id,OLD.last_name,now());
-- 	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION compliance.add_mapping_user_employee() OWNER TO postgres;

--
-- Name: add_mapping_user_employee_hod(); Type: FUNCTION; Schema: compliance; Owner: postgres
--

CREATE FUNCTION compliance.add_mapping_user_employee_hod() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	user_id integer;
	exist integer;
BEGIN
	SELECT 1 FROM compliance.wf_employee WHERE employee_id = NEW.id_employee_hod_gap INTO exist;

	IF (exist is null) THEN
		INSERT INTO compliance.wf_user(name, email, phone, created, modified) 
		VALUES(NEW.hod_gap, '-', '-',  EXTRACT(EPOCH FROM CURRENT_TIMESTAMP), EXTRACT(EPOCH FROM CURRENT_TIMESTAMP)) 
		RETURNING id INTO user_id;

		INSERT INTO compliance.wf_employee VALUES (NEW.id_employee_hod_gap, user_id);
	END IF;
-- 	IF NEW.last_name <> OLD.last_name THEN
-- 		 INSERT INTO employee_audits(employee_id,last_name,changed_on)
-- 		 VALUES(OLD.id,OLD.last_name,now());
-- 	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION compliance.add_mapping_user_employee_hod() OWNER TO postgres;

--
-- Name: report_close_gap(); Type: FUNCTION; Schema: compliance; Owner: postgres
--

CREATE FUNCTION compliance.report_close_gap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	yesterday timestamp without time zone;
	today timestamp without time zone;
	exist integer;
	current_row integer;
BEGIN
	SELECT now()::date INTO today;
	
	SELECT 
		1 
	FROM 
		compliance.report_gap_new 
	WHERE
		gap_date = today 

	INTO current_row;

	IF(current_row IS NULL) THEN
		INSERT INTO 
			compliance.report_gap_new
		(gap_date, opening, open_gap, close_gap, closing)
		SELECT today, closing, 0, 1, closing - 1 FROM compliance.report_gap_new ORDER BY id DESC LIMIT 1;
	ELSE
		UPDATE 
			compliance.report_gap_new
		SET
			close_gap = close_gap + 1,
			closing = closing - 1
		WHERE
			gap_date = today;
			
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION compliance.report_close_gap() OWNER TO postgres;

--
-- Name: report_close_gap_summary(); Type: FUNCTION; Schema: compliance; Owner: postgres
--

CREATE FUNCTION compliance.report_close_gap_summary() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	current_month integer;
	current_year integer;
	exist integer;
	current_row integer;

BEGIN
	SELECT extract('month' from now()) INTO current_month;
	SELECT extract('year' from now()) INTO current_year;
	
	SELECT 
		1 
	FROM 
		compliance.report_gap
	WHERE
		year = current_year
	AND
		month = current_month

	INTO current_row;

	IF(current_row IS NULL) THEN
		INSERT INTO 
			compliance.report_gap
		(month, year, open_gap)
		SELECT current_month, current_year, COALESCE(open_gap, 0) - 1 FROM compliance.report_gap ORDER BY id DESC LIMIT 1;
	ELSE
		UPDATE 
			compliance.report_gap
		SET
			open_gap = open_gap - 1
		WHERE
			year = current_year
		AND
			month = current_month;
	END IF;

	RETURN NEW;
END;
$$;


ALTER FUNCTION compliance.report_close_gap_summary() OWNER TO postgres;

--
-- Name: report_open_gap(); Type: FUNCTION; Schema: compliance; Owner: postgres
--

CREATE FUNCTION compliance.report_open_gap() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	yesterday timestamp without time zone;
	today timestamp without time zone;
	exist integer;
	current_row integer;

BEGIN
	SELECT now()::date INTO today;
	
	SELECT 1 FROM compliance.hod_gap_assessment WHERE approved_date IS NULL AND id_gap_assessment = NEW.id_gap_assessment
	INTO exist;

	IF(exist IS NULL) THEN
	
		SELECT 
			1 
		FROM 
			compliance.report_gap_new 
		WHERE
			gap_date = today 

		INTO current_row;

		IF(current_row IS NULL) THEN
			INSERT INTO 
				compliance.report_gap_new
			(gap_date, opening, open_gap, close_gap, closing)
			SELECT today, closing, 1, 0, closing + 1 FROM compliance.report_gap_new ORDER BY id DESC LIMIT 1;
--			VALUES(current_year, current_month, 1);
		ELSE
			UPDATE 
				compliance.report_gap_new
			SET
				open_gap = open_gap + 1,
				closing = closing + 1
			WHERE
				gap_date = today;
				
		END IF;
			
	END IF;
	RETURN NEW;
END;
$$;


ALTER FUNCTION compliance.report_open_gap() OWNER TO postgres;

--
-- Name: report_open_gap_summary(); Type: FUNCTION; Schema: compliance; Owner: postgres
--

CREATE FUNCTION compliance.report_open_gap_summary() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
	current_month integer;
	current_year integer;
	exist integer;
	current_row integer;

BEGIN
	SELECT extract('month' from now()) INTO current_month;
	SELECT extract('year' from now()) INTO current_year;
	
	SELECT 1 FROM compliance.hod_gap_assessment WHERE approved_date IS NULL AND id_gap_assessment = NEW.id_gap_assessment
	INTO exist;

	IF(exist IS NULL) THEN
	
		SELECT 
			1 
		FROM 
			compliance.report_gap
		WHERE
			year = current_year
		AND
			month = current_month

		INTO current_row;

		IF(current_row IS NULL) THEN
			INSERT INTO 
				compliance.report_gap
			(month, year, open_gap)
			SELECT current_month, current_year, COALESCE(open_gap, 0) + 1 FROM compliance.report_gap ORDER BY id DESC LIMIT 1;
		ELSE
			UPDATE 
				compliance.report_gap
			SET
				open_gap = open_gap + 1
			WHERE
				year = current_year
			AND
				month = current_month;
		END IF;
			
	END IF;
	RETURN NEW;
END;
$$;


ALTER FUNCTION compliance.report_open_gap_summary() OWNER TO postgres;

--
-- Name: sp_check_approval_1(bigint); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.sp_check_approval_1(in_workflow_id bigint) RETURNS refcursor
    LANGUAGE plpgsql
    AS $$
DECLARE
  ref refcursor;
BEGIN
  OPEN ref FOR SELECT true from wf_run_workflow where id = in_workflow_id;
  RETURN ref;
END;
$$;


ALTER FUNCTION public.sp_check_approval_1(in_workflow_id bigint) OWNER TO postgres;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: action_plan; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.action_plan (
    id_action_plan character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_gap_assessment character varying(255),
    action_plan character varying,
    initial_target_date timestamp without time zone,
    reschedule_target_date timestamp without time zone,
    regulation_timeline boolean,
    action_owner character varying,
    id_department_action_owner character varying,
    waiting_implementation_regulation boolean,
    revision boolean,
    status character varying
);


ALTER TABLE compliance.action_plan OWNER TO postgres;

--
-- Name: approved_attestation; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.approved_attestation (
    id_approved_attestation character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_attestation character varying(255),
    id_employee_approved character varying,
    approved_name character varying,
    job_title_approved character varying,
    approved_date timestamp without time zone,
    send_to_type character varying,
    id_employee_reassign character varying,
    reassign_name character varying,
    job_title_reasign character varying
);


ALTER TABLE compliance.approved_attestation OWNER TO postgres;

--
-- Name: article; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.article (
    id_article character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_regulation character varying(255),
    article text,
    status_article character varying(255),
    article_en text,
    gap_identified character varying,
    article_number character varying,
    progress integer
);


ALTER TABLE compliance.article OWNER TO postgres;

--
-- Name: assign_to; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.assign_to (
    id_assign_to character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_article character varying(255),
    name character varying(255),
    department character varying(255),
    id_employee character varying,
    id_department character varying,
    existing_process character varying,
    impact_risk_to_business character varying,
    submitted boolean
);


ALTER TABLE compliance.assign_to OWNER TO postgres;

--
-- Name: attestation; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.attestation (
    id_attestation character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_department character varying,
    department_name character varying,
    status integer,
    num bigint
);


ALTER TABLE compliance.attestation OWNER TO postgres;

--
-- Name: comment; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.comment (
    id_comment character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    detail_comment character varying(255),
    staff_name character varying(255),
    id_employee character varying,
    id_regulation character varying(255),
    id_article character varying(255),
    id_department character varying,
    department_name character varying
);


ALTER TABLE compliance.comment OWNER TO postgres;

--
-- Name: comment_attestation; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.comment_attestation (
    id_comment_attestation character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_attestation character varying(255),
    detail_comment_attestation character varying,
    id_employee character varying,
    staff_name character varying,
    id_department character varying,
    department_name character varying
);


ALTER TABLE compliance.comment_attestation OWNER TO postgres;

--
-- Name: department_related; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.department_related (
    id_department_related character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_article character varying(255),
    id_department character varying,
    department_name character varying
);


ALTER TABLE compliance.department_related OWNER TO postgres;

--
-- Name: function_owner; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.function_owner (
    id_function_owner character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_article character varying(255),
    function_owner character varying(255),
    id_department character varying
);


ALTER TABLE compliance.function_owner OWNER TO postgres;

--
-- Name: gap_assessment; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.gap_assessment (
    id_gap_assessment character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    status character varying,
    id_article character varying(255),
    remark_closed character varying,
    gap character varying,
    instance_name character varying,
    closed_gap_date timestamp without time zone,
    closed_gap_by character varying,
    progress integer
);


ALTER TABLE compliance.gap_assessment OWNER TO postgres;

--
-- Name: gap_evidence; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.gap_evidence (
    id_gap_evidence character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    file_name character varying(255),
    id_gap_assessment character varying(255),
    path character varying,
    id_department character varying
);


ALTER TABLE compliance.gap_evidence OWNER TO postgres;

--
-- Name: history; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.history (
    id character varying NOT NULL,
    unique_id character varying,
    history_type character varying,
    action character varying,
    username character varying,
    full_name character varying,
    department_name character varying,
    create_date timestamp without time zone,
    data text
);


ALTER TABLE compliance.history OWNER TO postgres;

--
-- Name: COLUMN history.history_type; Type: COMMENT; Schema: compliance; Owner: postgres
--

COMMENT ON COLUMN compliance.history.history_type IS 'REGULATION / ARTICLE / GAP';


--
-- Name: COLUMN history.action; Type: COMMENT; Schema: compliance; Owner: postgres
--

COMMENT ON COLUMN compliance.history.action IS 'CREATE NEW / UPDATE';


--
-- Name: COLUMN history.data; Type: COMMENT; Schema: compliance; Owner: postgres
--

COMMENT ON COLUMN compliance.history.data IS 'json nya';


--
-- Name: hod_gap_assessment; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.hod_gap_assessment (
    id_hod_gap_assessment character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    id_gap_assessment character varying(255),
    hod_gap character varying,
    id_employee_hod_gap character varying,
    approved_date timestamp without time zone,
    id_employee_reassign character varying,
    reassign_name character varying,
    reason_reassign character varying,
    id_department character varying,
    department_name character varying,
    approved boolean,
    send_to_type character varying,
    approved_submitted boolean
);


ALTER TABLE compliance.hod_gap_assessment OWNER TO postgres;

--
-- Name: notification; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.notification (
    id integer NOT NULL,
    create_by character varying,
    create_date timestamp without time zone,
    update_by character varying,
    update_date timestamp without time zone,
    message text,
    opened character(1),
    user_id character varying,
    event_code integer
);


ALTER TABLE compliance.notification OWNER TO postgres;

--
-- Name: notification_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.notification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.notification_id_seq OWNER TO postgres;

--
-- Name: notification_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.notification_id_seq OWNED BY compliance.notification.id;


--
-- Name: regulation; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.regulation (
    id_regulation character varying(255) NOT NULL,
    regulation_number character varying(255),
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    regulation_title character varying(255),
    brief_summary_of_requirement text,
    status_regulation character varying(255),
    regulation_type character varying,
    issued_by character varying,
    issuance_date timestamp without time zone,
    progress integer,
    id_attestation character varying(255),
    implication_to_function character varying,
    remarks character varying,
    upload_regulation boolean
);


ALTER TABLE compliance.regulation OWNER TO postgres;

--
-- Name: report_gap; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.report_gap (
    id integer NOT NULL,
    year integer NOT NULL,
    month integer NOT NULL,
    open_gap integer
);


ALTER TABLE compliance.report_gap OWNER TO postgres;

--
-- Name: report_gap_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.report_gap_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.report_gap_id_seq OWNER TO postgres;

--
-- Name: report_gap_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.report_gap_id_seq OWNED BY compliance.report_gap.id;


--
-- Name: report_gap_new; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.report_gap_new (
    id integer NOT NULL,
    gap_date timestamp without time zone,
    opening integer,
    open_gap integer,
    close_gap integer,
    closing integer
);


ALTER TABLE compliance.report_gap_new OWNER TO postgres;

--
-- Name: report_gap_new_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.report_gap_new_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.report_gap_new_id_seq OWNER TO postgres;

--
-- Name: report_gap_new_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.report_gap_new_id_seq OWNED BY compliance.report_gap_new.id;


--
-- Name: sample_report; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.sample_report (
    number integer NOT NULL,
    open_date timestamp without time zone,
    close_date timestamp without time zone
);


ALTER TABLE compliance.sample_report OWNER TO postgres;

--
-- Name: setting_status; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.setting_status (
    id_setting_status character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    internal_timeline_from integer,
    internal_timeline_to integer,
    timeline_reschedule character varying(255),
    timeline_regulator character varying(255),
    status_action_gap character varying(255),
    auto_reminder integer,
    num bigint
);


ALTER TABLE compliance.setting_status OWNER TO postgres;

--
-- Name: status_of_action; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.status_of_action (
    id_status_of_action character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    status_of_action character varying,
    id_employee character varying,
    id_action_plan character varying(255)
);


ALTER TABLE compliance.status_of_action OWNER TO postgres;

--
-- Name: supporting_document; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.supporting_document (
    id_supporting_document character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    file_name character varying(255),
    id_article character varying(255),
    path character varying,
    id_department character varying
);


ALTER TABLE compliance.supporting_document OWNER TO postgres;

--
-- Name: upload_regulation; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.upload_regulation (
    id_upload_regulation character varying(255) NOT NULL,
    create_by character varying(255),
    create_date timestamp without time zone,
    update_by character varying(255),
    update_date timestamp without time zone,
    file_name character varying(255),
    id_regulation character varying(255),
    path character varying
);


ALTER TABLE compliance.upload_regulation OWNER TO postgres;

--
-- Name: vw_open_gap; Type: VIEW; Schema: compliance; Owner: postgres
--

CREATE VIEW compliance.vw_open_gap AS
 SELECT to_char(ga.create_date, 'yyyy-MM-dd'::text) AS label,
    count(1) AS open_gap
   FROM ((compliance.gap_assessment ga
     JOIN ( SELECT hod_gap_assessment.id_gap_assessment,
            count(1) AS approval
           FROM compliance.hod_gap_assessment
          GROUP BY hod_gap_assessment.id_gap_assessment) approval ON (((ga.id_gap_assessment)::text = (approval.id_gap_assessment)::text)))
     LEFT JOIN ( SELECT hod_gap_assessment.id_gap_assessment,
            count(1) AS approved
           FROM compliance.hod_gap_assessment
          WHERE (hod_gap_assessment.approved_date IS NOT NULL)
          GROUP BY hod_gap_assessment.id_gap_assessment) approved ON (((ga.id_gap_assessment)::text = (approved.id_gap_assessment)::text)))
  WHERE (COALESCE(approval.approval, (0)::bigint) = COALESCE(approved.approved, (0)::bigint))
  GROUP BY (to_char(ga.create_date, 'yyyy-MM-dd'::text))
  ORDER BY (to_char(ga.create_date, 'yyyy-MM-dd'::text));


ALTER TABLE compliance.vw_open_gap OWNER TO postgres;

--
-- Name: vw_slt_hod; Type: VIEW; Schema: compliance; Owner: postgres
--

CREATE VIEW compliance.vw_slt_hod AS
 SELECT ga.id_article,
    ga.id_gap_assessment,
    slt.id_employee AS slt,
    slt.employee_name AS slt_name,
    hod.id_employee AS hod,
    hod.employee_name AS hod_name,
    slt.id_department AS slt_dept,
    hod.id_department AS hod_dept
   FROM ((compliance.gap_assessment ga
     LEFT JOIN ( SELECT hod_gap_assessment.id_gap_assessment,
            hod_gap_assessment.id_employee_hod_gap AS id_employee,
            hod_gap_assessment.hod_gap AS employee_name,
            hod_gap_assessment.id_department
           FROM compliance.hod_gap_assessment
          WHERE ((hod_gap_assessment.send_to_type)::text = 'HOD'::text)) hod ON (((hod.id_gap_assessment)::text = (ga.id_gap_assessment)::text)))
     LEFT JOIN ( SELECT hod_gap_assessment.id_gap_assessment,
            hod_gap_assessment.id_employee_hod_gap AS id_employee,
            hod_gap_assessment.hod_gap AS employee_name,
            hod_gap_assessment.id_department
           FROM compliance.hod_gap_assessment
          WHERE ((hod_gap_assessment.send_to_type)::text = 'SLT'::text)) slt ON (((slt.id_gap_assessment)::text = (ga.id_gap_assessment)::text)))
  WHERE (ga.progress > 1)
  ORDER BY ga.id_article, ga.id_gap_assessment;


ALTER TABLE compliance.vw_slt_hod OWNER TO postgres;

--
-- Name: vw_target_date; Type: VIEW; Schema: compliance; Owner: postgres
--

CREATE VIEW compliance.vw_target_date AS
 SELECT ga.id_article,
    ga.id_gap_assessment,
    ap.target_date,
    ((now())::date - (ap.target_date)::date) AS diff
   FROM (compliance.gap_assessment ga
     LEFT JOIN ( SELECT action_plan.id_gap_assessment,
            COALESCE(action_plan.reschedule_target_date, action_plan.initial_target_date, NULL::timestamp without time zone) AS target_date,
            row_number() OVER (PARTITION BY action_plan.id_gap_assessment ORDER BY COALESCE(action_plan.reschedule_target_date, action_plan.initial_target_date, NULL::timestamp without time zone) DESC) AS row_number
           FROM compliance.action_plan) ap ON ((((ga.id_gap_assessment)::text = (ap.id_gap_assessment)::text) AND (ap.row_number = 1))))
  WHERE (ap.target_date IS NOT NULL)
  ORDER BY ga.id_gap_assessment;


ALTER TABLE compliance.vw_target_date OWNER TO postgres;

--
-- Name: wf_config; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_config (
    id bigint NOT NULL,
    key character varying(50) NOT NULL,
    value character varying NOT NULL,
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_config OWNER TO postgres;

--
-- Name: wf_config_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_config_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_config_id_seq OWNER TO postgres;

--
-- Name: wf_config_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_config_id_seq OWNED BY compliance.wf_config.id;


--
-- Name: wf_employee; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_employee (
    employee_id character varying NOT NULL,
    user_id bigint NOT NULL
);


ALTER TABLE compliance.wf_employee OWNER TO postgres;

--
-- Name: wf_employee_user_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_employee_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_employee_user_id_seq OWNER TO postgres;

--
-- Name: wf_employee_user_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_employee_user_id_seq OWNED BY compliance.wf_employee.user_id;


--
-- Name: wf_fcm; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_fcm (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    token character varying NOT NULL,
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_fcm OWNER TO postgres;

--
-- Name: wf_fcm_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_fcm_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_fcm_id_seq OWNER TO postgres;

--
-- Name: wf_fcm_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_fcm_id_seq OWNED BY compliance.wf_fcm.id;


--
-- Name: wf_group; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_group (
    id bigint NOT NULL,
    name character varying(50) NOT NULL,
    type integer DEFAULT 1 NOT NULL,
    created bigint NOT NULL,
    modified bigint,
    description character varying(500)
);


ALTER TABLE compliance.wf_group OWNER TO postgres;

--
-- Name: wf_group_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_group_id_seq OWNER TO postgres;

--
-- Name: wf_group_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_group_id_seq OWNED BY compliance.wf_group.id;


--
-- Name: wf_job; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_job (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    created bigint NOT NULL,
    modified bigint,
    description character varying(500)
);


ALTER TABLE compliance.wf_job OWNER TO postgres;

--
-- Name: wf_job_group; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_job_group (
    id bigint NOT NULL,
    group_id bigint NOT NULL,
    job_id bigint NOT NULL,
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_job_group OWNER TO postgres;

--
-- Name: wf_job_group_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_job_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_job_group_id_seq OWNER TO postgres;

--
-- Name: wf_job_group_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_job_group_id_seq OWNED BY compliance.wf_job_group.id;


--
-- Name: wf_job_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_job_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_job_id_seq OWNER TO postgres;

--
-- Name: wf_job_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_job_id_seq OWNED BY compliance.wf_job.id;


--
-- Name: wf_organization; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_organization (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    superior_id bigint,
    job_id bigint NOT NULL,
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_organization OWNER TO postgres;

--
-- Name: wf_organization_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_organization_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_organization_id_seq OWNER TO postgres;

--
-- Name: wf_organization_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_organization_id_seq OWNED BY compliance.wf_organization.id;


--
-- Name: wf_pending; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_pending (
    id bigint NOT NULL,
    instance_name character varying(100) NOT NULL,
    definition_id character varying(50) NOT NULL,
    requester bigint NOT NULL
);


ALTER TABLE compliance.wf_pending OWNER TO postgres;

--
-- Name: wf_pending_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_pending_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_pending_id_seq OWNER TO postgres;

--
-- Name: wf_pending_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_pending_id_seq OWNED BY compliance.wf_pending.id;


--
-- Name: wf_run_inbox_task; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_run_inbox_task (
    id bigint NOT NULL,
    wf_instance_id bigint NOT NULL,
    recipient_result_id bigint NOT NULL,
    user_id bigint NOT NULL,
    status integer NOT NULL,
    link character varying(500),
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_run_inbox_task OWNER TO postgres;

--
-- Name: wf_run_inbox_task_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_run_inbox_task_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_run_inbox_task_id_seq OWNER TO postgres;

--
-- Name: wf_run_inbox_task_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_run_inbox_task_id_seq OWNED BY compliance.wf_run_inbox_task.id;


--
-- Name: wf_run_notification_outbox; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_run_notification_outbox (
    id bigint NOT NULL,
    recipient_result_id bigint NOT NULL,
    wf_instance_id bigint NOT NULL,
    step_instance_id bigint NOT NULL,
    variable_id character varying(50) NOT NULL,
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_run_notification_outbox OWNER TO postgres;

--
-- Name: wf_run_notification_outbox_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_run_notification_outbox_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_run_notification_outbox_id_seq OWNER TO postgres;

--
-- Name: wf_run_notification_outbox_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_run_notification_outbox_id_seq OWNED BY compliance.wf_run_notification_outbox.id;


--
-- Name: wf_run_parameter; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_run_parameter (
    id bigint NOT NULL,
    wf_instance_id bigint NOT NULL,
    key character varying(50),
    value character varying(300),
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_run_parameter OWNER TO postgres;

--
-- Name: wf_run_parameter_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_run_parameter_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_run_parameter_id_seq OWNER TO postgres;

--
-- Name: wf_run_parameter_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_run_parameter_id_seq OWNED BY compliance.wf_run_parameter.id;


--
-- Name: wf_run_recipient_result; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_run_recipient_result (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    step_instance_id bigint NOT NULL,
    execution_status integer DEFAULT 0 NOT NULL,
    result character varying(100),
    created bigint NOT NULL,
    modified bigint NOT NULL,
    active integer DEFAULT 1 NOT NULL
);


ALTER TABLE compliance.wf_run_recipient_result OWNER TO postgres;

--
-- Name: wf_run_recipient_result_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_run_recipient_result_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_run_recipient_result_id_seq OWNER TO postgres;

--
-- Name: wf_run_recipient_result_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_run_recipient_result_id_seq OWNED BY compliance.wf_run_recipient_result.id;


--
-- Name: wf_run_step; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_run_step (
    id bigint NOT NULL,
    wf_instance_id bigint NOT NULL,
    previous_step bigint,
    definition_step_id character varying(30) NOT NULL,
    execution_status integer DEFAULT 0 NOT NULL,
    modified bigint,
    created bigint,
    previous_decision character varying(100),
    notes character varying(500)
);


ALTER TABLE compliance.wf_run_step OWNER TO postgres;

--
-- Name: wf_run_step_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_run_step_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_run_step_id_seq OWNER TO postgres;

--
-- Name: wf_run_step_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_run_step_id_seq OWNED BY compliance.wf_run_step.id;


--
-- Name: wf_run_version; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_run_version (
    id bigint NOT NULL,
    wf_definition_id character varying(50) NOT NULL,
    version integer NOT NULL,
    created bigint NOT NULL,
    modified bigint,
    raw character varying NOT NULL
);


ALTER TABLE compliance.wf_run_version OWNER TO postgres;

--
-- Name: wf_run_version_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_run_version_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_run_version_id_seq OWNER TO postgres;

--
-- Name: wf_run_version_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_run_version_id_seq OWNED BY compliance.wf_run_version.id;


--
-- Name: wf_run_workflow; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_run_workflow (
    id bigint NOT NULL,
    requester bigint NOT NULL,
    run_version_id bigint NOT NULL,
    instance_name character varying(100) NOT NULL,
    current_step_instance_id bigint,
    status integer NOT NULL,
    created bigint NOT NULL,
    modified bigint,
    error text,
    error_trace text,
    error_data text,
    description text
);


ALTER TABLE compliance.wf_run_workflow OWNER TO postgres;

--
-- Name: wf_run_workflow_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_run_workflow_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_run_workflow_id_seq OWNER TO postgres;

--
-- Name: wf_run_workflow_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_run_workflow_id_seq OWNED BY compliance.wf_run_workflow.id;


--
-- Name: wf_schema; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_schema (
    id bigint NOT NULL,
    server_id bigint NOT NULL,
    schema_name character varying(50) NOT NULL,
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_schema OWNER TO postgres;

--
-- Name: wf_schema_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_schema_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_schema_id_seq OWNER TO postgres;

--
-- Name: wf_schema_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_schema_id_seq OWNED BY compliance.wf_schema.id;


--
-- Name: wf_server; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_server (
    id bigint NOT NULL,
    wf_app_id bigint NOT NULL,
    jdbc_url character varying(100),
    jdbc_user character varying(50),
    jdbc_password character varying(50),
    primary_server smallint DEFAULT 0 NOT NULL,
    created bigint NOT NULL,
    modified bigint,
    jdbc_public_url character varying
);


ALTER TABLE compliance.wf_server OWNER TO postgres;

--
-- Name: wf_server_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_server_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_server_id_seq OWNER TO postgres;

--
-- Name: wf_server_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_server_id_seq OWNED BY compliance.wf_server.id;


--
-- Name: wf_user; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_user (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    email character varying(100) NOT NULL,
    phone character varying(100) NOT NULL,
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_user OWNER TO postgres;

--
-- Name: wf_user_group; Type: TABLE; Schema: compliance; Owner: postgres
--

CREATE TABLE compliance.wf_user_group (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    group_id bigint NOT NULL,
    created bigint NOT NULL,
    modified bigint
);


ALTER TABLE compliance.wf_user_group OWNER TO postgres;

--
-- Name: wf_user_group_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_user_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_user_group_id_seq OWNER TO postgres;

--
-- Name: wf_user_group_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_user_group_id_seq OWNED BY compliance.wf_user_group.id;


--
-- Name: wf_user_id_seq; Type: SEQUENCE; Schema: compliance; Owner: postgres
--

CREATE SEQUENCE compliance.wf_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE compliance.wf_user_id_seq OWNER TO postgres;

--
-- Name: wf_user_id_seq; Type: SEQUENCE OWNED BY; Schema: compliance; Owner: postgres
--

ALTER SEQUENCE compliance.wf_user_id_seq OWNED BY compliance.wf_user.id;


--
-- Name: notification id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.notification ALTER COLUMN id SET DEFAULT nextval('compliance.notification_id_seq'::regclass);


--
-- Name: report_gap id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.report_gap ALTER COLUMN id SET DEFAULT nextval('compliance.report_gap_id_seq'::regclass);


--
-- Name: report_gap_new id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.report_gap_new ALTER COLUMN id SET DEFAULT nextval('compliance.report_gap_new_id_seq'::regclass);


--
-- Name: wf_config id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_config ALTER COLUMN id SET DEFAULT nextval('compliance.wf_config_id_seq'::regclass);


--
-- Name: wf_employee user_id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_employee ALTER COLUMN user_id SET DEFAULT nextval('compliance.wf_employee_user_id_seq'::regclass);


--
-- Name: wf_fcm id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_fcm ALTER COLUMN id SET DEFAULT nextval('compliance.wf_fcm_id_seq'::regclass);


--
-- Name: wf_group id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_group ALTER COLUMN id SET DEFAULT nextval('compliance.wf_group_id_seq'::regclass);


--
-- Name: wf_job id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_job ALTER COLUMN id SET DEFAULT nextval('compliance.wf_job_id_seq'::regclass);


--
-- Name: wf_job_group id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_job_group ALTER COLUMN id SET DEFAULT nextval('compliance.wf_job_group_id_seq'::regclass);


--
-- Name: wf_organization id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_organization ALTER COLUMN id SET DEFAULT nextval('compliance.wf_organization_id_seq'::regclass);


--
-- Name: wf_pending id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_pending ALTER COLUMN id SET DEFAULT nextval('compliance.wf_pending_id_seq'::regclass);


--
-- Name: wf_run_inbox_task id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_inbox_task ALTER COLUMN id SET DEFAULT nextval('compliance.wf_run_inbox_task_id_seq'::regclass);


--
-- Name: wf_run_notification_outbox id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_notification_outbox ALTER COLUMN id SET DEFAULT nextval('compliance.wf_run_notification_outbox_id_seq'::regclass);


--
-- Name: wf_run_parameter id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_parameter ALTER COLUMN id SET DEFAULT nextval('compliance.wf_run_parameter_id_seq'::regclass);


--
-- Name: wf_run_recipient_result id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_recipient_result ALTER COLUMN id SET DEFAULT nextval('compliance.wf_run_recipient_result_id_seq'::regclass);


--
-- Name: wf_run_step id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_step ALTER COLUMN id SET DEFAULT nextval('compliance.wf_run_step_id_seq'::regclass);


--
-- Name: wf_run_version id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_version ALTER COLUMN id SET DEFAULT nextval('compliance.wf_run_version_id_seq'::regclass);


--
-- Name: wf_run_workflow id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_workflow ALTER COLUMN id SET DEFAULT nextval('compliance.wf_run_workflow_id_seq'::regclass);


--
-- Name: wf_schema id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_schema ALTER COLUMN id SET DEFAULT nextval('compliance.wf_schema_id_seq'::regclass);


--
-- Name: wf_server id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_server ALTER COLUMN id SET DEFAULT nextval('compliance.wf_server_id_seq'::regclass);


--
-- Name: wf_user id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_user ALTER COLUMN id SET DEFAULT nextval('compliance.wf_user_id_seq'::regclass);


--
-- Name: wf_user_group id; Type: DEFAULT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_user_group ALTER COLUMN id SET DEFAULT nextval('compliance.wf_user_group_id_seq'::regclass);


--
-- Name: action_plan action_plan_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.action_plan
    ADD CONSTRAINT action_plan_pkey PRIMARY KEY (id_action_plan);


--
-- Name: approved_attestation approved_attestation_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.approved_attestation
    ADD CONSTRAINT approved_attestation_pkey PRIMARY KEY (id_approved_attestation);


--
-- Name: article article_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.article
    ADD CONSTRAINT article_pkey PRIMARY KEY (id_article);


--
-- Name: assign_to assign_to_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.assign_to
    ADD CONSTRAINT assign_to_pkey PRIMARY KEY (id_assign_to);


--
-- Name: attestation attestation_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.attestation
    ADD CONSTRAINT attestation_pkey PRIMARY KEY (id_attestation);


--
-- Name: comment_attestation comment_attestation_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.comment_attestation
    ADD CONSTRAINT comment_attestation_pkey PRIMARY KEY (id_comment_attestation);


--
-- Name: comment comment_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.comment
    ADD CONSTRAINT comment_pkey PRIMARY KEY (id_comment);


--
-- Name: department_related department_related_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.department_related
    ADD CONSTRAINT department_related_pkey PRIMARY KEY (id_department_related);


--
-- Name: function_owner function_owner_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.function_owner
    ADD CONSTRAINT function_owner_pkey PRIMARY KEY (id_function_owner);


--
-- Name: gap_assessment gap_assessment_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.gap_assessment
    ADD CONSTRAINT gap_assessment_pkey PRIMARY KEY (id_gap_assessment);


--
-- Name: gap_evidence gap_evidence_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.gap_evidence
    ADD CONSTRAINT gap_evidence_pkey PRIMARY KEY (id_gap_evidence);


--
-- Name: history history_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.history
    ADD CONSTRAINT history_pkey PRIMARY KEY (id);


--
-- Name: hod_gap_assessment hod_gap_assessment_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.hod_gap_assessment
    ADD CONSTRAINT hod_gap_assessment_pkey PRIMARY KEY (id_hod_gap_assessment);


--
-- Name: wf_job_group job_group_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_job_group
    ADD CONSTRAINT job_group_pkey PRIMARY KEY (id);


--
-- Name: notification notification_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.notification
    ADD CONSTRAINT notification_pkey PRIMARY KEY (id);


--
-- Name: wf_organization organizations_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_organization
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: regulation regulation_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.regulation
    ADD CONSTRAINT regulation_pkey PRIMARY KEY (id_regulation);


--
-- Name: report_gap_new report_gap_new_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.report_gap_new
    ADD CONSTRAINT report_gap_new_pkey PRIMARY KEY (id);


--
-- Name: report_gap report_gap_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.report_gap
    ADD CONSTRAINT report_gap_pkey PRIMARY KEY (year, month);


--
-- Name: wf_run_inbox_task run_inbox_task_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_inbox_task
    ADD CONSTRAINT run_inbox_task_pkey PRIMARY KEY (id);


--
-- Name: wf_run_recipient_result run_recipient_result_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_recipient_result
    ADD CONSTRAINT run_recipient_result_pkey PRIMARY KEY (id);


--
-- Name: wf_run_step run_step_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_step
    ADD CONSTRAINT run_step_pkey PRIMARY KEY (id);


--
-- Name: wf_run_workflow run_wf_instance_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_workflow
    ADD CONSTRAINT run_wf_instance_pkey PRIMARY KEY (id);


--
-- Name: sample_report sample_report_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.sample_report
    ADD CONSTRAINT sample_report_pkey PRIMARY KEY (number);


--
-- Name: wf_server server_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_server
    ADD CONSTRAINT server_pkey PRIMARY KEY (id);


--
-- Name: setting_status setting_status_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.setting_status
    ADD CONSTRAINT setting_status_pkey PRIMARY KEY (id_setting_status);


--
-- Name: status_of_action status_of_action_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.status_of_action
    ADD CONSTRAINT status_of_action_pkey PRIMARY KEY (id_status_of_action);


--
-- Name: supporting_document supporting_document_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.supporting_document
    ADD CONSTRAINT supporting_document_pkey PRIMARY KEY (id_supporting_document);


--
-- Name: upload_regulation upload_regulation_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.upload_regulation
    ADD CONSTRAINT upload_regulation_pkey PRIMARY KEY (id_upload_regulation);


--
-- Name: wf_user_group user_group_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_user_group
    ADD CONSTRAINT user_group_pkey PRIMARY KEY (id);


--
-- Name: wf_config wf_config_pk; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_config
    ADD CONSTRAINT wf_config_pk PRIMARY KEY (id);


--
-- Name: wf_employee wf_employee_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_employee
    ADD CONSTRAINT wf_employee_pkey PRIMARY KEY (employee_id);


--
-- Name: wf_fcm wf_fcm_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_fcm
    ADD CONSTRAINT wf_fcm_pkey PRIMARY KEY (id);


--
-- Name: wf_group wf_group_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_group
    ADD CONSTRAINT wf_group_pkey PRIMARY KEY (id);


--
-- Name: wf_job wf_job_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_job
    ADD CONSTRAINT wf_job_pkey PRIMARY KEY (id);


--
-- Name: wf_run_notification_outbox wf_notification_outbox_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_notification_outbox
    ADD CONSTRAINT wf_notification_outbox_pkey PRIMARY KEY (id);


--
-- Name: wf_pending wf_pending_pk; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_pending
    ADD CONSTRAINT wf_pending_pk PRIMARY KEY (id);


--
-- Name: wf_run_parameter wf_run_parameters_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_parameter
    ADD CONSTRAINT wf_run_parameters_pkey PRIMARY KEY (id);


--
-- Name: wf_run_version wf_run_version_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_version
    ADD CONSTRAINT wf_run_version_pkey PRIMARY KEY (id);


--
-- Name: wf_schema wf_schema_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_schema
    ADD CONSTRAINT wf_schema_pkey PRIMARY KEY (id);


--
-- Name: wf_user wf_user_pkey; Type: CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_user
    ADD CONSTRAINT wf_user_pkey PRIMARY KEY (id);


--
-- Name: job_group_group_id_job_id_uindex; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX job_group_group_id_job_id_uindex ON compliance.wf_job_group USING btree (group_id, job_id);


--
-- Name: run_inbox_task_run_wf_instance_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX run_inbox_task_run_wf_instance_id_index ON compliance.wf_run_inbox_task USING btree (wf_instance_id);


--
-- Name: run_inbox_task_run_wf_instance_id_user_id_uindex; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX run_inbox_task_run_wf_instance_id_user_id_uindex ON compliance.wf_run_inbox_task USING btree (wf_instance_id, user_id);


--
-- Name: run_inbox_task_user_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX run_inbox_task_user_id_index ON compliance.wf_run_inbox_task USING btree (user_id);


--
-- Name: wf_config_key_uindex; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX wf_config_key_uindex ON compliance.wf_config USING btree (key);


--
-- Name: wf_fcm_uindex; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX wf_fcm_uindex ON compliance.wf_fcm USING btree (token);


--
-- Name: wf_fcm_user_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_fcm_user_id_index ON compliance.wf_fcm USING btree (user_id);


--
-- Name: wf_group_name_uindex; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX wf_group_name_uindex ON compliance.wf_group USING btree (name);


--
-- Name: wf_job_name_uindex; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX wf_job_name_uindex ON compliance.wf_job USING btree (name);


--
-- Name: wf_organization_job_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_organization_job_id_index ON compliance.wf_organization USING btree (job_id);


--
-- Name: wf_organization_superior_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_organization_superior_id_index ON compliance.wf_organization USING btree (superior_id);


--
-- Name: wf_organization_user_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_organization_user_id_index ON compliance.wf_organization USING btree (user_id);


--
-- Name: wf_run_inbox_task_status_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_inbox_task_status_index ON compliance.wf_run_inbox_task USING btree (status);


--
-- Name: wf_run_notification_outbox_created_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_notification_outbox_created_index ON compliance.wf_run_notification_outbox USING btree (created);


--
-- Name: wf_run_notification_outbox_recipient_result_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_notification_outbox_recipient_result_id_index ON compliance.wf_run_notification_outbox USING btree (recipient_result_id);


--
-- Name: wf_run_parameters_wf_instance_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_parameters_wf_instance_id_index ON compliance.wf_run_parameter USING btree (wf_instance_id);


--
-- Name: wf_run_recipient_result_step_instance_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_recipient_result_step_instance_id_index ON compliance.wf_run_recipient_result USING btree (step_instance_id);


--
-- Name: wf_run_recipient_result_user_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_recipient_result_user_id_index ON compliance.wf_run_recipient_result USING btree (user_id);


--
-- Name: wf_run_step_previous_step_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_step_previous_step_index ON compliance.wf_run_step USING btree (previous_step);


--
-- Name: wf_run_step_wf_instance_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_step_wf_instance_id_index ON compliance.wf_run_step USING btree (wf_instance_id);


--
-- Name: wf_run_version_version; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_version_version ON compliance.wf_run_version USING btree (version);


--
-- Name: wf_run_version_wf_definition_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX wf_run_version_wf_definition_id_index ON compliance.wf_run_version USING btree (wf_definition_id, version);


--
-- Name: wf_run_workflow_current_step_instance_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_workflow_current_step_instance_id_index ON compliance.wf_run_workflow USING btree (current_step_instance_id);


--
-- Name: wf_run_workflow_modified; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_workflow_modified ON compliance.wf_run_workflow USING btree (modified DESC);


--
-- Name: wf_run_workflow_name_uindex; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX wf_run_workflow_name_uindex ON compliance.wf_run_workflow USING btree (instance_name);


--
-- Name: wf_run_workflow_requester_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_workflow_requester_index ON compliance.wf_run_workflow USING btree (requester);


--
-- Name: wf_run_workflow_status_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_workflow_status_index ON compliance.wf_run_workflow USING btree (status);


--
-- Name: wf_run_workflow_version_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_run_workflow_version_index ON compliance.wf_run_workflow USING btree (run_version_id);


--
-- Name: wf_schema_name_uindex; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE UNIQUE INDEX wf_schema_name_uindex ON compliance.wf_schema USING btree (schema_name);


--
-- Name: wf_user_group_group_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_user_group_group_id_index ON compliance.wf_user_group USING btree (group_id);


--
-- Name: wf_user_group_user_id_index; Type: INDEX; Schema: compliance; Owner: postgres
--

CREATE INDEX wf_user_group_user_id_index ON compliance.wf_user_group USING btree (user_id);


--
-- Name: hod_gap_assessment tr_hod_wf_employee; Type: TRIGGER; Schema: compliance; Owner: postgres
--

CREATE TRIGGER tr_hod_wf_employee AFTER INSERT ON compliance.hod_gap_assessment FOR EACH ROW EXECUTE PROCEDURE compliance.add_mapping_user_employee_hod();


--
-- Name: gap_assessment tr_update_report_gap; Type: TRIGGER; Schema: compliance; Owner: postgres
--

CREATE TRIGGER tr_update_report_gap AFTER UPDATE OF closed_gap_date ON compliance.gap_assessment FOR EACH ROW EXECUTE PROCEDURE compliance.report_close_gap();


--
-- Name: hod_gap_assessment tr_update_report_gap; Type: TRIGGER; Schema: compliance; Owner: postgres
--

CREATE TRIGGER tr_update_report_gap AFTER UPDATE OF approved_date ON compliance.hod_gap_assessment FOR EACH ROW EXECUTE PROCEDURE compliance.report_open_gap();


--
-- Name: gap_assessment tr_update_report_gap_summary; Type: TRIGGER; Schema: compliance; Owner: postgres
--

CREATE TRIGGER tr_update_report_gap_summary AFTER UPDATE OF closed_gap_date ON compliance.gap_assessment FOR EACH ROW EXECUTE PROCEDURE compliance.report_close_gap_summary();


--
-- Name: hod_gap_assessment tr_update_report_gap_summary; Type: TRIGGER; Schema: compliance; Owner: postgres
--

CREATE TRIGGER tr_update_report_gap_summary AFTER UPDATE OF approved_date ON compliance.hod_gap_assessment FOR EACH ROW EXECUTE PROCEDURE compliance.report_open_gap_summary();


--
-- Name: wf_job_group job_group_group_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_job_group
    ADD CONSTRAINT job_group_group_id_fk FOREIGN KEY (group_id) REFERENCES compliance.wf_group(id);


--
-- Name: wf_job_group job_group_job_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_job_group
    ADD CONSTRAINT job_group_job_id_fk FOREIGN KEY (job_id) REFERENCES compliance.wf_job(id);


--
-- Name: wf_organization organizations_jobs_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_organization
    ADD CONSTRAINT organizations_jobs_id_fk FOREIGN KEY (job_id) REFERENCES compliance.wf_job(id);


--
-- Name: wf_organization organizations_superior_id_fk_2; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_organization
    ADD CONSTRAINT organizations_superior_id_fk_2 FOREIGN KEY (superior_id) REFERENCES compliance.wf_organization(id);


--
-- Name: wf_organization organizations_users_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_organization
    ADD CONSTRAINT organizations_users_id_fk FOREIGN KEY (user_id) REFERENCES compliance.wf_user(id);


--
-- Name: wf_run_inbox_task run_inbox_task_run_wf_instance_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_inbox_task
    ADD CONSTRAINT run_inbox_task_run_wf_instance_id_fk FOREIGN KEY (wf_instance_id) REFERENCES compliance.wf_run_workflow(id);


--
-- Name: wf_run_inbox_task run_inbox_task_users_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_inbox_task
    ADD CONSTRAINT run_inbox_task_users_id_fk FOREIGN KEY (user_id) REFERENCES compliance.wf_user(id);


--
-- Name: wf_run_notification_outbox run_notification_outbox_run_step_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_notification_outbox
    ADD CONSTRAINT run_notification_outbox_run_step_id_fk FOREIGN KEY (step_instance_id) REFERENCES compliance.wf_run_step(id);


--
-- Name: wf_run_recipient_result run_recipient_result_run_step_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_recipient_result
    ADD CONSTRAINT run_recipient_result_run_step_id_fk FOREIGN KEY (step_instance_id) REFERENCES compliance.wf_run_step(id);


--
-- Name: wf_run_recipient_result run_recipient_result_users_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_recipient_result
    ADD CONSTRAINT run_recipient_result_users_id_fk FOREIGN KEY (user_id) REFERENCES compliance.wf_user(id);


--
-- Name: wf_run_step run_step_run_wf_instance_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_step
    ADD CONSTRAINT run_step_run_wf_instance_id_fk FOREIGN KEY (wf_instance_id) REFERENCES compliance.wf_run_workflow(id);


--
-- Name: wf_run_workflow run_workflow_user_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_workflow
    ADD CONSTRAINT run_workflow_user_id_fk FOREIGN KEY (requester) REFERENCES compliance.wf_user(id);


--
-- Name: wf_run_workflow run_workflow_version_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_workflow
    ADD CONSTRAINT run_workflow_version_id_fk FOREIGN KEY (run_version_id) REFERENCES compliance.wf_run_version(id);


--
-- Name: wf_schema schema_server_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_schema
    ADD CONSTRAINT schema_server_id_fk FOREIGN KEY (server_id) REFERENCES compliance.wf_server(id);


--
-- Name: wf_user_group user_group_group_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_user_group
    ADD CONSTRAINT user_group_group_id_fk FOREIGN KEY (group_id) REFERENCES compliance.wf_group(id);


--
-- Name: wf_user_group user_group_user_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_user_group
    ADD CONSTRAINT user_group_user_id_fk FOREIGN KEY (user_id) REFERENCES compliance.wf_user(id);


--
-- Name: wf_fcm wf_fcm_wf_user_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_fcm
    ADD CONSTRAINT wf_fcm_wf_user_id_fk FOREIGN KEY (user_id) REFERENCES compliance.wf_user(id);


--
-- Name: wf_run_notification_outbox wf_notification_outbox_wf_run_recipient_result_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_notification_outbox
    ADD CONSTRAINT wf_notification_outbox_wf_run_recipient_result_id_fk FOREIGN KEY (recipient_result_id) REFERENCES compliance.wf_run_recipient_result(id);


--
-- Name: wf_pending wf_pending_wf_user_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_pending
    ADD CONSTRAINT wf_pending_wf_user_id_fk FOREIGN KEY (requester) REFERENCES compliance.wf_user(id);


--
-- Name: wf_run_inbox_task wf_run_inbox_task_wf_run_recipient_result_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_inbox_task
    ADD CONSTRAINT wf_run_inbox_task_wf_run_recipient_result_id_fk FOREIGN KEY (recipient_result_id) REFERENCES compliance.wf_run_recipient_result(id);


--
-- Name: wf_run_notification_outbox wf_run_notification_outbox_wf_run_workflow_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_notification_outbox
    ADD CONSTRAINT wf_run_notification_outbox_wf_run_workflow_id_fk FOREIGN KEY (wf_instance_id) REFERENCES compliance.wf_run_workflow(id);


--
-- Name: wf_run_parameter wf_run_parameters_wf_run_workflow_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_parameter
    ADD CONSTRAINT wf_run_parameters_wf_run_workflow_id_fk FOREIGN KEY (wf_instance_id) REFERENCES compliance.wf_run_workflow(id);


--
-- Name: wf_run_step wf_run_step_wf_run_step_id_fk; Type: FK CONSTRAINT; Schema: compliance; Owner: postgres
--

ALTER TABLE ONLY compliance.wf_run_step
    ADD CONSTRAINT wf_run_step_wf_run_step_id_fk FOREIGN KEY (previous_step) REFERENCES compliance.wf_run_step(id);


--
-- Name: TABLE action_plan; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.action_plan TO app_role;


--
-- Name: TABLE approved_attestation; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.approved_attestation TO app_role;


--
-- Name: TABLE attestation; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.attestation TO app_role;


--
-- Name: TABLE comment; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.comment TO app_role;


--
-- Name: TABLE comment_attestation; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.comment_attestation TO app_role;


--
-- Name: TABLE department_related; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.department_related TO app_role;


--
-- Name: TABLE gap_assessment; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.gap_assessment TO app_role;


--
-- Name: TABLE gap_evidence; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.gap_evidence TO app_role;


--
-- Name: TABLE hod_gap_assessment; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.hod_gap_assessment TO app_role;


--
-- Name: TABLE setting_status; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.setting_status TO app_role;


--
-- Name: TABLE status_of_action; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.status_of_action TO app_role;


--
-- Name: TABLE supporting_document; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.supporting_document TO app_role;


--
-- Name: TABLE upload_regulation; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.upload_regulation TO app_role;


--
-- Name: TABLE wf_config; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_config TO app_role;


--
-- Name: TABLE wf_employee; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_employee TO app_role;


--
-- Name: TABLE wf_fcm; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_fcm TO app_role;


--
-- Name: TABLE wf_group; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_group TO app_role;


--
-- Name: TABLE wf_job; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_job TO app_role;


--
-- Name: TABLE wf_job_group; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_job_group TO app_role;


--
-- Name: TABLE wf_organization; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_organization TO app_role;


--
-- Name: TABLE wf_pending; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_pending TO app_role;


--
-- Name: TABLE wf_run_inbox_task; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_run_inbox_task TO app_role;


--
-- Name: TABLE wf_run_notification_outbox; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_run_notification_outbox TO app_role;


--
-- Name: TABLE wf_run_parameter; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_run_parameter TO app_role;


--
-- Name: TABLE wf_run_recipient_result; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_run_recipient_result TO app_role;


--
-- Name: TABLE wf_run_step; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_run_step TO app_role;


--
-- Name: TABLE wf_run_version; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_run_version TO app_role;


--
-- Name: TABLE wf_run_workflow; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_run_workflow TO app_role;


--
-- Name: TABLE wf_schema; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_schema TO app_role;


--
-- Name: TABLE wf_server; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_server TO app_role;


--
-- Name: TABLE wf_user; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_user TO app_role;


--
-- Name: TABLE wf_user_group; Type: ACL; Schema: compliance; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,UPDATE ON TABLE compliance.wf_user_group TO app_role;


--
-- PostgreSQL database dump complete
--

