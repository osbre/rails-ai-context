# frozen_string_literal: true

module RailsAiContext
  module Tools
    class AnalyzeFeature < BaseTool
      tool_name "rails_analyze_feature"
      description "Analyze a feature end-to-end: finds matching models, controllers, routes, and views in one call. " \
        "Use when: exploring an unfamiliar feature, onboarding to a codebase area, or tracing a feature across layers. " \
        "Pass feature:\"authentication\" or feature:\"User\" for broad cross-cutting discovery."

      input_schema(
        properties: {
          feature: {
            type: "string",
            description: "Feature keyword to search for (e.g. 'authentication', 'User', 'payments', 'orders'). Case-insensitive partial match across models, controllers, and routes."
          }
        },
        required: [ "feature" ]
      )

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(feature:, server_context: nil)
        ctx = cached_context
        pattern = feature.downcase
        lines = [ "# Feature Analysis: #{feature}", "" ]

        # --- Models ---
        models = ctx[:models] || {}
        matched_models = models.select { |name, data| !data[:error] && name.downcase.include?(pattern) }

        if matched_models.any?
          lines << "## Models (#{matched_models.size} matched)"
          matched_models.sort.each do |name, data|
            lines << ""
            lines << "### #{name}"
            lines << "**Table:** `#{data[:table_name]}`" if data[:table_name]

            # Schema columns from schema introspection
            table_name = data[:table_name]
            if table_name && (schema = ctx[:schema]) && (tables = schema[:tables])
              table_data = tables[table_name]
              if table_data && table_data[:columns]&.any?
                cols = table_data[:columns].reject { |c| %w[id created_at updated_at].include?(c[:name]) }
                lines << "**Columns:** #{cols.map { |c| "#{c[:name]}:#{c[:type]}" }.join(', ')}" if cols.any?
                if table_data[:indexes]&.any?
                  lines << "**Indexes:** #{table_data[:indexes].map { |i| "#{i[:columns].join(',')}#{i[:unique] ? ' (unique)' : ''}" }.join('; ')}"
                end
                if table_data[:foreign_keys]&.any?
                  lines << "**FKs:** #{table_data[:foreign_keys].map { |fk| "#{fk[:column]} -> #{fk[:to_table]}" }.join(', ')}"
                end
              end
            end

            if data[:associations]&.any?
              lines << "**Associations:** #{data[:associations].map { |a| "#{a[:type]} :#{a[:name]}" }.join(', ')}"
            end
            if data[:validations]&.any?
              lines << "**Validations:** #{data[:validations].map { |v| "#{v[:kind]} on #{v[:attributes].join(', ')}" }.uniq.join('; ')}"
            end
            if data[:scopes]&.any?
              lines << "**Scopes:** #{data[:scopes].join(', ')}"
            end
          end
        else
          lines << "## Models" << "_No models matching '#{feature}'._"
        end

        # --- Controllers ---
        controllers = (ctx.dig(:controllers, :controllers) || {})
        matched_controllers = controllers.select { |name, data| !data[:error] && name.downcase.include?(pattern) }

        lines << ""
        if matched_controllers.any?
          lines << "## Controllers (#{matched_controllers.size} matched)"
          matched_controllers.sort.each do |name, info|
            actions = info[:actions]&.join(", ") || "none"
            filters = (info[:filters] || []).map { |f| "#{f[:kind]} #{f[:name]}" }.join(", ")
            lines << "" << "### #{name}"
            lines << "- **Actions:** #{actions}"
            lines << "- **Filters:** #{filters}" unless filters.empty?
          end
        else
          lines << "## Controllers" << "_No controllers matching '#{feature}'._"
        end

        # --- Routes ---
        by_controller = (ctx.dig(:routes, :by_controller) || {})
        matched_routes = by_controller.select { |ctrl, _| ctrl.downcase.include?(pattern) }

        lines << ""
        if matched_routes.any?
          route_count = matched_routes.values.sum(&:size)
          lines << "## Routes (#{route_count} matched)"
          matched_routes.sort.each do |ctrl, actions|
            actions.each do |r|
              name_part = r[:name] ? " `#{r[:name]}`" : ""
              lines << "- `#{r[:verb]}` `#{r[:path]}` -> #{ctrl}##{r[:action]}#{name_part}"
            end
          end
        else
          lines << "## Routes" << "_No routes matching '#{feature}'._"
        end

        text_response(lines.join("\n"))
      end
    end
  end
end
