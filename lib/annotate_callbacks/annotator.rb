# frozen_string_literal: true

require "tempfile"
require "fileutils"

module AnnotateCallbacks
  class Annotator
    ANNOTATION_START = "# == Callbacks =="
    ANNOTATION_END   = "# == End Callbacks =="
    ANNOTATION_REGEX = /^#{Regexp.escape(ANNOTATION_START)}\n(.*?)^#{Regexp.escape(ANNOTATION_END)}\n\n?/m
    MODEL_DIR = "app/models"

    def annotate(model_class, file_path)
      callbacks = Inspector.new(model_class).callbacks
      return :skipped if callbacks.empty?

      content = File.read(file_path, encoding: "UTF-8")
      clean_content = content.sub(ANNOTATION_REGEX, "")

      insert_pos = class_definition_line(clean_content)
      return :skipped unless insert_pos

      annotation = build_annotation(callbacks)
      lines = clean_content.lines
      insert_pos = skip_preceding_comments(lines, insert_pos)
      lines.insert(insert_pos, annotation)
      new_content = lines.join

      return :unchanged if new_content == content

      atomic_write(file_path, new_content)
      :annotated
    end

    def remove_annotation(file_path)
      content = File.read(file_path, encoding: "UTF-8")
      return :skipped unless content.include?(ANNOTATION_START)

      new_content = content.sub(ANNOTATION_REGEX, "")
      return :unchanged if new_content == content

      atomic_write(file_path, new_content)
      :removed
    end

    def annotate_all
      results = Hash.new { |h, k| h[k] = [] }

      each_model do |model_class, file_path|
        status = annotate(model_class, file_path)
        results[status] << file_path
      rescue StandardError => e
        results[:errors] << { file: file_path, error: e.message }
      end

      results
    end

    def remove_all
      results = Hash.new { |h, k| h[k] = [] }

      Dir.glob(File.join(MODEL_DIR, "**", "*.rb")).sort.each do |file|
        status = remove_annotation(file)
        results[status] << file
      rescue StandardError => e
        results[:errors] << { file: file, error: e.message }
      end

      results
    end

    private

    def each_model
      ApplicationRecord.descendants.each do |klass|
        next if klass.abstract_class?

        file = source_file_for(klass)
        next unless file

        yield klass, file
      end
    end

    def source_file_for(klass)
      file = Object.const_source_location(klass.name)&.first if klass.name
      return nil unless file

      file.start_with?(project_model_dir) ? file : nil
    end

    def project_model_dir
      @project_model_dir ||= File.expand_path(MODEL_DIR)
    end

    def class_definition_line(content)
      content.lines.index { |line| line.match?(/\A\s*(class|module)\s+/) }
    end

    def skip_preceding_comments(lines, pos)
      while pos > 0
        prev = lines[pos - 1].strip
        break unless prev.start_with?("#")
        break if prev.match?(/^#.*(?:frozen_string_literal|encoding|warn_indent):/)
        pos -= 1
      end
      pos
    end

    def atomic_write(file_path, content)
      dir = File.dirname(file_path)
      Tempfile.create(["annotate_callbacks", ".rb"], dir) do |tmp|
        tmp.write(content)
        tmp.flush
        FileUtils.mv(tmp.path, file_path)
      end
    end

    def build_annotation(callbacks)
      max_type_len = callbacks.map { |c| c.type.length }.max
      max_name_len = callbacks.map { |c| format_name(c).length }.max

      lines = [ANNOTATION_START, "#"]
      callbacks.each do |cb|
        entry = "#   %-#{max_type_len}s  %-#{max_name_len}s" % [cb.type, format_name(cb)]
        entry += "  #{cb.options}" if cb.options
        entry += "  [#{cb.source}]" if cb.source
        lines << entry.rstrip
      end
      lines << "#"
      lines << ANNOTATION_END
      lines.map { |l| "#{l}\n" }.join + "\n"
    end

    def format_name(cb)
      cb.method_name.start_with?("(") ? cb.method_name : ":#{cb.method_name}"
    end
  end
end
