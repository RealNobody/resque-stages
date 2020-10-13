# frozen_string_literal: true

module Resque
  module Plugins
    # This module is added to any job class which needs to work within a stage.
    #
    # If the job is going to be retryable, this module needs to be included after
    # the retry module is extended so that we know that the class is retryable.
    module Stages
      extend ActiveSupport::Concern

      class Error < StandardError; end

      included do
        if singleton_class.included_modules.map(&:name).include?("Resque::Plugins::Retry")
          try_again_callback :stages_report_try_again
          give_up_callback :stages_report_giving_up
        else
          add_record_failure
        end
      end

      # rubocop:disable Metrics/BlockLength
      class_methods do
        def perform_job(*args)
          job = perform_job_from_param(args)

          if job.nil?
            job            = Resque::Plugins::Stages::StagedJob.new(SecureRandom.uuid)
            job.class_name = name
            job.args       = args
          end

          job
        end

        # rubocop:disable Metrics/AbcSize
        # rubocop:disable Metrics/CyclomaticComplexity
        def perform_job_from_param(args)
          return if args.blank? || !args.first.is_a?(Hash)

          hash            = args.first.with_indifferent_access
          job             = Resque::Plugins::Stages::StagedJob.new(hash[:staged_job_id]) if hash.key?(:staged_job_id)
          job&.class_name = name
          job.args        = (hash.key?(:resque_compressed) ? args : args[1..]) if !job.nil? && job.blank?

          job
        end

        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/AbcSize

        def before_perform_stages_successful(*args)
          job = perform_job(*args)

          return if job.blank?

          job.status = :running
        end

        def after_perform_stages_successful(*args)
          job = perform_job(*args)

          return if job.blank?
          return if job.status == :failed && Resque.inline?

          job.status = :successful
        end

        def around_perform_stages_inline_around(*args)
          yield
        rescue StandardError => e
          raise e unless Resque.inline?

          job = perform_job(*args)
          return if job.blank?

          job.status = :failed
        end

        def stages_report_try_again(_exception, *args)
          job = perform_job(*args)

          return if job.blank?

          job.status = :pending_re_run
        end

        def stages_report_giving_up(_exception, *args)
          job = perform_job(*args)

          return if job.blank?

          job.status = :failed
        end

        def add_record_failure
          define_singleton_method(:on_failure_stages_failed) do |_error, *args|
            job = perform_job(*args)

            return if job.blank?

            job.status = :failed
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
end
