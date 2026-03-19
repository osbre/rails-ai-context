# frozen_string_literal: true

module RailsAiContext
  module Serializers
    # Generates .windsurf/rules/*.md files in the new Windsurf rules format.
    # Each file is hard-capped at 5,800 characters (within Windsurf's 6K limit).
    class WindsurfRulesSerializer
      MAX_CHARS_PER_FILE = 5_800

      attr_reader :context

      def initialize(context)
        @context = context
      end

      def call(output_dir)
        rules_dir = File.join(output_dir, ".windsurf", "rules")
        FileUtils.mkdir_p(rules_dir)

        written = []
        skipped = []

        files = {
          "rails-context.md" => render_context_rule,
          "rails-mcp-tools.md" => render_mcp_tools_rule
        }

        files.each do |filename, content|
          next unless content
          # Enforce Windsurf's 6K limit
          content = content[0...MAX_CHARS_PER_FILE] if content.length > MAX_CHARS_PER_FILE

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

      def render_context_rule
        # Reuse WindsurfSerializer content
        WindsurfSerializer.new(context).call
      end

      def render_mcp_tools_rule # rubocop:disable Metrics/MethodLength
        lines = [
          "# Rails MCP Tools — Use These First",
          "",
          "ALWAYS use these tools BEFORE reading db/schema.rb, config/routes.rb, or model files.",
          "Start with detail:\"summary\", then drill into specifics.",
          "",
          "- rails_get_schema(detail:\"summary\") → rails_get_schema(table:\"name\")",
          "- rails_get_model_details(detail:\"summary\") → rails_get_model_details(model:\"Name\")",
          "- rails_get_routes(detail:\"summary\") → rails_get_routes(controller:\"name\")",
          "- rails_get_controllers(detail:\"summary\") → rails_get_controllers(controller:\"Name\")",
          "- rails_get_config | rails_get_test_info | rails_get_gems | rails_get_conventions",
          "- rails_search_code(pattern:\"regex\", file_type:\"rb\")"
        ]

        lines.join("\n")
      end
    end
  end
end
