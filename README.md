# SlotGuard

SlotGuard is a Rails application for conflict-safe reservations of shared rooms, equipment, and other limited resources.

## Stack

Ruby, Rails, PostgreSQL, Hotwire, Stimulus, Tailwind CSS, Minitest, and GitHub Actions. Exact runtime and dependency versions are recorded in `.ruby-version`, `.mise.toml`, and `Gemfile.lock`.

## Local setup

Ubuntu or WSL with PostgreSQL is expected.

    sudo service postgresql start
    mise install
    bundle install
    bin/rails db:prepare
    bin/dev

Open `http://localhost:3000` and create an account through the registration screen.

Development password-reset messages are written to `tmp/mail`.

## Verification

    bin/check

The check runs style analysis, security scans, dependency audits, database preparation, tests, and a production asset compilation.

## Configuration

Hosted environments must provide `DATABASE_URL`, `RAILS_MASTER_KEY`, `MAIL_FROM`, host configuration, and an Action Mailer delivery service.
