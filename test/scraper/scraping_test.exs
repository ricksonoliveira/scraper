defmodule Scraper.ScrapingTest do
  use Scraper.DataCase, async: true

  alias Scraper.Scraping
  alias Scraper.Services.ScraperService
  alias Scraper.Scraping.{Page, Link}

  import Scraper.AccountsFixtures

  describe "pages" do
    @valid_attrs %{url: "https://example.com", title: "Example Domain", status: "completed"}
    @invalid_attrs %{url: nil, title: nil, status: nil, user_id: nil}

    setup do
      user = user_fixture()
      %{user: user}
    end

    def page_fixture(attrs \\ %{}, user) do
      {:ok, page} =
        attrs
        |> Enum.into(@valid_attrs)
        |> Map.put(:user_id, user.id)
        |> Scraping.create_page()

      page
    end

    test "list_pages/1 returns all pages for a user", %{user: user} do
      page = page_fixture(%{}, user)
      [result] = Scraping.list_pages(user.id)
      assert result.id == page.id
      assert result.url == page.url
      assert result.title == page.title
      assert result.status == page.status
      assert result.user_id == page.user_id
    end

    test "get_page/1 returns the page with given id", %{user: user} do
      page = page_fixture(%{}, user)
      result = Scraping.get_page(page.id)
      assert result.id == page.id
      assert result.url == page.url
      assert result.title == page.title
      assert result.status == page.status
      assert result.user_id == page.user_id
    end

    test "get_page!/1 returns the page with given id", %{user: user} do
      page = page_fixture(%{}, user)
      result = Scraping.get_page!(page.id)
      assert result.id == page.id
      assert result.url == page.url
      assert result.title == page.title
      assert result.status == page.status
      assert result.user_id == page.user_id
    end

    test "create_page/1 with valid data creates a page", %{user: user} do
      valid_attrs = Map.put(@valid_attrs, :user_id, user.id)
      assert {:ok, %Page{} = page} = Scraping.create_page(valid_attrs)
      assert page.url == "https://example.com"
      assert page.title == "Example Domain"
      assert page.status == "completed"
      assert page.user_id == user.id
    end

    test "create_page/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Scraping.create_page(@invalid_attrs)
    end

    test "update_page_status/2 with valid status updates the page", %{user: user} do
      page = page_fixture(%{status: "in progress"}, user)
      assert {:ok, %Page{} = updated_page} = Scraping.update_page_status(page, "completed")
      assert updated_page.status == "completed"
    end

    test "delete_page/1 deletes the page and its links", %{user: user} do
      page = page_fixture(%{}, user)

      # Add some links to the page
      {:ok, _link1} = Scraping.create_link(%{url: "https://example.com/1", page_id: page.id})
      {:ok, _link2} = Scraping.create_link(%{url: "https://example.com/2", page_id: page.id})

      assert {:ok, %Page{}} = Scraping.delete_page(page)
      assert Scraping.get_page(page.id) == nil
      assert_raise Ecto.NoResultsError, fn -> Scraping.get_page!(page.id) end

      # Verify links are deleted (due to foreign key constraint with on_delete: :delete_all)
      {links, count} = Scraping.list_links(page.id)
      assert links == []
      assert count == 0
    end

    test "count_links/1 returns the number of links for a page", %{user: user} do
      page = page_fixture(%{}, user)
      assert Scraping.count_links(page.id) == 0

      # Add some links to the page
      {:ok, _link1} = Scraping.create_link(%{url: "https://example.com/1", page_id: page.id})
      {:ok, _link2} = Scraping.create_link(%{url: "https://example.com/2", page_id: page.id})

      assert Scraping.count_links(page.id) == 2
    end
  end

  describe "links" do
    @valid_attrs %{url: "https://example.com/page", name: "Example Link"}
    @invalid_attrs %{url: nil, page_id: nil}

    setup do
      user = user_fixture()

      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "completed",
          user_id: user.id
        })

      %{user: user, page: page}
    end

    test "create_link/1 with valid data creates a link", %{page: page} do
      valid_attrs = Map.put(@valid_attrs, :page_id, page.id)
      assert {:ok, %Link{} = link} = Scraping.create_link(valid_attrs)
      assert link.url == "https://example.com/page"
      assert link.name == "Example Link"
      assert link.page_id == page.id
    end

    test "create_link/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Scraping.create_link(@invalid_attrs)
    end

    test "list_links/3 returns links with pagination", %{page: page} do
      # Create 15 links
      for i <- 1..15 do
        {:ok, _} =
          Scraping.create_link(%{
            url: "https://example.com/page#{i}",
            name: "Link #{i}",
            page_id: page.id
          })
      end

      # Test first page (default 10 per page)
      {links, total_count} = Scraping.list_links(page.id)
      assert length(links) == 10
      assert total_count == 15

      # Test second page
      {links, _} = Scraping.list_links(page.id, 2)
      assert length(links) == 5

      # Test with custom page size
      {links, _} = Scraping.list_links(page.id, 1, 5)
      assert length(links) == 5
    end
  end

  # This test is mocked since we don't want to make actual HTTP requests in tests
  describe "scrape_page/2" do
    use Mimic

    setup :verify_on_exit!

    setup do
      user = user_fixture()
      %{user: user}
    end

    test "scrape_page/2 creates a page with in progress status", %{user: user} do
      # Mock Task.start to capture the function that would be executed asynchronously
      expect(Task, :start, fn _fun ->
        # We'll just store the function without executing it
        {:ok, self()}
      end)

      assert {:ok, %Page{} = page} = Scraping.scrape_page("https://example.com", user)
      assert page.url == "https://example.com"
      assert page.status == "in progress"
      assert page.user_id == user.id
    end

    test "process_page_scraping handles HTTP errors", %{user: user} do
      # Create a page for testing
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # Mock HTTPoison.get to simulate an error
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:error, %HTTPoison.Error{reason: :timeout}}
      end)

      # Call the public process_page_scraping function
      ScraperService.process_page_scraping(page)

      # Verify the page status was updated to error
      updated_page = Scraping.get_page(page.id)
      assert updated_page.status == "error"
    end
  end

  describe "update_page/2" do
    setup do
      user = user_fixture()
      page = page_fixture(%{status: "in progress"}, user)
      %{user: user, page: page}
    end

    test "updates a page with valid attributes", %{page: page} do
      assert {:ok, updated_page} = Scraping.update_page(page, %{title: "New Title"})
      assert updated_page.title == "New Title"
    end
  end
end
