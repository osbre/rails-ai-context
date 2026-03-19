# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .cursor/rules/*.mdc files in the new Cursor MDC format.
    # Each file is focused, <50 lines, with YAML frontmatter.
    # .cursorrules is deprecated by Cursor; this is the recommended format.
    class CursorRulesSerializer
      attr_reader :context

      def initialize(context)
        @context = context
      end

      # @param output_dir [String] Rails root path
      # @return [Hash] { written: [paths], skipped: [paths] }
      def call(output_dir)
        rules_dir = File.join(output_dir, ".cursor", "rules")
        FileUtils.mkdir_p(rules_dir)

        written = []
        skipped = []

        files = {
          "rails-project.mdc" => render_project_rule,
          "rails-models.mdc" => render_models_rule,
          "rails-controllers.mdc" => render_controllers_rule,
          "rails-mcp-tools.mdc" => render_mcp_tools_rule
        }

        files.each do |filename, content|
          next unless content
          filepath = File.join(rules_dir, filename)
          if File.exist?(filepath) && File.read(filepath) == content
            skipped << filepath
          else
            File.write(filepath, content)
            written << filepath
          end
        end

        { written: written, skipped: skipped }
      end

      private

      # Always-on project overview rule (<50 lines)
      def render_project_rule
        lines = [
          "---",
          "description: \"Rails project context for #{context[:app_name]}\"",
          "alwaysApply: true",
          "---",
          "",
          "# #{context[:app_name]}",
          "",
          "Rails #{context[:rails_version]} | Ruby #{context[:ruby_version]}",
          ""
        ]

        schema = context[:schema]
        if schema && !schema[:error]
          lines << "- Database: #{schema[:adapter]} — #{schema[:total_tables]} tables"
        end

        models = context[:models]
        lines << "- Models: #{models.size}" if models.is_a?(Hash) && !models[:error]

        routes = context[:routes]
        if routes && !routes[:error]
          lines << "- Routes: #{routes[:total_routes]}"
        end

        gems = context[:gems]
        if gems.is_a?(Hash) && !gems[:error]
          notable = gems[:notable_gems] || gems[:notable] || gems[:detected] || []
          grouped = notable.group_by { |g| g[:category]&.to_s || "other" }
          grouped.each do |cat, gem_list|
            lines << "- #{cat}: #{gem_list.map { |g| g[:name] }.join(', ')}"
          end
        end

        conv = context[:conventions]
        if conv.is_a?(Hash) && !conv[:error]
          (conv[:architecture] || []).first(5).each { |p| lines << "- #{p}" }
        end

        lines << ""
        lines << "MCP tools available — see rails-mcp-tools.mdc for full reference."
        lines << "Always call with detail:\"summary\" first, then drill into specifics."

        lines.join("\n")
      end

      # Auto-attached when working in app/models/
      def render_models_rule
        models = context[:models]
        return nil unless models.is_a?(Hash) && !models[:error] && models.any?

        lines = [
          "---",
          "description: \"ActiveRecord models reference\"",
          "globs:",
          "  - \"app/models/**/*.rb\"",
          "alwaysApply: false",
          "---",
          "",
          "# Models (#{models.size})",
          ""
        ]

        models.keys.sort.first(30).each do |name|
          data = models[name]
          assocs = (data[:associations] || []).size
          lines << "- #{name} (#{assocs} associations, table: #{data[:table_name] || '?'})"
        end

        lines << "- ...#{models.size - 30} more" if models.size > 30
        lines << ""
        lines << "Use `rails_get_model_details` MCP tool with model:\"Name\" for full detail."

        lines.join("\n")
      end

      # Auto-attached when working in app/controllers/
      def render_controllers_rule
        data = context[:controllers]
        return nil unless data.is_a?(Hash) && !data[:error]
        controllers = data[:controllers] || {}
        return nil if controllers.empty?

        lines = [
          "---",
          "description: \"Controller reference\"",
          "globs:",
          "  - \"app/controllers/**/*.rb\"",
          "alwaysApply: false",
          "---",
          "",
          "# Controllers (#{controllers.size})",
          ""
        ]

        controllers.keys.sort.first(25).each do |name|
          info = controllers[name]
          action_count = info[:actions]&.size || 0
          lines << "- #{name} (#{action_count} actions)"
        end

        lines << "- ...#{controllers.size - 25} more" if controllers.size > 25
        lines << ""
        lines << "Use `rails_get_controllers` MCP tool with controller:\"Name\" for full detail."

        lines.join("\n")
      end

      # Always-on MCP tool reference — strongest enforcement point for Cursor
      def render_mcp_tools_rule # rubocop:disable Metrics/MethodLength
        lines = [
          "---",
          "description: \"Rails MCP tools — ALWAYS use these before reading Rails files directly\"",
          "alwaysApply: true",
          "---",
          "",
          "# Rails MCP Tools — Use These First",
          "",
          "ALWAYS use these MCP tools BEFORE reading db/schema.rb, config/routes.rb, or model files.",
          "They return parsed, up-to-date data and save tokens. Start with detail:\"summary\".",
          "",
          "- `rails_get_schema(detail:\"summary\")` → then `rails_get_schema(table:\"name\")`",
          "- `rails_get_model_details(detail:\"summary\")` → then `rails_get_model_details(model:\"Name\")`",
          "- `rails_get_routes(detail:\"summary\")` → then `rails_get_routes(controller:\"name\")`",
          "- `rails_get_controllers(detail:\"summary\")` → then `rails_get_controllers(controller:\"Name\")`",
          "- `rails_get_config` — cache, session, middleware",
          "- `rails_get_test_info` — framework, factories, CI",
          "- `rails_get_gems` — categorized gems",
          "- `rails_get_conventions` — architecture patterns",
          "- `rails_search_code(pattern:\"regex\", file_type:\"rb\")` — codebase search"
        ]

        lines.join("\n")
      end
    end
  end
end
