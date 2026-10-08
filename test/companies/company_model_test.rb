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
      { name: 200, description: 5_000, website_url: 2_048 },
      Company::LIMITS
    )
    %w[legal_name email phone founded_on].each do |column|
      refute_includes Company.column_names, column
    end
    Company::LIMITS.each do |field, maximum|
      validator = Company.validators_on(field).find { |item| item.is_a?(ActiveModel::Validations::LengthValidator) }
      assert_equal maximum, validator.options[:maximum], "#{field} length"
    end
  end

  test "a field one character past its limit is invalid" do
    company = Company.new(name: "N" * 201, website_url: "a" * 2_048)

    assert_not company.valid?
    assert_equal ["is too long (maximum is 200 characters)"], company.errors[:name]
    assert_empty company.errors[:website_url]
  end

  test "blank strings become nil and the rest is stripped" do
    company = Company.new(name: "  Nike, Inc. ", website_url: " ", description: "\n")

    assert_equal "Nike, Inc.", company.name
    assert_nil company.website_url
    assert_nil company.description
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

  test "created at is set when the snapshot is inserted" do
    company = Company.create!(name: "Nike, Inc.")

    assert_predicate company.created_at, :present?
    assert_equal false, Company.record_timestamps
  end
end
