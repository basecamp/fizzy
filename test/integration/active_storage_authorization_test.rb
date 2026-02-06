require "test_helper"

class ActiveStorageAuthorizationTest < ActionDispatch::IntegrationTest
  setup do
    Current.session = sessions(:david)
    @account = accounts("37s")
    @board = boards(:writebook)
    @card = cards(:logo)
    @blob = attach_blob_to_card(@card)
  end

  test "authenticated user with board access can view blob" do
    sign_in_as :david

    get rails_blob_path(@blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "authenticated user without board access cannot view blob" do
    sign_in_as :mike

    get rails_blob_path(@blob, disposition: :inline)
    assert_response :forbidden
  end

  test "unauthenticated user cannot view blob" do
    get rails_blob_path(@blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{/session/new}, response.location
  end

  test "authenticated user with board access can view representation" do
    sign_in_as :david

    get rails_representation_path(@blob.representation(resize_to_limit: [ 100, 100 ]))
    assert_response :redirect
    assert_match %r{rails/active_storage/}, response.location
  end

  test "authenticated user without board access cannot view representation" do
    sign_in_as :mike

    get rails_representation_path(@blob.representation(resize_to_limit: [ 100, 100 ]))
    assert_response :forbidden
  end

  test "unauthenticated user can view blob on published board with published card" do
    @board.publish

    get rails_blob_path(@blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "unauthenticated user cannot view blob on published board with draft card" do
    @board.publish

    # Create the draft card and attachment with proper Current context
    draft_blob = nil
    Current.with(account: @account, session: sessions(:david)) do
      draft_card = @board.cards.create!(title: "Draft", status: :drafted, creator: users(:david))
      draft_card.image.attach io: file_fixture("moon.jpg").open, filename: "draft.jpg", content_type: "image/jpeg"
      draft_blob = draft_card.image.blob
    end

    get rails_blob_path(draft_blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{/session/new}, response.location
  end

  # Rich text embeds in cards

  test "authenticated user with board access can view rich text embed in card" do
    sign_in_as :david

    blob = attach_blob_as_rich_text_embed(@card)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "authenticated user without board access cannot view rich text embed in card" do
    sign_in_as :mike

    blob = attach_blob_as_rich_text_embed(@card)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :forbidden
  end

  test "unauthenticated user can view rich text embed in card on published board" do
    @board.publish

    blob = attach_blob_as_rich_text_embed(@card)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  # Rich text embeds in comments

  test "authenticated user with board access can view rich text embed in comment" do
    sign_in_as :david

    comment = comments(:logo_1)
    blob = attach_blob_as_rich_text_embed(comment)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "authenticated user without board access cannot view rich text embed in comment" do
    sign_in_as :mike

    comment = comments(:logo_1)
    blob = attach_blob_as_rich_text_embed(comment)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :forbidden
  end

  test "unauthenticated user can view rich text embed in comment on published board" do
    @board.publish

    comment = comments(:logo_1)
    blob = attach_blob_as_rich_text_embed(comment)

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "unauthenticated user can view avatar" do
    blob = attach_avatar_to(users(:david))

    get rails_blob_path(blob, disposition: :inline)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "unauthenticated user can view avatar thumbnail" do
    blob = attach_avatar_to(users(:david))

    get rails_representation_path(blob.representation(resize_to_fill: [ 256, 256 ]))
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  # Account exports

  test "export owner can download their export" do
    sign_in_as :david

    blob = create_export_blob_for(users(:david))

    get rails_blob_path(blob, disposition: :attachment)
    assert_response :redirect
    assert_match %r{rails/active_storage}, response.location
  end

  test "non-owner cannot download another user's export" do
    sign_in_as :jz

    blob = create_export_blob_for(users(:david))

    get rails_blob_path(blob, disposition: :attachment)
    assert_response :forbidden
  end

  test "unauthenticated user cannot download export" do
    blob = create_export_blob_for(users(:david))

    get rails_blob_path(blob, disposition: :attachment)
    assert_response :redirect
    assert_match %r{/session/new}, response.location
  end

  private
    def attach_blob_to_card(card)
      Current.with(session: sessions(:david)) do
        card.image.attach io: file_fixture("moon.jpg").open, filename: "test.jpg", content_type: "image/jpeg"
        card.image.blob
      end
    end

    def attach_blob_as_rich_text_embed(container)
      Current.with(account: @account, session: sessions(:david)) do
        blob = ActiveStorage::Blob.create_and_upload! \
          io: file_fixture("moon.jpg").open,
          filename: "embed.jpg",
          content_type: "image/jpeg"

        attachment_html = ActionText::Attachment.from_attachable(blob).to_html
        if container.respond_to?(:description)
          container.update!(description: "<p>Description with image: #{attachment_html}</p>")
        else
          container.update!(body: "<p>Body with image: #{attachment_html}</p>")
        end

        blob.reload
      end
    end

    def create_export_blob_for(user)
      export = Account::Export.create!(account: @account, user: user)
      export.file.attach io: StringIO.new("test export content"), filename: "export.zip", content_type: "application/zip"
      export.file.blob
    end

    def attach_avatar_to(user)
      Current.with(account: @account, session: sessions(:david)) do
        user.avatar.attach io: file_fixture("moon.jpg").open, filename: "avatar.jpg", content_type: "image/jpeg"
        user.avatar.blob
      end
    end
end
