# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsAiContext::Introspectors::SchemaIntrospector do
  let(:app) { double("app", root: Pathname.new(fixture_path)) }
  let(:fixture_path) { File.expand_path("../../fixtures", __FILE__) }
  let(:introspector) { described_class.new(app) }

  describe "#call" do
    context "when ActiveRecord is not connected and no schema file" do
      before do
        allow(introspector).to receive(:active_record_connected?).and_return(false)
      end

      it "returns an error" do
        result = introspector.call
        expect(result[:error]).to include("No db/schema.rb or db/structure.sql")
      end
    end

    context "with a valid schema.rb fixture" do
      before do
        allow(introspector).to receive(:active_record_connected?).and_return(false)

        # Create fixture schema.rb
        db_dir = File.join(fixture_path, "db")
        FileUtils.mkdir_p(db_dir)
        File.write(File.join(db_dir, "schema.rb"), <<~RUBY)
          ActiveRecord::Schema[7.1].define(version: 2024_01_15_000000) do
            create_table "users" do |t|
              t.string "email"
              t.string "name"
              t.integer "role"
              t.timestamps
            end

            create_table "posts" do |t|
              t.string "title"
              t.text "body"
              t.references "user"
              t.timestamps
            end
          end
        RUBY
      end

      after do
        FileUtils.rm_rf(File.join(fixture_path, "db"))
      end

      it "falls back to static schema.rb parsing" do
        result = introspector.call
        expect(result[:adapter]).to eq("static_parse")
        expect(result[:note]).to include("no DB connection")
      end

      it "parses tables from schema.rb" do
        result = introspector.call
        expect(result[:tables]).to have_key("users")
        expect(result[:tables]).to have_key("posts")
        expect(result[:total_tables]).to eq(2)
      end

      it "extracts column names and types" do
        result = introspector.call
        user_cols = result[:tables]["users"][:columns]
        expect(user_cols).to include(a_hash_including(name: "email", type: "string"))
        expect(user_cols).to include(a_hash_including(name: "role", type: "integer"))
      end
    end

    context "with a valid structure.sql fixture" do
      before do
        allow(introspector).to receive(:active_record_connected?).and_return(false)

        db_dir = File.join(fixture_path, "db")
        FileUtils.mkdir_p(db_dir)
        File.write(File.join(db_dir, "structure.sql"), <<~SQL)
          CREATE TABLE public.users (
              id bigint NOT NULL,
              email character varying NOT NULL,
              name character varying,
              role integer DEFAULT 0,
              created_at timestamp(6) without time zone NOT NULL,
              updated_at timestamp(6) without time zone NOT NULL
          );

          CREATE TABLE public.posts (
              id bigint NOT NULL,
              title character varying,
              body text,
              user_id bigint,
              created_at timestamp(6) without time zone NOT NULL,
              updated_at timestamp(6) without time zone NOT NULL
          );

          CREATE TABLE public.schema_migrations (
              version character varying NOT NULL
          );

          CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);
          CREATE INDEX index_posts_on_user_id ON public.posts USING btree (user_id);

          ALTER TABLE ONLY public.posts
              ADD CONSTRAINT fk_rails_user FOREIGN KEY (user_id) REFERENCES public.users(id);
        SQL
      end

      after do
        FileUtils.rm_rf(File.join(fixture_path, "db"))
      end

      it "falls back to static structure.sql parsing" do
        result = introspector.call
        expect(result[:adapter]).to eq("static_parse")
        expect(result[:note]).to include("structure.sql")
      end

      it "parses tables from structure.sql" do
        result = introspector.call
        expect(result[:tables]).to have_key("users")
        expect(result[:tables]).to have_key("posts")
        expect(result[:total_tables]).to eq(2)
      end

      it "excludes schema_migrations table" do
        result = introspector.call
        expect(result[:tables]).not_to have_key("schema_migrations")
      end

      it "extracts columns with normalized types" do
        result = introspector.call
        user_cols = result[:tables]["users"][:columns]
        expect(user_cols).to include(a_hash_including(name: "email", type: "string"))
        expect(user_cols).to include(a_hash_including(name: "role", type: "integer"))
        expect(user_cols).to include(a_hash_including(name: "created_at", type: "datetime"))
      end

      it "extracts indexes" do
        result = introspector.call
        user_indexes = result[:tables]["users"][:indexes]
        expect(user_indexes).to include(a_hash_including(name: "index_users_on_email"))
      end

      it "extracts foreign keys" do
        result = introspector.call
        post_fks = result[:tables]["posts"][:foreign_keys]
        expect(post_fks).to include(a_hash_including(
          from_table: "posts",
          to_table: "users",
          column: "user_id"
        ))
      end
    end

    context "prefers schema.rb over structure.sql" do
      before do
        allow(introspector).to receive(:active_record_connected?).and_return(false)

        db_dir = File.join(fixture_path, "db")
        FileUtils.mkdir_p(db_dir)
        File.write(File.join(db_dir, "schema.rb"), <<~RUBY)
          ActiveRecord::Schema[7.1].define(version: 2024_01_15_000000) do
            create_table "users" do |t|
              t.string "email"
            end
          end
        RUBY
        File.write(File.join(db_dir, "structure.sql"), "CREATE TABLE public.other (id bigint);")
      end

      after do
        FileUtils.rm_rf(File.join(fixture_path, "db"))
      end

      it "uses schema.rb when both exist" do
        result = introspector.call
        expect(result[:note]).to include("schema.rb")
        expect(result[:tables]).to have_key("users")
      end
    end

    context "schema version parsing" do
      before do
        allow(introspector).to receive(:active_record_connected?).and_return(true)
        allow(introspector).to receive(:adapter_name).and_return("postgresql")
        allow(introspector).to receive(:table_names).and_return([])
        allow(introspector).to receive(:extract_tables).and_return({})
      end

      it "parses full schema version with underscores" do
        db_dir = File.join(fixture_path, "db")
        FileUtils.mkdir_p(db_dir)
        File.write(File.join(db_dir, "schema.rb"), <<~RUBY)
          ActiveRecord::Schema[7.1].define(version: 2024_01_15_123456) do
          end
        RUBY

        result = introspector.call
        expect(result[:schema_version]).to eq("20240115123456")
      ensure
        FileUtils.rm_rf(db_dir)
      end
    end
  end
end
