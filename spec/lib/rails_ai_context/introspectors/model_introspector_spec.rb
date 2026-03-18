# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::ModelIntrospector do
  let(:introspector) { described_class.new(Rails.application) }

  describe "#call" do
    subject(:result) { introspector.call }

    it "discovers User and Post models" do
      expect(result).to have_key("User")
      expect(result).to have_key("Post")
    end

    it "extracts User associations" do
      assocs = result["User"][:associations]
      expect(assocs).to include(a_hash_including(name: "posts", type: "has_many"))
    end

    it "extracts Post associations" do
      assocs = result["Post"][:associations]
      expect(assocs).to include(a_hash_including(name: "user", type: "belongs_to"))
    end

    it "extracts validations" do
      vals = result["User"][:validations]
      expect(vals).to include(a_hash_including(kind: "presence", attributes: [ "email" ]))
    end

    it "extracts scopes from source files" do
      expect(result["User"][:scopes]).to include("active", "admins")
      expect(result["Post"][:scopes]).to include("published", "recent")
    end

    it "extracts enums" do
      expect(result["User"][:enums]).to have_key("role")
      expect(result["User"][:enums]["role"]).to include("member", "admin")
    end

    it "extracts table names" do
      expect(result["User"][:table_name]).to eq("users")
      expect(result["Post"][:table_name]).to eq("posts")
    end
  end
end
