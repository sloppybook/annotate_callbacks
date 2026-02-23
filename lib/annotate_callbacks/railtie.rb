# frozen_string_literal: true

module AnnotateCallbacks
  class Railtie < Rails::Railtie
    rake_tasks do
      namespace :callbacks do
        desc "Annotate callbacks in model files"
        task annotate: :environment do
          Rails.application.eager_load!

          results = Annotator.new.annotate_all

          puts "Annotated: #{results[:annotated].length} file(s)"
          results[:annotated].each { |f| puts "  #{f}" }

          if results[:errors].any?
            puts "\nErrors: #{results[:errors].length}"
            results[:errors].each { |e| puts "  #{e[:file]}: #{e[:error]}" }
          end
        end

        desc "Remove callback annotations from model files"
        task :remove do
          results = Annotator.new.remove_all

          puts "Removed: #{results[:removed].length} file(s)"
          results[:removed].each { |f| puts "  #{f}" }

          if results[:errors].any?
            puts "\nErrors: #{results[:errors].length}"
            results[:errors].each { |e| puts "  #{e[:file]}: #{e[:error]}" }
          end
        end
      end
    end
  end
end
