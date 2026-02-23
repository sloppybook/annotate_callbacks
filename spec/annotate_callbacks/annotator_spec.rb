# frozen_string_literal: true

require "tmpdir"
require "fileutils"

RSpec.describe AnnotateCallbacks::Annotator do
  let(:annotator) { described_class.new }
  let(:tmpdir) { Dir.mktmpdir }
  let(:dummy_class) { Class.new }

  after { FileUtils.rm_rf(tmpdir) }

  def write_fixture(name, content, dest_dir: tmpdir)
    dest = File.join(dest_dir, name)
    File.write(dest, content)
    dest
  end

  def copy_fixture(name, dest_dir: tmpdir)
    src = File.join(FIXTURES_PATH, name)
    dest = File.join(dest_dir, name)
    FileUtils.cp(src, dest)
    dest
  end

  def stub_inspector(callbacks)
    inspector = instance_double(AnnotateCallbacks::Inspector, callbacks: callbacks)
    allow(AnnotateCallbacks::Inspector).to receive(:new).and_return(inspector)
  end

  def make_callback(type:, method_name:, options: nil, source: nil)
    AnnotateCallbacks::Inspector::CallbackEntry.new(
      type: type, method_name: method_name, options: options, source: source
    )
  end

  describe "#annotate" do
    it "annotates a model file with callbacks" do
      file = copy_fixture("user_model.rb")
      stub_inspector([
        make_callback(type: "before_save", method_name: "encrypt_password"),
        make_callback(type: "after_create", method_name: "send_welcome_email")
      ])

      expect(annotator.annotate(dummy_class, file)).to eq(:annotated)

      content = File.read(file)
      expect(content).to include("== Callbacks ==")
      expect(content).to include(":encrypt_password")
      expect(content).to include(":send_welcome_email")
      expect(content).to include("== End Callbacks ==")
    end

    it "shows source module in annotation" do
      file = copy_fixture("user_model.rb")
      stub_inspector([
        make_callback(type: "before_save", method_name: "track_changes", source: "Trackable")
      ])

      annotator.annotate(dummy_class, file)

      expect(File.read(file)).to include("[Trackable]")
    end

    it "shows options in annotation" do
      file = copy_fixture("user_model.rb")
      stub_inspector([
        make_callback(type: "after_save", method_name: "update_cache", options: "if: :name_changed?")
      ])

      annotator.annotate(dummy_class, file)

      expect(File.read(file)).to include("if: :name_changed?")
    end

    it "skips files with no callbacks" do
      file = copy_fixture("plain_model.rb")
      stub_inspector([])

      expect(annotator.annotate(dummy_class, file)).to eq(:skipped)
    end

    it "returns unchanged when annotation is current" do
      file = copy_fixture("user_model.rb")
      cbs = [make_callback(type: "before_save", method_name: "do_it")]
      stub_inspector(cbs)

      annotator.annotate(dummy_class, file)
      expect(annotator.annotate(dummy_class, file)).to eq(:unchanged)
    end

    it "places annotation before class definition" do
      file = copy_fixture("user_model.rb")
      stub_inspector([make_callback(type: "before_save", method_name: "do_it")])

      annotator.annotate(dummy_class, file)

      content = File.read(file)
      expect(content.index("== Callbacks ==")).to be < content.index("class User")
    end

    it "places annotation before outermost module" do
      file = copy_fixture("namespaced_model.rb")
      stub_inspector([make_callback(type: "before_save", method_name: "do_it")])

      annotator.annotate(dummy_class, file)

      content = File.read(file)
      expect(content.index("== Callbacks ==")).to be < content.index("module Legacy")
    end

    it "places annotation before doc comments" do
      file = write_fixture("doc_model.rb", <<~RUBY)
        # Documentation comment
        class DocModel < ApplicationRecord
        end
      RUBY
      stub_inspector([make_callback(type: "before_save", method_name: "do_it")])

      annotator.annotate(dummy_class, file)

      content = File.read(file)
      expect(content.index("== Callbacks ==")).to be < content.index("# Documentation comment")
    end

    it "does not skip past magic comments" do
      file = write_fixture("magic_model.rb", <<~RUBY)
        # frozen_string_literal: true
        class MagicModel < ApplicationRecord
        end
      RUBY
      stub_inspector([make_callback(type: "before_save", method_name: "do_it")])

      annotator.annotate(dummy_class, file)

      content = File.read(file)
      frozen_pos = content.index("frozen_string_literal")
      callback_pos = content.index("== Callbacks ==")
      expect(frozen_pos).to be < callback_pos
    end
  end

  describe "#remove_annotation" do
    it "removes existing annotations" do
      file = copy_fixture("annotated_model.rb")
      expect(annotator.remove_annotation(file)).to eq(:removed)

      content = File.read(file)
      expect(content).not_to include("== Callbacks ==")
      expect(content).to include("class AnnotatedModel")
    end

    it "skips files without annotations" do
      file = copy_fixture("user_model.rb")
      expect(annotator.remove_annotation(file)).to eq(:skipped)
    end
  end

  describe "round-trip" do
    it "restores original content after annotate then remove" do
      file = copy_fixture("user_model.rb")
      original = File.read(file)

      stub_inspector([make_callback(type: "before_save", method_name: "do_it")])
      annotator.annotate(dummy_class, file)
      annotator.remove_annotation(file)

      expect(File.read(file)).to eq(original)
    end

    it "restores namespaced file after annotate then remove" do
      file = copy_fixture("namespaced_model.rb")
      original = File.read(file)

      stub_inspector([make_callback(type: "before_save", method_name: "do_it")])
      annotator.annotate(dummy_class, file)
      annotator.remove_annotation(file)

      expect(File.read(file)).to eq(original)
    end

    it "restores file with doc comments after annotate then remove" do
      content = <<~RUBY
        # Documentation comment
        class DocModel < ApplicationRecord
        end
      RUBY
      file = write_fixture("doc_model.rb", content)

      stub_inspector([make_callback(type: "before_save", method_name: "do_it")])
      annotator.annotate(dummy_class, file)
      annotator.remove_annotation(file)

      expect(File.read(file)).to eq(content)
    end

    it "is idempotent when annotated twice" do
      file = copy_fixture("user_model.rb")
      cbs = [make_callback(type: "before_save", method_name: "do_it")]
      stub_inspector(cbs)

      annotator.annotate(dummy_class, file)
      first_content = File.read(file)
      annotator.annotate(dummy_class, file)

      expect(File.read(file)).to eq(first_content)
    end
  end

  describe "#remove_all" do
    it "removes annotations from all model files" do
      model_dir = File.join(tmpdir, "app", "models")
      FileUtils.mkdir_p(model_dir)
      file = copy_fixture("annotated_model.rb", dest_dir: model_dir)

      stub_const("AnnotateCallbacks::Annotator::MODEL_DIR", model_dir)

      results = annotator.remove_all
      expect(results[:removed].length).to eq(1)
      expect(File.read(file)).not_to include("== Callbacks ==")
    end
  end
end
