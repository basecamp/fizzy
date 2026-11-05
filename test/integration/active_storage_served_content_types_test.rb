require "test_helper"

# A blob's content type is whatever the uploader declared whenever the bytes can't be identified, and
# some of the routes that serve a blob answer from the app's own origin. So a blob keeps its stored type
# only when we recognize that type; anything else goes out as binary.
class ActiveStorageServedContentTypesTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts("37s")
    @board = boards(:writebook)
    @card = cards(:logo)
  end

  test "types we don't recognize are served as binary" do
    sign_in_as :david

    [
      "text/javascript",
      "application/javascript",
      "application/x-javascript",
      "text/ecmascript",
      "application/ecmascript",
      "text/jscript",
      "text/x-javascript",
      "application/json",
      "text/css",
      "text/html",
      "text/vnd.turbo-stream.html",
      "application/xhtml+xml",
      "image/svg+xml",
      "text/xml",
      "application/x-unrecognized",
      "",
      nil
    ].each do |content_type|
      serve declared_blob(content_type)

      assert_equal "application/octet-stream", response.media_type, "#{content_type.inspect} was served as declared"
      assert_equal "nosniff", response.headers["X-Content-Type-Options"], content_type.inspect
      assert_match(/\Aattachment\b/, response.headers["Content-Disposition"], content_type.inspect)
    end
  end

  test "a type outside the list can't ask to be shown inline" do
    sign_in_as :david

    serve declared_blob("text/javascript"), disposition: :inline

    assert_equal "application/octet-stream", response.media_type
    assert_match(/\Aattachment\b/, response.headers["Content-Disposition"])
  end

  test "parameters and case don't carry a type past the list" do
    [ "text/javascript; charset=utf-8", "Text/JavaScript", " text/html", "text/plain; x=video/mp4" ].each do |content_type|
      assert_served_as_binary content_type
    end
  end

  test "a list of types is served as binary, even one that starts with a type we keep" do
    [ "video/mp4, text/javascript", "image/png, text/html", "video/mp4; codecs=a, text/javascript",
      "audio/mpeg,text/javascript", "video/mp4 text/javascript" ].each do |content_type|
      assert_served_as_binary content_type
    end
  end

  test "a type with control or non-ASCII characters is served as binary" do
    [ "image/png\r\nX-Other: value", "image/png; x=\r\nX-Other: value", "video/mp4\u0000", "video/mKv", "image/png; x=é" ].each do |content_type|
      assert_served_as_binary content_type
    end
  end

  test "images and PDFs keep their type and display inline" do
    sign_in_as :david

    %w[ image/png image/jpeg image/gif image/webp image/avif application/pdf ].each do |content_type|
      serve declared_blob(content_type), disposition: :inline

      assert_equal content_type, response.media_type
      assert_match(/\Ainline\b/, response.headers["Content-Disposition"], content_type)
    end
  end

  test "audio, video and the images we convert keep their type" do
    sign_in_as :david

    %w[ video/mp4 video/webm video/quicktime audio/mpeg audio/ogg audio/mp4 image/heic image/heif ].each do |content_type|
      serve declared_blob(content_type)

      assert_equal content_type, response.media_type
    end
  end

  test "a recognized type keeps its parameters and spelling" do
    assert_equal "audio/ogg; codecs=opus", typed("audio/ogg; codecs=opus").content_type_for_serving
    assert_equal "Image/PNG", typed("Image/PNG").content_type_for_serving
  end

  test "documents stay downloads under their own filename" do
    sign_in_as :david

    %w[ text/plain text/csv text/markdown application/msword application/vnd.openxmlformats-officedocument.wordprocessingml.document ].each do |content_type|
      serve declared_blob(content_type, filename: "report.docx")

      assert_equal "application/octet-stream", response.media_type, content_type
      assert_match(/\Aattachment; filename="report\.docx"/, response.headers["Content-Disposition"], content_type)
    end
  end

  test "exports keep their zip type and download as attachments" do
    sign_in_as :david

    [ Account::Export.create!(account: @account, user: users(:david)), User::DataExport.create!(account: @account, user: users(:david)) ].each do |export|
      export.file.attach io: StringIO.new("zip"), filename: "export.zip", content_type: "application/zip"

      serve export.file.blob, disposition: :attachment

      assert_equal "application/zip", response.media_type
      assert_match(/\Aattachment; filename="export\.zip"/, response.headers["Content-Disposition"])
    end
  end

  test "an avatar keeps displaying for an anonymous visitor" do
    Current.with(account: @account, session: sessions(:david)) do
      users(:david).avatar.attach io: file_fixture("moon.jpg").open, filename: "avatar.jpg", content_type: "image/jpeg"
    end

    get user_avatar_path(users(:david))
    follow_redirect! while response.redirect?

    assert_response :success
    assert_includes %w[ image/jpeg image/png image/webp ], response.media_type
    assert_match(/\Ainline\b/, response.headers["Content-Disposition"])
  end

  test "a published card's images and media keep displaying for an anonymous visitor" do
    @board.publish
    ActiveStorage::Preview.any_instance.stubs(:processed) # These bytes aren't a video ffmpeg can read

    Current.with(account: @account, session: sessions(:david)) do
      @card.image.attach io: file_fixture("moon.jpg").open, filename: "background.jpg", content_type: "image/jpeg"

      embeds = [
        ActiveStorage::Blob.create_and_upload!(io: file_fixture("moon.jpg").open, filename: "embed.jpg", content_type: "image/jpeg"),
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new("video"), filename: "embed.mp4", content_type: "video/mp4", identify: false),
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new("audio"), filename: "embed.mp3", content_type: "audio/mpeg", identify: false)
      ]

      @card.update! description: embeds.collect { |blob| ActionText::Attachment.from_attachable(blob).to_html }.join
    end

    get public_board_card_path(@board.publication.key, @card)
    assert_response :success

    background, video, audio = css_select("img[src*='background.jpg']"), css_select("video[src*='embed.mp4']"), css_select("audio source[src*='embed.mp3']")
    embed = css_select("img[src*='embed.jpg']")
    assert_equal [ 1, 1, 1, 1 ], [ background, embed, video, audio ].collect(&:size)

    fetch background.first["src"]
    assert_equal "image/jpeg", response.media_type
    assert_match(/\Ainline\b/, response.headers["Content-Disposition"])

    fetch embed.first["src"]
    assert_includes %w[ image/jpeg image/png image/webp ], response.media_type
    assert_match(/\Ainline\b/, response.headers["Content-Disposition"])

    fetch video.first["src"]
    assert_equal "video/mp4", response.media_type

    fetch audio.first["src"]
    assert_equal "audio/mpeg", response.media_type
  end

  private
    def serve(blob, **options)
      fetch rails_blob_path(blob, **options)
    end

    def fetch(path)
      get path
      follow_redirect! while response.redirect?
      assert_response :success
    end

    def assert_served_as_binary(content_type)
      blob = typed(content_type)

      assert_equal "application/octet-stream", blob.content_type_for_serving, content_type.inspect
      assert_equal :attachment, blob.forced_disposition_for_serving, content_type.inspect
    end

    # Unsaved, since uploading infers a type for a nil one and the database won't hold every spelling.
    def typed(content_type)
      ActiveStorage::Blob.new(content_type: content_type)
    end

    # As a direct upload stores it: the declared type, unidentified.
    def declared_blob(content_type, filename: "file.bin")
      Current.with(account: @account, session: sessions(:david)) do
        ActiveStorage::Blob.create_before_direct_upload!(filename: filename, content_type: content_type, byte_size: 4, checksum: OpenSSL::Digest::MD5.base64digest("data")).tap do |blob|
          blob.upload_without_unfurling(StringIO.new("data"))
        end
      end
    end
end
