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

    test "deletes a page when delete button is clicked", %{conn: conn} do
      user = user_fixture()
      page = page_fixture(%{user_id: user.id, status: "completed"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/")

      # Verify the page exists in the view
      assert has_element?(view, "td", page.title)

      # Click the delete button (with JS confirm dialog bypassed for testing)
      view
      |> element("button[phx-click='delete_page'][phx-value-id='#{page.id}']", "Delete")
      |> render_click()

      # Check flash message
      assert has_element?(view, "#flash-info", "Page deleted successfully")

      # Verify the page no longer exists in the database
      assert Scraping.get_page(page.id) == nil

      # Verify the page is no longer displayed in the view
      refute has_element?(view, "td", page.title)
    end

    test "prevents deleting a page that doesn't belong to the user", %{conn: conn} do
      user = user_fixture()
      other_user = user_fixture()
      page = page_fixture(%{user_id: other_user.id, status: "completed"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/")

      # Manually trigger the delete_page event with the other user's page ID
      view
      |> render_hook("delete_page", %{"id" => page.id})

      # Check error flash message
      assert has_element?(view, "#flash-error", "You don't have permission to delete this page")

      # Verify the page still exists in the database
      assert Scraping.get_page(page.id) != nil
    end
  end
end
