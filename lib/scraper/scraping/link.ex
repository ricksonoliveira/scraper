defmodule Scraper.Scraping.Link do
  use Ecto.Schema
  import Ecto.Changeset

  schema "links" do
    field :name, :string
    field :url, :string

    belongs_to :page, Scraper.Scraping.Page

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:url, :name, :page_id])
    |> validate_required([:url, :page_id])
    |> foreign_key_constraint(:page_id)
  end
end
