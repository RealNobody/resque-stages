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

      # rubocop:disable Metrics/ClassLength
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

        def queue_time
          @queue_time ||= stored_values[:queue_time].to_time
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

          redis.hset(job_key, "staged_group_stage_id", staged_group_stage_id)

          value.add_job(self)
        end

        # rubocop:disable Metrics/AbcSize
        def save!
          redis.hsetnx(job_key, "queue_time", Time.now)
          redis.hset(job_key, "class_name", class_name)
          redis.hset(job_key, "args", encode_args(*compressed_args(args)))
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
          case status
            when :pending
              self.status = :queued
              Resque.enqueue(*enqueue_args)

            when :pending_re_run
              Resque.enqueue_delayed_selection do |args|
                # :nocov:
                klass.perform_job(*Array.wrap(args)).job_id == job_id
                # :nocov:
              end
          end
        end

        def enqueue_args
          [klass, *enqueue_compressed_args]
        end

        def enqueue_compressed_args
          new_args = compressed_args([{ staged_job_id: job_id }, *args])

          new_args[0][:staged_job_id] = job_id

          new_args
        end

        def uncompressed_args
          decompress_args(args)
        end

        def args
          @args = if defined?(@args)
                    @args
                  else
                    decompress_args(Array.wrap(decode_args(stored_values[:args])))
                  end
        end

        def args=(value)
          @args = value.nil? ? [] : Array.wrap(value).dup
        end

        def completed?
          %i[failed successful].include? status
        end

        def queued?
          %i[queued running pending_re_run].include? status
        end

        def pending?
          %i[pending pending_re_run].include? status
        end

        def blank?
          !redis.exists(job_key)
        end

        def verify
          return build_new_structure if staged_group_stage.blank?

          staged_group_stage.verify
          staged_group_stage.verify_job(self)
        end

        private

        def build_new_structure
          group = Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid)
          stage = group.current_stage

          self.staged_group_stage = stage
        end

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

          if status == :pending
            mark_stage_pending
          elsif queued?
            mark_stage_running
          else
            staged_group_stage.job_completed
          end
        end

        def mark_stage_pending
          return if %i[running pending].include? staged_group_stage.status

          staged_group_stage.status = :pending
        end

        def mark_stage_running
          return if staged_group_stage.status == :running

          staged_group_stage.status = :running
        end

        def described_class
          return if class_name.blank?

          class_name.constantize
        rescue StandardError
          # :nocov:
          nil
          # :nocov:
        end

        def compressable?
          !described_class.blank? &&
              described_class.singleton_class.included_modules.map(&:name).include?("Resque::Plugins::Compressible")
        end

        def compressed_args(compress_args)
          return compress_args unless compressable?
          return compress_args if described_class.compressed?(compress_args)

          [{ resque_compressed: true, payload: described_class.compressed_args(compress_args) }]
        end

        def decompress_args(basic_args)
          return basic_args unless compressable?
          return basic_args unless described_class.compressed?(basic_args)

          described_class.uncompressed_args(basic_args.first[:payload] || basic_args.first["payload"])
        end
      end

      # rubocop:enable Metrics/ClassLength
    end
  end
end
