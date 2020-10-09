# frozen_string_literal: true

module Resque
  module Plugins
    module Stages
      # A class representing a staged job.
      #
      # Staged jobs can have the following statuses:
      #   :pending        - not yet run
      #   :queued         - in the Resque queue
      #   :running        - currently running
      #   :pending_re_run - currently in the retry queue
      #   :failed         - completed with a failure
      #   :successful     - completed successfully
      class StagedJob
        include Resque::Plugins::Stages::RedisAccess
        include Comparable

        attr_reader :job_id
        attr_writer :class_name

        class << self
          # Creates a job to be queued to Resque that has an ID that we can track its status with.
          def create_job(staged_group_stage, klass, *args)
            job = Resque::Plugins::Stages::StagedJob.new(SecureRandom.uuid)

            job.staged_group_stage = staged_group_stage
            job.class_name         = klass.name
            job.args               = args

            job.save!

            job
          end

          def perform_job(*args)
            job = perform_job_from_param(args)

            if job.nil?
              job      = Resque::Plugins::Stages::StagedJob.new(SecureRandom.uuid)
              job.args = args
            end

            job
          end

          private

          def perform_job_from_param(args)
            return if args.blank? || !args.first.is_a?(Hash)

            hash     = args.first.with_indifferent_access
            job      = Resque::Plugins::Stages::StagedJob.new(hash[:staged_job_id]) if hash.key?(:staged_job_id)
            job.args = args[1..] if !job.nil? && job.blank?

            job
          end
        end

        def initialize(job_id)
          @job_id = job_id
        end

        def <=>(other)
          return nil unless other.is_a?(Resque::Plugins::Stages::StagedJob)

          job_id <=> other.job_id
        end

        def class_name
          @class_name ||= stored_values[:class_name]
        end

        def status
          @status ||= stored_values[:status]&.to_sym || :pending
        end

        def status=(value)
          @status = value
          redis.hset(job_key, "status", status)

          notify_stage
        end

        def status_message
          @status_message ||= stored_values[:status_message]
        end

        def status_message=(value)
          @status_message = value
          redis.hset(job_key, "status_message", status_message)
        end

        def staged_group_stage
          return nil if staged_group_stage_id.blank?

          @staged_group_stage ||= Resque::Plugins::Stages::StagedGroupStage.new(staged_group_stage_id)
        end

        def staged_group_stage=(value)
          @staged_group_stage    = value
          @staged_group_stage_id = value.group_stage_id

          value.add_job(self)
        end

        # rubocop:disable Metrics/AbcSize
        def save!
          redis.hset(job_key, "class_name", class_name)
          redis.hset(job_key, "args", encode_args(*args))
          redis.hset(job_key, "staged_group_stage_id", staged_group_stage_id)
          redis.hset(job_key, "status", status)
          redis.hset(job_key, "status_message", status_message)
        end

        # rubocop:enable Metrics/AbcSize

        def delete
          # Make sure the job is loaded into memory so we can use it even though we are going to delete it.
          stored_values

          redis.del(job_key)

          staged_group_stage.remove_job(self)
        end

        def enqueue_job
          self.status = :queued
          Resque.enqueue(*enqueue_args)
        end

        def enqueue_args
          [klass, { staged_job_id: job_id }, *args]
        end

        def args
          @args = if defined?(@args)
                    @args
                  else
                    Array.wrap(decode_args(stored_values[:args]))
                  end
        end

        def args=(value)
          @args = if value.nil?
                    []
                  else
                    Array.wrap(value).dup
                  end
        end

        def completed?
          %i[failed successful].include? status
        end

        def queued?
          %i[queued running pending_re_run].include? status
        end

        def pending?
          %i[pending].include? status
        end

        def blank?
          !redis.exists(job_key)
        end

        private

        def stored_values
          @stored_values ||= (redis.hgetall(job_key) || {}).with_indifferent_access
        end

        def klass
          @klass ||= class_name.constantize
        end

        def encode_args(*args)
          Resque.encode(args)
        end

        def decode_args(args_string)
          return if args_string.blank?

          Resque.decode(args_string)
        end

        def job_key
          "StagedJob::#{job_id}"
        end

        def staged_group_stage_id
          @staged_group_stage_id ||= stored_values[:staged_group_stage_id]
        end

        def notify_stage
          return if staged_group_stage.blank?

          if pending?
            return if %i[running pending].include? staged_group_stage.status

            staged_group_stage.status = :pending
          elsif queued?
            return if staged_group_stage.status == :running

            staged_group_stage.status = :running
          else
            staged_group_stage.job_completed
          end
        end
      end
    end
  end
end
