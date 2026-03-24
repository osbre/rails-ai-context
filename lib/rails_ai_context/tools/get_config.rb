# frozen_string_literal: true

module RailsAiContext
  module Tools
    class GetConfig < BaseTool
      tool_name "rails_get_config"
      description "Get Rails app configuration: cache store, session store, timezone, queue adapter, custom middleware, initializers. " \
        "Use when: configuring caching, checking session/queue setup, or seeing what initializers exist. " \
        "No parameters needed. Returns only non-default middleware and notable initializers."

      input_schema(properties: {})

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(server_context: nil)
        data = cached_context[:config]
        return text_response("Config introspection not available. Add :config to introspectors or use `config.preset = :full`.") unless data
        return text_response("Config introspection failed: #{data[:error]}") if data[:error]

        lines = [ "# Application Configuration", "" ]

        # Database — critical for query syntax decisions
        db_config = detect_database
        lines << "- **Database:** #{db_config}" if db_config

        # Auth framework — affects every controller
        auth = detect_auth_framework
        lines << "- **Auth:** #{auth}" if auth

        # Assets/CSS — affects view development
        assets = detect_assets_stack
        lines << "- **Assets:** #{assets}" if assets

        lines << "- **Cache store:** #{data[:cache_store]}" if data[:cache_store]
        lines << "- **Session store:** #{data[:session_store]}" if data[:session_store]
        lines << "- **Timezone:** #{data[:timezone]}" if data[:timezone]
        lines << "- **Queue adapter:** #{data[:queue_adapter]}" if data[:queue_adapter]
        if data[:mailer].is_a?(Hash) && data[:mailer].any?
          lines << "- **Mailer:** #{data[:mailer].map { |k, v| "#{k}: #{v}" }.join(', ')}"
        end

        if data[:middleware_stack]&.any?
          # Filter default Rails middleware AND dev-only middleware
          dev_middleware = %w[
            Propshaft::Server WebConsole::Middleware ActionDispatch::Reloader
            Bullet::Rack ActiveSupport::Cache::Strategy::LocalCache
          ]
          excluded_mw = RailsAiContext.configuration.excluded_middleware
          custom = data[:middleware_stack].reject { |m| excluded_mw.include?(m) || dev_middleware.include?(m) }
          if custom.any?
            lines << "" << "## Custom Middleware"
            custom.each { |m| lines << "- #{m}" }
          end
        end

        if data[:initializers]&.any?
          # Filter out standard Rails initializers that every app has
          standard_inits = %w[
            content_security_policy.rb filter_parameter_logging.rb
            inflections.rb permissions_policy.rb assets.rb
            new_framework_defaults.rb cors.rb wrap_parameters.rb
          ]
          notable = data[:initializers].reject { |i| standard_inits.include?(i) }
          if notable.any?
            lines << "" << "## Initializers"
            notable.each { |i| lines << "- `#{i}`" }
          end
        end

        if data[:current_attributes]&.any?
          lines << "" << "## CurrentAttributes"
          data[:current_attributes].each { |c| lines << "- `#{c}`" }
        end

        text_response(lines.join("\n"))
      end

      private_class_method def self.detect_database
        adapter = Rails.configuration.database_configuration&.dig(Rails.env, "adapter") rescue nil
        return nil unless adapter
        adapter
      end

      private_class_method def self.detect_auth_framework
        gems = cached_context[:gems]
        return nil unless gems.is_a?(Hash)

        all_gems = (gems[:notable] || []) + (gems[:all] || [])
        gem_names = all_gems.map { |g| g.is_a?(Hash) ? g[:name] : g.to_s }

        if gem_names.include?("devise")
          "Devise"
        elsif gem_names.include?("rodauth-rails")
          "Rodauth"
        elsif gem_names.include?("sorcery")
          "Sorcery"
        elsif gem_names.include?("clearance")
          "Clearance"
        elsif File.exist?(Rails.root.join("app/models/concerns/authentication.rb")) ||
              File.exist?(Rails.root.join("app/controllers/concerns/authentication.rb"))
          "Rails 8 authentication (built-in)"
        end
      end

      private_class_method def self.detect_assets_stack
        parts = []

        pkg = Rails.root.join("package.json")
        if File.exist?(pkg)
          content = File.read(pkg) rescue ""
          parts << "Tailwind" if content.include?("tailwindcss")
          parts << "Bootstrap" if content.include?("bootstrap")
          parts << "esbuild" if content.include?("esbuild")
          parts << "Vite" if content.include?("vite")
          parts << "Webpack" if content.include?("webpack")
          parts << "React" if content.include?("react")
          parts << "Vue" if content.include?("vue")
        end

        parts << "Propshaft" if defined?(Propshaft)
        parts << "Sprockets" if defined?(Sprockets) && !defined?(Propshaft)
        parts << "Import Maps" if File.exist?(Rails.root.join("config/importmap.rb"))

        parts.any? ? parts.join(", ") : nil
      end
    end
  end
end
