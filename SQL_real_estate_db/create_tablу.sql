CREATE TABLE person(
	id bigint PRIMARY KEY,
	created_at timestamp NOT NULL,
	is_deleted boolean,
	duplicate_of bigint
);

CREATE TABLE breakdowns (
    id serial PRIMARY KEY,
    device_platform varchar NOT NULL,
    platform varchar NOT NULL,
    placement varchar NOT NULL
);

CREATE TABLE campaign (
    id bigint PRIMARY KEY,
    name varchar NOT NULL ,
    created_at timestamp NOT NULL
);

CREATE TABLE ad_set (
    id bigint PRIMARY KEY,
    name varchar NOT NULL ,
    created_at timestamp NOT NULL,
    campaign_id bigint NOT NULL REFERENCES campaign(id)
);

CREATE TABLE ad (
    id bigint PRIMARY KEY,
    name varchar NOT NULL ,
    created_at timestamp NOT NULL,
    ad_set_id bigint NOT NULL REFERENCES ad_set(id),
    breakdowns_id integer NOT NULL REFERENCES breakdowns(id)
);

CREATE TABLE deal (
    id bigint PRIMARY KEY,
    person_id bigint NOT NULL REFERENCES person(id),
    created_at timestamp NOT NULL,
    ad_id bigint REFERENCES ad(id),
    breakdowns_id integer REFERENCES breakdowns(id),
	is_deleted boolean,
	duplicate_of bigint
);

CREATE TABLE crm_events (
    id serial PRIMARY KEY,
    deal_id bigint NOT NULL REFERENCES deal(id),
    created_at timestamp NOT NULL,
    funnel varchar NOT NULL,
    stage varchar NOT NULL,
    qualification varchar,
    event_date timestamp NOT NULL,
    status varchar,
    lost_reason json
);

CREATE TABLE ads_events (
    id serial PRIMARY KEY,
    ad_id bigint NOT NULL REFERENCES ad(id),
    breakdowns_id bigint NOT NULL REFERENCES breakdowns(id),
    day date NOT NULL,
    impressions integer NOT NULL,
    reach integer NOT NULL,
    click integer NOT NULL,
    result integer NOT NULL,
    result_type varchar NOT NULL
);
