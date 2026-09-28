require "test_helper"

class Fizzy::Saas::UnprocessableRepresentationTest < ActionDispatch::IntegrationTest
  setup do
    Current.session = sessions(:david)
    @blob = attach_blob_to_card(cards(:logo))
    sign_in_as :david
  end

  test "a permanent verdict answers 422 rather than 500" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")

    get rails_representation_path(@blob.representation(resize_to_limit: [ 100, 100 ]))

    assert_response :unprocessable_entity
  end

  test "the proxy route answers 422 too" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("unreadable")

    get rails_storage_proxy_path(@blob.representation(resize_to_limit: [ 100, 100 ]))

    assert_response :unprocessable_entity
  end

  test "a permanent verdict is reported once, as handled" do
    transforms_raise Fizzy::Saas::Cell::UnprocessableAttachment.new("killed: fsize")
    Rails.error.expects(:report)
      .with { |error, handled:, severity:, **| error.is_a?(Fizzy::Saas::Cell::UnprocessableAttachment) && handled && severity == :info }.once

    get rails_representation_path(@blob.representation(resize_to_limit: [ 100, 100 ]))
  end

  test "a transient failure is left to raise for the retry" do
    transforms_raise Fizzy::Saas::Cell::ProcessingUnavailable.new("capacity")

    assert_raises Fizzy::Saas::Cell::ProcessingUnavailable do
      get rails_representation_path(@blob.representation(resize_to_limit: [ 100, 100 ]))
    end
  end

  private
    def transforms_raise(error)
      ActiveStorage::Variation.any_instance.stubs(:transform).raises(error)
    end

    def attach_blob_to_card(card)
      Current.with(session: sessions(:david)) do
        card.image.attach io: file_fixture("moon.jpg").open, filename: "test.jpg", content_type: "image/jpeg"
        card.image.blob
      end
    end
end
