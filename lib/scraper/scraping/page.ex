defmodule Scraper.Scraping.Page do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pages" do
    field :status, :string
    field :title, :string
    field :url, :string
    
    belongs_to :user, Scraper.Accounts.User
    has_many :links, Scraper.Scraping.Link

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(page, attrs) do
    page
    |> cast(attrs, [:url, :title, :status, :user_id])
    |> validate_required([:url, :title, :status, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
