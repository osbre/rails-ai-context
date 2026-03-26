# frozen_string_literal: true

require "json"

module RailsAiContext
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Install rails-ai-context: creates initializer, MCP config, and generates initial context files."

      AI_TOOLS = {
        "1" => { key: :claude,   name: "Claude Code",     files: "CLAUDE.md + .claude/rules/",                        format: :claude },
        "2" => { key: :cursor,   name: "Cursor",          files: ".cursor/rules/",                                     format: :cursor },
        "3" => { key: :copilot,  name: "GitHub Copilot",  files: ".github/copilot-instructions.md + .github/instructions/", format: :copilot },
        "4" => { key: :opencode, name: "OpenCode",        files: "AGENTS.md",                                          format: :opencode }
      }.freeze

      def select_ai_tools
        say ""
        say "Which AI tools do you use? (select all that apply)", :yellow
        say ""
        AI_TOOLS.each do |num, info|
          say "  #{num}. #{info[:name].ljust(16)} → #{info[:files]}"
        end
        say "  a. All of the above"
        say ""

        input = ask("Enter numbers separated by commas (e.g. 1,2) or 'a' for all:").strip.downcase

        @selected_formats = if input == "a" || input == "all"
          AI_TOOLS.values.map { |t| t[:format] }
        else
          nums = input.split(/[\s,]+/)
          nums.filter_map { |n| AI_TOOLS[n]&.dig(:format) }
        end

        if @selected_formats.empty?
          say "No tools selected — defaulting to all.", :yellow
          @selected_formats = AI_TOOLS.values.map { |t| t[:format] }
        end

        selected_names = AI_TOOLS.values.select { |t| @selected_formats.include?(t[:format]) }.map { |t| t[:name] }
        say ""
        say "Selected: #{selected_names.join(', ')}", :green
      end

      def select_tool_mode
        say ""
        say "Do you also want MCP server support?", :yellow
        say ""
        say "  1. Yes — MCP primary + CLI fallback (generates .mcp.json)"
        say "  2. No  — CLI only (no server needed)"
        say ""

        input = ask("Enter number (default: 1):").strip

        @tool_mode = case input
        when "2" then :cli
        else :mcp
        end

        mode_label = @tool_mode == :mcp ? "MCP + CLI fallback" : "CLI only"
        say "Selected: #{mode_label}", :green
      end

      def create_mcp_config
        # Skip .mcp.json for CLI-only mode
        if @tool_mode == :cli
          say "Skipped .mcp.json (CLI-only mode)", :yellow
          return
        end
        mcp_path = Rails.root.join(".mcp.json")
        server_entry = {
          "command" => "bundle",
          "args" => [ "exec", "rails", "ai:serve" ]
        }

        if File.exist?(mcp_path)
          existing = JSON.parse(File.read(mcp_path)) rescue {}
          existing["mcpServers"] ||= {}

          if existing["mcpServers"]["rails-ai-context"]
            say ".mcp.json already has rails-ai-context — skipped", :yellow
          else
            existing["mcpServers"]["rails-ai-context"] = server_entry
            File.write(mcp_path, JSON.pretty_generate(existing) + "\n")
            say "Added rails-ai-context to existing .mcp.json", :green
          end
        else
          create_file ".mcp.json", JSON.pretty_generate({
            mcpServers: { "rails-ai-context" => server_entry }
          }) + "\n"
          say "Created .mcp.json (auto-discovered by Claude Code, Cursor, etc.)", :green
        end
      end

      def create_initializer
        tools_line = if @selected_formats.size == AI_TOOLS.size
          "  # config.ai_tools = %i[claude cursor copilot opencode]  # default: all"
        else
          "  config.ai_tools = %i[#{@selected_formats.join(' ')}]"
        end

        tool_mode_line = if @tool_mode == :cli
          "  config.tool_mode = :cli    # CLI only (no MCP server needed)"
        else
          "  # config.tool_mode = :mcp  # MCP primary + CLI fallback (default)"
        end

        create_file "config/initializers/rails_ai_context.rb", <<~RUBY
          # frozen_string_literal: true

          RailsAiContext.configure do |config|
            # ── AI Tools ──────────────────────────────────────────────────────
            # Which AI tools to generate context files for (selected during install)
            # Run `rails generate rails_ai_context:install` to change selection
          #{tools_line}

            # Tool invocation mode:
            #   :mcp — MCP primary + CLI fallback (default, requires `rails ai:serve`)
            #   :cli — CLI only (no MCP server needed, uses `rails 'ai:tool[NAME]'`)
          #{tool_mode_line}

            # ── Introspection ─────────────────────────────────────────────────
            # Introspector preset:
            #   :full     — all 28 introspectors (default)
            #   :standard — 13 core introspectors (schema, models, routes, jobs, gems,
            #               conventions, controllers, tests, migrations, stimulus,
            #               view_templates, design_tokens, config)
            # config.preset = :full

            # Context mode: :compact (default, ≤150 lines) or :full (dumps everything)
            # config.context_mode = :compact

            # Max lines for CLAUDE.md in compact mode
            # config.claude_max_lines = 150

            # Whether to generate root files (CLAUDE.md, AGENTS.md, etc.)
            # Set false to only generate split rules (.claude/rules/, .cursor/rules/, etc.)
            # config.generate_root_files = true

            # ── Models & Filtering ────────────────────────────────────────────
            # Models to exclude from introspection
            # config.excluded_models += %w[AdminUser InternalThing]

            # Controllers to exclude from listings
            # config.excluded_controllers += %w[Admin::BaseController]

            # Route prefixes to hide with app_only filter
            # config.excluded_route_prefixes += %w[sidekiq/]

            # ── MCP Server ────────────────────────────────────────────────────
            # Cache TTL in seconds for introspection data
            # config.cache_ttl = 60

            # Max characters for any single tool response (safety net)
            # config.max_tool_response_chars = 200_000

            # Live reload: auto-invalidate MCP tool caches on file changes
            #   :auto — enable if `listen` gem is available (default)
            #   true  — enable, raise if `listen` gem is missing
            #   false — disable entirely
            # config.live_reload = :auto

            # Auto-mount HTTP MCP endpoint (for HTTP transport)
            # config.auto_mount = false
            # config.http_path = "/mcp"
            # config.http_port = 6029

            # ── File Size Limits ──────────────────────────────────────────────
            # Increase for larger projects
            # config.max_file_size = 5_000_000         # Per-file read (5MB)
            # config.max_test_file_size = 1_000_000    # Test file read (1MB)
            # config.max_schema_file_size = 10_000_000 # schema.rb parse (10MB)
            # config.max_view_total_size = 10_000_000  # Aggregated view content (10MB)
            # config.max_view_file_size = 1_000_000    # Per-view file (1MB)
            # config.max_search_results = 200          # Max search results per call
            # config.max_validate_files = 50           # Max files per validate call

            # ── Extensibility ─────────────────────────────────────────────────
            # Register additional MCP tool classes alongside the 25 built-in tools
            # config.custom_tools = [MyApp::CustomTool]

            # Exclude specific built-in tools by name
            # config.skip_tools = %w[rails_security_scan]

            # ── Security ──────────────────────────────────────────────────────
            # Paths excluded from code search
            # config.excluded_paths += %w[vendor/cache]

            # File patterns blocked from search and read tools
            # config.sensitive_patterns += %w[config/secrets.yml]

            # ── Search ────────────────────────────────────────────────────────
            # File extensions for fallback search (when ripgrep unavailable)
            # config.search_extensions = %w[rb js erb yml yaml json ts tsx vue svelte haml slim]

            # Where to look for concern source files
            # config.concern_paths = %w[app/models/concerns app/controllers/concerns]
          end
        RUBY

        say "Created config/initializers/rails_ai_context.rb", :green
      end

      def add_to_gitignore
        gitignore = Rails.root.join(".gitignore")
        return unless File.exist?(gitignore)

        content = File.read(gitignore)
        append = []
        append << ".ai-context.json" unless content.include?(".ai-context.json")

        if append.any?
          File.open(gitignore, "a") do |f|
            f.puts ""
            f.puts "# rails-ai-context (JSON cache — markdown files should be committed)"
            append.each { |line| f.puts line }
          end
          say "Updated .gitignore", :green
        end
      end

      def generate_context_files
        say ""
        say "Generating AI context files...", :yellow

        unless Rails.application
          say "  Skipped (Rails app not fully loaded). Run `rails ai:context` after install.", :yellow
          return
        end

        require "rails_ai_context"

        @selected_formats.each do |fmt|
          begin
            result = RailsAiContext.generate_context(format: fmt)
            (result[:written] || []).each { |f| say "  ✅ #{f}", :green }
            (result[:skipped] || []).each { |f| say "  ⏭️  #{f} (unchanged)", :yellow }
          rescue => e
            say "  ❌ #{fmt}: #{e.message}", :red
          end
        end
      end

      def show_instructions
        say ""
        say "=" * 50, :cyan
        say " rails-ai-context installed!", :cyan
        say "=" * 50, :cyan
        say ""
        say "Your setup:", :yellow
        AI_TOOLS.each_value do |info|
          next unless @selected_formats.include?(info[:format])
          say "  ✅ #{info[:name].ljust(16)} → #{info[:files]}"
        end
        say ""
        say "Commands:", :yellow
        say "  rails ai:context         # Regenerate context files"
        say "  rails 'ai:tool[schema]'    # Run any of the 25 tools from CLI"
        if @tool_mode == :mcp
          say "  rails ai:serve           # Start MCP server (25 live tools)"
        end
        say "  rails ai:doctor          # Check AI readiness"
        say "  rails ai:inspect         # Print introspection summary"
        say ""
        if @tool_mode == :mcp
          say "MCP auto-discovery:", :yellow
          say "  .mcp.json is auto-detected by Claude Code and Cursor."
          say "  No manual config needed — just open your project."
        else
          say "CLI tools:", :yellow
          say "  AI agents can run `rails 'ai:tool[schema]' table=users` directly."
          say "  No MCP server needed — tools work from the terminal."
        end
        say ""
        say "To add more AI tools later:", :yellow
        say "  rails ai:context:cursor   # Generate for Cursor"
        say "  rails ai:context:copilot  # Generate for Copilot"
        say "  rails generate rails_ai_context:install  # Re-run to pick tools"
        say ""
        say "Commit context files and .mcp.json so your team benefits!", :green
      end
    end
  end
end
