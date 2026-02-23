# frozen_string_literal: true

require_relative "annotate_callbacks/version"
require_relative "annotate_callbacks/inspector"
require_relative "annotate_callbacks/annotator"

module AnnotateCallbacks
end

require_relative "annotate_callbacks/railtie" if defined?(Rails::Railtie)
