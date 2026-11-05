require "test_helper"

class Oauth::AvailabilityTest < ActiveSupport::TestCase
  include OauthAvailabilityTestHelper, OauthAuditTestHelper

  test "lit in test" do
    assert Oauth::Availability.acceptance_enabled?
    assert Oauth::Availability.issuance_enabled?
  end

  test "an unset acceptance switch is dark" do
    with_oauth_availability acceptance: nil, issuance: nil do
      assert_not Oauth::Availability.acceptance_enabled?
      assert_not Oauth::Availability.issuance_enabled?
    end
  end

  test "acceptance must be exactly true" do
    with_oauth_availability acceptance: "false" do
      assert_not Oauth::Availability.acceptance_enabled?
    end
  end

  test "issuance follows acceptance unless paused" do
    with_oauth_availability acceptance: true, issuance: nil do
      assert Oauth::Availability.issuance_enabled?
    end

    with_oauth_availability acceptance: true, issuance: false do
      assert Oauth::Availability.acceptance_enabled?
      assert_not Oauth::Availability.issuance_enabled?
    end
  end

  test "issuance is subordinate to acceptance" do
    with_oauth_availability acceptance: false, issuance: true do
      assert_not Oauth::Availability.issuance_enabled?
    end
  end

  test "a pilot client clears both switches, and only by its exact client_id" do
    with_oauth_availability acceptance: false, issuance: false, pilot_client_ids: [ "pilot_1" ] do
      assert Oauth::Availability.acceptance_enabled?("pilot_1")
      assert Oauth::Availability.issuance_enabled?("pilot_1")

      assert_not Oauth::Availability.acceptance_enabled?
      assert_not Oauth::Availability.issuance_enabled?("pilot_2")
      assert_not Oauth::Availability.issuance_enabled?("PILOT_1")
      assert_not Oauth::Availability.issuance_enabled?([ "pilot_1" ])
      assert_not Oauth::Availability.issuance_enabled?("")
    end
  end

  test "admits everyone unless connecting apps is in preview" do
    assert Oauth::Availability.admits?(identities(:jz))
    assert Oauth::Availability.admits?(nil)

    with_oauth_availability preview: true do
      assert Oauth::Availability.admits?(identities(:david))
      assert_not Oauth::Availability.admits?(identities(:jz))
      assert_not Oauth::Availability.admits?(nil)
    end
  end

  test "admits the reviewers listed by identity id, only while in preview" do
    with_oauth_availability preview: true, reviewer_ids: [ identities(:jz).id ] do
      assert Oauth::Availability.admits?(identities(:jz))
      assert Oauth::Availability.admits?(identities(:david))
      assert_not Oauth::Availability.admits?(identities(:mike))
      assert_not Oauth::Availability.admits?(nil)
    end

    with_oauth_availability preview: false, reviewer_ids: [] do
      assert Oauth::Availability.admits?(identities(:mike))
    end
  end

  test "no reviewer ids admits staff alone" do
    with_oauth_availability preview: true, reviewer_ids: nil do
      assert Oauth::Availability.admits?(identities(:david))
      assert_not Oauth::Availability.admits?(identities(:jz))
    end
  end

  test "admits whoever an extension admits as a reviewer, only while in preview" do
    saved = Oauth::Availability.reviewer_predicates.dup
    Oauth::Availability.reviewer_predicates = []
    Oauth::Availability.admit_as_reviewer ->(identity) { identity == identities(:jz) }
    Oauth::Availability.admit_as_reviewer ->(identity) { "truthy, not true" }

    with_oauth_availability preview: true do
      assert Oauth::Availability.admits?(identities(:jz))
      assert Oauth::Availability.admits?(identities(:david))
      assert_not Oauth::Availability.admits?(identities(:mike))
      assert_not Oauth::Availability.admits?(nil)
    end
  ensure
    Oauth::Availability.reviewer_predicates = saved
  end

  test "the preview must be exactly true" do
    with_oauth_availability preview: "true" do
      assert_not Oauth::Availability.connected_apps_preview?
    end
  end

  test "the preview is on from CONNECTED_APPS_PREVIEW, or its old name while the new one is unset" do
    assert Oauth::Availability.connected_apps_preview_from("CONNECTED_APPS_PREVIEW" => "true")
    assert Oauth::Availability.connected_apps_preview_from("OAUTH_STAFF_ONLY" => "true")
    assert Oauth::Availability.connected_apps_preview_from("CONNECTED_APPS_PREVIEW" => "", "OAUTH_STAFF_ONLY" => "true")
    assert Oauth::Availability.connected_apps_preview_from("CONNECTED_APPS_PREVIEW" => "true", "OAUTH_STAFF_ONLY" => "false")

    assert_not Oauth::Availability.connected_apps_preview_from({})
    assert_not Oauth::Availability.connected_apps_preview_from("CONNECTED_APPS_PREVIEW" => "false", "OAUTH_STAFF_ONLY" => "true")
    assert_not Oauth::Availability.connected_apps_preview_from("CONNECTED_APPS_PREVIEW" => "1")
    assert_not Oauth::Availability.connected_apps_preview_from("OAUTH_STAFF_ONLY" => "yes")
  end

  test "reviewer ids are parsed from a list separated by commas or spaces" do
    one, two = identities(:jz).id, "03f5h2k9xq7m1b8n4c6d0e2gz"

    assert_equal [ one, two ], Oauth::Availability.reviewer_ids_from(" #{one} ,#{two.upcase}\n#{one}, ")
    assert_equal [], Oauth::Availability.reviewer_ids_from(nil)
    assert_equal [], Oauth::Availability.reviewer_ids_from("")
    assert_equal [], Oauth::Availability.reviewer_ids_from(" , ")
  end

  test "reviewer entries that aren't identity ids are skipped with a warning that doesn't repeat them" do
    logged = StringIO.new
    Rails.stubs(:logger).returns(ActiveSupport::Logger.new(logged))

    ids = nil
    events = capture_oauth_events do
      ids = Oauth::Availability.reviewer_ids_from("reviewer@example.com, 42, #{identities(:jz).id}, #{identities(:jz).id}x")
    end

    assert_equal [ identities(:jz).id ], ids
    skipped = oauth_event(events, "oauth.preview.reviewers_skipped")
    assert_equal 3, skipped[:skipped]
    assert_equal "system", skipped[:actor]
    assert_no_match "reviewer@example.com", skipped.values.join(" ")
    assert_match "skipping entries that aren't identity ids (3)", logged.string
    assert_no_match "reviewer@example.com", logged.string
  end

  test "a clean reviewer list logs nothing" do
    logged = StringIO.new
    Rails.stubs(:logger).returns(ActiveSupport::Logger.new(logged))

    events = capture_oauth_events { Oauth::Availability.reviewer_ids_from(identities(:jz).id) }

    assert_empty logged.string
    assert_empty events
  end
end
