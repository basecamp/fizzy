require "test_helper"

# Regression coverage for HackerOne #3943339, link 1 (parameter injection).
#
# pagination_link builds the "next page" URL by feeding every request parameter
# to url_for. url_for interprets reserved keys such as `script_name`, `host`,
# and `only_path` as URL-generation control options, so an attacker who slips
# `script_name` into the request query can rewrite the beginning of the
# generated path onto an arbitrary same-origin route (e.g. an Active Storage
# blob-proxy path). The helper must forward only ordinary filter params, never
# url_for control options.
class PaginationHelperTest < ActionView::TestCase
  include Turbo::FramesHelper

  test "next-page link does not honor an attacker-supplied script_name" do
    with_request_params controller: "public/boards/columns/streams", action: "show",
      board_id: "the-board", script_name: "/rails/active_storage/blobs/proxy/SIGNED/x.html%23" do
      href = pagination_href(:stream_column, 2)

      assert_no_match %r{active_storage}, href,
        "script_name must not be able to rewrite the pagination path onto a blob-proxy route"
      assert_match %r{\A/public/boards/the-board/columns/stream}, href,
        "the link should still point at the real next-page route"
    end
  end

  test "next-page link does not honor other url_for control options" do
    # No only_path here: with host present and only_path absent, pre-patch
    # url_for emits an absolute https://attacker.example/... URL, so this
    # genuinely fails without the filter rather than passing for the wrong
    # reason.
    with_request_params controller: "public/boards/columns/streams", action: "show",
      board_id: "the-board", host: "attacker.example", protocol: "https" do
      href = pagination_href(:stream_column, 2)

      assert_no_match %r{attacker\.example}, href,
        "host/protocol must not turn the link into an absolute cross-origin URL"
      assert_match %r{\A/public/boards/the-board/columns/stream}, href,
        "the link must stay a relative path on the real next-page route"
    end
  end

  # original_script_name is prepended to script_name by url_for exactly as
  # script_name is (RouteSet#url_for), so it opens the same path-rewrite vector.
  test "next-page link does not honor an attacker-supplied original_script_name" do
    with_request_params controller: "public/boards/columns/streams", action: "show",
      board_id: "the-board",
      original_script_name: "/rails/active_storage/blobs/proxy/SIGNED/x.html%23" do
      href = pagination_href(:stream_column, 2)

      assert_no_match %r{active_storage}, href,
        "original_script_name must not be able to rewrite the pagination path onto a blob-proxy route"
      assert_match %r{\A/public/boards/the-board/columns/stream}, href,
        "the link should still point at the real next-page route"
    end
  end

  test "next-page link preserves ordinary filter params" do
    with_request_params controller: "public/boards/columns/streams", action: "show",
      board_id: "the-board", previous: "true", tag: "urgent" do
      href = pagination_href(:stream_column, 2)

      assert_match %r{tag=urgent}, href, "legitimate filter params must survive"
      assert_match %r{page=2}, href
    end
  end

  # Link 2: automatic pagination drives Turbo's native FrameRenderer (which
  # creates a live <turbo-frame src> and executes <script> with a copied CSP
  # nonce), NOT the inert DOMParser path. In pagination_controller.js that is the
  # `#replacePaginationLinkWithFrame` branch, taken whenever `discardFrame` is
  # false; the auto-activated link is loaded by the IntersectionObserver with no
  # user click. This pins the rendered markup that selects that branch.
  test "automatic pagination selects the script-executing native Turbo frame branch" do
    with_request_params controller: "public/boards/columns/streams", action: "show", board_id: "the-board" do
      frag = Nokogiri::HTML::DocumentFragment.parse(with_automatic_pagination(:stream_column, FakePage.new) { "" })

      list = frag.at_css("[data-controller='pagination']")
      assert_nil list["data-pagination-discard-frame-value"],
        "discardFrame must stay false so Turbo's native FrameRenderer (script-executing) runs"

      link = frag.at_css("a.pagination-link--active-when-observed")
      assert_not_nil link, "the next-page link must be observer-activated"
      assert_nil link["data-action"], "no click action: the IntersectionObserver loads it without a user click"
    end
  end

  private
    class FakePage
      def number = 1
      def used? = true
      def before_last? = true
      def records = []
    end

    def with_request_params(**params)
      controller.params = ActionController::Parameters.new(params)
      yield
    end

    def pagination_href(namespace, page_number)
      html = pagination_link(namespace, page_number)
      Nokogiri::HTML::DocumentFragment.parse(html).at_css("a")["href"]
    end
end
