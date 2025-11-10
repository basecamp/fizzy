require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  def parse(html)
    Nokogiri::HTML::DocumentFragment.parse(html)
  end

  test "page_title_tag on untenanted page" do
    ApplicationRecord.without_tenant do
      assert_select parse(page_title_tag), "title", text: "Fizzy"
    end
  end

  test "page_title_tag on untenanted page with a page title" do
    @page_title = "Holodeck"

    ApplicationRecord.without_tenant do
      assert_select parse(page_title_tag), "title", text: "Holodeck | Fizzy"
    end
  end

  test "page_title_tag on tenanted page when user has a single membership" do
    Current.session = sessions(:david)

    assert_select parse(page_title_tag), "title", text: "Fizzy"
  end

  test "page_title_tag on tenanted page when user has multiple memberships" do
    Current.session = sessions(:david)
    identities(:david).memberships.create!(tenant: "dangling-tenant")

    assert_select parse(page_title_tag), "title", text: "37signals | Fizzy"
  end

  test "page_title_tag on tenanted page with a page title when user has a single membership" do
    Current.session = sessions(:david)
    @page_title = "Holodeck"

    assert_select parse(page_title_tag), "title", text: "Holodeck | Fizzy"
  end

  test "page_title_tag on tenanted page with a page title when user has multiple memberships" do
    Current.session = sessions(:david)
    identities(:david).memberships.create!(tenant: "dangling-tenant")
    @page_title = "Holodeck"

    assert_select parse(page_title_tag), "title", text: "Holodeck | 37signals | Fizzy"
  end
end
