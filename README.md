# SlotGuard

SlotGuard is a Rails application for booking shared rooms and equipment without double reservations.

Workspaces keep their own members, roles, resources, weekly availability, and IANA time zone. Members enter local dates and times while the database stores reservation instants in UTC and rejects daylight-saving gaps or ambiguous local times. PostgreSQL exclusion constraints protect the shared schedule during concurrent requests.

Reservations can be created once or as a recurring series. Series creation is atomic, so one unavailable occurrence rejects the complete set. A reservation can be cancelled alone or together with later occurrences. Confirmation, cancellation, and optional reminder emails are delivered through Active Job and Solid Queue.

Owners and managers can close individual resources for maintenance or temporary unavailability. Owners can also close the complete workspace. Timed and all-day blackout periods share the same database schedule ledger as reservations, so an overlap cannot be committed. Existing confirmed reservations must be cancelled before a conflicting blackout is added.

Owners set workspace defaults for booking notice, advance booking, reservation duration, and cancellation cutoff. A resource can override any setting independently while inheriting the remaining workspace policy. Every occurrence in a recurring series is checked against the effective resource policy.

Important reservation, blackout, resource, invitation, membership, and policy actions are written to an immutable workspace activity log. Owners see the complete history, managers see scheduling and resource activity, and members see events for their own reservations.

## Local setup

SlotGuard expects Ruby, PostgreSQL, and the versions recorded in `.ruby-version`, `.mise.toml`, and `Gemfile.lock`.

    sudo service postgresql start
    mise install
    bundle install
    bin/rails db:prepare
    bin/dev

Open `http://localhost:3000`. Development mail is written to `tmp/mail`.

## Verification

    bin/check

The check runs formatting, security and dependency audits, database preparation, tests, and production asset compilation.

## Configuration

Hosted environments must provide `DATABASE_URL`, `RAILS_MASTER_KEY`, `MAIL_FROM`, the public host settings, and an Action Mailer delivery service. Solid Queue must run with the application, and the database role must be able to install the trusted `btree_gist` extension during migration.
