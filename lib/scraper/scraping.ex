defmodule Scraper.Scraping do
  @moduledoc """
  The Scraping context.
  This context handles all operations related to web page scraping and link management.
  """

  import Ecto.Query, warn: false
  alias Scraper.Repo
  alias Scraper.Scraping.{Page, Link}

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
  Gets a single page with links.

  Raises `Ecto.NoResultsError` if the Page does not exist.

  ## Examples

      iex> get_page!(123)
      %Page{}

      iex> get_page!(456)
      ** (Ecto.NoResultsError)

  """
  def get_page!(id) do
    Page
    |> Repo.get!(id)
    |> Repo.preload(:links)
  end

  @doc """
  Creates a page.

  ## Examples

      iex> create_page(%{field: value})
      {:ok, %Page{}}

      iex> create_page(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_page(attrs \\ %{}) do
    %Page{}
    |> Page.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a page's status.

  ## Examples

      iex> update_page_status(page, "completed")
      {:ok, %Page{}}

  """
  def update_page_status(%Page{} = page, status) do
    page
    |> Page.changeset(%{status: status})
    |> Repo.update()
  end

  @doc """
  Updates a page with the given attributes.

  ## Examples

      iex> update_page(page, %{field: new_value})
      {:ok, %Page{}}

      iex> update_page(page, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_page(%Page{} = page, attrs) do
    page
    |> Page.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Creates a link.

  ## Examples

      iex> create_link(%{field: value})
      {:ok, %Link{}}

      iex> create_link(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_link(attrs \\ %{}) do
    %Link{}
    |> Link.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the list of links for a specific page with pagination.

  ## Examples

      iex> list_links(page_id, page_number, page_size)
      {[%Link{}, ...], total_count}

  """
  def list_links(page_id, page_number \\ 1, page_size \\ 10) do
    query =
      from l in Link,
        where: l.page_id == ^page_id,
        order_by: [asc: l.id]

    total_count = Repo.aggregate(query, :count, :id)

    links =
      query
      |> limit(^page_size)
      |> offset(^((page_number - 1) * page_size))
      |> Repo.all()

    {links, total_count}
  end

  @doc """
  Returns the list of pages for a specific user with pagination.

  ## Examples

      iex> list_pages_paginated(user_id, page_number, page_size)
      {[%Page{}, ...], total_count}

  """
  def list_pages_paginated(user_id, page_number \\ 1, page_size \\ 10) do
    query =
      from p in Page,
        where: p.user_id == ^user_id,
        order_by: [desc: p.inserted_at]

    total_count = Repo.aggregate(query, :count, :id)

    pages =
      query
      |> limit(^page_size)
      |> offset(^((page_number - 1) * page_size))
      |> Repo.all()
      |> Repo.preload(:links)

    {pages, total_count}
  end

  @doc """
  Returns the total number of links for a page.

  ## Examples

      iex> count_links(page_id)
      42

  """
  def count_links(page_id) do
    Repo.aggregate(from(l in Link, where: l.page_id == ^page_id), :count, :id)
  end

  @doc """
  Scrapes a web page and stores the links found.
  Delegates to ScraperService for the actual scraping logic.

  ## Examples

      iex> scrape_page(url, user)
      {:ok, %Page{}}

      iex> scrape_page(bad_url, user)
      {:error, %Ecto.Changeset{}}

  """
  defdelegate scrape_page(url, user), to: Scraper.Services.ScraperService
end
