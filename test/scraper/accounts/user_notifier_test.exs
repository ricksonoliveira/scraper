defmodule Scraper.Accounts.UserNotifierTest do
  use Scraper.DataCase, async: true
  use ExUnit.Case

  import Swoosh.TestAssertions

  alias Scraper.Accounts.UserNotifier
  import Scraper.AccountsFixtures

  setup do
    # Create a test user
    user = user_fixture()
    test_url = "https://example.com/some/confirmation/url"

    %{user: user, url: test_url}
  end

  describe "deliver_confirmation_instructions/2" do
    test "sends confirmation email with the provided URL", %{user: user, url: url} do
      # Send the email
      {:ok, email} = UserNotifier.deliver_confirmation_instructions(user, url)

      # Verify email was delivered
      assert_email_sent(email)

      # Verify email content
      assert email.subject == "Confirmation instructions"
      assert email.text_body =~ "You can confirm your account"
      assert email.text_body =~ url
      assert email.to == [{"", user.email}]
      assert email.from == {"Scraper", "contact@example.com"}
    end
  end

  describe "deliver_reset_password_instructions/2" do
    test "sends reset password email with the provided URL", %{user: user, url: url} do
      # Send the email
      {:ok, email} = UserNotifier.deliver_reset_password_instructions(user, url)

      # Verify email was delivered
      assert_email_sent(email)

      # Verify email content
      assert email.subject == "Reset password instructions"
      assert email.text_body =~ "You can reset your password"
      assert email.text_body =~ url
      assert email.to == [{"", user.email}]
    end
  end

  describe "deliver_update_email_instructions/2" do
    test "sends update email instructions with the provided URL", %{user: user, url: url} do
      # Send the email
      {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)

      # Verify email was delivered
      assert_email_sent(email)

      # Verify email content
      assert email.subject == "Update email instructions"
      assert email.text_body =~ "You can change your email"
      assert email.text_body =~ url
      assert email.to == [{"", user.email}]
    end
  end
end
