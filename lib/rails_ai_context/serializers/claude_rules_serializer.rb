# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .claude/rules/ files for Claude Code auto-discovery.
    # These provide quick-reference lists without bloating CLAUDE.md.
    class ClaudeRulesSerializer
      attr_reader :context

      def initialize(context)
        @context = context
      end

      # @param output_dir [String] Rails root path
      # @return [Hash] { written: [paths], skipped: [paths] }
      def call(output_dir)
        rules_dir = File.join(output_dir, ".claude", "rules")
        FileUtils.mkdir_p(rules_dir)

        written = []
        skipped = []

        files = {
          "rails-context.md" => render_context_overview,
          "rails-schema.md" => render_schema_reference,
          "rails-models.md" => render_models_reference,
          "rails-mcp-tools.md" => render_mcp_tools_reference
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

      def render_context_overview
        lines = [
          "# #{context[:app_name] || 'Rails App'} — Overview",
          "",
          "Rails #{context[:rails_version]} | Ruby #{context[:ruby_version]}",
          ""
        ]

        schema = context[:schema]
        if schema.is_a?(Hash) && !schema[:error]
          lines << "- Database: #{schema[:adapter]} — #{schema[:total_tables]} tables"
        end

        models = context[:models]
        lines << "- Models: #{models.size}" if models.is_a?(Hash) && !models[:error]

        routes = context[:routes]
        lines << "- Routes: #{routes[:total_routes]}" if routes.is_a?(Hash) && !routes[:error]

        gems = context[:gems]
        if gems.is_a?(Hash) && !gems[:error]
          notable = gems[:notable_gems] || []
          notable.group_by { |g| g[:category]&.to_s || "other" }.first(6).each do |cat, gem_list|
            lines << "- #{cat}: #{gem_list.map { |g| g[:name] }.join(', ')}"
          end
        end

        conv = context[:conventions]
        if conv.is_a?(Hash) && !conv[:error]
          (conv[:architecture] || []).first(5).each { |p| lines << "- #{p}" }
        end

        lines << ""
        lines << "Use MCP tools for detailed data. Start with `detail:\"summary\"`."

        lines.join("\n")
      end

      def render_schema_reference
        schema = context[:schema]
        return nil unless schema.is_a?(Hash) && !schema[:error]
        tables = schema[:tables] || {}
        return nil if tables.empty?

        lines = [
          "# Database Tables (#{tables.size})",
          "",
          "DO NOT read db/schema.rb directly. Use the `rails_get_schema` MCP tool instead.",
          "Call with `detail:\"summary\"` first, then `table:\"name\"` for specifics.",
          ""
        ]

        tables.keys.sort.each do |name|
          data = tables[name]
          col_count = data[:columns]&.size || 0
          pk = data[:primary_key] || "id"
          lines << "- #{name} (#{col_count} cols, pk: #{pk})"
        end

        lines.join("\n")
      end

      def render_models_reference
        models = context[:models]
        return nil unless models.is_a?(Hash) && !models[:error]
        return nil if models.empty?

        lines = [
          "# ActiveRecord Models (#{models.size})",
          "",
          "DO NOT read model files to check associations/validations. Use `rails_get_model_details` MCP tool instead.",
          "Call with `detail:\"summary\"` first, then `model:\"Name\"` for specifics.",
          ""
        ]

        models.keys.sort.each do |name|
          data = models[name]
          assocs = (data[:associations] || []).size
          vals = (data[:validations] || []).size
          table = data[:table_name]
          line = "- #{name}"
          line += " (table: #{table})" if table
          line += " — #{assocs} assocs, #{vals} validations"
          lines << line
        end

        lines.join("\n")
      end

      def render_mcp_tools_reference # rubocop:disable Metrics/MethodLength,Metrics/AbcSize
        lines = [
          "# Rails MCP Tools — ALWAYS Use These First",
          "",
          "IMPORTANT: This project has live MCP tools that return parsed, up-to-date data.",
          "ALWAYS use these tools BEFORE reading files like db/schema.rb, config/routes.rb, or model source files.",
          "The tools return structured, token-efficient summaries. Reading raw files wastes tokens and may be stale.",
          "",
          "## Required Workflow",
          "1. ALWAYS start with `detail:\"summary\"` to get the full landscape",
          "2. Then drill into specifics with filters (`table:`, `model:`, `controller:`)",
          "3. NEVER use `detail:\"full\"` unless you specifically need indexes, FKs, or constraints",
          "4. DO NOT read db/schema.rb — use `rails_get_schema` instead",
          "5. DO NOT read model files to understand associations — use `rails_get_model_details` instead",
          "6. DO NOT read config/routes.rb — use `rails_get_routes` instead",
          "",
          "## Tools",
          "",
          "**rails_get_schema** — database tables, columns, indexes, foreign keys",
          "- `rails_get_schema(detail:\"summary\")` — all tables with column counts",
          "- `rails_get_schema(table:\"users\")` — full detail for one table",
          "",
          "**rails_get_model_details** — associations, validations, scopes, enums, callbacks",
          "- `rails_get_model_details(detail:\"summary\")` — list all model names",
          "- `rails_get_model_details(model:\"User\")` — full detail for one model",
          "",
          "**rails_get_routes** — HTTP verbs, paths, controller actions",
          "- `rails_get_routes(detail:\"summary\")` — route counts per controller",
          "- `rails_get_routes(controller:\"users\")` — routes for one controller",
          "",
          "**rails_get_controllers** — actions, filters, strong params, concerns",
          "- `rails_get_controllers(detail:\"summary\")` — names + action counts",
          "- `rails_get_controllers(controller:\"UsersController\")` — full detail",
          "",
          "**rails_get_config** — cache store, session, timezone, middleware, initializers",
          "**rails_get_test_info** — test framework, factories/fixtures, CI config",
          "**rails_get_gems** — notable gems categorized by function",
          "**rails_get_conventions** — architecture patterns, directory structure",
          "**rails_search_code** — regex search: `rails_search_code(pattern:\"regex\", file_type:\"rb\")`"
        ]

        lines.join("\n")
      end
    end
  end
end
