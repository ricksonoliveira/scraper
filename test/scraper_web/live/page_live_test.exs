defmodule ScraperWeb.PageLiveTest do
  use ScraperWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Scraper.AccountsFixtures
  import Scraper.ScrapingFixtures

  alias Scraper.Scraping

  describe "Page live view" do
    test "displays welcome message for unauthenticated users", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "h1", "Welcome to Scraper")
      assert has_element?(view, "a", "Register")
      assert has_element?(view, "a", "Log in")
    end

    test "displays scraping interface for authenticated users", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "h2", "Add URL to Scrape")
      assert has_element?(view, "h2", "Your Scraped Pages")
      assert has_element?(view, "button", "Scrape")
    end

    test "shows empty state when user has no pages", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "p", "You haven't scraped any pages yet")
    end

    test "lists user's scraped pages", %{conn: conn} do
      user = user_fixture()
      page = page_fixture(%{user_id: user.id, status: "completed"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "td", page.title)
      assert has_element?(view, "td", page.url)
      assert has_element?(view, "span", "Completed")
    end

    test "submits URL for scraping", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("form", %{url: "https://example.com"})
      |> render_submit()

      # Check flash message
      assert has_element?(view, "#flash-info", "Page scraping started")

      # Verify a page was created in the database
      assert [page] = Scraping.list_pages(user.id)
      assert page.url == "https://example.com"
      assert page.status == "in progress"
    end

    test "validates URL input", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      {:ok, view, _html} = live(conn, ~p"/")

      # Submit an empty URL
      html =
        view
        |> form("form", %{url: ""})
        |> render_change()

      assert html =~ "required"
    end

    test "paginates pages list", %{conn: conn} do
      user = user_fixture()

      # Create 11 pages to trigger pagination (default page size is 10)
      for i <- 1..11 do
        page_fixture(%{
          user_id: user.id,
          url: "https://example.com/page#{i}",
          title: "Page #{i}",
          status: "completed"
        })
      end

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/")

      # Check that we have pagination
      assert has_element?(view, "nav[aria-label='Pagination']")

      # Check that we have 10 pages on the first page
      rendered = render(view)
      assert length(Floki.find(rendered, "tbody tr")) == 10

      # Navigate to page 2
      {:ok, view, _html} = view |> element("a", "2") |> render_click() |> follow_redirect(conn)

      # Check that we have 1 page on the second page
      rendered = render(view)
      assert length(Floki.find(rendered, "tbody tr")) == 1
    end
  end
end
