# frozen_string_literal: true

require_relative "support"

class DisplayHelperTest < ActiveSupport::TestCase
  include CompanyTestSupport

  test "the logo is the company's image when it has one" do
    nike = create_company(press_centre, "Nike, Inc.")
    RecordingStudioCompany.set_logo(nike, signed_blob_id: png_blob.signed_id, actor: owner)

    image = render_erb("<%= recording_studio_company_logo(company, size: :sm) %>", company: nike).at_css("img")

    assert image
    assert_equal "Nike, Inc. logo", image["alt"]
    assert_match %r{\A/recording_studio_attachable/}, image["src"]
    assert_includes image["src"], "square_small"
  end

  test "the logo falls back to the company's initials" do
    nike = create_company(press_centre, "Nike, Inc.")

    html = render_erb("<%= recording_studio_company_logo(company) %>", company: nike)

    assert_nil html.at_css("img")
    assert_includes html.text, "NI"
  end

  test "a removed logo falls back to the initials" do
    nike = create_company(press_centre, "Nike, Inc.")
    RecordingStudioCompany.set_logo(nike, signed_blob_id: png_blob.signed_id, actor: owner)
    RecordingStudioCompany.remove_logo(nike, actor: owner)

    assert_nil render_erb("<%= recording_studio_company_logo(company) %>", company: nike).at_css("img")
  end

  test "the card shows every present field" do
    nike = create_company(
      press_centre,
      "Nike",
      description: "Athletic footwear and apparel.",
      website_url: "about.nike.com",
      phone: "+1 (503) 671-6453"
    )

    card = render_card(nike)
    text = card.text.squish

    ["Nike", "Athletic footwear and apparel.", "about.nike.com", "+1 (503) 671-6453"].each do |value|
      assert_includes text, value
    end
    assert_equal "https://about.nike.com", card.at_css("a[target=_blank]")["href"]
    assert_equal "noopener noreferrer", card.at_css("a[target=_blank]")["rel"]
    assert card.at_css("a[href='tel:+15036716453']")
    refute_includes text, "Email"
    refute_includes text, "Founded"
  end

  test "the card leaves out blank fields" do
    acme = create_company(agency, "Acme Coffee Pty Ltd")

    card = render_card(acme)

    assert_equal(["Acme Coffee Pty Ltd"], card.css("p").map { |paragraph| paragraph.text.strip })
    assert_nil card.at_css("dl")
    %w[Website Phone Email Founded].each { |label| refute_includes card.text, label }
  end

  test "the card links the website only through website_href" do
    company = create_company(agency, "Odd Website Pty Ltd", website_url: "javascript:alert(1)")

    card = render_card(company)

    assert_includes card.text, "javascript:alert(1)"
    assert_empty card.css("a[href^='javascript']")
    assert_nil card.at_css("a[target=_blank]")
  end

  test "the card escapes every field" do
    payload = "<script>alert(1)</script>"
    company = create_company(agency, "#{payload} Pty Ltd", description: payload)

    card = render_card(company)

    assert_empty card.css("script")
    assert_includes card.text, "#{payload} Pty Ltd"
  end

  test "the card links nothing in the company pages" do
    nike = create_company(press_centre, "Nike, Inc.", website_url: "https://about.nike.com")

    hrefs = render_card(nike).css("a").map { |link| link["href"] }

    assert_equal ["https://about.nike.com"], hrefs
  end

  private

  def render_card(company)
    render_erb("<%= recording_studio_company_card(company) %>", company:).at_css("[data-recording-studio-company-card]")
  end

  def render_erb(template, **locals)
    Nokogiri::HTML5.fragment(ApplicationController.render(inline: template, locals:, layout: false))
  end
end
