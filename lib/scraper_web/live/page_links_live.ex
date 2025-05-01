defmodule ScraperWeb.PageLinksLive do
  use ScraperWeb, :live_view

  alias Scraper.Scraping
  alias Scraper.Accounts

  @impl true
  def mount(%{"id" => id}, session, socket) do
    socket = assign_defaults(socket, session)

    if socket.assigns.current_user do
      # Handle the case when the page is not found
      try do
        page = Scraping.get_page!(id)

        # Check if the page belongs to the current user
        if page.user_id == socket.assigns.current_user.id do
          {links, total_count} = Scraping.list_links(page.id)

          socket =
            socket
            |> assign(:page, page)
            |> assign(:links, links)
            |> assign(:total_count, total_count)
            |> assign(:page_number, 1)
            |> assign(:page_size, 10)

          {:ok, socket}
        else
          {:ok,
           socket
           |> put_flash(:error, "You don't have access to this page")
           |> push_navigate(to: ~p"/")}
        end
      rescue
        Ecto.NoResultsError ->
          {:ok,
           socket
           |> put_flash(:error, "Page not found")
           |> push_navigate(to: ~p"/")}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "You need to log in to view this page")
       |> push_navigate(to: ~p"/users/log_in")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    page_number = String.to_integer(params["page"] || "1")

    if socket.assigns[:page] do
      {links, total_count} =
        Scraping.list_links(
          socket.assigns.page.id,
          page_number,
          socket.assigns.page_size
        )

      {:noreply,
       socket
       |> assign(:links, links)
       |> assign(:total_count, total_count)
       |> assign(:page_number, page_number)}
    else
      {:noreply, socket}
    end
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

  # Generate page path for pagination
  # In templates, we don't need the socket - we can use @page directly
  defp page_path(%{assigns: %{page: page}}, page_number) do
    ~p"/pages/#{page.id}?page=#{page_number}"
  end

  # Format the link name for display
  defp format_link_name(name) when is_binary(name) and byte_size(name) > 0, do: name
  defp format_link_name(_), do: "No text"
end
