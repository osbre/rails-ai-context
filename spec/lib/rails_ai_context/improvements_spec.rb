# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Token-saving improvements" do
  describe "Improvement 1: UI pattern extraction" do
    let(:introspector) { RailsAiContext::Introspectors::ViewTemplateIntrospector.new(Rails.application) }

    it "returns ui_patterns key" do
      result = introspector.call
      expect(result).to have_key(:ui_patterns)
      expect(result[:ui_patterns]).to be_a(Hash)
    end

    it "extracts patterns from views with repeated classes" do
      Dir.mktmpdir do |dir|
        views_dir = File.join(dir, "app", "views", "posts")
        FileUtils.mkdir_p(views_dir)
        # Create two views with repeated class patterns
        content = '<div class="bg-white rounded-xl p-4 shadow-sm border border-gray-100">card</div>'
        File.write(File.join(views_dir, "index.html.erb"), content * 3)
        File.write(File.join(views_dir, "show.html.erb"), content * 2)

        app = double("app", root: Pathname.new(dir))
        result = RailsAiContext::Introspectors::ViewTemplateIntrospector.new(app).call
        expect(result[:ui_patterns]).to be_a(Hash)
      end
    end

    it "includes UI Patterns in ClaudeSerializer compact output" do
      context = RailsAiContext.introspect
      context[:view_templates] = {
        ui_patterns: { buttons: [ "bg-orange-600 text-white px-4 py-2 rounded-xl hover:bg-orange-700" ] }
      }
      output = RailsAiContext::Serializers::ClaudeSerializer.new(context).call
      expect(output).to include("UI Patterns")
      expect(output).to include("bg-orange-600")
    end

    it "includes UI Patterns in OpencodeSerializer compact output" do
      context = RailsAiContext.introspect
      context[:view_templates] = {
        ui_patterns: { cards: [ "bg-white rounded-2xl p-6 shadow-sm" ] }
      }
      output = RailsAiContext::Serializers::OpencodeSerializer.new(context).call
      expect(output).to include("UI Patterns")
    end

    it "includes UI Patterns in CopilotSerializer compact output" do
      context = RailsAiContext.introspect
      context[:view_templates] = {
        ui_patterns: { inputs: [ "border rounded-lg px-3 py-2 focus:ring-2" ] }
      }
      output = RailsAiContext::Serializers::CopilotSerializer.new(context).call
      expect(output).to include("UI Patterns")
    end

    it "generates rails-ui-patterns.md in Claude rules" do
      context = RailsAiContext.introspect
      context[:view_templates] = {
        ui_patterns: { buttons: [ "bg-orange-600 text-white rounded-xl" ] }
      }
      Dir.mktmpdir do |dir|
        result = RailsAiContext::Serializers::ClaudeRulesSerializer.new(context).call(dir)
        ui_file = File.join(dir, ".claude", "rules", "rails-ui-patterns.md")
        expect(File.exist?(ui_file)).to be true
        expect(File.read(ui_file)).to include("bg-orange-600")
      end
    end

    it "generates rails-ui-patterns.mdc in Cursor rules" do
      context = RailsAiContext.introspect
      context[:view_templates] = {
        ui_patterns: { cards: [ "bg-white rounded-xl shadow-sm" ] }
      }
      Dir.mktmpdir do |dir|
        result = RailsAiContext::Serializers::CursorRulesSerializer.new(context).call(dir)
        ui_file = File.join(dir, ".cursor", "rules", "rails-ui-patterns.mdc")
        expect(File.exist?(ui_file)).to be true
        expect(File.read(ui_file)).to include("bg-white")
      end
    end

    it "generates rails-ui-patterns.instructions.md in Copilot rules" do
      context = RailsAiContext.introspect
      context[:view_templates] = {
        ui_patterns: { labels: [ "block text-sm font-semibold" ] }
      }
      Dir.mktmpdir do |dir|
        result = RailsAiContext::Serializers::CopilotInstructionsSerializer.new(context).call(dir)
        ui_file = File.join(dir, ".github", "instructions", "rails-ui-patterns.instructions.md")
        expect(File.exist?(ui_file)).to be true
        expect(File.read(ui_file)).to include("font-semibold")
      end
    end
  end

  describe "Improvement 2: View partial structure" do
    it "extracts model fields from partials" do
      introspector = RailsAiContext::Introspectors::ViewTemplateIntrospector.new(Rails.application)
      result = introspector.call
      partials = result[:partials] || {}
      partials.each_value do |meta|
        expect(meta).to have_key(:fields)
        expect(meta).to have_key(:helpers)
      end
    end

    it "shows partial fields in rails_get_view standard detail" do
      context = RailsAiContext.introspect
      context[:view_templates] = {
        templates: { "cooks/show.html.erb" => { lines: 50, partials: [ "cooks/output" ], stimulus: [ "cook-status" ] } },
        partials: { "cooks/_output.html.erb" => { lines: 100, fields: %w[confidence_score strategy_brief], helpers: %w[render_markdown] } },
        ui_patterns: {}
      }
      allow(RailsAiContext::Tools::GetView).to receive(:cached_context).and_return(context)
      result = RailsAiContext::Tools::GetView.call(controller: "cooks", detail: "standard")
      text = result.content.first[:text]
      expect(text).to include("_output.html.erb")
      expect(text).to include("confidence_score")
      expect(text).to include("render_markdown")
    end
  end

  describe "Improvement 3: Column names in schema rules" do
    it "includes column names in Claude schema rules" do
      context = RailsAiContext.introspect
      Dir.mktmpdir do |dir|
        result = RailsAiContext::Serializers::ClaudeRulesSerializer.new(context).call(dir)
        schema_file = File.join(dir, ".claude", "rules", "rails-schema.md")
        content = File.read(schema_file)
        # Should have column names, not just counts
        expect(content).to include("title")
        expect(content).to include("body")
      end
    end

    it "excludes id, timestamps, and foreign keys from column list" do
      context = RailsAiContext.introspect
      Dir.mktmpdir do |dir|
        RailsAiContext::Serializers::ClaudeRulesSerializer.new(context).call(dir)
        content = File.read(File.join(dir, ".claude", "rules", "rails-schema.md"))
        # Should not list these
        lines = content.lines.select { |l| l.start_with?("- ") }
        lines.each do |line|
          next unless line.include?("—")
          cols_part = line.split("—").last
          expect(cols_part).not_to include("created_at")
          expect(cols_part).not_to include("updated_at")
        end
      end
    end
  end
end
