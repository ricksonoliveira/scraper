defmodule ScraperWeb.UserConfirmationLiveTest do
  use ScraperWeb.ConnCase, async: true
  use Mimic

  import Phoenix.LiveViewTest
  import Scraper.AccountsFixtures

  alias Scraper.Accounts
  alias Scraper.Repo

  setup do
    %{user: user_fixture()}
  end

  describe "Confirm user" do
    test "renders confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/confirm/some-token")
      assert html =~ "Confirm Account"
    end

    test "confirms the given token once", %{conn: conn, user: user} do
      # Create a token manually for testing
      # We can't use deliver_user_confirmation_instructions since it auto-confirms now
      {encoded_token, user_token} = Scraper.Accounts.UserToken.build_email_token(user, "confirm")
      Repo.insert!(user_token)

      token = encoded_token

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "User confirmed successfully"

      assert Accounts.get_user!(user.id).confirmed_at
      refute get_session(conn, :user_token)
      assert Repo.all(Accounts.UserToken) == []

      # when not logged in
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User confirmation link is invalid or it has expired"

      # when logged in
      conn =
        build_conn()
        |> log_in_user(user)

      {:ok, lv, _html} = live(conn, ~p"/users/confirm/#{token}")

      result =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, "/")

      assert {:ok, conn} = result
      refute Phoenix.Flash.get(conn.assigns.flash, :error)
    end

    test "does not confirm email with invalid token", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/users/confirm/invalid-token")

      {:ok, conn} =
        lv
        |> form("#confirmation_form")
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~
               "User confirmation link is invalid or it has expired"

      refute Accounts.get_user!(user.id).confirmed_at
    end
  end
end
