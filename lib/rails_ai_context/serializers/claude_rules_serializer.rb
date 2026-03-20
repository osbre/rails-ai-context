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
          "rails-ui-patterns.md" => render_ui_patterns_reference,
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

        skip_cols = %w[id created_at updated_at]
        # Always show these even if they end in _id/_type (important for AI)
        keep_cols = %w[type deleted_at discarded_at]

        tables.keys.sort.first(30).each do |name|
          data = tables[name]
          columns = data[:columns] || []
          col_count = columns.size
          pk = data[:primary_key]
          pk_display = pk.is_a?(Array) ? pk.join(", ") : (pk || "id").to_s

          key_cols = columns.map { |c| c[:name] }.select do |c|
            next true if keep_cols.include?(c)
            next true if c.end_with?("_type") # polymorphic associations
            next false if skip_cols.include?(c)
            next false if c.end_with?("_id")
            true
          end

          col_sample = key_cols.first(12)
          shown = col_sample.join(", ")
          shown += ", ..." if key_cols.size > 12
          col_names = col_sample.any? ? " — #{shown}" : ""
          lines << "- #{name} (#{col_count} cols, pk: #{pk_display})#{col_names}"
        end

        if tables.size > 30
          lines << "- ...#{tables.size - 30} more tables (use `rails_get_schema` MCP tool)"
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

      def render_ui_patterns_reference
        vt = context[:view_templates]
        return nil unless vt.is_a?(Hash) && !vt[:error]
        patterns = vt[:ui_patterns] || {}
        return nil if patterns.empty?

        lines = [
          "# UI Patterns",
          "",
          "Common CSS class patterns found in this app's views.",
          "Use these when creating new views to match the existing design.",
          ""
        ]

        patterns.each do |type, classes_list|
          classes_list.each do |classes|
            lines << "- #{type.to_s.chomp('s').capitalize}: `#{classes}`"
          end
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
          "7. DO NOT read view ERB files to understand UI — use `rails_get_view` instead",
          "8. DO NOT read JS files to understand Stimulus — use `rails_get_stimulus` instead",
          "9. DO NOT read entire controllers — use `rails_get_controllers(controller:\"Name\", action:\"index\")` for one action",
          "10. DO NOT read test files for patterns — use `rails_get_test_info(detail:\"full\")` instead",
          "",
          "## Tools (11)",
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
          "**rails_get_controllers** — actions, filters, strong params, action source code",
          "- `rails_get_controllers(detail:\"summary\")` — names + action counts",
          "- `rails_get_controllers(controller:\"CooksController\", action:\"index\")` — action source code + filters",
          "",
          "**rails_get_view** — view templates, partials, Stimulus references",
          "- `rails_get_view(controller:\"cooks\")` — list all views for a controller",
          "- `rails_get_view(path:\"cooks/index.html.erb\")` — full template content",
          "",
          "**rails_get_stimulus** — Stimulus controllers with targets, values, actions",
          "- `rails_get_stimulus(detail:\"summary\")` — all controllers with counts",
          "- `rails_get_stimulus(controller:\"filter-form\")` — full detail for one controller",
          "",
          "**rails_get_test_info** — test framework, fixtures, factories, helpers",
          "- `rails_get_test_info(detail:\"full\")` — fixture names, factory names, helper setup",
          "- `rails_get_test_info(model:\"Cook\")` — existing tests for a model",
          "- `rails_get_test_info(controller:\"Cooks\")` — existing controller tests",
          "",
          "**rails_get_config** — cache store, session, timezone, middleware, initializers",
          "**rails_get_gems** — notable gems categorized by function",
          "**rails_get_conventions** — architecture patterns, directory structure",
          "**rails_search_code** — regex search: `rails_search_code(pattern:\"regex\", file_type:\"rb\")`"
        ]

        lines.join("\n")
      end
    end
  end
end
