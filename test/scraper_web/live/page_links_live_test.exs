defmodule ScraperWeb.PageLinksLiveTest do
  use ScraperWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Scraper.AccountsFixtures
  import Scraper.ScrapingFixtures

  describe "Page links live view" do
    setup %{conn: conn} do
      user = user_fixture()
      page = page_fixture(%{user_id: user.id, status: "completed"})

      # Create some links for the page
      for i <- 1..5 do
        link_fixture(%{
          page_id: page.id,
          url: "https://example.com/link#{i}",
          name: "Link #{i}"
        })
      end

      %{conn: conn, user: user, page: page}
    end

    test "redirects if user is not authenticated", %{conn: conn, page: page} do
      result = live(conn, ~p"/pages/#{page.id}")
      assert {:error, {:live_redirect, %{to: "/users/log_in"}}} = result
    end

    test "redirects if page doesn't belong to user", %{conn: conn, page: page} do
      other_user = user_fixture()
      conn = log_in_user(conn, other_user)

      result = live(conn, ~p"/pages/#{page.id}")
      assert {:error, {:live_redirect, %{to: "/"}}} = result
    end

    test "displays page details and links", %{conn: conn, user: user, page: page} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/pages/#{page.id}")

      # Check page details
      assert has_element?(view, "h1", "Links for: #{page.title}")
      assert has_element?(view, "p", page.url)
      assert has_element?(view, "span", "Completed")

      # Check links table
      assert has_element?(view, "h2", "Links Found (5)")

      # Check that all 5 links are displayed
      for i <- 1..5 do
        assert has_element?(view, "td", "Link #{i}")
        assert has_element?(view, "td a", "https://example.com/link#{i}")
      end
    end

    test "displays empty state when page has no links", %{conn: conn, user: user} do
      # Create a new page with no links
      empty_page = page_fixture(%{user_id: user.id, status: "completed"})

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/pages/#{empty_page.id}")

      assert has_element?(view, "p", "No links found on this page")
    end

    test "paginates links lists", %{conn: conn, user: user, page: page} do
      # Create more links to trigger pagination (default page size is 20)
      for i <- 6..25 do
        link_fixture(%{
          page_id: page.id,
          url: "https://example.com/link#{i}",
          name: "Link #{i}"
        })
      end

      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/pages/#{page.id}")

      # Check that we have the correct title
      assert has_element?(view, "h1", "Links for: #{page.title}")

      # Check that we have links displayed
      rendered = render(view)
      assert length(Floki.find(rendered, "tbody tr")) > 0

      # Check that we have the correct count displayed
      assert has_element?(view, "h2", "Links Found (25)")
    end

    test "back button navigates to home page", %{conn: conn, user: user, page: page} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/pages/#{page.id}")

      result = view |> element("a", "Back to Pages") |> render_click()
      assert {:error, {:live_redirect, %{to: "/"}}} = result
    end

    test "redirects with error when page doesn't exist", %{conn: conn} do
      user = user_fixture()
      conn = log_in_user(conn, user)

      # Use a non-existent page ID
      non_existent_id = "0"

      # This should trigger the Ecto.NoResultsError rescue block
      # which redirects to home with a flash message
      {:error, {:live_redirect, %{to: "/", flash: %{"error" => "Page not found"}}}} =
        live(conn, ~p"/pages/#{non_existent_id}")
    end
  end

  describe "pagination" do
    setup :register_and_log_in_user

    setup %{conn: conn, user: user} do
      page = page_fixture(%{user_id: user.id, status: "completed"})

      # Create 25 links to trigger pagination (page size is 10)
      for i <- 1..25 do
        link_fixture(%{
          page_id: page.id,
          url: "https://example.com/link#{i}",
          name: "Link #{i}"
        })
      end

      %{conn: conn, user: user, page: page}
    end

    test "paginates links list", %{conn: conn, user: user, page: page} do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/pages/#{page.id}")

      # Check that we have pagination
      assert has_element?(view, "nav[aria-label='Pagination']")

      # Check that we have 10 links on the first page
      rendered = render(view)
      assert length(Floki.find(rendered, "tbody tr")) == 10

      # Navigate to page 2
      {:ok, view, _html} =
        view
        |> element("a[href='/pages/#{page.id}?page=2']", "2")
        |> render_click()
        |> follow_redirect(conn)

      # Check that we have 10 links on the second page
      rendered = render(view)
      assert length(Floki.find(rendered, "tbody tr")) == 10

      # Navigate to page 3
      {:ok, view, _html} =
        view
        |> element("a[href='/pages/#{page.id}?page=3']", "3")
        |> render_click()
        |> follow_redirect(conn)

      # Check that we have 5 links on the third page
      rendered = render(view)
      assert length(Floki.find(rendered, "tbody tr")) == 5
    end
  end

  describe "link formatting" do
    setup %{conn: conn} do
      user = user_fixture()
      page = page_fixture(%{user_id: user.id, status: "completed"})

      # Create links with various name formats
      link_fixture(%{page_id: page.id, url: "https://example.com/1", name: "Normal Link"})
      link_fixture(%{page_id: page.id, url: "https://example.com/2", name: nil})
      link_fixture(%{page_id: page.id, url: "https://example.com/3", name: ""})

      %{conn: conn, user: user, page: page}
    end

    test "displays 'No text' for links with empty or nil names", %{
      conn: conn,
      user: user,
      page: page
    } do
      conn = log_in_user(conn, user)
      {:ok, view, _html} = live(conn, ~p"/pages/#{page.id}")

      # Check that normal link name is displayed correctly
      assert has_element?(view, "td", "Normal Link")

      # Check that empty/nil link names show "No text"
      assert has_element?(view, "td", "No text")

      # Count occurrences of "No text" (should be 2)
      html = render(view)
      assert length(Floki.find(html, "td:fl-contains('No text')")) == 2
    end
  end
end
