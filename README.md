# SlotGuard

SlotGuard is a Ruby on Rails application for conflict-safe reservations of shared rooms, equipment, and other limited resources.

## Stack

Ruby, Rails, PostgreSQL, Hotwire, Stimulus, Tailwind CSS, Minitest, RuboCop, Brakeman, and GitHub Actions.

## Local setup

Start PostgreSQL and prepare the application:

    sudo service postgresql start
    bin/setup --skip-server

Start the development server:

    bin/dev

Open `http://localhost:3000`.

## Verification

Run the test suite and static checks:

    bin/rails test
    bin/rubocop
    bin/brakeman --no-pager

## Configuration

Development uses the local PostgreSQL role matching the current WSL user. Hosted environments must provide their database connection, Rails credentials, secret key, host configuration, and mail delivery settings.
