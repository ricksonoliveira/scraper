defmodule ScraperWeb.PageLive do
  use ScraperWeb, :live_view

  alias Scraper.Scraping
  alias Scraper.Accounts

  @impl true
  def mount(_params, session, socket) do
    socket = assign_defaults(socket, session)

    if socket.assigns.current_user do
      # Get the user's pages with pagination
      {pages, total_count} = Scraping.list_pages_paginated(socket.assigns.current_user.id)

      # Subscribe to updates for each page
      subscribe_to_pages(pages)

      {:ok,
       socket
       |> assign(:pages, pages)
       |> assign(:total_count, total_count)
       |> assign(:page_number, 1)
       |> assign(:page_size, 10)
       |> assign(:url, "")
       |> assign(:loading, false)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")

    if socket.assigns[:current_user] do
      {pages, total_count} =
        Scraping.list_pages_paginated(
          socket.assigns.current_user.id,
          page_number,
          socket.assigns.page_size
        )

      # Subscribe to updates for each page
      subscribe_to_pages(pages)

      {:noreply,
       socket
       |> assign(:pages, pages)
       |> assign(:total_count, total_count)
       |> assign(:page_number, page_number)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("scrape", %{"url" => url}, socket) do
    if socket.assigns.current_user do
      case Scraping.scrape_page(url, socket.assigns.current_user) do
        {:ok, page} ->
          # Subscribe to updates for the new page
          subscribe_to_pages([page])

          # Refresh the pages list
          {pages, total_count} =
            Scraping.list_pages_paginated(
              socket.assigns.current_user.id,
              socket.assigns.page_number,
              socket.assigns.page_size
            )

          {:noreply,
           socket
           |> assign(:pages, pages)
           |> assign(:total_count, total_count)
           |> assign(:url, "")
           |> put_flash(:info, "Page scraping started.")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to start scraping. Please check the URL and try again.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate", %{"url" => url}, socket) do
    {:noreply, assign(socket, :url, url)}
  end

  defp assign_defaults(socket, session) do
    socket
    |> assign_new(:current_user, fn ->
      find_current_user(session)
    end)
  end

  defp find_current_user(session) do
    with user_token when not is_nil(user_token) <- session["user_token"],
         %Accounts.User{} = user <- Accounts.get_user_by_session_token(user_token) do
      user
    else
      _ -> nil
    end
  end

  # Calculate total pages for pagination
  defp total_pages(total_count, page_size) do
    ceil(total_count / page_size)
  end

  # Subscribe to updates for each page
  defp subscribe_to_pages(pages) do
    Enum.each(pages, fn page ->
      ScraperWeb.Endpoint.subscribe("page:#{page.id}")
    end)
  end

  # Generate page path for pagination
  defp page_path(_socket, page_number) do
    ~p"/?page=#{page_number}"
  end

  # Handle page update broadcasts
  @impl true
  def handle_info(%{event: "status_updated", payload: payload}, socket) do
    # Update the page in the pages list if it exists
    updated_pages =
      Enum.map(socket.assigns.pages, fn page ->
        if page.id == payload.id do
          # Update only the status and title fields
          %{page | status: payload.status, title: payload.title}
        else
          page
        end
      end)

    {:noreply, assign(socket, :pages, updated_pages)}
  end
end
