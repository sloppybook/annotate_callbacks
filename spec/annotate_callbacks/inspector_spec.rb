# frozen_string_literal: true

RSpec.describe AnnotateCallbacks::Inspector do
  CallbackStub = Struct.new(:filter, :kind, keyword_init: true) do
    def initialize(filter:, kind:, if_conditions: [], unless_conditions: [])
      super(filter: filter, kind: kind)
      @if = Array(if_conditions)
      @unless = Array(unless_conditions)
    end
  end

  def build_model_class(callback_chains)
    klass = Class.new
    callback_chains.each do |type, callbacks|
      klass.define_singleton_method("_#{type}_callbacks") { callbacks }
    end
    klass
  end

  def build_model_class_with_module(callback_chains, included_methods)
    klass = build_model_class(callback_chains)
    included_methods.each do |name, owner|
      mod = Module.new { define_method(name) {} }
      mod.define_singleton_method(:name) { owner }
      klass.include(mod)
    end
    klass
  end

  describe "#callbacks" do
    it "extracts symbol callbacks" do
      model = build_model_class(
        "save" => [
          CallbackStub.new(filter: :normalize_name, kind: :before),
          CallbackStub.new(filter: :update_cache, kind: :after)
        ]
      )

      callbacks = described_class.new(model).callbacks

      expect(callbacks.length).to eq(2)
      expect(callbacks[0]).to have_attributes(type: "before_save", method_name: "normalize_name")
      expect(callbacks[1]).to have_attributes(type: "after_save", method_name: "update_cache")
    end

    it "displays block callbacks with relative path" do
      model = build_model_class(
        "create" => [CallbackStub.new(filter: -> {}, kind: :after)]
      )

      callbacks = described_class.new(model).callbacks

      expect(callbacks[0].type).to eq("after_create")
      expect(callbacks[0].method_name).to match(/\(block: .+:\d+\)/)
    end

    it "displays (block) when source location is unavailable" do
      filter = proc {}
      allow(filter).to receive(:source_location).and_return(nil)

      model = build_model_class(
        "save" => [CallbackStub.new(filter: filter, kind: :before)]
      )

      expect(described_class.new(model).callbacks[0].method_name).to eq("(block)")
    end

    it "extracts symbol if conditions only" do
      model = build_model_class(
        "save" => [CallbackStub.new(filter: :do_thing, kind: :before, if_conditions: [:active?, proc {}])]
      )

      expect(described_class.new(model).callbacks[0].options).to eq("if: :active?")
    end

    it "extracts symbol unless conditions only" do
      model = build_model_class(
        "save" => [CallbackStub.new(filter: :do_thing, kind: :before, unless_conditions: [:draft?])]
      )

      expect(described_class.new(model).callbacks[0].options).to eq("unless: :draft?")
    end

    it "returns nil options when only proc conditions exist" do
      model = build_model_class(
        "save" => [CallbackStub.new(filter: :do_thing, kind: :before, if_conditions: [proc {}])]
      )

      expect(described_class.new(model).callbacks[0].options).to be_nil
    end

    it "returns nil options when no conditions exist" do
      model = build_model_class(
        "save" => [CallbackStub.new(filter: :do_thing, kind: :before)]
      )

      expect(described_class.new(model).callbacks[0].options).to be_nil
    end

    it "extracts callbacks from multiple types" do
      model = build_model_class(
        "validation" => [CallbackStub.new(filter: :check_email, kind: :before)],
        "save" => [CallbackStub.new(filter: :encrypt, kind: :before)],
        "create" => [CallbackStub.new(filter: :welcome, kind: :after)]
      )

      types = described_class.new(model).callbacks.map(&:type)
      expect(types).to include("before_validation", "before_save", "after_create")
    end

    it "returns empty array when no callbacks exist" do
      expect(described_class.new(build_model_class({})).callbacks).to eq([])
    end

    it "skips non-symbol non-proc filters" do
      model = build_model_class("save" => [CallbackStub.new(filter: "string", kind: :before)])
      expect(described_class.new(model).callbacks).to be_empty
    end

    it "handles around callbacks" do
      model = build_model_class("save" => [CallbackStub.new(filter: :with_lock, kind: :around)])
      expect(described_class.new(model).callbacks[0]).to have_attributes(type: "around_save")
    end

    it "filters out autosave callbacks by name pattern" do
      model = build_model_class(
        "save" => [
          CallbackStub.new(filter: :autosave_associated_records_for_posts, kind: :before),
          CallbackStub.new(filter: :normalize_name, kind: :before)
        ]
      )

      callbacks = described_class.new(model).callbacks
      expect(callbacks.length).to eq(1)
      expect(callbacks[0].method_name).to eq("normalize_name")
    end

    it "filters out internal callbacks by source module" do
      model = build_model_class_with_module(
        { "save" => [
          CallbackStub.new(filter: :some_internal, kind: :before),
          CallbackStub.new(filter: :normalize_name, kind: :before)
        ] },
        { some_internal: "ActiveRecord::AutosaveAssociation" }
      )

      callbacks = described_class.new(model).callbacks
      expect(callbacks.length).to eq(1)
      expect(callbacks[0].method_name).to eq("normalize_name")
    end

    it "detects source module when method is defined in an included module" do
      model = build_model_class_with_module(
        { "save" => [CallbackStub.new(filter: :track_changes, kind: :before)] },
        { track_changes: "Trackable" }
      )

      expect(described_class.new(model).callbacks[0].source).to eq("Trackable")
    end

    it "returns nil source when method is defined directly on the class" do
      model = build_model_class("save" => [CallbackStub.new(filter: :do_thing, kind: :before)])
      expect(described_class.new(model).callbacks[0].source).to be_nil
    end
  end
end
