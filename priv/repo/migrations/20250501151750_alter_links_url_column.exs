defmodule Scraper.Repo.Migrations.AlterLinksUrlColumn do
  use Ecto.Migration

  def change do
    # Change url column from string to text to support longer URLs
    alter table(:links) do
      modify :url, :text, null: false
    end
  end
end
