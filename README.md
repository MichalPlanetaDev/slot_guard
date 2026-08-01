# SlotGuard

SlotGuard is a Rails application for conflict-safe reservations of shared rooms, equipment, and other limited resources.

Each workspace owns an IANA time zone. Members enter and review availability and reservations in that local time, while reservation instants remain stored in UTC. Local times skipped or repeated during daylight-saving transitions are rejected so a booking never silently moves to a different instant.

Workspace owners manage identity, time zone, invitations, roles, and member access. Managers maintain resources and weekly availability. Members create confirmed reservations inside those windows. PostgreSQL exclusion constraints prevent overlapping bookings for the same resource.

Each account keeps its personal workspace and can join additional workspaces through an invitation. Invitation links expire after seven days, are restricted to the invited email address, and become unusable after acceptance or revocation. SlotGuard stores only invitation-token digests.

## Stack

Ruby, Rails, PostgreSQL, Hotwire, Stimulus, Tailwind CSS, Minitest, and GitHub Actions. Exact versions are recorded in `.ruby-version`, `.mise.toml`, and `Gemfile.lock`.

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
