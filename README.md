# SlotGuard

SlotGuard is a Rails application for conflict-safe reservations of shared rooms, equipment, and other limited resources.

Each workspace owns an IANA time zone. Members enter and review availability and reservations in that local time, while reservation instants remain stored in UTC. Local times skipped or repeated during daylight-saving transitions are rejected.

A reservation series creates between two and twenty-six occurrences at a one-to-twelve-week interval. Every occurrence remains a normal reservation protected by PostgreSQL’s exclusion constraint. Series creation is atomic, and cancellation can affect one occurrence or the selected occurrence together with later confirmed occurrences.

Reservation creators receive queued confirmation and cancellation emails. Each reservation can use no reminder or a reminder one, four, twenty-four, or forty-eight hours before its start. A single database-backed reminder record coordinates scheduled delivery, suppresses duplicate jobs, and becomes skipped when its reservation is cancelled or has already started. Production delivery uses the existing Solid Queue worker configuration.

Workspace owners manage identity, time zone, invitations, roles, and member access. Managers maintain resources and weekly availability. Each account keeps its personal workspace and can join additional workspaces through expiring, single-use invitation links whose raw tokens are never persisted.

## Stack

Ruby, Rails, PostgreSQL, Hotwire, Stimulus, Tailwind CSS, Minitest, and Solid Queue. Exact versions are recorded in `.ruby-version`, `.mise.toml`, and `Gemfile.lock`.

The booking schema uses PostgreSQL range expressions, GiST exclusion constraints, and the trusted `btree_gist` extension.

## Local setup

Ubuntu or WSL with PostgreSQL is expected.

    sudo service postgresql start
    mise install
    bundle install
    bin/rails db:prepare
    bin/dev

Open `http://localhost:3000` and create an account. Development mail is written to `tmp/mail`.

## Verification

    bin/check

The check runs style analysis, security scans, dependency audits, database preparation, tests, and production asset compilation.

## Configuration

Hosted environments must provide `DATABASE_URL`, `RAILS_MASTER_KEY`, `MAIL_FROM`, host configuration, and an Action Mailer delivery service. The database role must be able to install the trusted `btree_gist` extension during migration.
