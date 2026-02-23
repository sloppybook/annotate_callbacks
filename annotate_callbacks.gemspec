# frozen_string_literal: true

require_relative "lib/annotate_callbacks/version"

Gem::Specification.new do |spec|
  spec.name = "annotate_callbacks"
  spec.version = AnnotateCallbacks::VERSION
  spec.authors = ["sloppybook"]
  spec.summary = "Annotate ActiveRecord callbacks as comments in model files"
  spec.description = "Adds a comment block summarizing all ActiveRecord callbacks (including those from concerns and parent classes) at the top of each model file using runtime reflection."
  spec.homepage = "https://github.com/sloppybook/annotate_callbacks"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir["lib/**/*", "LICENSE.txt", "README.md"]

  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 7.0"
  spec.add_dependency "activesupport", ">= 7.0"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
