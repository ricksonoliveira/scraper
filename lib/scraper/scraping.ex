defmodule Scraper.Scraping do
  @moduledoc """
  The Scraping context.
  This context handles all operations related to web page scraping and link management.
  """

  import Ecto.Query, warn: false
  alias Scraper.Repo

  @doc """
  Returns the list of pages for a specific user.

  ## Examples

      iex> list_pages(user_id)
      [%Page{}, ...]

  """
  def list_pages(user_id) do
    Page
    |> where([p], p.user_id == ^user_id)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
    |> Repo.preload(:links)
  end

  @doc """
  Gets a single page.

  Raises `Ecto.NoResultsError` if the Page does not exist.

  ## Examples

      iex> get_page(123)
      %Page{}

      iex> get_page(456)
      nil

  """
  def get_page(id) do
    Page
    |> Repo.get(id)
    |> Repo.preload(:links)
  end

  @doc """
  Scrapes a web page and stores the links found.

  ## Examples

      iex> scrape_page(url, user)
      {:ok, %Page{}}

      iex> scrape_page(bad_url, user)
      {:error, %Ecto.Changeset{}}

  """
  def scrape_page(_url, _user) do
    # This will be implemented in the next step
    {:error, "Not implemented yet"}
  end
end
