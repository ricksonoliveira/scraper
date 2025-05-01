defmodule Scraper.Repo.Migrations.CreateLinks do
  use Ecto.Migration

  def change do
    create table(:links) do
      add :url, :string, null: false
      add :name, :text
      add :page_id, references(:pages, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:links, [:page_id])
  end
end
