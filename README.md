# SlotGuard

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/MichalPlanetaDev/slot_guard?quickstart=1)

![SlotGuard workspace preview](public/slotguard-preview.svg)

SlotGuard is a Rails application for booking shared rooms and equipment without double reservations. PostgreSQL exclusion constraints protect concurrent bookings and blackout periods, while workspace-local time zones, recurring reservations, inherited booking policies, reminders, and an immutable activity log cover the complete scheduling workflow.

Owners manage workspaces, members, resources, availability, booking policies, and blackout periods. Members create one-off or recurring reservations, receive notifications, and can review the activity visible to their role.

## Local setup

SlotGuard expects Ruby, PostgreSQL, and the versions recorded in `.ruby-version`, `.mise.toml`, and `Gemfile.lock`.

    sudo service postgresql start
    mise install
    bundle install
    bin/rails db:prepare
    bin/dev

Open `http://localhost:3000`. Development mail is written to `tmp/mail`.

## Configuration

Local development uses PostgreSQL. A production environment must provide `DATABASE_URL`, `RAILS_MASTER_KEY`, `APP_HOST`, and `MAIL_FROM`. Set `SOLID_QUEUE_IN_PUMA=true` when jobs run inside the web process.

## Verification

    bin/check

The check runs style, security, dependency, database, test, and production asset verification.
