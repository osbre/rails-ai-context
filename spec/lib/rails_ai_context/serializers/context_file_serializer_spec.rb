# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Serializers::ContextFileSerializer do
  let(:context) { RailsAiContext.introspect }

  describe "#call" do
    it "writes files for all formats including split rules" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :all)
        result = serializer.call
        # 5 root files + split rules (claude/rules, cursor/rules, windsurf/rules, opencode, github/instructions)
        expect(result[:written].size).to be >= 5
        expect(result[:skipped]).to be_empty
      end
    end

    it "skips unchanged files on second run" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        described_class.new(context, format: :claude).call
        result = described_class.new(context, format: :claude).call
        expect(result[:skipped].size).to be >= 1
        expect(result[:written]).to be_empty
      end
    end

    it "writes a single format with split rules" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :claude)
        result = serializer.call
        expect(result[:written].size).to be >= 1
        expect(result[:written].any? { |f| f.end_with?("CLAUDE.md") }).to be true
      end
    end

    it "generates .claude/rules/ when writing claude format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :claude)
        result = serializer.call
        claude_rules = result[:written].select { |f| f.include?(".claude/rules/") }
        expect(claude_rules).not_to be_empty
      end
    end

    it "generates only split rules for cursor format (no root .cursorrules)" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :cursor)
        result = serializer.call
        cursor_rules = result[:written].select { |f| f.include?(".cursor/rules/") }
        expect(cursor_rules).not_to be_empty
        expect(result[:written].none? { |f| f.end_with?(".cursorrules") }).to be true
      end
    end

    it "generates .windsurf/rules/ when writing windsurf format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :windsurf)
        result = serializer.call
        windsurf_rules = result[:written].select { |f| f.include?(".windsurf/rules/") }
        expect(windsurf_rules).not_to be_empty
      end
    end

    it "generates .github/instructions/ when writing copilot format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :copilot)
        result = serializer.call
        copilot_instructions = result[:written].select { |f| f.include?(".github/instructions/") }
        expect(copilot_instructions).not_to be_empty
      end
    end

    it "generates AGENTS.md when writing opencode format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :opencode)
        result = serializer.call
        agents_file = result[:written].find { |f| f.end_with?("AGENTS.md") }
        expect(agents_file).not_to be_nil
      end
    end

    it "raises for unknown format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        serializer = described_class.new(context, format: :bogus)
        expect { serializer.call }.to raise_error(ArgumentError, /Unknown format/)
      end
    end
  end

  describe "section markers" do
    it "wraps new file content in markers" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        described_class.new(context, format: :claude).call
        content = File.read(File.join(dir, "CLAUDE.md"))
        expect(content).to include("<!-- BEGIN rails-ai-context -->")
        expect(content).to include("<!-- END rails-ai-context -->")
      end
    end

    it "preserves user content outside markers on re-run" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        filepath = File.join(dir, "CLAUDE.md")

        described_class.new(context, format: :claude).call

        existing = File.read(filepath)
        File.write(filepath, "# My Custom Notes\n\n#{existing}\n# Footer\n")

        described_class.new(context, format: :claude).call
        updated = File.read(filepath)
        expect(updated).to include("My Custom Notes")
        expect(updated).to include("Footer")
        expect(updated).to include("<!-- BEGIN rails-ai-context -->")
      end
    end

    it "appends marked section to file without markers" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        filepath = File.join(dir, "CLAUDE.md")
        File.write(filepath, "# My hand-written CLAUDE.md\nSome rules here.\n")

        described_class.new(context, format: :claude).call
        content = File.read(filepath)
        expect(content).to start_with("# My hand-written CLAUDE.md")
        expect(content).to include("<!-- BEGIN rails-ai-context -->")
        expect(content).to include("<!-- END rails-ai-context -->")
      end
    end

    it "does not use markers for JSON format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        described_class.new(context, format: :json).call
        content = File.read(File.join(dir, ".ai-context.json"))
        expect(content).not_to include("<!-- BEGIN")
      end
    end
  end

  describe "generate_root_files = false" do
    it "skips root files but still generates split rules" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        allow(RailsAiContext.configuration).to receive(:generate_root_files).and_return(false)
        result = described_class.new(context, format: :claude).call
        expect(result[:written].none? { |f| f.end_with?("CLAUDE.md") }).to be true
        split_rules = result[:written].select { |f| f.include?(".claude/rules/") }
        expect(split_rules).not_to be_empty
      end
    end

    it "skips all root files for :all format" do
      Dir.mktmpdir do |dir|
        allow(RailsAiContext.configuration).to receive(:output_dir_for).and_return(dir)
        allow(RailsAiContext.configuration).to receive(:generate_root_files).and_return(false)
        result = described_class.new(context, format: :all).call
        root_files = result[:written].select { |f|
          base = File.basename(f)
          %w[CLAUDE.md AGENTS.md .windsurfrules .ai-context.json].include?(base) ||
            f.end_with?("copilot-instructions.md")
        }
        expect(root_files).to be_empty
        expect(result[:written]).not_to be_empty
      end
    end
  end
end
