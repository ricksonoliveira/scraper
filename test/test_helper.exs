# Mimic copies
Mimic.copy(HTTPoison)
Mimic.copy(Task)
Mimic.copy(Scraper.Accounts)
Mimic.copy(Scraper.Scraping)
Mimic.copy(Floki)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Scraper.Repo, :manual)
