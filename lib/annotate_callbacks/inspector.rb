# frozen_string_literal: true

module AnnotateCallbacks
  class Inspector
    CallbackEntry = Data.define(:type, :method_name, :options, :source)

    CALLBACK_TYPES = %w[
      initialize find touch validation
      save create update destroy
      commit rollback
    ].freeze

    INTERNAL_FILTER_PATTERNS = [
      /\Aautosave_associated_records_for_/,
    ].freeze

    INTERNAL_BLOCK_PATHS = %w[
      active_record/associations/builder/
      active_record/timestamp
      active_record/transactions
      active_record/locking
    ].freeze

    INTERNAL_SOURCES = %w[
      ActiveRecord::AutosaveAssociation
      ActiveRecord::Timestamp
      ActiveRecord::Transactions
      ActiveRecord::Persistence
      ActiveRecord::AttributeMethods::Dirty
      ActiveRecord::Locking::Optimistic
      ActiveRecord::CounterCache
      ActiveRecord::Normalization
      ActiveModel::Attributes::Normalization
    ].freeze

    def initialize(model_class)
      @target = model_class
    end

    def callbacks
      CALLBACK_TYPES
        .flat_map { |type| extract_callbacks_for(type) }
        .reject { |cb| internal?(cb) }
    end

    private

    def extract_callbacks_for(type)
      method_name = "_#{type}_callbacks"
      return [] unless @target.respond_to?(method_name)

      @target.send(method_name).filter_map { |cb| build_callback_info(cb, type) }
    end

    def build_callback_info(cb, type)
      name = case cb.filter
             when Symbol then cb.filter.to_s
             when Proc then format_block(cb.filter)
             else return nil
             end

      CallbackEntry.new(
        type: "#{cb.kind}_#{type}",
        method_name: name,
        options: extract_options(cb),
        source: detect_source(cb.filter)
      )
    end

    def internal?(cb)
      internal_by_name?(cb) || internal_by_block_path?(cb) || internal_by_source?(cb)
    end

    def internal_by_name?(cb)
      INTERNAL_FILTER_PATTERNS.any? { |p| p.match?(cb.method_name) }
    end

    def internal_by_block_path?(cb)
      return false unless cb.method_name.start_with?("(block:")

      INTERNAL_BLOCK_PATHS.any? { |path| cb.method_name.include?(path) }
    end

    def internal_by_source?(cb)
      cb.source && INTERNAL_SOURCES.any? { |s| cb.source.start_with?(s) }
    end

    def detect_source(filter)
      return nil unless filter.is_a?(Symbol)
      return nil unless @target.method_defined?(filter) || @target.private_method_defined?(filter)

      owner = @target.instance_method(filter).owner
      owner == @target ? nil : owner.name
    rescue NameError
      nil
    end

    def extract_options(cb)
      if_conditions = extract_symbol_conditions(cb, :@if)
      unless_conditions = extract_symbol_conditions(cb, :@unless)

      parts = []
      parts << "if: #{if_conditions.join(", ")}" if if_conditions.any?
      parts << "unless: #{unless_conditions.join(", ")}" if unless_conditions.any?
      parts.empty? ? nil : parts.join(", ")
    end

    def extract_symbol_conditions(cb, ivar)
      (cb.instance_variable_get(ivar) || [])
        .select { |c| c.is_a?(Symbol) }
        .map { |c| ":#{c}" }
    end

    def format_block(proc_obj)
      loc = proc_obj.source_location
      return "(block)" unless loc

      path = defined?(Rails) ? loc[0].sub("#{Rails.root}/", "") : loc[0]
      "(block: #{path}:#{loc[1]})"
    end
  end
end
