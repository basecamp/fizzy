require "test_helper"

# pagination_link builds the "next page" URL from the request. url_for reads
# reserved keys such as `script_name`, `host`, `only_path` and `use_route` as
# URL-generation options, and any other key as a possible path segment, so a query
# must never reach it as options: only as the link's own query string.
class PaginationHelperTest < ActionView::TestCase
  include Turbo::FramesHelper

  OWN_PATH = "/public/boards/the-board/columns/stream"
  OWN_ROUTE = { controller: "public/boards/columns/streams", action: "show", board_id: "the-board" }

  {
    script_name: "/elsewhere",
    original_script_name: "/elsewhere",
    relative_url_root: "/elsewhere",
    host: "elsewhere.example",
    protocol: "ftp",
    port: "8080",
    subdomain: "elsewhere",
    domain: "elsewhere.example",
    tld_length: "0",
    only_path: "false",
    trailing_slash: "true",
    anchor: "elsewhere",
    user: "someone",
    password: "secret",
    use_route: "root",
    path_params: { format: "xml" },
    params: { elsewhere: "true" },
    _recall: { controller: "cards", action: "index" },
    format: "xml",
    controller: "cards",
    action: "index",
    id: "elsewhere",
    board_id: "elsewhere"
  }.each do |option, value|
    test "next-page link keeps to its own route when the query names #{option}" do
      with_request query: { option => value } do
        assert_equal OWN_PATH, pagination_uri.path
        assert_nil pagination_uri.host
        assert_nil pagination_uri.fragment
        assert_equal "2", pagination_query["page"]
      end
    end
  end

  test "next-page link keeps the query" do
    with_request query: { tag: "urgent", terms: [ "one", "two" ], nested: { key: "value" } } do
      assert_equal OWN_PATH, pagination_uri.path
      assert_equal "urgent", pagination_query["tag"]
      assert_equal [ "one", "two" ], pagination_query["terms"]
      assert_equal({ "key" => "value" }, pagination_query["nested"])
    end
  end

  test "next-page link replaces the query's page" do
    with_request query: { page: "7" } do
      assert_equal "2", pagination_query["page"]
    end
  end

  test "next-page link leaves out form params" do
    with_request form: { authenticity_token: "secret" } do
      assert_nil pagination_query["authenticity_token"]
    end
  end

  # Link 2: automatic pagination drives Turbo's native FrameRenderer (which
  # creates a live <turbo-frame src> and executes <script> with a copied CSP
  # nonce), NOT the inert DOMParser path. In pagination_controller.js that is the
  # `#replacePaginationLinkWithFrame` branch, taken whenever `discardFrame` is
  # false; the auto-activated link is loaded by the IntersectionObserver with no
  # user click. This pins the rendered markup that selects that branch.
  test "automatic pagination selects the script-executing native Turbo frame branch" do
    with_request do
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

    def with_request(query: {}, form: {})
      request.path_parameters = OWN_ROUTE
      request.set_header "QUERY_STRING", query.to_query
      request.request_parameters = form
      controller.params = ActionController::Parameters.new(query.merge(form).merge(OWN_ROUTE))
      yield
    end

    def pagination_uri
      URI(Nokogiri::HTML::DocumentFragment.parse(pagination_link(:stream_column, 2)).at_css("a")["href"])
    end

    def pagination_query
      Rack::Utils.parse_nested_query(pagination_uri.query)
    end
end
