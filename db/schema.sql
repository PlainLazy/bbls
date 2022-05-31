--
-- PostgreSQL database dump
--

-- Dumped from database version 10.1
-- Dumped by pg_dump version 10.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: admin; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA admin;


--
-- Name: plpgsql; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS plpgsql WITH SCHEMA pg_catalog;


--
-- Name: EXTENSION plpgsql; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION plpgsql IS 'PL/pgSQL procedural language';


SET search_path = admin, pg_catalog;

--
-- Name: _create_new_admin(text, text); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION _create_new_admin(t_login text, t_passw text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	t_salt text;
	rw_admin "admin"."admins"%rowtype;
	
begin
	
	
	-- salt
	
	select "value" from "admin"."config" where "key" = 'admin_passw_salt'
	into t_salt;
	
	if t_salt is null then
		return jsonb_build_object('err', 'e_internal', 'msg', 'admin passw salt not defined');
	end if;
	
	
	-- creating
	
	rw_admin."id" = nextval('"admin"."admins_id_seq"');
	rw_admin."login" = t_login;
	rw_admin."passw" = md5(format('%s%s', t_salt, t_passw));
	
	insert into "admin"."admins" values (rw_admin.*);
	
	
	-- done
	
	return jsonb_build_object(
		'err', null,
		'id', rw_admin."id"
	);
	
	
end;$$;


--
-- Name: login(jsonb); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION login(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	t_salt text;
	rw_admin "admin"."admins"%rowtype;
	rw_sess "admin"."sessions"%rowtype;
	
begin
	
	
	-- params
	
	if j_cm->'login' is null then
		return jsonb_build_object('err', 'e_adm_login_internal', 'msg', 'login required');
	end if;
	
	if j_cm->'passw' is null then
		return jsonb_build_object('err', 'e_adm_login_internal', 'msg', 'passw required');
	end if;
	
	
	-- salt
	
	select "value" from "admin"."config" where "key" = 'admin_passw_salt'
	into t_salt;
	
	if t_salt is null then
		return jsonb_build_object('err', 'e_adm_login_internal', 'msg', 'passw salt not defined');
	end if;
	
	
	-- check
	
	select * from "admin"."admins" where "login" = j_cm->>'login' and "passw" = md5(format('%s%s', t_salt, j_cm->>'passw')) for update
	into rw_admin;
	
	if rw_admin."id" is null then
		return jsonb_build_object('err', 'e_adm_login_not_found', 'msg', 'invalid login or passw');
	end if;
	
	update "public"."players" set "atime" = timezone('utc', now()) where "id" = rw_admin."id";
	
	
	rw_sess."id" = nextval('"admin"."sessions_id_seq"');
	rw_sess."ctime" = timezone('utc', now());
	rw_sess."atime" = timezone('utc', now());
	rw_sess."admin" = rw_admin."id";
	rw_sess."token" = md5(format('%s%s%s', rw_sess."ctime", '_642salt930_', rw_sess."id"));
	
	insert into "admin"."sessions" values (rw_sess.*);
	
	
	return jsonb_build_object(
		'err', null,
		'token', format('admin-%s', rw_sess."token")
	);
	
	
end;$$;


--
-- Name: logout(jsonb, text); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION logout(j_cm jsonb, t_token text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_admin int8;
	rw_admin "admin"."admins"%rowtype;
	rw_sess "admin"."sessions"%rowtype;
	
begin
	
	
	i_admin = (j_cm->>'_admin')::int8;
	
	if i_admin is null then
		return jsonb_build_object('err', 'e_adm_not_auth', 'msg', 'admin auth required');
	end if;
	
	
	if j_cm->>'all' = 'true' then
		
		delete from "admin"."sessions" where "admin" = i_admin;
		
	else
		
		delete from "admin"."sessions" where "token" = t_token;
		
	end if;
	
	
	return jsonb_build_object(
		'err', null
	);
	
	
end;$$;


--
-- Name: player_state_get(jsonb); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION player_state_get(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_admin int8;
	rw_player "public"."players"%rowtype;
	
begin
	
	
	i_admin = (j_cm->>'_admin')::int8;
	
	if i_admin is null then
		return jsonb_build_object('err', 'e_adm_not_auth', 'msg', 'admin auth required');
	end if;
	
	
	begin
		rw_player."id" = (j_cm->>'player')::int8;
	exception
		when others then
			return jsonb_build_object('err', 'e_invalid_params', 'msg', SQLERRM);
	end;
	
	
	select * from "public"."players" where "id" = rw_player."id"
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', j_cm->'player'));
	end if;
	
	
	return jsonb_build_object(
		'err', null,
		'data', rw_player."state",
		'time', extract(epoch from now())::int8
	);
	
	
end;$$;


--
-- Name: player_state_set(jsonb); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION player_state_set(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_admin int8;
	rw_player "public"."players"%rowtype;
	j_state jsonb;
	
begin
	
	
	i_admin = (j_cm->>'_admin')::int8;
	
	if i_admin is null then
		return jsonb_build_object('err', 'e_adm_not_auth', 'msg', 'admin auth required');
	end if;
	
	
	begin
		rw_player."id" = (j_cm->>'player')::int8;
		assert rw_player."id" is not null, '"player" is null';
	exception
		when others or assert_failure then
			return jsonb_build_object('err', 'e_invalid_params', 'msg', SQLERRM);
	end;
	
	
	if not(j_cm ? 'data') then
		return jsonb_build_object('err', 'e_invalid_params', 'msg', '"data" required');
	end if;
	
	
	select * from "public"."players" where "id" = rw_player."id" for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', j_cm->'player'));
	end if;
	
	
	update "public"."players" set "state" = j_cm->'data' where "id" = rw_player."id";
	
	
	return jsonb_build_object(
		'err', null,
		'time', extract(epoch from now())::int8
	);
	
	
end;$$;


--
-- Name: players_list(jsonb); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION players_list(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_admin int8;
	
	t_order text;
	b_asc bool;
	i_offset int8;
	i_limit int8;
	i_xlimit int8;
	
	i_filter__id int8;
	t_filter__dev_id text;
	t_filter__fb_id text;
	
	c1 refcursor;
	r1 record;
	i_total int8;
	t_query text;
	a_result jsonb[];
	
begin
	
	
	i_admin = (j_cm->>'_admin')::int8;
	
	if i_admin is null then
		return jsonb_build_object('err', 'e_adm_not_auth', 'msg', 'admin auth required');
	end if;
	
	
	b_asc = j_cm->>'dir' = 'ASC';
	t_order = j_cm->>'order';
	
	begin
		i_offset = coalesce((j_cm->>'offset')::int8, 0);
		i_limit = least(greatest(coalesce((j_cm->>'limit')::int8, 50), 1), 500);
	exception
		when others then
			return jsonb_build_object('err', 'e_invalid params', 'msg', SQLERRM);
	end;
	
	i_xlimit = i_limit;
	
	
	-- filter by id
	
	begin
		i_filter__id = (j_cm#>>'{filters,id}')::int8;
	exception
		when others then
			null;
	end;
	
	
	-- filter by dev_id
	
	t_filter__dev_id = j_cm#>>'{filters,dev_id}';
	if t_filter__dev_id is not null then
		t_filter__dev_id = '%' || regexp_replace(t_filter__dev_id, '[\%\_\\]', '\\\&', 'g') || '%';  -- ilike safe
	end if;
	
	
	-- filter by fb_id
	
	t_filter__fb_id = j_cm#>>'{filters,fb_id}';
	if t_filter__fb_id is not null then
		t_filter__fb_id = '%' || regexp_replace(t_filter__fb_id, '[\%\_\\]', '\\\&', 'g') || '%';  -- ilike safe
	end if;
	
	
	-- request
	
	open c1 for
	select "id", "ctime", "device_id", "fb_id"
	from "public"."players"
	where
		
		(i_filter__id is null or "id" = i_filter__id)
			and
		(t_filter__dev_id is null or "device_id" ilike t_filter__dev_id)
			and
		(t_filter__fb_id is null or "fb_id" ilike t_filter__fb_id)
		
	order by
		
		-- order by int8
		
		case when not b_asc then
			case when t_order = 'id' then "id"
			else null end
		else null end desc,
		
		case when b_asc then
			case when t_order = 'id' then "id"
			else null end
		else null end asc,
		
		-- order by timestamp
		
		case when not b_asc then
			case when t_order = 'ctime' then "ctime"
			else null end
		else null end desc,
		
		case when b_asc then
			case when t_order = 'ctime' then "ctime"
			else null end
		else null end asc,
		
		-- order by text
		
		case when not b_asc then
			case
				when t_order = 'dev_id' then "device_id"
				when t_order = 'fb_id' then "fb_id"
			else null end
		else null end desc,
		
		case when b_asc then
			case
				when t_order = 'dev_id' then "device_id"
				when t_order = 'fb_id' then "fb_id"
			else null end
		else null end asc;
	
	
	move forward all in c1;
	get diagnostics i_total = ROW_COUNT;
	--raise log 'i_total=%', i_total;
	--move first in c1;
	move absolute 0 in c1;
	move forward i_offset in c1;
	loop
		fetch c1 into r1;
		exit when not found;
		a_result = a_result || jsonb_build_object(
			'id', r1."id",
			'ctime', extract(epoch from r1."ctime")::int8,
			'dev_id', r1."device_id",
			'fb_id', r1."fb_id"
		);
		exit when i_xlimit <= 1;
		i_xlimit = i_xlimit - 1;
	end loop;
	close c1;
	
	
	return jsonb_build_object(
		'err', null,
		'admin', i_admin,
		'time', extract(epoch from now())::int8,
		'total', i_total,
		'offset', i_offset,
		'limit', i_limit,
		'data',  coalesce(a_result, array[]::jsonb[])
	);
	
	
end;$$;


--
-- Name: state_get(jsonb); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION state_get(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_admin int8;
	
begin
	
	
	i_admin = (j_cm->>'_admin')::int8;
	
	if i_admin is null then
		return jsonb_build_object('err', 'e_adm_not_auth', 'msg', 'admin auth required');
	end if;
	
	
	return jsonb_build_object(
		'err', null,
		'admin', i_admin,
		'time', extract(epoch from now())::int8
	);
	
	
end;$$;


--
-- Name: statistics2_get(jsonb); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION statistics2_get(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_admin int8;
	ts_min timestamp without time zone;
	ts_max timestamp without time zone;
	i_level_min int8;
	i_level_max int8;
	ts_check timestamp;
	a_available_levels text[];
	i_level int8;
	t_level text;
	i_result1 int8;
	i_result2 int8;
	f_result1 float8;
	r_result record;
	i_players_total int8;
	j_statistics jsonb = jsonb_build_object();
	j_data_list jsonb = jsonb_build_array();
	j_data_item jsonb;
	
	i_result_enters int8;
	i_result_bonus1buy int8;
	i_result_bonus2buy int8;
	i_result_bonus3buy int8;
	i_result_bubblebuy int8;
	i_result_lifebuy int8;
	i_result_winscnt int8;
	i_result_winsavgscore int8;
	i_result_winsstar1pc int8;
	i_result_winsstar2pc int8;
	i_result_winsstar3pc int8;
	f_result_purchase float8;
	
begin
	
	
	i_admin = (j_cm->>'_admin')::int8;
	
	if i_admin is null then
		return jsonb_build_object('err', 'e_adm_not_auth', 'msg', 'admin auth required');
	end if;
	
	
	begin
		--rw_player."id" = (j_cm->>'player')::int8;
		ts_min = timezone('utc', to_timestamp((j_cm->>'utc_min')::int8));
		ts_max = timezone('utc', to_timestamp((j_cm->>'utc_max')::int8));
		i_level_min = (j_cm->>'level_min')::int8;
		i_level_max = (j_cm->>'level_max')::int8;
	exception
		when others then
			return jsonb_build_object('err', 'e_invalid_params', 'msg', SQLERRM);
	end;
	
	--raise log '=== ts_min %, ts_max %', ts_min, ts_max;
	
	
	ts_check = clock_timestamp();
	
	
	if i_level_min is null then
		select coalesce(min(("event"->>'level')::int8), 0) from "public"."events" where jsonb_typeof("event"->'level') = 'number' into i_level_min;
	end if;
	
	if i_level_max is null then
		select coalesce(max(("event"->>'level')::int8), 10) from "public"."events" where jsonb_typeof("event"->'level') = 'number' into i_level_max;
	end if;
	
	
	--i_level_min = 0;
	--i_level_max = 30;
	
	
	select array_agg( distinct "event"->>'level' ) from "public"."events" where "event" ? 'level' into a_available_levels;
	raise log '=== a_available_levels %', a_available_levels;
	
	
	select count("id") from "public"."players" into i_players_total;
	raise log '=== i_players_total %', i_players_total;
	
	
	create temp table "events_t1" on commit drop as
	select * from "public"."events"
	where (ts_min is null or "ctime" >= ts_min)
	  and (ts_max is null or "ctime" <= ts_max)
	  and (i_level_min is not null or "event"->'level' >= to_jsonb(i_level_min))
	  and (i_level_max is not null or "event"->'level' <= to_jsonb(i_level_max));
	
	
	
	
	
	
	for i_level in i_level_min .. i_level_max loop
		
		
		if array_position(a_available_levels, i_level::text) is null then
			continue;
		end if;
		
		
		
		
		create temp table "events_lvl" on commit drop as
		select * from "events_t1"
		where "event"->'level' = to_jsonb(i_level);
		
		
		create temp table "events_win_lvl" on commit drop as
		select * from "events_lvl"
		where "event"->>'type' = 'win';
		
		
		select count("id") from "events_lvl" where "event"->>'type' = 'enter' into i_result_enters;
		select count("id") from "events_lvl" where "event"->>'type' = 'bonus1buy' into i_result_bonus1buy;
		select count("id") from "events_lvl" where "event"->>'type' = 'bonus2buy' into i_result_bonus2buy;
		select count("id") from "events_lvl" where "event"->>'type' = 'bonus3buy' into i_result_bonus3buy;
		select count("id") from "events_lvl" where "event"->>'type' = 'bubblebuy' into i_result_bubblebuy;
		select count("id") from "events_lvl" where "event"->>'type' = 'lifebuy' into i_result_lifebuy;
		select sum(("event"->>'summ')::float8) from "events_lvl" where "event"->>'type' = 'purchase' and jsonb_typeof("event"->'summ') = 'number' into f_result_purchase;
		
		
		select
			count("id") "_total",
			(sum(("event"->>'score')::int8) / count("id"))::int8 "_avg_score"
		from "events_win_lvl"
		where jsonb_typeof("event"->'score') = 'number'
		into
			i_result_winscnt,
			i_result_winsavgscore;
		
		
		select count("id") from "events_win_lvl" where "event"->'stars' = to_jsonb(1) into i_result_winsstar1pc;
		select count("id") from "events_win_lvl" where "event"->'stars' = to_jsonb(2) into i_result_winsstar2pc;
		select count("id") from "events_win_lvl" where "event"->'stars' = to_jsonb(3) into i_result_winsstar3pc;
		
		
		j_data_item = jsonb_build_object(
			'level', i_level,
			
			'01_enters_cnt', coalesce(i_result_enters, 0),
			'02_loses_cnt', (select count("id") from "events_lvl" where "event"->>'type' = 'lose'),
			'03_leaves_cnt', (select count("id") from "events_lvl" where "event"->>'type' = 'leave'),
			'04_wins_cnt', i_result_winscnt,
			'05_players_last_levels', (select count("id") from "public"."players" where "state"->'lastLevel' = to_jsonb(i_level)),
			
			'07_wins_avg_score', i_result_winsavgscore,
			'08_wins_star1_pc', case when i_result_winscnt != 0 then ((i_result_winsstar1pc / i_result_winscnt::float8)*100)::int8 else 0 end,
			'09_wins_star2_pc', case when i_result_winscnt != 0 then ((i_result_winsstar2pc / i_result_winscnt::float8)*100)::int8 else 0 end,
			'10_wins_star3_pc', case when i_result_winscnt != 0 then ((i_result_winsstar3pc / i_result_winscnt::float8)*100)::int8 else 0 end,
			
			'13_bonus1buy_cnt', i_result_bonus1buy,
			'14_bonus1buy_avg', case when i_result_enters != 0 then i_result_bonus1buy/i_result_enters::float8 else 0 end,
			
			'15_bonus2buy_cnt', i_result_bonus2buy,
			'16_bonus2buy_avg', case when i_result_enters != 0 then i_result_bonus2buy/i_result_enters::float8 else 0 end,
			
			'17_bonus3buy_cnt', i_result_bonus3buy,
			'18_bonus3buy_avg', case when i_result_enters != 0 then i_result_bonus3buy/i_result_enters::float8 else 0 end,
			
			'19_bubblebuy_cnt', i_result_bubblebuy,
			'20_bubblebuy_avg', case when i_result_enters != 0 then i_result_bubblebuy/i_result_enters::float8 else 0 end,
			
			'21_lifebuy_cnt', i_result_lifebuy,
			'22_lifebuy_avg', case when i_result_enters != 0 then i_result_lifebuy/i_result_enters::float8 else 0 end,
			
			'23_bindfb_cnt', (select count("id") from "events_lvl" where "event"->>'type' = 'bindfb'),
			'24_invites_cnt', (select count("id") from "events_lvl" where "event"->>'type' in ('invite_send', 'invite_accept')),
			'25_gotlife_cnt', (select count("id") from "events_lvl" where "event"->>'type' = 'got_life'),
			
			'28_revenue', coalesce(f_result_purchase, 0),
			'29_ARPU', case when i_players_total != 0 then coalesce(f_result_purchase, 0) / i_players_total::float8 else 0 end
			
		);
		
		
		drop table "events_lvl";
		drop table "events_win_lvl";
		
		
		j_data_list = j_data_list || j_data_item;
		
	end loop;
	
	
	return jsonb_build_object(
		'err', null,
		'data', j_data_list,
		'time', extract(epoch from now())::int8,
		'working_time', extract(milliseconds from (clock_timestamp() - ts_check)) / 1000
	);
	
	
end;$$;


--
-- Name: statistics_get(jsonb); Type: FUNCTION; Schema: admin; Owner: -
--

CREATE FUNCTION statistics_get(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_admin int8;
	ts_min timestamp without time zone;
	ts_max timestamp without time zone;
	ts_check timestamp;
	i_level int8;
	t_level text;
	i_result1 int8;
	i_result2 int8;
	f_result1 float8;
	r_result record;
	i_players_total int8;
	j_statistics jsonb = jsonb_build_object();
	
begin
	
	
	i_admin = (j_cm->>'_admin')::int8;
	
	if i_admin is null then
		return jsonb_build_object('err', 'e_adm_not_auth', 'msg', 'admin auth required');
	end if;
	
	
	begin
		--rw_player."id" = (j_cm->>'player')::int8;
		ts_min = timezone('utc', to_timestamp((j_cm->>'utc_min')::int8));
		ts_max = timezone('utc', to_timestamp((j_cm->>'utc_max')::int8));
	exception
		when others then
			return jsonb_build_object('err', 'e_invalid_params', 'msg', SQLERRM);
	end;
	
	--raise log '=== ts_min %, ts_max %', ts_min, ts_max;
	
	
	ts_check = clock_timestamp();
	
	
	select count("id") from "public"."players" into i_players_total;
	
	
	
	create temp table "events_t1" on commit drop as
	select * from "public"."events"
	where (ts_min is null or "ctime" >= ts_min) and (ts_max is null or "ctime" <= ts_max);
	
	
	create temp table "events_win1" on commit drop as
	select * from "events_t1"
	where "event"->>'type' = 'win';
	
	
	j_statistics = jsonb_set(j_statistics, '{01_enters_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{02_loses_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{03_leaves_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{04_wins_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{05_players_last_levels}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{07_wins_avg_score}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{08_wins_star1_pc}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{09_wins_star2_pc}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{10_wins_star3_pc}', '[]'::jsonb);
	
	j_statistics = jsonb_set(j_statistics, '{13_bonus1buy_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{14_bonus1buy_avg}', '[]'::jsonb);
	
	j_statistics = jsonb_set(j_statistics, '{15_bonus2buy_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{16_bonus2buy_avg}', '[]'::jsonb);
	
	j_statistics = jsonb_set(j_statistics, '{17_bonus3buy_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{18_bonus3buy_avg}', '[]'::jsonb);
	
	j_statistics = jsonb_set(j_statistics, '{19_bubblebuy_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{20_bubblebuy_avg}', '[]'::jsonb);
	
	j_statistics = jsonb_set(j_statistics, '{21_lifebuy_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{22_lifebuy_avg}', '[]'::jsonb);
	
	j_statistics = jsonb_set(j_statistics, '{23_bindfb_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{24_invites_cnt}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{25_gotlife_cnt}', '[]'::jsonb);
	
	j_statistics = jsonb_set(j_statistics, '{28_revenue}', '[]'::jsonb);
	j_statistics = jsonb_set(j_statistics, '{29_ARPU}', '[]'::jsonb);
	
	
	for i_level in 1..15 loop
		
		
		t_level = format('%s', i_level-1);
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'enter' and "event"->'level' = to_jsonb(i_level)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['01_enters_cnt', t_level], to_jsonb(coalesce(i_result1, 0)));
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'bonus1buy' and "event"->'level' = to_jsonb(i_level)
		into i_result2;
		j_statistics = jsonb_set(j_statistics, array['13_bonus1buy_cnt', t_level], to_jsonb(i_result2));
		j_statistics = jsonb_set(j_statistics, array['14_bonus1buy_avg', t_level], case when i_result1 != 0 then to_jsonb(i_result2/i_result1::float8) else to_jsonb(0) end);
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'bonus2buy' and "event"->'level' = to_jsonb(i_level)
		into i_result2;
		j_statistics = jsonb_set(j_statistics, array['15_bonus2buy_cnt', t_level], to_jsonb(i_result2));
		j_statistics = jsonb_set(j_statistics, array['16_bonus2buy_avg', t_level], case when i_result1 != 0 then to_jsonb(i_result2/i_result1::float8) else to_jsonb(0) end);
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'bonus3buy' and "event"->'level' = to_jsonb(i_level)
		into i_result2;
		j_statistics = jsonb_set(j_statistics, array['17_bonus3buy_cnt', t_level], to_jsonb(i_result2));
		j_statistics = jsonb_set(j_statistics, array['18_bonus3buy_avg', t_level], case when i_result1 != 0 then to_jsonb(i_result2/i_result1::float8) else to_jsonb(0) end);
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'bubblebuy' and "event"->'level' = to_jsonb(i_level)
		into i_result2;
		j_statistics = jsonb_set(j_statistics, array['19_bubblebuy_cnt', t_level], to_jsonb(i_result2));
		j_statistics = jsonb_set(j_statistics, array['20_bubblebuy_avg', t_level], case when i_result1 != 0 then to_jsonb(i_result2/i_result1::float8) else to_jsonb(0) end);
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'lifebuy' and "event"->'level' = to_jsonb(i_level)
		into i_result2;
		j_statistics = jsonb_set(j_statistics, array['21_lifebuy_cnt', t_level], to_jsonb(i_result2));
		j_statistics = jsonb_set(j_statistics, array['22_lifebuy_avg', t_level], case when i_result1 != 0 then to_jsonb(i_result2/i_result1::float8) else to_jsonb(0) end);
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'lose' and "event"->'level' = to_jsonb(i_level)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['02_loses_cnt', t_level], to_jsonb(coalesce(i_result1, 0)));
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'leave' and "event"->'level' = to_jsonb(i_level)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['03_leaves_cnt', t_level], to_jsonb(coalesce(i_result1, 0)));
		
		
		select count("id") from "public"."players" where "state"->'lastLevel' = to_jsonb(i_level)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['05_players_last_levels', t_level], to_jsonb(coalesce(i_result1, 0)));
		
		
		
		
		
		
		select
			count("id") "_total",
			(sum(("event"->>'score')::int8) / count("id"))::int8 "_avg_score"
		from "events_win1" where "event"->'level' = to_jsonb(i_level)
		into r_result;
		j_statistics = jsonb_set(j_statistics, array['04_wins_cnt', t_level], to_jsonb(r_result."_total"));
		j_statistics = jsonb_set(j_statistics, array['07_wins_avg_score', t_level], to_jsonb(r_result."_avg_score"));
		
		-- x1 stars
		select count("id") from "events_win1" where "event"->'level' = to_jsonb(i_level) and "event"->'stars' = to_jsonb(1)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['08_wins_star1_pc', t_level], case when r_result."_total" != 0 then to_jsonb(i_result1 / r_result."_total"::float8) else to_jsonb(0) end);
		
		-- x2 stars
		select count("id") from "events_win1" where "event"->'level' = to_jsonb(i_level) and "event"->'stars' = to_jsonb(2)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['09_wins_star2_pc', t_level], case when r_result."_total" != 0 then to_jsonb(i_result1 / r_result."_total"::float8) else to_jsonb(0) end);
		
		-- x3 stars
		select count("id") from "events_win1" where "event"->'level' = to_jsonb(i_level) and "event"->'stars' = to_jsonb(3)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['10_wins_star3_pc', t_level], case when r_result."_total" != 0 then to_jsonb(i_result1 / r_result."_total"::float8) else to_jsonb(0) end);
		
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'bindfb' and "event"->'level' = to_jsonb(i_level)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['23_bindfb_cnt', t_level], to_jsonb(coalesce(i_result1, 0)));
		
		
		select count("id") from "events_t1" where "event"->>'type' in ('invite_send', 'invite_accept') and "event"->'level' = to_jsonb(i_level)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['24_invites_cnt', t_level], to_jsonb(coalesce(i_result1, 0)));
		
		
		select count("id") from "events_t1" where "event"->>'type' = 'got_life' and "event"->'level' = to_jsonb(i_level)
		into i_result1;
		j_statistics = jsonb_set(j_statistics, array['25_gotlife_cnt', t_level], to_jsonb(coalesce(coalesce(i_result1, 0), 0)));
		
		
		select sum(("event"->>'summ')::float8) from "events_t1" where "event"->>'type' = 'purchase' and "event"->'level' = to_jsonb(i_level)
		into f_result1;
		j_statistics = jsonb_set(j_statistics, array['28_revenue', t_level], to_jsonb(coalesce(f_result1, 0)));
		
		
		j_statistics = jsonb_set(j_statistics, array['29_ARPU', t_level], case when i_players_total != 0 then to_jsonb(coalesce(f_result1 / i_players_total::float8, 0)) else to_jsonb(0) end);
		
		
		
		
	end loop;
	
	
	return jsonb_build_object(
		'err', null,
		'statistics', j_statistics,
		'time', extract(epoch from now())::int8,
		'working_time', extract(milliseconds from (clock_timestamp() - ts_check)) / 1000
	);
	
	
end;$$;


SET search_path = public, pg_catalog;

--
-- Name: _fb_auth(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _fb_auth(j_fb_acc jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	rw_player "public"."players"%rowtype;
	rw_sess "public"."sessions"%rowtype;
	
begin
	
	
	if j_fb_acc->'id' is null then
		return jsonb_build_object('err', 'e_fb_auth_internal', 'msg', 'fb_acc.id required');
	end if;
	
	if j_fb_acc->'email' is null then
		return jsonb_build_object('err', 'e_fb_auth_internal', 'msg', 'fb_acc.email required');
	end if;
	
	
	lock table "public"."players" in share mode;
	
	select * from "public"."players" where "fb_id" = j_fb_acc->>'id' for update
	into rw_player;
	
	if rw_player."id" is null then
		
		rw_player."id" = nextval('"public"."players_id_seq"');
		rw_player."ctime" = timezone('utc', now());
		rw_player."atime" = timezone('utc', now());
		rw_player."fb_id" = j_fb_acc->>'id';
		rw_player."fb_email" = j_fb_acc->>'email';
		rw_player."fb_acc" = j_fb_acc;
		
		insert into "public"."players" values (rw_player.*);
		
	else
		
		update "public"."players" set
			"atime" = timezone('utc', now()),
			"fb_acc" = j_fb_acc
		where "id" = rw_player."id";
		
	end if;
	
	
	rw_sess."id" = nextval('"public"."sessions_id_seq"');
	rw_sess."ctime" = timezone('utc', now());
	rw_sess."atime" = timezone('utc', now());
	rw_sess."player" = rw_player."id";
	rw_sess."token" = md5(format('%s%s%s', rw_sess."ctime", '_254salt810_', rw_sess."id"));
	
	insert into "public"."sessions" values (rw_sess.*);
	
	
	return jsonb_build_object(
		'err', null,
		'token', rw_sess."token"
	);
	
	
end;$$;


--
-- Name: _recalc_level_pack_players(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _recalc_level_pack_players(_level_id text) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	rw_level "public"."levels_packs"%rowtype;
	i_players int8;
	
begin
	
	
	--raise log '_recalc_level_pack_players %', _level_id;
	
	
	select * from "public"."levels_packs" where "level_id" = _level_id
	into rw_level;
	
	if rw_level."id" is null then
		return jsonb_build_object('err', 'level not found');
	end if;
	
	
	select count("id") from "public"."players" where "levels_pack" = rw_level."level_id"
	into i_players;
	
	
	update "public"."levels_packs" set "players_count" = i_players where "id" = rw_level."id";
	
	
	--raise log 'i_players %', i_players;
	
	
	return jsonb_build_object('players', i_players);
	
	
end;$$;


--
-- Name: _recalc_player_max_level(bigint); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION _recalc_player_max_level(_player bigint) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	rw_level "public"."levels_packs"%rowtype;
	i_players int8;
	
begin
	
	
	update "public"."players" set
		"max_level" = (
			select max("level") from "public"."progress" where "player" = _player
		)
	where "id" = _player;
	
	
	return jsonb_build_object('status', 'OK');
	
	
end;$$;


--
-- Name: device_auth(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION device_auth(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	rw_player "public"."players"%rowtype;
	rw_sess "public"."sessions"%rowtype;
	
begin
	
	
	if j_cm->'id' is null then
		return jsonb_build_object('err', 'e_dev_auth_internal', 'msg', 'param "id" required');
	end if;
	
	if j_cm->'secret' is null then
		return jsonb_build_object('err', 'e_dev_auth_internal', 'msg', 'param "secret" required');
	end if;
	
	
	select * from "public"."players" where "device_id" = j_cm->>'id' and "device_secret" = j_cm->>'secret' for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_dev_auth_not_found', 'msg', 'invalid id or secret');
	end if;
	
	
	update "public"."players" set "atime" = timezone('utc', now()) where "id" = rw_player."id";
	
	
	rw_sess."id" = nextval('"public"."sessions_id_seq"');
	rw_sess."ctime" = timezone('utc', now());
	rw_sess."atime" = timezone('utc', now());
	rw_sess."player" = rw_player."id";
	rw_sess."token" = md5(format('%s%s%s', rw_sess."ctime", '_547salt201_', rw_sess."id"));
	
	insert into "public"."sessions" values (rw_sess.*);
	
	
	return jsonb_build_object(
		'err', null,
		'token', rw_sess."token"
	);
	
	
end;$$;


--
-- Name: device_reg(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION device_reg(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	rw_player "public"."players"%rowtype;
	
begin
	
	
	if j_cm->'id' is null then
		return jsonb_build_object('err', 'e_dev_reg_internal', 'msg', 'param "id" required');
	end if;
	
	
	lock table "public"."players" in share mode;
	
	
	select * from "public"."players" where "device_id" = j_cm->>'id'
	into rw_player;
	
	
	if rw_player."id" is null then
		
		
		rw_player."id" = nextval('"public"."players_id_seq"');
		rw_player."ctime" = timezone('utc', now());
		rw_player."device_id" = j_cm->>'id';
		rw_player."device_secret" = left(md5(format('%s%s%s', rw_player."ctime", '_145salt931_', rw_player."id")), 16);
		
		insert into "public"."players" values (rw_player.*);
		
		
	else
		
		
		if rw_player."atime" is not null then
			return jsonb_build_object(
				'err', 'e_dev_reg_used',
				'msg', format('device "%s" already registered and activated', j_cm->>'id')
			);
		end if;
		
		rw_player."device_secret" = left(md5(format('%s%s%s', timezone('utc', now()), '_145salt931_', rw_player."id")), 16);
		
		update "public"."players" set "device_secret" = rw_player."device_secret" where "id" = rw_player."id";
		
		
	end if;
	
	
	return jsonb_build_object(
		'err', null,
		'secret', rw_player."device_secret"
	);
	
	
end;$$;


--
-- Name: event(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION event(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	rw_event "public"."events"%rowtype;
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required for "event"');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	rw_event."id" = nextval('"public"."events_id_seq"');
	rw_event."ctime" = timezone('utc', now());
	rw_event."player" = rw_player."id";
	rw_event."event" = j_cm->'data';
	
	insert into "public"."events" values (rw_event.*);
	
	
	return jsonb_build_object('err', null);
	
	
end;$$;


--
-- Name: fb_move(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fb_move(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	rw_target_player "public"."players"%rowtype;
	rw_target_sess "public"."sessions"%rowtype;
	
begin
	
	
	-- origin account
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_fb_move_internal', 'msg', 'no player');
	end if;
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_fb_move_internal', 'msg', 'no origin account');
	end if;
	
	if rw_player."fb_id" is null then
		return jsonb_build_object('err', 'e_fb_move_invalid_origin', 'msg', 'origin account have no binded facebook user');
	end if;
	
	
	-- target account
	
	if j_cm->'target' is null then
		return jsonb_build_object('err', 'e_fb_move_internal', 'msg', 'param "target" required');
	end if;
	
	select * from "public"."sessions" where "token" = j_cm->>'target' for update
	into rw_target_sess;
	
	if rw_target_sess."id" is null then
		return jsonb_build_object('err', 'e_fb_move_invalid_target', 'msg', 'target account not exists');
	end if;
	
	select * from "public"."players" where "id" = rw_target_sess."player" for update
	into rw_target_player;
	
	if rw_target_player."id" is null then
		return jsonb_build_object('err', 'e_fb_move_internal', 'msg', 'no target account');
	end if;
	
	
	-- fb migrate
	
	update "public"."players" set
		"fb_id" = rw_player."fb_id",
		"fb_email" = rw_player."fb_email",
		"fb_acc" = rw_player."fb_acc"
	where "id" = rw_target_player."id";
	
	update "public"."players" set
		"fb_id" = null,
		"fb_email" = null,
		"fb_acc" = null
	where "id" = rw_player."id";
	
	
	-- done
	
	return jsonb_build_object(
		'err', null
	);
	
	
end;$$;


--
-- Name: fb_players_level_scores(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fb_players_level_scores(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	i_level int8;
	a_fb_ids text[];
	a_players_ids int8[];
	rw_x_player "public"."players"%rowtype;
	i_score int8;
	j_result jsonb[];
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	begin
		i_level = (j_cm->>'level')::int8;
		assert i_level is not null, 'invalid level';
	exception
		when assert_failure or others then
			return jsonb_build_object('err', 'e_fb_players_level_scores_invalid_level', 'msg', SQLERRM);
	end;
	
	
	if (j_cm ? 'fb_ids' and jsonb_typeof(j_cm->'fb_ids') = 'array') is not true then
		return jsonb_build_object('err', 'e_fb_players_level_scores_invalid_fb_ids', 'msg', 'unexpected param "fb_ids"');
	end if;
	
	
	if jsonb_array_length(j_cm->'fb_ids') > 100 then
		return jsonb_build_object('err', 'e_fb_players_level_scores_max_fb_ids', 'msg', 'max 100 items');
	end if;
	
	
	for rw_x_player in (
		select * from "public"."players" where "fb_id" = any(select jsonb_array_elements_text(j_cm->'fb_ids'))
	) loop
		--raise log '///// rw_x_player: %', rw_x_player;
		select max("score") from "public"."progress" where "player" = rw_x_player."id" and "level" = i_level into i_score;
		--raise log '///// i_score %', i_score;
		if i_score is not null then
			j_result = j_result || jsonb_build_object(
				'id', rw_x_player."fb_id",
				'score', i_score
			);
		end if;
	end loop;
	
	
	return jsonb_build_object(
		'err', null,
		'players', coalesce(j_result, array[]::jsonb[])
	);
	
	
end;$$;


--
-- Name: fb_players_levels(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION fb_players_levels(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	a_fb_ids text[];
	rw_target_player "public"."players"%rowtype;
	j_result jsonb[];
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	if (j_cm ? 'fb_ids' and jsonb_typeof(j_cm->'fb_ids') = 'array') is not true then
		return jsonb_build_object('err', 'e_fb_players_levels_invalid_fb_ids', 'msg', 'unexpected param "fb_ids"');
	end if;
	
	
	if jsonb_array_length(j_cm->'fb_ids') > 100 then
		return jsonb_build_object('err', 'e_fb_players_levels_max_fb_ids', 'msg', 'max 100 items');
	end if;
	
	
	select array_agg("v") from (select jsonb_array_elements_text(j_cm->'fb_ids') "v") "t"
	into a_fb_ids;
	
	
	for rw_target_player in (select * from "public"."players" where "fb_id" = any(a_fb_ids)) loop
		
		j_result = j_result || jsonb_build_object(
			'id', rw_target_player."fb_id",
			'level', rw_target_player."max_level"
		);
		
	end loop;
	
	
	return jsonb_build_object(
		'err', null,
		'players', coalesce(j_result, array[]::jsonb[])
	);
	
	
end;$$;


--
-- Name: levels_packs(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION levels_packs(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	
begin
	
	
	return jsonb_build_object(
		'err', null,
		'levels_packs', coalesce(
			(
				select jsonb_agg("level_id")
				from "public"."levels_packs"
			),
			jsonb_build_array()
		)
	);
	
	
end;$$;


--
-- Name: main(text, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION main(t_cmd text, j_headers jsonb, j_params jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	t_token text;
	a_cookie text[];
	a_token text[];
	rw_admin_sess "admin"."sessions"%rowtype;
	rw_player_sess "public"."sessions"%rowtype;
	
	t_hint text;
	t_stack text;
	
begin
	
	
	raise log E'--- main ---\n%\n%\n%', format('cmd: "%s"', t_cmd), format('headers: %s', j_headers), format('params: %s', j_params);
	
	
	-- token from params
	
	t_token = j_params->>'token';
	
	
	-- token from http headers
	
	if t_token is null then
		-- WARN: python app modify case from "BubbleToken" to "Bubbletoken"
		t_token = coalesce(
			j_headers#>>'{BubbleToken,0}',
			j_headers#>>'{Bubbletoken,0}'
		);
	end if;
	
	
	-- token from cookie
	
	if t_token is null then
		a_cookie = regexp_match(j_headers#>>'{Cookie,0}', 'token=([^;]+)');
		-- todo: check cookie 1,2,... indexes
		if a_cookie is not null then
			t_token = a_cookie[1];
		end if;
	end if;
	
	
	-- token check
	
	if t_token is not null then
		
		a_token = regexp_match(t_token, '(?:(\w+)\-)?(\w+)');
		
		if a_token is not null and a_token[1] = 'admin' then
			
			-- admin's token
			
			select * from "admin"."sessions" where "token" = a_token[2] for update
			into rw_admin_sess;
			
			if rw_admin_sess."id" is null then
				return jsonb_build_object('err', 'e_cmn_invalid_admin_token', 'msg', format('token "%s" not exists', t_token));
			end if;
			
			update "admin"."sessions" set "atime" = timezone('utc', now()) where "id" = rw_admin_sess."id";
			
			-- authorized admin
			
			j_params = jsonb_set(j_params, array['_admin'], to_jsonb(rw_admin_sess."admin"));
			
		else
			
			-- player's token
			
			select * from "public"."sessions" where "token" = a_token[2] for update
			into rw_player_sess;
			
			if rw_player_sess."id" is null then
				return jsonb_build_object('err', 'e_cmn_invalid_token', 'msg', format('token "%s" not exists', t_token));
			end if;
			
			update "public"."sessions" set "atime" = timezone('utc', now()) where "id" = rw_player_sess."id";
			
			-- authorized player
			
			j_params = jsonb_set(j_params, array['_player'], to_jsonb(rw_player_sess."player"));
			
		end if;
		
	else
		
		-- not authorized client
		
	end if;
	
	
	-- exec cmd
	
	case t_cmd
		when 'device_reg' then return "public"."device_reg"(j_params);
		when 'device_auth' then return "public"."device_auth"(j_params);
		when 'state_set' then return "public"."state_set"(j_params);
		when 'state_get' then return "public"."state_get"(j_params);
		when 'progress_set' then return "public"."progress_set"(j_params);
		when 'progress_get' then return "public"."progress_get"(j_params);
		when 'levels_packs' then return "public"."levels_packs"(j_params);
		when 'event' then return "public"."event"(j_params);
		when 'fb_move' then return "public"."fb_move"(j_params);
		when 'fb_players_levels' then return "public"."fb_players_levels"(j_params);
		when 'fb_players_level_scores' then return "public"."fb_players_level_scores"(j_params);
		when 'store_pair_set' then return "public"."store_pair_set"(j_params);
		when 'store_pair_get' then return "public"."store_pair_get"(j_params);
		when 'replay_set' then return "public"."replay_set"(j_params);
		when 'admin_login' then return "admin"."login"(j_params);
		when 'admin_logout' then return "admin"."logout"(j_params, rw_admin_sess."token");
		when 'admin_state_get' then return "admin"."state_get"(j_params);
		when 'admin_players_list' then return "admin"."players_list"(j_params);
		when 'admin_player_state_get' then return "admin"."player_state_get"(j_params);
		when 'admin_player_state_set' then return "admin"."player_state_set"(j_params);
		when 'admin_statistics_get' then return "admin"."statistics_get"(j_params);
		when 'admin_statistics2_get' then return "admin"."statistics2_get"(j_params);
		else
	end case;
	
	
	-- unhandled cmd
	
	return jsonb_build_object('err', 'e_unhandled_cmd', 'msg', format('unhandled command: %s', t_cmd));
	
	
exception
	when RAISE_EXCEPTION then
		get stacked diagnostics t_hint = PG_EXCEPTION_HINT;
		return jsonb_build_object('err', case when t_hint != '' then t_hint else 'e_unhandled_exception' end, 'msg', SQLERRM);
	when others then
		get stacked diagnostics t_stack = PG_EXCEPTION_CONTEXT;
		raise log E'!!! ERROR state=% errm=(%)\n%', SQLSTATE, SQLERRM, t_stack;
		return jsonb_build_object('err', 'e_bd_exec', 'msg', format('unhandled error %s', SQLSTATE));
end;$$;


--
-- Name: progress_get(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION progress_get(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	t_level text;
	i_level int8;
	a_levels int8[];
	j_result jsonb;
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	if (j_cm ? 'levels' and jsonb_typeof(j_cm->'levels') = 'array') is not true then
		return jsonb_build_object('err', 'e_prog_get_invalid_levels', 'msg', 'unexpected param "levels"');
	end if;
	
	
	if jsonb_array_length(j_cm->'levels') > 100 then
		return jsonb_build_object('err', 'e_prog_get_max_levels', 'msg', 'max 100 items');
	end if;
	
	
	for t_level in (select jsonb_array_elements_text(j_cm->'levels')) loop
		
		--raise log 't_level %', t_level;
		
		begin
			i_level = t_level::int8;
			assert i_level is not null, format('bad level: %s', t_level);
		exception
			when assert_failure or others then
				raise exception using message = format('unexpected input data: %s', SQLERRM), hint = 'e_prog_get_invalid_level_item';
		end;
		
		a_levels = a_levels || i_level;
		
	end loop;
	
	
	select json_agg("raw") from "public"."progress" where "player" = i_player and "level" = any(a_levels)
	into j_result;
	
	
	return jsonb_build_object(
		'err', null,
		'levels', coalesce(j_result, jsonb_build_array())
	);
	
	
end;$$;


--
-- Name: progress_set(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION progress_set(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	j_level jsonb;
	rw_progress "public"."progress"%rowtype;
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	if j_cm ? 'levels' and jsonb_typeof(j_cm->'levels') = 'array' then
		
		
		if jsonb_array_length(j_cm->'levels') > 100 then
			return jsonb_build_object('err', 'e_prog_set_max_levels', 'msg', 'max 100 items');
		end if;
		
		
		for j_level in (select jsonb_array_elements(j_cm->'levels')) loop
			
			--raise log 'j_level %', j_level;
			
			if jsonb_typeof(j_level) != 'object' then
				raise exception using message = format('unexpected type of level item: %s', j_level), hint = 'e_prog_set_invalid_level_item';
			end if;
			
			
			/*
			if jsonb_typeof(j_level->'level') != 'number' then
				raise exception using message = format('unexpected type of level.level: %s', j_level->'level'), hint = 'e_prog_set_invalid_level_item';
			end if;
			
			if jsonb_typeof(j_level->'score') != 'number' then
				raise exception using message = format('unexpected type of level.score: %s', j_level->'score'), hint = 'e_prog_set_invalid_level_item';
			end if;
			
			if jsonb_typeof(j_level->'stars') != 'number' then
				raise exception using message = format('unexpected type of level.stars: %s', j_level->'stars'), hint = 'e_prog_set_invalid_level_item';
			end if;
			*/
			
			
			begin
				rw_progress."level" = (j_level->>'level')::int8;
				rw_progress."score" = (j_level->>'score')::int8;
				rw_progress."stars" = (j_level->>'stars')::int8;
				assert rw_progress."level" is not null, format('bad level: %s', j_level->'level');
				assert rw_progress."score" is not null, format('bad score: %s', j_level->'score');
				assert rw_progress."stars" is not null, format('bad stars: %s', j_level->'stars');
			exception
				when assert_failure or others then
					raise exception using message = format('unexpected input data: %s', SQLERRM), hint = 'e_prog_set_invalid_level_item';
			end;
			
			
			delete from "public"."progress" where "player" = i_player and "level" = rw_progress."level";
			
			
			rw_progress."id" = nextval('"public"."progress_id_seq"');
			rw_progress."player" = i_player;
			rw_progress."raw" = j_level;
			
			insert into "public"."progress" values (rw_progress.*);
			
			
			perform "public"."_recalc_player_max_level"(i_player);
			
			
		end loop;
		
		
	else
		
		return jsonb_build_object('err', 'e_prog_set_invalid_levels', 'msg', 'unexpected param "levels"');
		
	end if;
	
	
	return jsonb_build_object('err', null);
	
	
end;$$;


--
-- Name: replay_set(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION replay_set(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	rw_replays "public"."replays"%rowtype;
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required for "event"');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	if not(j_cm ? 'level') then
		return jsonb_build_object('err', 'e_cmn_bad_params', 'msg', '"level" required');
	end if;
	
	if not(j_cm ? 'replay') then
		return jsonb_build_object('err', 'e_cmn_bad_params', 'msg', '"replay" required');
	end if;
	
	
	rw_replays."id" = nextval('"public"."replays_id_seq"');
	rw_replays."ctime" = timezone('utc', now());
	rw_replays."player" = rw_player."id";
	rw_replays."data" = j_cm->'replay';
	
	begin
		rw_replays."level" = (j_cm->>'level')::int8;
		assert rw_replays."level" is not null, format('bad level: %s', j_cm->'level');
	exception
		when assert_failure or others then
			raise exception using message = format('unexpected input data: %s', SQLERRM), hint = 'e_cmn_bad_params';
	end;
	
	insert into "public"."replays" values (rw_replays.*);
	
	
	return jsonb_build_object('err', null);
	
	
end;$$;


--
-- Name: state_get(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION state_get(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required for "state_set"');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	return jsonb_build_object(
		'err', null,
		'account', rw_player."id",
		'ctime', floor(extract(epoch from rw_player."ctime"))::int8,
		'fb_user_id', rw_player."fb_id",
		'device_id', rw_player."device_id",
		'levels_pack', rw_player."levels_pack",
		'data', rw_player."state"
	);
	
	
end;$$;


--
-- Name: state_set(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION state_set(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required for "state_set"');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	--if not(jsonb_typeof(j_cm->'data') = any(array['object', 'null'])) then
	--	return jsonb_build_object('err', 'e_state_set_invalid_data', 'msg', 'parameter "data" must be object or null');
	--end if;
	
	
	if j_cm ? 'data' then
		update "public"."players" set "state" = j_cm->'data' where "id" = rw_player."id";
	end if;
	
	
	if j_cm ? 'channel' then
		update "public"."players" set "channel" = j_cm->>'channel' where "id" = rw_player."id";
	end if;
	
	
	if j_cm ? 'shop' then
		update "public"."players" set "shop" = j_cm->>'shop' where "id" = rw_player."id";
	end if;
	
	
	if j_cm ? 'levels_pack' then
		
		if j_cm->>'levels_pack' is not null then
			
			
			-- клиент сообщил свою версию level_pack
			
			if rw_player."levels_pack" is distinct from j_cm->>'levels_pack' then
				update "public"."players" set "levels_pack" = j_cm->>'levels_pack' where "id" = rw_player."id";
			end if;
			
			
		else
			
			
			-- клиент сообщил level_pack=null, автоматическая выдача level_pack
			
			if rw_player."levels_pack" is not null then
				
				update "public"."players" set "levels_pack" = null where "id" = rw_player."id";
				
				perform "public"."_recalc_level_pack_players"(rw_player."levels_pack");
				
			end if;
			
			select "level_id"
			into rw_player."levels_pack"
			from "public"."levels_packs"
			order by "players_count"
			limit 1;
			
			if rw_player."levels_pack" is not null then
				
				update "public"."players" set "levels_pack" = rw_player."levels_pack" where "id" = rw_player."id";
				
				perform "public"."_recalc_level_pack_players"(rw_player."levels_pack");
				
			end if;
			
			
		end if;
		
	end if;
	
	
	return jsonb_build_object('err', null);
	
	
end;$$;


--
-- Name: store_pair_get(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION store_pair_get(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	rw_pair "public"."store_pairs"%rowtype;
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required for "event"');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	if not(j_cm ? 'key') then
		return jsonb_build_object('err', 'e_cmn_bad_params', 'msg', '"key" required');
	end if;
	
	
	select * from "public"."store_pairs" where "player" = rw_player."id" and "key" = j_cm->>'key'
	into rw_pair;
	
	
	return jsonb_build_object(
		'err', null,
		'value', rw_pair."value"
	);
	
	
end;$$;


--
-- Name: store_pair_set(jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION store_pair_set(j_cm jsonb) RETURNS jsonb
    LANGUAGE plpgsql
    AS $$declare
	
	i_player int8;
	rw_player "public"."players"%rowtype;
	rw_pair "public"."store_pairs"%rowtype;
	
begin
	
	
	i_player = (j_cm->>'_player')::int8;
	
	if i_player is null then
		return jsonb_build_object('err', 'e_not_auth', 'msg', 'auth required for "event"');
	end if;
	
	
	select * from "public"."players" where "id" = i_player for update
	into rw_player;
	
	if rw_player."id" is null then
		return jsonb_build_object('err', 'e_player_not_found', 'msg', format('player %s not found', i_player));
	end if;
	
	
	if not(j_cm ? 'key') then
		return jsonb_build_object('err', 'e_cmn_bad_params', 'msg', '"key" required');
	end if;
	
	if not(j_cm ? 'value') then
		return jsonb_build_object('err', 'e_cmn_bad_params', 'msg', '"value" required');
	end if;
	
	
	rw_pair."id" = nextval('"public"."events_id_seq"');
	rw_pair."ctime" = timezone('utc', now());
	rw_pair."player" = rw_player."id";
	rw_pair."key" = j_cm->>'key';
	rw_pair."value" = j_cm->'value';
	
	insert into "public"."store_pairs" values (rw_pair.*);
	delete from "public"."store_pairs" where "player" = rw_player."id" and "key" = j_cm->>'key' and "id" != rw_pair."id";
	
	
	return jsonb_build_object('err', null);
	
	
end;$$;


SET search_path = admin, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: admins; Type: TABLE; Schema: admin; Owner: -
--

CREATE TABLE admins (
    id bigint NOT NULL,
    login text,
    passw text,
    atime timestamp without time zone
);


--
-- Name: admins_id_seq; Type: SEQUENCE; Schema: admin; Owner: -
--

CREATE SEQUENCE admins_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admins_id_seq; Type: SEQUENCE OWNED BY; Schema: admin; Owner: -
--

ALTER SEQUENCE admins_id_seq OWNED BY admins.id;


--
-- Name: config; Type: TABLE; Schema: admin; Owner: -
--

CREATE TABLE config (
    key text NOT NULL,
    value text
);


--
-- Name: sessions; Type: TABLE; Schema: admin; Owner: -
--

CREATE TABLE sessions (
    id bigint NOT NULL,
    ctime timestamp without time zone,
    atime timestamp without time zone,
    admin bigint,
    token text
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: admin; Owner: -
--

CREATE SEQUENCE sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: admin; Owner: -
--

ALTER SEQUENCE sessions_id_seq OWNED BY sessions.id;


SET search_path = public, pg_catalog;

--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE events (
    id bigint NOT NULL,
    ctime timestamp without time zone,
    player bigint,
    event jsonb
);


--
-- Name: events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE events_id_seq OWNED BY events.id;


--
-- Name: levels_packs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE levels_packs (
    id bigint NOT NULL,
    level_id text,
    players_count bigint
);


--
-- Name: TABLE levels_packs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE levels_packs IS '-- recalc all levels
select "level_id", "public"."_recalc_level_pack_players"("level_id") from "public"."levels_packs";';


--
-- Name: levels_packs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE levels_packs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: levels_packs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE levels_packs_id_seq OWNED BY levels_packs.id;


--
-- Name: players; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE players (
    id bigint NOT NULL,
    ctime timestamp without time zone DEFAULT timezone('utc'::text, now()),
    device_id text,
    fb_id text,
    state jsonb,
    fb_email text,
    device_secret text,
    fb_acc jsonb,
    atime timestamp without time zone,
    channel text,
    shop text,
    levels_pack text,
    max_level bigint
);


--
-- Name: players_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE players_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: players_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE players_id_seq OWNED BY players.id;


--
-- Name: progress; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE progress (
    id bigint NOT NULL,
    player bigint,
    level bigint,
    score bigint,
    stars bigint,
    raw jsonb
);


--
-- Name: progress_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE progress_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: progress_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE progress_id_seq OWNED BY progress.id;


--
-- Name: replays; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE replays (
    id bigint NOT NULL,
    ctime timestamp without time zone,
    player bigint,
    data jsonb,
    level bigint
);


--
-- Name: replays_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE replays_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: replays_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE replays_id_seq OWNED BY replays.id;


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE sessions (
    id bigint NOT NULL,
    ctime timestamp without time zone DEFAULT timezone('utc'::text, now()),
    atime timestamp without time zone,
    player bigint,
    token text
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE sessions_id_seq OWNED BY sessions.id;


--
-- Name: store_pairs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE store_pairs (
    id bigint NOT NULL,
    ctime timestamp without time zone,
    player bigint,
    key text,
    value jsonb
);


--
-- Name: store_pairs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE store_pairs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: store_pairs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE store_pairs_id_seq OWNED BY store_pairs.id;


SET search_path = admin, pg_catalog;

--
-- Name: admins id; Type: DEFAULT; Schema: admin; Owner: -
--

ALTER TABLE ONLY admins ALTER COLUMN id SET DEFAULT nextval('admins_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: admin; Owner: -
--

ALTER TABLE ONLY sessions ALTER COLUMN id SET DEFAULT nextval('sessions_id_seq'::regclass);


SET search_path = public, pg_catalog;

--
-- Name: events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY events ALTER COLUMN id SET DEFAULT nextval('events_id_seq'::regclass);


--
-- Name: levels_packs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY levels_packs ALTER COLUMN id SET DEFAULT nextval('levels_packs_id_seq'::regclass);


--
-- Name: players id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY players ALTER COLUMN id SET DEFAULT nextval('players_id_seq'::regclass);


--
-- Name: progress id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY progress ALTER COLUMN id SET DEFAULT nextval('progress_id_seq'::regclass);


--
-- Name: replays id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY replays ALTER COLUMN id SET DEFAULT nextval('replays_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY sessions ALTER COLUMN id SET DEFAULT nextval('sessions_id_seq'::regclass);


--
-- Name: store_pairs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY store_pairs ALTER COLUMN id SET DEFAULT nextval('store_pairs_id_seq'::regclass);


SET search_path = admin, pg_catalog;

--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: admin; Owner: -
--

ALTER TABLE ONLY admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: config config_pkey; Type: CONSTRAINT; Schema: admin; Owner: -
--

ALTER TABLE ONLY config
    ADD CONSTRAINT config_pkey PRIMARY KEY (key);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: admin; Owner: -
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


SET search_path = public, pg_catalog;

--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: levels_packs levels_packs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY levels_packs
    ADD CONSTRAINT levels_packs_pkey PRIMARY KEY (id);


--
-- Name: players players_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY players
    ADD CONSTRAINT players_pkey PRIMARY KEY (id);


--
-- Name: progress progress_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY progress
    ADD CONSTRAINT progress_pkey PRIMARY KEY (id);


--
-- Name: replays replays_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY replays
    ADD CONSTRAINT replays_pkey PRIMARY KEY (id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: store_pairs store_pairs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY store_pairs
    ADD CONSTRAINT store_pairs_pkey PRIMARY KEY (id);


--
-- Name: players_device_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX players_device_id_idx ON players USING hash (device_id);


--
-- Name: players_fb_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX players_fb_id_idx ON players USING hash (fb_id);


--
-- Name: sessions_token_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX sessions_token_idx ON sessions USING hash (token);


--
-- PostgreSQL database dump complete
--

