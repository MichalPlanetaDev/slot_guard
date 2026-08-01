# SlotGuard

SlotGuard is a Rails application for conflict-safe reservations of shared rooms, equipment, and other limited resources. Workspace owners and managers maintain resources and weekly UTC availability. Members create confirmed reservations inside those windows, while PostgreSQL exclusion constraints prevent overlapping bookings for the same resource.

## Stack

Ruby, Rails, PostgreSQL, Hotwire, Stimulus, Tailwind CSS, Minitest, and GitHub Actions. Exact runtime and dependency versions are recorded in `.ruby-version`, `.mise.toml`, and `Gemfile.lock`.

The booking schema uses PostgreSQL range expressions, GiST exclusion constraints, and the trusted `btree_gist` extension.

## Local setup

Ubuntu or WSL with PostgreSQL is expected.

    sudo service postgresql start
    mise install
    bundle install
    bin/rails db:prepare
    bin/dev

Open `http://localhost:3000` and create an account. Add a resource, configure at least one weekly availability window, then create a reservation inside that window.

Development password-reset messages are written to `tmp/mail`.

## Verification

    bin/check

The check runs style analysis, security scans, dependency audits, database preparation, tests, and a production asset compilation.

## Configuration

Hosted environments must provide `DATABASE_URL`, `RAILS_MASTER_KEY`, `MAIL_FROM`, host configuration, and an Action Mailer delivery service. The database role must be able to install the trusted `btree_gist` extension during migration.
