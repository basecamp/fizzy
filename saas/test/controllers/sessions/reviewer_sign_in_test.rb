require "test_helper"

class Sessions::ReviewerSignInTest < ActionDispatch::IntegrationTest
  setup do
    @code = Identity::ReviewerSignIn.generate_code
    @reviewer = identities(:kevin)
    configure email_address: @reviewer.email_address, code_digest: Identity::ReviewerSignIn.digest(@code)
  end

  teardown { configure email_address: nil, code_digest: nil }

  test "the reviewer signs in with the fixed code in place of the emailed one" do
    untenanted do
      post session_path, params: { email_address: @reviewer.email_address }
      post session_magic_link_url, params: { code: @code }

      assert_redirected_to landing_path
      assert cookies[:session_token].present?
    end
  end

  test "each use of the code is in the request's structured log" do
    lines = []
    Rails.application.config.structured_logging.logger.stubs(:info).with { |line| lines << line }

    untenanted do
      post session_path, params: { email_address: @reviewer.email_address }
      post session_magic_link_url, params: { code: @code }

      assert cookies[:session_token].present?
    end

    used = lines.select { |line| line.include?("reviewer_sign_in") }
    assert_equal 1, used.size
    assert_equal @reviewer.id, JSON.parse(used.first).dig("authentication", "reviewer_sign_in", "identity", "id")
    assert lines.none? { |line| line.include?(@code) }
  end

  test "the reviewer's emailed code still works" do
    untenanted do
      post session_path, params: { email_address: @reviewer.email_address }
      magic_link = @reviewer.magic_links.order(:created_at).last
      post session_magic_link_url, params: { code: magic_link.code }

      assert_redirected_to landing_path
      assert cookies[:session_token].present?
    end
  end

  test "another identity can't sign in with the reviewer's code" do
    other = identities(:jason)

    untenanted do
      post session_path, params: { email_address: other.email_address }
      post session_magic_link_url, params: { code: @code }

      assert_redirected_to session_magic_link_path
      assert_not cookies[:session_token].present?
    end
  end

  test "a wrong code is refused for the reviewer" do
    untenanted do
      post session_path, params: { email_address: @reviewer.email_address }
      post session_magic_link_url, params: { code: Identity::ReviewerSignIn.generate_code }

      assert_redirected_to session_magic_link_path
      assert_not cookies[:session_token].present?
    end
  end

  test "the code does nothing when the exemption isn't configured" do
    configure email_address: nil, code_digest: nil

    untenanted do
      post session_path, params: { email_address: @reviewer.email_address }
      post session_magic_link_url, params: { code: @code }

      assert_redirected_to session_magic_link_path
      assert_not cookies[:session_token].present?
    end
  end

  test "the code needs the reviewer's pending sign-in" do
    untenanted do
      post session_magic_link_url, params: { code: @code }

      assert_redirected_to new_session_path
      assert_not cookies[:session_token].present?
    end
  end

  private
    def configure(email_address:, code_digest:)
      Rails.application.config.x.reviewer_sign_in.email_address = email_address
      Rails.application.config.x.reviewer_sign_in.code_digest = code_digest
    end
end
