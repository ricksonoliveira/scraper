defmodule Scraper.Services.ScraperServiceTest do
  use Scraper.DataCase, async: true
  use Mimic

  alias Scraper.Services.ScraperService
  alias Scraper.Scraping
  alias Scraper.Scraping.Page

  import Scraper.AccountsFixtures

  setup :verify_on_exit!

  describe "scrape_page/2" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "creates a page with in-progress status and starts async processing", %{user: user} do
      # Mock Task.start to capture the function that would be executed asynchronously
      expect(Task, :start, fn _fun ->
        # We'll just store the function without executing it
        {:ok, self()}
      end)

      assert {:ok, %Page{} = page} = ScraperService.scrape_page("https://example.com", user)
      assert page.url == "https://example.com"
      assert page.status == "in progress"
      assert page.user_id == user.id
    end

    test "returns error when page creation fails", %{user: user} do
      # Invalid URL (nil) to trigger validation error
      assert {:error, %Ecto.Changeset{}} = ScraperService.scrape_page(nil, user)
    end
  end

  describe "extract_title_from_url/1" do
    test "extracts domain from URL" do
      assert ScraperService.extract_title_from_url("https://example.com/path") == "example.com"
    end

    test "returns 'Unknown page' for invalid URLs" do
      assert ScraperService.extract_title_from_url("invalid-url") == "Unknown page"
    end
  end

  describe "process_page_scraping/1" do
    setup do
      user = user_fixture()
      %{user: user}
    end

    test "successfully processes a page with links", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # HTML with title and links
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Example Page Title</title>
        </head>
        <body>
          <a href="https://example.com/link1">Link 1</a>
          <a href="https://example.com/link2">Link 2</a>
        </body>
      </html>
      """

      # Mock HTTPoison.get to return our HTML
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page was updated
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "completed"
      assert updated_page.title == "Example Page Title"

      # Verify links were created
      {links, _total_count} = Scraping.list_links(page.id)
      assert length(links) == 2

      link_urls = Enum.map(links, & &1.url)
      assert "https://example.com/link1" in link_urls
      assert "https://example.com/link2" in link_urls

      # Verify link names
      link_names = Enum.map(links, & &1.name)
      assert "Link 1" in link_names
      assert "Link 2" in link_names
    end

    test "handles empty link text by using default name", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # HTML with a link that has no text content
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Example Page Title</title>
        </head>
        <body>
          <a href="https://example.com/empty-link"></a>
        </body>
      </html>
      """

      # Mock HTTPoison.get to return our HTML
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page was updated
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "completed"

      # Verify link was created with default name
      {links, _total_count} = Scraping.list_links(page.id)
      assert length(links) == 1

      # The link should have the URL but the name should be the default "Link"
      # since the link text is empty
      assert hd(links).url == "https://example.com/empty-link"
      assert hd(links).name == "Link"
    end

    test "handles link creation error gracefully", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # HTML with a link
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Example Page Title</title>
        </head>
        <body>
          <a href="https://example.com/error-link">Error Link</a>
        </body>
      </html>
      """

      # Mock HTTPoison.get to return our HTML
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html}}
      end)

      # Mock Scraping.create_link to return an error
      expect(Scraping, :create_link, fn _params ->
        {:error, %Ecto.Changeset{errors: [url: {"is invalid", []}]}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page was updated despite the link creation error
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "completed"

      # Verify no links were created due to the error
      {links, total_count} = Scraping.list_links(page.id)
      assert total_count == 0
      assert Enum.empty?(links)
    end

    test "handles HTML parsing error by setting page status to error", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # Mock HTTPoison.get to return valid response
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok,
         %HTTPoison.Response{status_code: 200, body: "Invalid HTML that will cause parsing error"}}
      end)

      # Mock Floki.parse_document to raise an error
      expect(Floki, :parse_document, fn _html ->
        {:error, "HTML parsing error"}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page status was set to error
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "error"

      # Verify no links were created
      {links, total_count} = Scraping.list_links(page.id)
      assert total_count == 0
      assert Enum.empty?(links)
    end

    test "handles non-200 HTTP response by setting page status to error", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # Mock HTTPoison.get to return a non-200 response
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 404, body: "Not Found"}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page status was set to error
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "error"

      # Verify no links were created
      {links, total_count} = Scraping.list_links(page.id)
      assert total_count == 0
      assert Enum.empty?(links)
    end

    test "processes a page with no links", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # HTML with title but no links
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>No Links Page</title>
        </head>
        <body>
          <p>This page has no links.</p>
        </body>
      </html>
      """

      # Mock HTTPoison.get to return our HTML
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page was updated
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "completed"
      assert updated_page.title == "No Links Page"

      # Verify no links were created
      {links, total_count} = Scraping.list_links(page.id)
      assert total_count == 0
      assert links == []
    end

    test "processes a page with links that have no href attribute", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # HTML with links that have no href attribute
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Bad Links Page</title>
        </head>
        <body>
          <a>This link has no href</a>
          <a onclick="javascript:void(0)">JavaScript link</a>
          <a href="https://example.com/good">Good link</a>
        </body>
      </html>
      """

      # Mock HTTPoison.get to return our HTML
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page was updated
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "completed"
      assert updated_page.title == "Bad Links Page"

      # Verify only the good link was created
      {links, total_count} = Scraping.list_links(page.id)
      assert total_count == 1
      assert length(links) == 1
      assert hd(links).url == "https://example.com/good"
    end

    test "processes a page with complex HTML structure", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # HTML with nested links and complex structure
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Complex Page</title>
          <meta charset="utf-8">
        </head>
        <body>
          <header>
            <nav>
              <ul>
                <li><a href="https://example.com/home">Home</a></li>
                <li><a href="https://example.com/about">About</a></li>
              </ul>
            </nav>
          </header>
          <main>
            <article>
              <h1>Main Article</h1>
              <p>Some text with a <a href="https://example.com/link1">link</a> inside.</p>
              <div class="sidebar">
                <h2>Related Links</h2>
                <ul>
                  <li><a href="https://example.com/related1">Related 1</a></li>
                  <li><a href="https://example.com/related2">Related 2</a></li>
                </ul>
              </div>
            </article>
          </main>
          <footer>
            <a href="https://example.com/privacy">Privacy</a> |
            <a href="https://example.com/terms">Terms</a>
          </footer>
        </body>
      </html>
      """

      # Mock HTTPoison.get to return our HTML
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page was updated
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "completed"
      assert updated_page.title == "Complex Page"

      # Verify all links were created
      {links, total_count} = Scraping.list_links(page.id)
      assert total_count == 7

      # Check for specific links
      link_urls = Enum.map(links, & &1.url)

      expected_urls = [
        "https://example.com/home",
        "https://example.com/about",
        "https://example.com/link1",
        "https://example.com/related1",
        "https://example.com/related2",
        "https://example.com/privacy",
        "https://example.com/terms"
      ]

      for url <- expected_urls do
        assert url in link_urls
      end
    end

    test "handles a page with no title tag", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # HTML with no title tag
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="utf-8">
        </head>
        <body>
          <a href="https://example.com/link1">Link 1</a>
        </body>
      </html>
      """

      # Mock HTTPoison.get to return our HTML
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page was updated but title remains unchanged
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "completed"
      # Title should remain unchanged
      assert updated_page.title == "Example Domain"

      # Verify link was created
      {links, _} = Scraping.list_links(page.id)
      assert length(links) == 1
    end

    test "handles non-200 HTTP responses", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # Mock HTTPoison.get to return a 404
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 404, body: "Not Found"}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page status was updated to error
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "error"
    end

    test "handles HTTPoison errors", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # Mock HTTPoison.get to return an error
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:error, %HTTPoison.Error{reason: :timeout}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page status was updated to error
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "error"
    end

    test "handles unexpected exceptions", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # Mock HTTPoison.get to raise an exception
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        raise "Unexpected error"
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page status was updated to error
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "error"
    end

    test "processes a page with non-ASCII characters in link names", %{user: user} do
      # Create a test page
      {:ok, page} =
        Scraping.create_page(%{
          url: "https://example.com",
          title: "Example Domain",
          status: "in progress",
          user_id: user.id
        })

      # HTML with title and links containing non-ASCII characters
      html = """
      <!DOCTYPE html>
      <html>
        <head>
          <title>Example Page Title</title>
        </head>
        <body>
          <a href="https://example.com/link1">Link 1</a>
          <a href="https://example.com/link2">Noticias</a>
          <a href="https://example.com/link3">Informacao</a>
          <a href="https://example.com/link4">Cafe</a>
        </body>
      </html>
      """

      # Mock HTTPoison.get to return our HTML
      expect(HTTPoison, :get, fn _url, _headers, _options ->
        {:ok, %HTTPoison.Response{status_code: 200, body: html}}
      end)

      # Process the page
      ScraperService.process_page_scraping(page)

      # Verify the page was updated
      updated_page = Scraping.get_page!(page.id)
      assert updated_page.status == "completed"
      assert updated_page.title == "Example Page Title"

      # Verify links were created and non-ASCII characters were handled
      updated_page = Repo.preload(updated_page, :links)
      links = updated_page.links
      assert length(links) == 4

      # Check that the links were created correctly
      link_names = Enum.map(links, & &1.name)
      assert "Link 1" in link_names
      assert "Noticias" in link_names
      assert "Informacao" in link_names
      assert "Cafe" in link_names
    end
  end

  # External test removed - we now have proper tests with mocking
end
