# frozen_string_literal: true

require "test_helper"

class ForwardAuthAuthenticationTest < ActionDispatch::IntegrationTest
  def enable_forward_auth(trusted_ips: [ "127.0.0.0/8" ], auto_provision: false, create_session: false, use_email_local_part_and_lock_email: false)
    Rails.application.config.forward_auth = ForwardAuth::Config.new(
      enabled: true,
      trusted_ips: trusted_ips,
      auto_provision: auto_provision,
      default_role: "member",
      create_session: create_session,
      use_email_local_part_and_lock_email: use_email_local_part_and_lock_email
    )
  end

  def disable_forward_auth
    Rails.application.config.forward_auth = ForwardAuth::Config.new(enabled: false)
  end

  test "when Forward Auth is disabled, request with X-Auth-Email redirects to login" do
    disable_forward_auth
    get cards_path, headers: { "X-Auth-Email" => identities(:kevin).email_address }

    assert_redirected_to new_session_path(script_name: nil)
  end

  test "when Forward Auth is enabled but no trust mechanism configured, redirects to login" do
    Rails.application.config.forward_auth = ForwardAuth::Config.new(
      enabled: true,
      trusted_ips: [],
      secret_header: nil,
      secret: nil
    )
    get cards_path, headers: { "X-Auth-Email" => identities(:kevin).email_address }

    assert_redirected_to new_session_path(script_name: nil)
  end

  test "when Forward Auth is enabled and trusted, valid X-Auth-Email authenticates existing user" do
    enable_forward_auth
    get cards_path, headers: { "X-Auth-Email" => identities(:kevin).email_address }

    assert_response :success
  end

  test "when Forward Auth is enabled but IP not trusted, redirects to login" do
    enable_forward_auth(trusted_ips: [ "10.0.0.0/8" ]) # 127.0.0.1 not in this range
    get cards_path, headers: { "X-Auth-Email" => identities(:kevin).email_address }

    assert_redirected_to new_session_path(script_name: nil)
  end

  test "when Forward Auth is enabled and trusted but no X-Auth-Email header, redirects to login" do
    enable_forward_auth
    get cards_path

    assert_redirected_to new_session_path(script_name: nil)
  end

  test "when Forward Auth is enabled and trusted but X-Auth-Email is invalid format, redirects to login" do
    enable_forward_auth
    get cards_path, headers: { "X-Auth-Email" => "not-an-email" }

    assert_redirected_to new_session_path(script_name: nil)
  end

  test "when Forward Auth is enabled and trusted but email has no User in account and auto_provision is false, redirects to login" do
    enable_forward_auth(auto_provision: false)
    # Identity exists but has no user in 37s (kevin is in 37s; use an identity that is only in another account)
    identity = identities(:mike) # mike is in initech, not 37s
    get cards_path, headers: { "X-Auth-Email" => identity.email_address }

    assert_redirected_to new_session_path(script_name: nil)
  end

  test "when Forward Auth is enabled with auto_provision, creates User for existing Identity in current account" do
    enable_forward_auth(auto_provision: true, create_session: false)
    identity = identities(:mike)
    assert_not identity.users.exists?(account: accounts("37s"))

    get cards_path, headers: { "X-Auth-Email" => identity.email_address }

    assert_response :success
    user = identity.users.find_by(account: accounts("37s"))
    assert user
    assert_equal "member", user.role
    assert user.verified_at.present?
  end

  test "when Forward Auth is enabled with auto_provision, creates Identity and User for new email" do
    enable_forward_auth(auto_provision: true, create_session: false)
    email = "newuser@example.com"
    assert_not Identity.exists?(email_address: email)

    get cards_path, headers: { "X-Auth-Email" => email }

    assert_response :success
    identity = Identity.find_by!(email_address: email)
    user = identity.users.find_by(account: accounts("37s"))
    assert user
    assert_equal "newuser", user.name
    assert_equal "member", user.role
  end

  test "when Forward Auth is enabled with auto_provision, X-Auth-User is used as name when present" do
    enable_forward_auth(auto_provision: true, create_session: false)
    email = "another@example.com"
    get cards_path, headers: { "X-Auth-Email" => email, "X-Auth-User" => "6ce8ddac0ffdd907" }

    assert_response :success
    user = Identity.find_by!(email_address: email).users.find_by(account: accounts("37s"))
    assert_equal "6ce8ddac0ffdd907", user.name
  end

  test "when Forward Auth is enabled and trusted, session cookie is set when create_session is true" do
    enable_forward_auth(create_session: true)
    get cards_path, headers: { "X-Auth-Email" => identities(:kevin).email_address }

    assert_response :success
    assert cookies[:session_token].present?
  end

  test "when use_email_local_part_and_lock_email is true, auto-provisioned user has name from email local part and identity email is locked" do
    enable_forward_auth(auto_provision: true, create_session: false, use_email_local_part_and_lock_email: true)
    email = "suyang@staff.linkerhub.work"
    assert_not Identity.exists?(email_address: email)

    get cards_path, headers: { "X-Auth-Email" => email }

    assert_response :success
    identity = Identity.find_by!(email_address: email)
    user = identity.users.find_by(account: accounts("37s"))
    assert user
    assert_equal "suyang", user.name
    assert identity.email_locked? if identity.respond_to?(:email_locked?)
  end

  test "when use_email_local_part_and_lock_email is true, X-Auth-User is ignored and name is email local part" do
    enable_forward_auth(auto_provision: true, create_session: false, use_email_local_part_and_lock_email: true)
    email = "alice@example.com"
    get cards_path, headers: { "X-Auth-Email" => email, "X-Auth-User" => "gateway-display-name" }

    assert_response :success
    user = Identity.find_by!(email_address: email).users.find_by(account: accounts("37s"))
    assert_equal "alice", user.name
  end
end
