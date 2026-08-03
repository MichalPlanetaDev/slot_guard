# SlotGuard

[![Live Demo](https://img.shields.io/badge/Live_Demo-open-059669?style=for-the-badge)](https://slotguard-michalplanetadev.onrender.com)
[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/MichalPlanetaDev/slot_guard?quickstart=1)

![SlotGuard workspace preview](public/slotguard-preview.svg)

SlotGuard is a Rails application for booking shared rooms and equipment without double reservations. PostgreSQL exclusion constraints protect concurrent bookings and blackout periods, while workspace-local time zones, recurring reservations, inherited booking policies, reminders, and an immutable activity log cover the complete scheduling workflow.

The public demo uses a resettable sample workspace. Sign in with `demo@slotguard.app` and `SlotGuard-demo-2026!`. Outbound email is disabled in demo mode. A free Render service can take about a minute to wake after inactivity.

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

## Configuration

Production requires `DATABASE_URL`, `RAILS_MASTER_KEY`, `APP_HOST`, and `MAIL_FROM`. Set `SOLID_QUEUE_IN_PUMA=true` for a single-service deployment. The PostgreSQL role must be able to install the trusted `btree_gist` extension.
