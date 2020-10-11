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

          add_record_inline_failure
        else
          add_record_failure
        end
      end

      # rubocop:disable Metrics/BlockLength
      class_methods do
        def before_perform_stages_successful(*args)
          job = Resque::Plugins::Stages::StagedJob.perform_job(*args)

          return if job.blank?

          job.status = :running
        end

        def after_perform_stages_successful(*args)
          job = Resque::Plugins::Stages::StagedJob.perform_job(*args)

          return if job.blank?

          job.status = :successful
        end

        def stages_report_try_again(_exception, *args)
          job = Resque::Plugins::Stages::StagedJob.perform_job(*args)

          return if job.blank?

          job.status = :pending_re_run
        end

        def stages_report_giving_up(_exception, *args)
          job = Resque::Plugins::Stages::StagedJob.perform_job(*args)

          return if job.blank?

          job.status = :failed
        end

        def add_record_failure
          define_singleton_method(:on_failure_stages_failed) do |_error, *args|
            job = Resque::Plugins::Stages::StagedJob.perform_job(*args)

            return if job.blank?

            job.status = :failed
          end
        end

        def add_record_inline_failure
          define_singleton_method(:on_failure_stages_inline_failed) do |_error, *args|
            return unless Resque.inline?

            job = Resque::Plugins::Stages::StagedJob.perform_job(*args)

            return if job.blank?

            job.status = :failed
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
end
