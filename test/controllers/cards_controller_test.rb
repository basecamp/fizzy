require "test_helper"

class BubblesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as :kevin
  end

  test "index" do
    get bubbles_url
    assert_response :success
  end

  test "filtered index" do
    get bubbles_url(filters(:jz_assignments).as_params.merge(term: "haggis"))
    assert_response :success
  end

  test "create" do
    assert_difference "Bubble.count", 1 do
      post bucket_bubbles_url(buckets(:writebook))
    end
    assert_redirected_to bucket_bubble_url(buckets(:writebook), Bubble.last)
  end

  test "show" do
    get bucket_bubble_url(buckets(:writebook), bubbles(:logo))
    assert_response :success
  end

  test "edit" do
    get edit_bucket_bubble_url(buckets(:writebook), bubbles(:logo))
    assert_response :success
  end

  test "update" do
    patch bucket_bubble_url(buckets(:writebook), bubbles(:logo)), params: {
      bubble: {
        title: "Logo needs to change",
        color: "#000000",
        due_on: 1.week.from_now,
        image: fixture_file_upload("moon.jpg", "image/jpeg"),
        draft_comment: "Something more in-depth",
        tag_ids: [ tags(:mobile).id ] } }
    assert_redirected_to bucket_bubble_url(buckets(:writebook), bubbles(:logo))

    bubble = bubbles(:logo).reload
    assert_equal "Logo needs to change", bubble.title
    assert_equal "#000000", bubble.color
    assert_equal 1.week.from_now.to_date, bubble.due_on
    assert_equal "moon.jpg", bubble.image.filename.to_s
    assert_equal [ tags(:mobile) ], bubble.tags

    assert_equal "Something more in-depth", bubble.messages.comments.first.comment.body_plain_text.strip
  end

  test "users can only see bubbles in buckets they have access to" do
    get bucket_bubble_url(buckets(:writebook), bubbles(:logo))
    assert_response :success

    buckets(:writebook).update! all_access: false
    buckets(:writebook).accesses.revoke_from users(:kevin)
    get bucket_bubble_url(buckets(:writebook), bubbles(:logo))
    assert_response :not_found
  end
end
