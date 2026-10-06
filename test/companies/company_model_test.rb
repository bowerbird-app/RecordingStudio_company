# frozen_string_literal: true

require_relative "support"

class CompanyModelTest < ActiveSupport::TestCase
  Company = RecordingStudioCompany::Company

  test "fields are the table's columns other than id and created_at" do
    assert_equal Company.column_names.map(&:to_sym) - %i[id created_at], Company::FIELDS
    refute_includes Company.column_names, "updated_at"
  end

  test "every string and text field has a length limit from LIMITS" do
    text_fields = Company.columns.select { |column| %i[string text].include?(column.type) }.map(&:name).map(&:to_sym)

    assert_equal text_fields.sort, Company::LIMITS.keys.sort
    assert_equal(
      { name: 200, legal_name: 255, description: 5_000, website_url: 2_048, email: 320, phone: 50 },
      Company::LIMITS
    )
    Company::LIMITS.each do |field, maximum|
      validator = Company.validators_on(field).find { |item| item.is_a?(ActiveModel::Validations::LengthValidator) }
      assert_equal maximum, validator.options[:maximum], "#{field} length"
    end
  end

  test "a field one character past its limit is invalid" do
    company = Company.new(name: "N" * 201, phone: "1" * 50)

    assert_not company.valid?
    assert_equal ["is too long (maximum is 200 characters)"], company.errors[:name]
    assert_empty company.errors[:phone]
  end

  test "blank strings become nil and the rest is stripped" do
    company = Company.new(name: "  Nike, Inc. ", legal_name: " ", email: "", description: "\n")

    assert_equal "Nike, Inc.", company.name
    assert_nil company.legal_name
    assert_nil company.email
    assert_nil company.description
  end

  test "founded on is a date, blank for unknown, and an error for anything else" do
    assert_equal Date.new(1964, 1, 25), Company.new(name: "Nike", founded_on: "1964-01-25").founded_on
    assert_predicate Company.new(name: "Nike", founded_on: ""), :valid?
    assert_nil Company.new(name: "Nike", founded_on: "").founded_on

    company = Company.new(name: "Nike", founded_on: "soon")
    assert_not company.valid?
    assert_equal ["is invalid"], company.errors[:founded_on]
  end

  test "website href links only http and https addresses" do
    {
      "https://about.nike.com" => "https://about.nike.com",
      "http://x.test/path" => "http://x.test/path",
      "nike.com" => "https://nike.com",
      "javascript:alert(1)" => nil,
      "mailto:press@nike.com" => nil,
      "https://" => nil,
      "not a url" => nil,
      nil => nil
    }.each do |stored, href|
      company = Company.new(name: "Nike", website_url: stored)

      if href.nil?
        assert_nil company.website_href, stored.inspect
      else
        assert_equal href, company.website_href
      end
    end
  end

  test "website href never rewrites the stored value" do
    company = Company.new(name: "Nike", website_url: "nike.com")
    company.website_href

    assert_equal "nike.com", company.website_url
  end

  test "phone href keeps a leading plus and the digits" do
    assert_equal "tel:+15036716453", Company.new(name: "Nike", phone: "+1 (503) 671-6453").phone_href
    assert_equal "tel:0298765432", Company.new(name: "Nike", phone: "02 9876 5432").phone_href
    assert_nil Company.new(name: "Nike", phone: "ext 12").phone_href
    assert_nil Company.new(name: "Nike").phone_href
  end

  test "created at is set when the snapshot is inserted" do
    company = Company.create!(name: "Nike, Inc.")

    assert_predicate company.created_at, :present?
    assert_equal false, Company.record_timestamps
  end
end
