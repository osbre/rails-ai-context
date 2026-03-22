# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.15.3] - 2026-03-22

### Fixed

- **Schema `add_index` column parsing** — option keys (e.g. `unique`, `name`) were being picked up as column names (PR #12).
- **Windsurf test command** — extracted `TestCommandDetection` shared module; Windsurf now shows specific test command instead of generic "Run tests after changes".

### Changed

- **Documentation** — updated all docs (README, CLAUDE.md, GUIDE.md, SECURITY.md, CHANGELOG, server.json, install generator) to match v0.15.x codebase. Fixed spec counts, file counts, preset counts, config options, and supported versions.

## [0.15.2] - 2026-03-22

### Fixed

- **Test command detection** — Serializers now use detected test framework (minitest → `rails test`, rspec → `bundle exec rspec`) instead of hardcoding `bundle exec rspec`. Default is `rails test` (the Rails default). Contributed by @curi (PR #13).

## [0.15.1] - 2026-03-22

### Fixed

- **Copilot serializer** — Show all model associations (not capped at 3), use human-readable architecture/pattern labels.
- **OpenCode rules serializer** — Filter framework controllers (Devise) from AGENTS.md output, show all associations, match `before_action` with `!`/`?` suffixes.

## [0.15.0] - 2026-03-22

### Security

- **Sensitive file blocking** — `search_code` and `get_edit_context` now block access to `.env*`, `*.key`, `*.pem`, `config/master.key`, `config/credentials.yml.enc`. Configurable via `config.sensitive_patterns`.
- **Credentials key names redacted** — Replaced `credentials_keys` (exposed names like `stripe_secret_key`) with `credentials_configured` boolean. No more information disclosure via JSON output or MCP resources.
- **View content size cap** — `collect_all_view_content` capped at 5MB total / 500KB per file to prevent memory exhaustion.
- **Schema file size limits** — 10MB limit on `schema.rb`/`structure.sql` parsing. Cached `schema.rb` reads to avoid re-reading per table.

### Added

- **Token optimization (~1,500-2,700 tokens/session saved)**:
  - Filter framework filters (`verify_authenticity_token`, etc.) from controller output
  - Filter framework/gem concerns (`Devise::*`, `Turbo::*`, `*::Generated*`) from models
  - Combine duplicate PUT/PATCH routes into single `PATCH|PUT` entry
  - Only show Nullable/Default columns when they have meaningful values
  - Drop gem version numbers from default output
  - Single HTML naming hint for Stimulus (not per-controller)
  - Only show non-default middleware and initializers in config
  - Group sibling controllers/routes with identical structure
  - Compress repeated Tailwind classes in view full output
  - Strip inline SVGs from view content
  - Separate active vs lifecycle-only Stimulus controllers

### Fixed

- **Controller staleness** — Source-file parsing for actions/filters instead of Ruby reflection. Filesystem discovery for new controllers not yet loaded as classes.
- **Schema `t.index` format** — Parse indexes inside `create_table` blocks (not just `add_index` outside).
- **Stimulus nested values** — Brace-depth counting for single-line `{ active: { type: String, default: "overview" } }`.
- **Stimulus phantom `type:Number`** — Exclude `type`/`default` as value names (JS keywords, not Stimulus values).
- **Search context_lines** — Use `--field-context-separator=:` for ripgrep `-C` output compatibility.
- **Schema defaults** — Supplement live DB nil defaults with values from `schema.rb`.
- **Config missing data** — Added `queue_adapter` and `mailer` settings to config introspector and tool.
- **View garbled fields** — Only extract from `@variable.field` patterns (not arbitrary method chains).
- **View shared partials** — `controller:"shared"` now finds partials in `app/views/shared/`.
- **View full detail** — Lists available controllers when no controller specified.
- **Edit context hint** — "Also found" only shown for matches outside the context window.
- **Model file structure** — Compressed to single-line format.
- **Strong params body** — Action detail now shows the actual `permit(...)` call.
- **AR-generated methods** — Filter `build_*`, `*_ids=`, etc. from model instance methods.

## [0.14.0] - 2026-03-20

### Fixed

- **Schema 0 indexes** — Fixed composite index parsing in schema.rb (regex didn't match array syntax) and structure.sql (`.first` only took first column). Both single and composite indexes now extracted correctly.
- **Stale routes after editing routes.rb** — Route introspector now calls `routes_reloader.execute_if_updated` to force Rails to reload routes before extraction.
- **Config "not available"** — Added `:config` to `:standard` preset. Was `:full` only, so default users never saw config data.
- **Stimulus values lost name** — Fixed parsing for both simple (`name: Type`) and complex (`name: { type: Type, default: val }`) formats. Now shows `max: Number (default: 3)`.
- **Model concerns noise** — Filtered out internal Rails modules (ActiveRecord::, ActiveModel::, Kernel, JSON::, etc.) from concerns list.

### Added

- **Route helpers in standard detail** — `rails_get_routes(detail: "standard")` now includes route helper names alongside paths.
- **`app_only` filter for routes** — `rails_get_routes(app_only: true)` (default) hides internal Rails routes (Active Storage, Action Mailbox, Conductor).
- **Search context lines** — `rails_search_code(context_lines: 2)` adds surrounding lines to matches (passes `-C` to ripgrep).
- **Stimulus dash/underscore normalization** — Both `weekly-chart` and `weekly_chart` work for controller lookup. Output shows HTML `data-controller` attribute.
- **Model public method signatures** — `rails_get_model_details(model: "Cook")` shows method names with params from source, stopping at private boundary.

## [0.13.1] - 2026-03-20

### Changed

- **View summary** — now shows partials used by each view.
- **Model details** — shows method signatures (name + parameters) instead of just method names.
- Removed unused demo files; fixed GUIDE.md preset tables.

## [0.13.0] - 2026-03-20

### Added

- **`rails_validate` MCP tool** — batch syntax validation for Ruby, ERB, and JavaScript files. Replaces separate `ruby -c`, ERB check, and `node -c` calls. Returns pass/fail for each file with error details. Uses `Open3.capture2e` (no shell execution). Falls back to brace-matching when Node.js is unavailable.
- **Model constants extraction** — introspects `STATUSES = %w[...]` style constants and includes them in model context.
- **Global before_actions in controller rules** — OpenCode AGENTS.md now shows ApplicationController before_actions.
- **Service objects and jobs listed** — OpenCode controller AGENTS.md now lists service objects and background jobs.
- **Validate spec** — 8 tests covering happy path, syntax errors, path traversal, MAX_FILES, unsupported types.

### Security

- **Validate tool uses Open3 array form** — no shell execution for `ruby -c`, ERB compilation, or `node -c`. Fixed critical shell quoting bug in ERB validation that caused it to always fail.
- **File size limit** on JavaScript fallback validation (2MB).
- **`which node` check uses array form** — `system("which", "node")` instead of shell string.

### Fixed

- ERB validation was broken due to shell quoting bug (backticks + nested quotes). Replaced with `Open3.capture2e("ruby", "-e", script, ARGV[0])`.
- Rubocop offenses in validate.rb (18 spacing issues auto-corrected).

## [0.12.0] - 2026-03-20

### Added

- **Design Token Introspector** — auto-detects CSS framework and extracts tokens from Tailwind v3/v4, Bootstrap/Sass, plain CSS custom properties, Webpacker-era stylesheets, and ViewComponent sidecar CSS. Tested across 8 CSS setups. Added to standard preset.
- **`rails_get_edit_context` MCP tool** — purpose-built for surgical edits. Returns code around a match point with line numbers. Replaces the Read + Edit workflow with a single call.
- **Line numbers in action source** — `rails_get_controllers(action: "index")` now returns start/end line numbers for targeted editing.
- **Model file structure** — `rails_get_model_details(model: "Cook")` now returns line ranges for each section (associations, validations, scopes, etc.).

### Changed

- **MCP instructions updated** — "Use MCP for reference files (schema, routes, tests). Read directly if you'll edit." Prevents unnecessary double-reads.
- **UI pattern extractor rewritten** — semantic labels (primary/secondary/danger), deduplication, 12+ component types, color scheme + radius + form layout extraction, framework-agnostic.
- **Schema rules include column types** — `status:string, intake:jsonb` instead of just names. Also shows foreign keys, indexes, and enum values.
- **View standard detail enhanced** — shows partial fields, helper methods, and shared partials.

### Security

- **File.realpath symlink protection** on all file-reading tools (get_view, get_edit_context, get_test_info, search_code).
- **File size limits** — 2MB on controllers/models/views, 500KB on test files.
- **Ripgrep flag injection prevention** — `--` separator before user pattern.
- **Nil guards** on all component rendering across 10 serializers.
- **Non-greedy regex** — ReDoS prevention in card/input/label pattern matching.
- **UTF-8 encoding safety** — all File.read calls handle binary/non-UTF-8 files gracefully.

### Fixed

- Off-by-one in model structure section line ranges.
- Stimulus sort crash on nil controller name.
- Secondary button picking up disabled states (`cursor-not-allowed`).
- Progress bars misclassified as badges.
- Input detection picking up alert divs instead of actual inputs.

## [0.11.0] - 2026-03-20

### Added

- **UI pattern extraction** — scans all views for repeated CSS class patterns. Detects buttons, cards, inputs, labels, badges, links, headings, flashes, alerts. Added to ALL serializers (root files + split rules for Claude, Cursor, Windsurf, Copilot, OpenCode).
- **View partial structure** — `rails_get_view(detail: "standard")` shows model fields and helper methods used by each partial.
- **Schema column names** — `.claude/rules/rails-schema.md` shows key column names with types, foreign keys, indexes, and enum values. Keeps polymorphic `_type`, STI `type`, and soft-delete `deleted_at` columns.

## [0.10.2] - 2026-03-20

### Security

- **ReDoS protection** — added regex timeout and converted greedy quantifiers to non-greedy across all pattern matching.
- **File size limits** — added size caps on parsed files to prevent memory exhaustion from oversized inputs.

## [0.10.1] - 2026-03-19

### Changed

- Patch release for RubyGems republish (no code changes).

## [0.10.0] - 2026-03-19

### Added

- **`rails_get_view` MCP tool** — get view template contents, partials, Stimulus references. Filter by controller or specific path. Supports summary/standard/full detail levels. Eliminates reading 490+ lines of view files per task. ([#7](https://github.com/crisnahine/rails-ai-context/issues/7))
- **`rails_get_stimulus` MCP tool** — get Stimulus controller details (targets, values, actions, outlets, classes). Filter by controller name. Wraps existing StimulusIntrospector. ([#8](https://github.com/crisnahine/rails-ai-context/issues/8))
- **`rails_get_controllers` `action` parameter** — returns actual action source code + applicable filters instead of the entire controller file. Saves ~1,400 tokens per call. ([#9](https://github.com/crisnahine/rails-ai-context/issues/9))
- **`rails_get_test_info` enhanced** — now supports `detail` levels (summary/standard/full), `model` and `controller` params to find existing tests, fixture/factory names, test helper setup. ([#10](https://github.com/crisnahine/rails-ai-context/issues/10))
- **ViewTemplateIntrospector** — new introspector that reads view file contents and extracts partial references and Stimulus data attributes.
- **Stimulus and view_templates in standard preset** — both introspectors now in `:standard` preset (11 introspectors, was 10).

## [0.9.0] - 2026-03-19

### Added

- **`config.generate_root_files` option** — when set to `false`, skips generating root-level context files (CLAUDE.md, AGENTS.md, .windsurfrules, copilot-instructions.md, .ai-context.json) while still generating all split rules (.claude/rules/, .cursor/rules/, .windsurf/rules/, .github/instructions/). Defaults to `true`.
- **Section markers on root files** — generated content in CLAUDE.md, AGENTS.md, .windsurfrules, and copilot-instructions.md is now wrapped in `<!-- BEGIN rails-ai-context -->` / `<!-- END rails-ai-context -->` markers. User content outside the markers is preserved on re-generation. Existing files without markers get the marked section appended.
- **App overview split rules** — new `rails-context.md` in `.claude/rules/` and `rails-context.instructions.md` in `.github/instructions/` provide a compact app overview (stack, models, routes, gems, architecture) so context is available even when root files are disabled.

### Changed

- **Removed `.cursorrules` root file** — Cursor officially deprecated `.cursorrules` in favor of `.cursor/rules/`. The `:cursor` format now generates only `.cursor/rules/*.mdc` split rules. The `rails-project.mdc` split rule (with `alwaysApply: true`) already provides the project overview.
- **License changed from AGPL-3.0 to MIT** — removes the copyleft blocker for SaaS and commercial projects.

## [0.8.5] - 2026-03-19

### Fixed

- **Thread-safe shared tool cache** — `BaseTool.cached_context` now uses a Mutex-protected shared cache across all 9 tool subclasses. Previously, each subclass cached independently (up to 9 redundant introspections after invalidation) and had no synchronization for multi-threaded servers like Puma. ([#2](https://github.com/crisnahine/rails-ai-context/issues/2))
- **SearchCode ripgrep total result cap** — `rg --max-count N` limits matches per file, not total. A search with `max_results: 5` against a large codebase could return hundreds of results. Now capped with `.first(max_results)` after parsing, matching the Ruby fallback behavior. ([#3](https://github.com/crisnahine/rails-ai-context/issues/3))
- **JobIntrospector Proc queue fallback** — when a Proc-based `queue_name` raises during introspection, the queue now falls back to `"default"` instead of producing garbage like `"#<Proc:0x00007f...>"`. ([#4](https://github.com/crisnahine/rails-ai-context/issues/4))
- **CLI `version` command crash** — `rails-ai-context version` crashed with `LoadError` due to wrong `require_relative` path (`../rails_ai_context/version` instead of `../lib/rails_ai_context/version`). ([#5](https://github.com/crisnahine/rails-ai-context/issues/5))

### Documentation

- **Standalone CLI documented** — the `rails-ai-context` executable (serve, context, inspect, watch, doctor, version) is now documented in README, GUIDE, and CLAUDE.md.

## [0.8.4] - 2026-03-19

### Added

- **`structure.sql` support** — the schema introspector now parses `db/structure.sql` when no `db/schema.rb` exists and no database connection is available. Extracts tables, columns (with SQL type normalization), indexes, and foreign keys from PostgreSQL dump format. Prefers `schema.rb` when both exist.
- **Fingerprinter watches `db/structure.sql`** — file changes to `structure.sql` now trigger cache invalidation and live reload.

## [0.8.3] - 2026-03-19

### Changed

- **License published to RubyGems** — v0.8.2 changed the license from MIT to AGPL-3.0 but the gem was not republished. This release ensures the AGPL-3.0 license is reflected on RubyGems.

## [0.8.2] - 2026-03-19

### Changed

- **License** — changed from MIT to AGPL-3.0 to protect against unauthorized clones and ensure derivative works remain open source.
- **CI: auto-publish to MCP Registry** — the release workflow now automatically publishes to the MCP Registry via `mcp-publisher` with GitHub OIDC auth. No manual `mcp-publisher login` + `publish` needed.

## [0.8.1] - 2026-03-19

### Added

- **OpenCode support** — generates `AGENTS.md` (native OpenCode context file) plus per-directory `app/models/AGENTS.md` and `app/controllers/AGENTS.md` that OpenCode auto-loads when reading files in those directories. Falls back to `CLAUDE.md` when no `AGENTS.md` exists. New command: `rails ai:context:opencode`.

### Fixed

- **Live reload LoadError in HTTP mode** — when `live_reload = true` and the `listen` gem was missing, the `start_http` method's rescue block (for rackup fallback) swallowed the live reload error, producing a confusing rack error instead of the correct "listen gem required" message. The rescue is now scoped to the rackup require only.
- **Dangling @live_reload reference** — `@live_reload` was assigned before `start` was called. If `start` raised LoadError, the instance variable pointed to a non-functional object. Now only assigned after successful start.

## [0.8.0] - 2026-03-19

### Added

- **MCP Live Reload** — when running `rails ai:serve`, file changes automatically invalidate tool caches and send MCP notifications (`notifications/resources/list_changed`) to connected AI clients. The AI's context stays fresh without manual re-querying. Requires the `listen` gem (enabled by default when available). Configurable via `config.live_reload` (`:auto`, `true`, `false`) and `config.live_reload_debounce` (default: 1.5s).
- **Live reload doctor check** — `rails ai:doctor` now warns when the `listen` gem is not installed.

## [0.7.1] - 2026-03-19

### Added

- **Full MCP tool reference in all context files** — every generated file (CLAUDE.md, .cursorrules, .windsurfrules, copilot-instructions.md) now includes complete tool documentation with parameters, detail levels, pagination examples, and usage workflow. Dedicated `rails-mcp-tools` split rule files added for Claude, Cursor, Windsurf, and Copilot.
- **MCP Registry listing** — published to the [official MCP Registry](https://registry.modelcontextprotocol.io) as `io.github.crisnahine/rails-ai-context` via mcpb package type.

### Fixed

- **Schema version parsing** — versions with underscores (e.g. `2024_01_15_123456`) were truncated to the first digit group. Now captures the full version string.
- **Documentation** — updated README (detail levels, pagination, generated file tree, config options), SECURITY.md (supported versions), CONTRIBUTING.md (project structure), gemspec (post-install message), demo_script.sh (all 17 generated files).

## [0.7.0] - 2026-03-19

### Added

- **Detail levels on MCP tools** — `detail:"summary"`, `detail:"standard"` (default), `detail:"full"` on `rails_get_schema`, `rails_get_routes`, `rails_get_model_details`, `rails_get_controllers`. AI calls summary first, then drills down. Based on Anthropic's recommended MCP pattern.
- **Pagination** — `limit` and `offset` parameters on schema and routes tools for apps with hundreds of tables/routes.
- **Response size safety net** — Configurable hard cap (`max_tool_response_chars`, default 120K) on tool responses. Truncated responses include hints to use filters.
- **Compact CLAUDE.md** — New `:compact` context mode (default) generates ≤150 lines per Claude Code's official recommendation. Contains stack overview, key models, and MCP tool usage guide.
- **Full mode preserved** — `config.context_mode = :full` retains the existing full-dump behavior. Also available via `rails ai:context:full` or `CONTEXT_MODE=full`.
- **`.claude/rules/` generation** — Generates quick-reference files in `.claude/rules/` for schema and models. Auto-loaded by Claude Code alongside CLAUDE.md.
- **Cursor MDC rules** — Generates `.cursor/rules/*.mdc` files with YAML frontmatter (globs, alwaysApply). Project overview is always-on; model/controller rules auto-attach when working in matching directories. Legacy `.cursorrules` kept for backward compatibility.
- **Windsurf 6K compliance** — `.windsurfrules` is now hard-capped at 5,800 characters (within Windsurf's 6,000 char limit). Generates `.windsurf/rules/*.md` for the new rules format.
- **Copilot path-specific instructions** — Generates `.github/instructions/*.instructions.md` with `applyTo` frontmatter for model and controller contexts. Main `copilot-instructions.md` respects compact mode (≤500 lines).
- **`rails ai:context:full` task** — Dedicated rake task for full context dump.
- **Configurable limits** — `claude_max_lines` (default: 150), `max_tool_response_chars` (default: 120K).

### Changed

- Default `context_mode` is now `:compact` (was implicitly `:full`). Existing behavior available via `config.context_mode = :full`.
- Tools default to `detail:"standard"` which returns bounded results, not unlimited.
- All tools return pagination hints when results are truncated.
- `.windsurfrules` now uses dedicated `WindsurfSerializer` instead of sharing `RulesSerializer` with Cursor.

## [0.6.0] - 2026-03-18

### Added

- **Migrations introspector** — Discovers migration files, pending migrations, recent history, schema version, and migration statistics. Works without DB connection.
- **Seeds introspector** — Analyzes db/seeds.rb structure, discovers seed files in db/seeds/, detects which models are seeded, and identifies patterns (Faker, environment conditionals, find_or_create_by).
- **Middleware introspector** — Discovers custom Rack middleware in app/middleware/, detects patterns (auth, rate limiting, tenant isolation, logging), and categorizes the full middleware stack.
- **Engine introspector** — Discovers mounted Rails engines from routes.rb with paths and descriptions for 23+ known engines (Sidekiq::Web, Flipper::UI, PgHero, ActiveAdmin, etc.).
- **Multi-database introspector** — Discovers multiple databases, replicas, sharding config, and model-specific `connects_to` declarations. Works with database.yml parsing fallback.
- **2 new MCP resources** — `rails://migrations`, `rails://engines`
- **Migrations added to :standard preset** — AI tools now see migration context by default
- **Doctor check** — New `check_migrations` diagnostic
- **Fingerprinter** — Now watches `db/migrate/`, `app/middleware/`, and `config/database.yml`

### Changed

- Default `:standard` preset expanded from 8 to 9 introspectors (added `:migrations`)
- Default `:full` preset expanded from 21 to 26 introspectors
- Doctor checks expanded from 11 to 12
- Static MCP resources expanded from 7 to 9

## [0.5.2] - 2026-03-18

### Fixed

- **MCP tool nil crash** — All 9 MCP tools now handle missing introspector data gracefully instead of crashing with `NoMethodError` when the introspector is not in the active preset (e.g. `rails_get_config` with `:standard` preset)
- **Zeitwerk dependency** — Changed from open-ended `>= 2.6` to pessimistic `~> 2.6` per RubyGems best practices
- **Documentation** — Updated CONTRIBUTING.md, CHANGELOG.md, and CLAUDE.md to reflect Zeitwerk autoloading, introspector presets, and `.mcp.json` auto-discovery changes

## [0.5.1] - 2026-03-18

### Fixed

- Documentation updates and animated demo GIF added to README.
- Zeitwerk autoloading fixes for edge cases.

## [0.5.0] - 2026-03-18

### Added

- **Introspector presets** — `:standard` (8 core introspectors, fast) and `:full` (all 21, thorough) via `config.preset = :standard`
- **`.mcp.json` auto-discovery** — Install generator creates `.mcp.json` so Claude Code and Cursor auto-detect the MCP server with zero manual config
- **Zeitwerk autoloading** — Replaced 47 `require_relative` calls with Zeitwerk for faster boot and conventional file loading
- **Automated release workflow** — GitHub Actions publishes to RubyGems via trusted publishing when a version tag is pushed
- **Version consistency check** — Release workflow verifies git tag matches `version.rb` before publishing
- **Auto GitHub Release** — Release notes extracted from CHANGELOG.md automatically
- **Dependabot** — Weekly automated dependency and GitHub Actions updates
- **README demo GIF** — Animated terminal recording showing install, doctor, and context generation
- **SECURITY.md** — Security policy with supported versions and reporting process
- **CODE_OF_CONDUCT.md** — Contributor Covenant v2.1
- **GitHub repo topics** — Added discoverability keywords (rails, mcp, ai, etc.)

### Changed

- Default introspectors reduced from 21 to 8 (`:standard` preset) for faster boot; use `config.preset = :full` for all 21
- New files auto-loaded by Zeitwerk — no manual `require_relative` needed when adding introspectors or tools

## [0.4.0] - 2026-03-18

### Added

- **14 new introspectors** — Controllers, Views, Turbo/Hotwire, I18n, Config, Active Storage, Action Text, Auth, API, Tests, Rake Tasks, Asset Pipeline, DevOps, Action Mailbox
- **3 new MCP tools** — `rails_get_controllers`, `rails_get_config`, `rails_get_test_info`
- **3 new MCP resources** — `rails://controllers`, `rails://config`, `rails://tests`
- **Model introspector enhancements** — Extracts `has_secure_password`, `encrypts`, `normalizes`, `delegate`, `serialize`, `store`, `generates_token_for`, `has_one_attached`, `has_many_attached`, `has_rich_text`, `broadcasts_to` via source parsing
- **Stimulus introspector enhancements** — Extracts `outlets` and `classes` from controllers
- **Gem introspector enhancements** — 30+ new notable gems: monitoring (Sentry, Datadog, New Relic, Skylight), admin (ActiveAdmin, Administrate, Avo), pagination (Pagy, Kaminari), search (Ransack, pg_search, Searchkick), forms (SimpleForm), utilities (Faraday, Flipper, Bullet, Rack::Attack), and more
- **Convention detector enhancements** — Detects concerns, validators, policies, serializers, notifiers, Phlex, PWA, encrypted attributes, normalizations
- **Markdown serializer sections** — All 14 new introspector sections rendered in generated context files
- **Doctor enhancements** — 4 new checks: controllers, views, i18n, tests (11 total)
- **Fingerprinter expansion** — Watches `app/controllers`, `app/views`, `app/jobs`, `app/mailers`, `app/channels`, `app/javascript/controllers`, `config/initializers`, `lib/tasks`; glob now covers `.rb`, `.rake`, `.js`, `.ts`, `.erb`, `.haml`, `.slim`, `.yml`

### Fixed

- **YAML parsing** — `YAML.load_file` calls now pass `permitted_classes: [Symbol], aliases: true` for Psych 4 (Ruby 3.1+) compatibility
- **Rake task parser** — Fixed `@last_desc` instance variable leaking between files; fixed namespace tracking with indent-based stack
- **Vite detection** — Changed `File.exist?("vite.config")` to `Dir.glob("vite.config.*")` to match `.js`/`.ts`/`.mjs` extensions
- **Health check regex** — Added word boundaries to avoid false positives on substrings (e.g. "groups" matching "up")
- **Multi-attribute macros** — `normalizes :email, :name` now captures all attributes, not just the first
- **Stimulus action regex** — Requires `method(args) {` pattern to avoid matching control flow keywords
- **Controller respond_to** — Simplified format extraction to avoid nested `end` keyword issues
- **GetRoutes nil guard** — Added `|| {}` fallback for `by_controller` to prevent crash on partial introspection data
- **GetSchema nil guard** — Added `|| {}` fallback for `schema[:tables]` to prevent crash on partial schema data
- **View layout discovery** — Added `File.file?` filter to exclude directories from layout listing
- **Fingerprinter glob** — Changed from `**/*.rb` to multi-extension glob to detect changes in `.rake`, `.js`, `.ts`, `.erb` files

### Changed

- Default introspectors expanded from 7 to 21
- MCP tools expanded from 6 to 9
- Static MCP resources expanded from 4 to 7
- Doctor checks expanded from 7 to 11
- Test suite expanded from 149 to 247 examples with exact value assertions

## [0.3.0] - 2026-03-18

### Added

- **Cache invalidation** — TTL + file fingerprinting for MCP tool cache (replaces permanent `||=` cache)
- **MCP Resources** — Static resources (`rails://schema`, `rails://routes`, `rails://conventions`, `rails://gems`) and resource template (`rails://models/{name}`)
- **Per-assistant serializers** — Claude gets behavioral rules, Cursor/Windsurf get compact rules, Copilot gets task-oriented GFM
- **Stimulus introspector** — Extracts Stimulus controller targets, values, and actions from JS/TS files
- **Database stats introspector** — Opt-in PostgreSQL approximate row counts via `pg_stat_user_tables`
- **Auto-mount HTTP middleware** — Rack middleware for MCP endpoint when `config.auto_mount = true`
- **Diff-aware regeneration** — Context file generation skips unchanged files
- **`rails ai:doctor`** — Diagnostic command with AI readiness score (0-100)
- **`rails ai:watch`** — File watcher that auto-regenerates context files on change (requires `listen` gem)

### Fixed

- **Shell injection in SearchCode** — Replaced backtick execution with `Open3.capture2` array form; added file_type validation, max_results cap, and path traversal protection
- **Scope extraction** — Fixed broken `model.methods.grep(/^_scope_/)` by parsing source files for `scope :name` declarations
- **Route introspector** — Fixed `route.internal?` compatibility with Rails 8.1

### Changed

- `generate_context` now returns `{ written: [], skipped: [] }` instead of flat array
- Default introspectors now include `:stimulus`

## [0.2.0] - 2026-03-18

### Added

- Named rake tasks (`ai:context:claude`, `ai:context:cursor`, etc.) that work without quoting in zsh
- AI assistant summary table printed after `ai:context` and `ai:inspect`
- `ENV["FORMAT"]` fallback for `ai:context_for` task
- Format validation in `ContextFileSerializer` — unknown formats now raise `ArgumentError` with valid options

### Fixed

- `rails ai:context_for[claude]` failing in zsh due to bracket glob interpretation
- Double introspection in `ai:context` and `ai:context_for` tasks (removed unused `RailsAiContext.introspect` calls)

## [0.1.0] - 2026-03-18

### Added

- Initial release
- Schema introspection (live DB + static schema.rb fallback)
- Model introspection (associations, validations, scopes, enums, callbacks, concerns)
- Route introspection (HTTP verbs, paths, controller actions, API namespaces)
- Job introspection (ActiveJob, mailers, Action Cable channels)
- Gem analysis (40+ notable gems mapped to categories with explanations)
- Convention detection (architecture style, design patterns, directory structure)
- 6 MCP tools: `rails_get_schema`, `rails_get_routes`, `rails_get_model_details`, `rails_get_gems`, `rails_search_code`, `rails_get_conventions`
- Context file generation: CLAUDE.md, .cursorrules, .windsurfrules, .github/copilot-instructions.md, JSON
- Rails Engine with Railtie auto-setup
- Install generator (`rails generate rails_ai_context:install`)
- Rake tasks: `ai:context`, `ai:serve`, `ai:serve_http`, `ai:inspect`
- CLI executable: `rails-ai-context serve|context|inspect`
- Stdio + Streamable HTTP transport support via official mcp SDK
- CI matrix: Ruby 3.2/3.3/3.4 × Rails 7.1/7.2/8.0
