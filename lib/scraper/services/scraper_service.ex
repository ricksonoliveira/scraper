defmodule Scraper.Services.ScraperService do
  @moduledoc """
  Service module for handling web page scraping logic.
  This separates the business logic from the database operations.
  """

  alias Scraper.Scraping
  alias ScraperWeb.Endpoint
  alias Scraper.Scraping.Page
  alias Scraper.Accounts.User

  @doc """
  Scrapes a web page and stores the links found.

  ## Examples

      iex> scrape_page(url, user)
      {:ok, %Page{}}

      iex> scrape_page(bad_url, user)
      {:error, %Ecto.Changeset{}}
  """
  def scrape_page(url, %User{} = user) do
    # Start by creating a page with "in progress" status
    with {:ok, page} <-
           Scraping.create_page(%{
             url: url,
             title: extract_title_from_url(url),
             status: "in progress",
             user_id: user.id
           }) do
      # Start the scraping process asynchronously
      Task.start(fn -> process_page_scraping(page) end)

      # Return the page immediately so the user doesn't have to wait
      {:ok, page}
    end
  end

  @doc """
  Extracts a title from a URL by using the domain name.
  Returns the domain if available, or "Unknown page" otherwise.
  """
  def extract_title_from_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.host do
      uri.host
    else
      "Unknown page"
    end
  end

  def extract_title_from_url(_), do: "Unknown page"

  @doc """
  Extracts the title from a document.
  Returns the title text if found, or falls back to the existing page title.
  """
  def extract_title(document, fallback_title) do
    case Floki.find(document, "title") do
      [title_element | _] -> Floki.text(title_element)
      _ -> fallback_title
    end
  end

  @doc """
  Processes a single link element and creates a database record.
  Returns {:ok, link} if successful, or :error if there was a problem.
  """
  def process_link(link, page_id) do
    href = Floki.attribute(link, "href") |> List.first()

    if href do
      # Sanitize the name to handle encoding issues
      name =
        Floki.text(link)
        # Remove non-ASCII characters
        |> String.replace(~r/[^\x00-\x7F]/, "")
        |> String.trim()

      # If the name is empty after sanitization, use a default
      name = if name == "", do: "Link", else: name

      # Create a link record and handle potential errors
      case Scraping.create_link(%{url: href, name: name, page_id: page_id}) do
        {:ok, link} -> {:ok, link}
        {:error, _} -> :error
      end
    else
      :error
    end
  end

  @doc """
  Extracts and processes all links from a document.
  Returns a list of successfully created link records.
  """
  def extract_and_process_links(document, page_id) do
    Floki.find(document, "a")
    |> Enum.filter(fn link ->
      # Only process links that have href attributes
      href = Floki.attribute(link, "href") |> List.first()
      href != nil
    end)
    |> Enum.map(fn link -> process_link(link, page_id) end)
    |> Enum.filter(fn result -> match?({:ok, _}, result) end)
  end

  @doc """
  Processes a page for scraping.
  Fetches the page content, extracts the title and links, and updates the page status.
  """
  def process_page_scraping(%Page{} = page) do
    try do
      # Fetch the page content
      case HTTPoison.get(page.url, [],
             follow_redirect: true,
             timeout: 30_000,
             recv_timeout: 30_000
           ) do
        {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
          # Parse the HTML
          case Floki.parse_document(body) do
            {:ok, document} ->
              # Extract the page title
              title = extract_title(document, page.title)

              # Update the page status to processing
              {:ok, page} = Scraping.update_page_status(page, "processing")
              # Broadcast status change
              broadcast_status_update(page)

              # Update the page title
              {:ok, page} = Scraping.update_page(page, %{title: title})

              # Extract and process all links from the page
              _links_created = extract_and_process_links(document, page.id)

              # Update the page status to completed
              {:ok, updated_page} = Scraping.update_page_status(page, "completed")
              # Broadcast status change
              broadcast_status_update(updated_page)

            {:error, _reason} ->
              # Handle HTML parsing errors
              {:ok, updated_page} = Scraping.update_page_status(page, "error")
              # Broadcast status change
              broadcast_status_update(updated_page)
          end

        {:ok, %HTTPoison.Response{}} ->
          # Handle non-200 responses
          {:ok, updated_page} = Scraping.update_page_status(page, "error")
          # Broadcast status change
          broadcast_status_update(updated_page)

        {:error, %HTTPoison.Error{}} ->
          # Handle HTTP errors
          {:ok, updated_page} = Scraping.update_page_status(page, "error")
          # Broadcast status change
          broadcast_status_update(updated_page)
      end
    rescue
      _ ->
        # Handle any unexpected errors
        {:ok, updated_page} = Scraping.update_page_status(page, "error")
        # Broadcast status change
        broadcast_status_update(updated_page)
    end
  end

  # Helper function to broadcast page status updates
  # Broadcasts a status update for a page to all subscribers.
  # This is used to update the UI in real-time when a page's status changes.
  defp broadcast_status_update(page) do
    Endpoint.broadcast("page:#{page.id}", "status_updated", %{
      id: page.id,
      status: page.status,
      title: page.title
    })
  end
end
