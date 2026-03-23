# frozen_string_literal: true

module RailsAiContext
  module Tools
    class GetGems < BaseTool
      tool_name "rails_get_gems"
      description "Get notable gems from Gemfile.lock grouped by category: auth, jobs, frontend, API, database, testing, deploy. " \
        "Use when: checking what libraries are available before adding a dependency, or understanding the tech stack. " \
        "Filter with category:\"auth\" or category:\"database\". Omit for all categories."

      input_schema(
        properties: {
          category: {
            type: "string",
            enum: %w[auth jobs frontend api database files testing deploy all],
            description: "Filter by category. Default: all."
          }
        }
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(category: "all", server_context: nil)
        gems = cached_context[:gems]
        return text_response("Gem introspection not available. Add :gems to introspectors.") unless gems
        return text_response("Gem introspection failed: #{gems[:error]}") if gems[:error]

        notable = gems[:notable_gems] || []
        notable = notable.select { |g| g[:category] == category } unless category == "all"

        lines = [ "# Notable Gems" ]

        if notable.any?
          current_cat = nil
          notable.sort_by { |g| [ g[:category], g[:name] ] }.each do |g|
            if g[:category] != current_cat
              current_cat = g[:category]
              lines << "" << "## #{current_cat.capitalize}"
            end
            lines << "- **#{g[:name]}**: #{g[:note]}"
          end
        else
          all_cats = (gems[:notable_gems] || []).map { |g| g[:category] }.uniq.sort
          hint = all_cats.any? ? " Available categories: #{all_cats.join(', ')}" : ""
          lines << "_No notable gems found#{" in category '#{category}'" unless category == 'all'}.#{hint}_"
        end

        text_response(lines.join("\n"))
      end
    end
  end
end
