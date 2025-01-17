# frozen_string_literal: true
require 'marcel'

module Bulkrax
  module ImporterExporterBehavior
    extend ActiveSupport::Concern

    def parser
      @parser ||= parser_class.new(self)
    end

    def parser_class
      self.parser_klass.constantize
    end

    def last_imported_at
      @last_imported_at ||= self.importer_runs.last&.created_at
    end

    def next_import_at
      (last_imported_at || Time.current) + frequency.to_seconds if schedulable? && last_imported_at.present?
    end

    def increment_counters(index, collection: false, file_set: false, work: false)
      # Only set the totals if they were not set on initialization
      importer_run = ImporterRun.find(current_run.id) # make sure fresh
      if collection
        importer_run.total_collection_entries = index + 1 unless parser.collections_total.positive?
      elsif file_set
        importer_run.total_file_set_entries = index + 1 unless parser.file_sets_total.positive?
      elsif work
        # TODO: differentiate between work and collection counts for exporters
        importer_run.total_work_entries = index + 1 unless limit.to_i.positive? || parser.total.positive?
      end
      importer_run.enqueued_records += 1
      importer_run.save!
    end

    def keys_without_numbers(keys)
      keys.map { |key| key_without_numbers(key) }
    end

    def key_without_numbers(key)
      key.gsub(/_\d+/, '').sub(/^\d+_/, '')
    end

    # Is this a file?
    def file?
      parser_fields&.[]('import_file_path') && File.file?(parser_fields['import_file_path'])
    end

    # Is this a zip file?
    def zip?
      filename = parser_fields&.[]('import_file_path')
      return false unless filename
      return false unless File.file?(filename)
      returning_value = false
      File.open(filename) do |file|
        returning_value = ::Marcel::MimeType.for(file).include?('application/zip')
      end
      returning_value
    end
  end
end
