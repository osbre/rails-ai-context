# frozen_string_literal: true

module RailsAiContext
  module Introspectors
    # Reads actual view template contents and extracts metadata:
    # partial references, Stimulus controller usage, line counts.
    # Separate from ViewIntrospector which focuses on structural discovery.
    class ViewTemplateIntrospector
      attr_reader :app

      def initialize(app)
        @app = app
      end

      def call
        views_dir = File.join(app.root.to_s, "app", "views")
        return { templates: {}, partials: {}, ui_patterns: {} } unless Dir.exist?(views_dir)

        all_content = collect_all_view_content(views_dir)
        {
          templates: scan_templates(views_dir),
          partials: scan_partials(views_dir),
          ui_patterns: extract_ui_patterns(all_content)
        }
      rescue => e
        { error: e.message }
      end

      private

      def scan_templates(views_dir)
        templates = {}
        Dir.glob(File.join(views_dir, "**", "*")).each do |path|
          next if File.directory?(path)
          next if File.basename(path).start_with?("_") # skip partials
          next if path.include?("/layouts/")

          relative = path.sub("#{views_dir}/", "")
          content = File.read(path) rescue next
          templates[relative] = {
            lines: content.lines.count,
            partials: extract_partial_refs(content),
            stimulus: extract_stimulus_refs(content)
          }
        end
        templates
      end

      def scan_partials(views_dir)
        partials = {}
        Dir.glob(File.join(views_dir, "**", "_*")).each do |path|
          next if File.directory?(path)
          relative = path.sub("#{views_dir}/", "")
          content = File.read(path) rescue next
          partials[relative] = {
            lines: content.lines.count,
            fields: extract_model_fields(content),
            helpers: extract_helper_calls(content)
          }
        end
        partials
      end

      def collect_all_view_content(views_dir)
        content = ""
        Dir.glob(File.join(views_dir, "**", "*.{erb,haml,slim}")).each do |path|
          next if File.directory?(path)
          content += (File.read(path) rescue "")
        end
        content
      end

      def extract_ui_patterns(all_content) # rubocop:disable Metrics/MethodLength
        patterns = {}
        class_groups = Hash.new(0)

        # Match both double and single quoted class attributes
        all_content.scan(/class="([^"]+)"/).each do |m|
          classes = m[0].gsub(/<%=.*?%>/, "").strip # Strip ERB interpolation
          next if classes.length < 5
          class_groups[classes] += 1
        end
        all_content.scan(/class='([^']+)'/).each do |m|
          classes = m[0].gsub(/<%=.*?%>/, "").strip
          next if classes.length < 5
          class_groups[classes] += 1
        end

        # Find repeated patterns (used 2+ times) grouped by element type
        # Framework-agnostic: works with Tailwind, Bootstrap, or custom CSS
        buttons = []
        cards = []
        inputs = []
        labels = []
        badges = []
        links = []

        class_groups.each do |classes, count|
          next if count < 2

          if classes.match?(/btn|button|submit|bg-\w+-\d+.*text-white|hover:bg|btn-primary|btn-secondary/)
            buttons << classes
          elsif classes.match?(/card|panel|shadow|border.*rounded.*p-\d|bg-white.*rounded/)
            cards << classes
          elsif classes.match?(/input|field|form-control|border.*rounded.*px-\d|focus:ring|focus:border/)
            inputs << classes
          elsif classes.match?(/label|font-semibold.*mb-|font-medium.*mb-|form-label|block.*text-sm/)
            labels << classes
          elsif classes.match?(/badge|rounded-full|pill|tag|px-2.*py-1.*text-xs/)
            badges << classes
          elsif classes.match?(/link|hover:text-|hover:underline|hover:bg-.*text-.*font-/)
            links << classes
          end
        end

        patterns[:buttons] = buttons.first(3) if buttons.any?
        patterns[:cards] = cards.first(3) if cards.any?
        patterns[:inputs] = inputs.first(3) if inputs.any?
        patterns[:labels] = labels.first(3) if labels.any?
        patterns[:badges] = badges.first(3) if badges.any?
        patterns[:links] = links.first(3) if links.any?

        patterns
      end

      EXCLUDED_METHODS = %w[
        each map select reject first last size count any? empty? present? blank?
        new build create find where order limit nil? join class html_safe
        to_s to_i to_f inspect strip chomp downcase upcase capitalize
        humanize pluralize singularize truncate gsub sub scan match split
        freeze dup clone length bytes chars reverse uniq compact flatten
        flat_map zip sort sort_by min max sum group_by
        persisted? new_record? valid? errors reload save destroy update
        delete respond_to? is_a? kind_of? send try
        abs round ceil floor
        strftime iso8601 beginning_of_day end_of_day ago from_now
      ].freeze

      def extract_model_fields(content)
        fields = []
        content.scan(/(?:@?\w+)\.(\w+)/).each do |m|
          field = m[0]
          next if field.length < 3 || field.length > 40
          next if field.match?(/\A[0-9a-f]+\z/)
          next if field.match?(/\A[A-Z]/) # skip constant/class access
          next if EXCLUDED_METHODS.include?(field)
          next if field.start_with?("to_", "html_")
          next if field.end_with?("?", "!")
          fields << field
        end
        fields.uniq.first(15)
      end

      def extract_helper_calls(content)
        helpers = []
        # Custom helper methods (render_*, format_*, *_path, *_url)
        content.scan(/\b(render_\w+|format_\w+)\b/).each { |m| helpers << m[0] }
        helpers.uniq
      end

      def extract_partial_refs(content)
        refs = []
        # render "partial_name" or render partial: "name"
        content.scan(/render\s+(?:partial:\s*)?["']([^"']+)["']/).each { |m| refs << m[0] }
        # render @collection
        content.scan(/render\s+@(\w+)/).each { |m| refs << m[0] }
        refs.uniq
      end

      def extract_stimulus_refs(content)
        refs = []
        # data-controller="name" or data-controller="name1 name2"
        content.scan(/data-controller=["']([^"']+)["']/).each do |m|
          m[0].split.each { |c| refs << c }
        end
        # data: { controller: "name" }
        content.scan(/controller:\s*["']([^"']+)["']/).each do |m|
          m[0].split.each { |c| refs << c }
        end
        refs.uniq
      end
    end
  end
end
