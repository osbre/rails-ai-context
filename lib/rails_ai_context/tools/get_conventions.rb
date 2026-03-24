# frozen_string_literal: true

module RailsAiContext
  module Tools
    class GetConventions < BaseTool
      tool_name "rails_get_conventions"
      description "Detect app architecture and conventions: API-only vs Hotwire, design patterns, directory layout. " \
        "Use when: starting work on an unfamiliar codebase, choosing implementation patterns, or checking what frameworks are in use. " \
        "No parameters needed. Returns architecture style, detected patterns (STI, service objects), and notable config files."

      input_schema(properties: {})

      annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)

      def self.call(server_context: nil)
        conventions = cached_context[:conventions]
        return text_response("Convention detection not available. Add :conventions to introspectors.") unless conventions
        return text_response("Convention detection failed: #{conventions[:error]}") if conventions[:error]

        lines = [ "# App Conventions & Architecture", "" ]

        # Architecture
        if conventions[:architecture]&.any?
          lines << "## Architecture"
          conventions[:architecture].each { |a| lines << "- #{humanize_arch(a)}" }
        end

        # Patterns
        if conventions[:patterns]&.any?
          lines << "" << "## Detected patterns"
          conventions[:patterns].each { |p| lines << "- #{humanize_pattern(p)}" }
        end

        # Directory structure
        if conventions[:directory_structure]&.any?
          lines << "" << "## Directory structure"
          conventions[:directory_structure].sort_by { |k, _| k }.each do |dir, count|
            lines << "- `#{dir}/` → #{count} files"
          end
        end

        # Frontend stack from package.json
        frontend = detect_frontend_stack
        if frontend.any?
          lines << "" << "## Frontend stack"
          frontend.each { |f| lines << "- #{f}" }
        end

        # Config files — only show non-obvious ones (skip files every Rails app has)
        if conventions[:config_files]&.any?
          obvious = %w[
            config/application.rb config/puma.rb config/locales/en.yml
            Gemfile package.json Rakefile
          ]
          notable = conventions[:config_files].reject { |f| obvious.include?(f) }
          if notable.any?
            lines << "" << "## Notable config files"
            notable.each { |f| lines << "- `#{f}`" }
          end
        end

        text_response(lines.join("\n"))
      end

      ARCH_LABELS = {
        "api_only" => "API-only mode (no views/assets)",
        "hotwire" => "Hotwire (Turbo + Stimulus)",
        "graphql" => "GraphQL API (app/graphql/)",
        "grape_api" => "Grape API framework (app/api/)",
        "service_objects" => "Service objects pattern (app/services/)",
        "form_objects" => "Form objects (app/forms/)",
        "query_objects" => "Query objects (app/queries/)",
        "presenters" => "Presenters/Decorators",
        "view_components" => "ViewComponent (app/components/)",
        "stimulus" => "Stimulus controllers (app/javascript/controllers/)",
        "importmaps" => "Import maps (no JS bundler)",
        "docker" => "Dockerized",
        "kamal" => "Kamal deployment",
        "ci_github_actions" => "GitHub Actions CI"
      }.freeze

      PATTERN_LABELS = {
        "sti" => "Single Table Inheritance (STI)",
        "polymorphic" => "Polymorphic associations",
        "soft_delete" => "Soft deletes (paranoia/discard)",
        "versioning" => "Model versioning/auditing",
        "state_machine" => "State machines (AASM/workflow)",
        "multi_tenancy" => "Multi-tenancy",
        "searchable" => "Full-text search (Searchkick/pg_search/Ransack)",
        "taggable" => "Tagging",
        "sluggable" => "Friendly URLs/slugs",
        "nested_set" => "Tree/nested set structures"
      }.freeze

      private_class_method def self.humanize_arch(key)
        ARCH_LABELS[key] || key.humanize
      end

      private_class_method def self.humanize_pattern(key)
        PATTERN_LABELS[key] || key.humanize
      end

      private_class_method def self.detect_frontend_stack
        pkg_path = Rails.root.join("package.json")
        return [] unless File.exist?(pkg_path)

        content = File.read(pkg_path) rescue ""
        stack = []

        # CSS frameworks
        stack << "Tailwind CSS" if content.include?("tailwindcss")
        stack << "Bootstrap" if content.include?("bootstrap")
        stack << "DaisyUI" if content.include?("daisyui")

        # JS bundlers
        stack << "esbuild" if content.include?("esbuild")
        stack << "Vite" if content.include?("vite")
        stack << "Webpack" if content.include?("webpack")

        # JS frameworks
        stack << "React" if content.include?("\"react\"")
        stack << "Vue" if content.include?("\"vue\"")
        stack << "Svelte" if content.include?("svelte")

        # Utilities
        stack << "TypeScript" if content.include?("typescript")
        stack << "Turbo" if content.include?("@hotwired/turbo")
        stack << "Stimulus" if content.include?("@hotwired/stimulus")

        stack
      end
    end
  end
end
