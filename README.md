# Web Scraper Application 🕷️🕸️

A modern, user-friendly web application for scraping links from web pages. Built with Elixir, Phoenix, and LiveView, this application allows users to enter a URL, scrape all links from the page, and view the results in real-time.

⚓ Deployed application: https://scraper-purple-voice-8836.fly.dev

## Features 🛠️

- User authentication system with registration, login, and password reset
- Asynchronous web scraping with real-time updates
- User-friendly UI with Tailwind CSS
- Pagination for both scraped pages and links
- Comprehensive test suite with 100% code coverage

## Technology Stack 📚

- **Backend**: Elixir 1.17.2, Erlang/OTP 27
- **Web Framework**: Phoenix 1.7.21 with LiveView 1.0.10
- **Database**: PostgreSQL (via Docker)
- **UI**: Tailwind CSS, HeroIcons
- **Testing**: ExUnit with Coveralls for coverage reporting
- **Scraping**: HTTPoison for HTTP requests, Floki for HTML parsing

## Installation and Setup 🔌

### Prerequisites 💭

- Elixir 1.17.2 or later
- Erlang/OTP 27 or later
- Docker and Docker Compose (for PostgreSQL database)

### Database Setup 📦

The application uses PostgreSQL in a Docker container. To start the database:

```bash
# Start the PostgreSQL container
docker-compose up -d
```

The database configuration is in `config/dev.exs` and is set up to connect to the Docker container.

### Application Setup 🧭

```bash
# Clone the repository
git clone https://github.com/your-username/scraper.git
cd scraper

# Install dependencies and setup the database
mix setup

# Start the Phoenix server
mix phx.server
```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser and start scraping! 🚀

## Architecture and Design Patterns 🖼️

### Asynchronous Processing 🔀

The application uses Elixir's `Task.async` to handle web scraping in the background, preventing the UI from blocking during potentially long-running scraping operations. This is especially important for large web pages with many links.

```elixir
# Example of asynchronous processing in ScraperService
Task.start(fn ->
  process_page_scraping(page)
end)
```

### Best practices used in this application: 🛟

- **Phoenix Auth generator**: The `phx.gen.auth` generator was used to create a safe and seamless authentication system built-in from Phoenix. 🔒
- **TDD development**: Tools like `test.watch` and `coveralls` were used to ensure code test coverage while developing the application. 🧪
- **Credo**: `Credo` was used to enforce code quality and style consistency. ✅
- **Dialyxir**: `Dialyxir` was used to enforce code quality and type safety. 🆙
- **Sobelow**: `Sobelow` was used to enforce code security. 🛡️
- **CI/CD**: GitHub Actions were used to enforce continuous integration and delivery. The application is deployed to [Fly.io](https://fly.io) at https://scraper-purple-voice-8836.fly.dev. ✈️
- **Documentation and Comments**: All functions are documented with descriptions, examples, and comments throughout the codebase. 📝

### Real-time Updates with PubSub 📈

We use Phoenix PubSub to broadcast updates to connected clients in real-time. As the scraping progresses, users see status updates without needing to refresh the page.

```elixir
# Broadcasting updates to clients
ScraperWeb.Endpoint.broadcast("page:#{page.id}", "status_updated", %{
  id: page.id,
  status: page.status,
  title: page.title,
  link_count: Scraping.count_links(page.id)
})
```

### Context-based Architecture 🏗️

Following Phoenix best practices, the application is organized into contexts that encapsulate related functionality:

- `Accounts`: User management and authentication
- `Scraping`: Page and link management
- `Services`: Business logic for web scraping

This separation of concerns makes the codebase more maintainable and testable.

### Nice UI Design 🎨

The UI is built with Tailwind CSS, providing a nice user experience across different device sizes. Key UI features include:

- Truncation with tooltips for long text
- Auto screen size tables with appropriate column widths
- User-friendly navigation and pagination
- Status indicators with appropriate colors and icons

## Testing 🧪

The application follows Test-Driven Development (TDD) principles and has 100% test coverage! 🎉

Tests include:

- Unit tests for contexts and services
- Integration tests for LiveView components
- End-to-end tests for user flows

### Running Tests 🏃

```bash
# Run all tests
mix test

# Run tests with coverage reporting
mix coveralls

# Generate HTML coverage report
mix coveralls.html
```

You should see something like this:

```bash
➜  mix coveralls
Running ExUnit with seed: 500905, max_cases: 40

.........................................................................................................................................................................................
Finished in 0.8 seconds (0.8s async, 0.00s sync)
185 tests, 0 failures
----------------
COV    FILE                                        LINES RELEVANT   MISSED
100.0% lib/scraper.ex                                  9        0        0
100.0% lib/scraper/accounts.ex                       371       49        0
100.0% lib/scraper/accounts/user.ex                  161       24        0
100.0% lib/scraper/accounts/user_notifier.ex          79       11        0
100.0% lib/scraper/accounts/user_token.ex            179       25        0
100.0% lib/scraper/mailer.ex                           3        0        0
100.0% lib/scraper/repo.ex                             5        0        0
100.0% lib/scraper/scraping.ex                       238       21        0
100.0% lib/scraper/scraping/link.ex                   21        2        0
100.0% lib/scraper/scraping/page.ex                   24        2        0
100.0% lib/scraper/services/scraper_service.ex       283       81        0
100.0% lib/scraper_web/components/layouts.ex          14        0        0
100.0% lib/scraper_web/controllers/error_html.e       24        1        0
100.0% lib/scraper_web/controllers/error_json.e       21        1        0
100.0% lib/scraper_web/controllers/page_html.ex       10        0        0
100.0% lib/scraper_web/controllers/user_session       42        9        0
100.0% lib/scraper_web/endpoint.ex                    53        0        0
100.0% lib/scraper_web/gettext.ex                     25        0        0
100.0% lib/scraper_web/live/page_links_live.ex       102       27        0
100.0% lib/scraper_web/live/user_confirmation_i       51       16        0
100.0% lib/scraper_web/live/user_confirmation_l       58       18        0
100.0% lib/scraper_web/live/user_forgot_passwor       50       16        0
100.0% lib/scraper_web/live/user_login_live.ex        43       15        0
100.0% lib/scraper_web/live/user_registration_l       87       28        0
100.0% lib/scraper_web/live/user_reset_password       89       28        0
100.0% lib/scraper_web/live/user_settings_live.      167       61        0
100.0% lib/scraper_web/user_auth.ex                  229       39        0
100.0% test/support/conn_case.ex                      64        6        0
100.0% test/support/fixtures/accounts_fixtures.       31        8        0
100.0% test/support/fixtures/scraping_fixtures.       46        8        0
[TOTAL] 100.0%
----------------
```

## Future Improvements 👨‍🚀

With more time, the application could be enhanced with:

1. **Advanced Scraping Options**: Allow users to specify scraping depth, filter links by type, or set custom user agents.

2. **Scheduled Scraping**: Enable users to schedule periodic scraping of websites to track changes over time.

3. **Export Functionality**: Add options to export scraped links in various formats (CSV, JSON, etc.).

4. **Link Analysis**: Provide insights about the scraped links, such as domain distribution, link types, or broken link detection.

5. **API Access**: Create a REST or GraphQL API to allow programmatic access to the scraping functionality.

6. **Enhanced Security**: Implement rate limiting, CAPTCHA verification, and more robust user permissions.

7. **Distributed Scraping**: Scale the application using Elixir's distributed capabilities to handle very large websites.

8. **Frontend Responsiveness**: Improve the frontend responsiveness and user experience for mobile devices.

Cheers! 🍾
