defmodule Scraper.ScrapingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Scraper.Scraping` context.
  """

  @doc """
  Generate a page.
  """
  def page_fixture(attrs \\ %{}) do
    {:ok, page} =
      attrs
      |> Enum.into(%{
        url: "https://example.com",
        title: "Example Domain",
        status: "completed",
        user_id: attrs[:user_id] || user_fixture().id
      })
      |> Scraper.Scraping.create_page()

    # Always return a page with empty links list for consistent test comparisons
    %{page | links: []}
  end

  @doc """
  Generate a link.
  """
  def link_fixture(attrs \\ %{}) do
    page = attrs[:page] || page_fixture()

    {:ok, link} =
      attrs
      |> Enum.into(%{
        url: "https://example.com/page",
        name: "Example Link",
        page_id: attrs[:page_id] || page.id
      })
      |> Scraper.Scraping.create_link()

    link
  end

  defp user_fixture do
    Scraper.AccountsFixtures.user_fixture()
  end
end
