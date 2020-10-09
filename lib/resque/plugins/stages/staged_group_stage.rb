# frozen_string_literal: true

module Resque
  module Plugins
    module Stages
      # A class which represents a single stage and all of the jobs for that stage.
      #
      # Each stage has a status that it progresses through
      #   :pending  - not started yet
      #   :running  - currently running
      #   :complete - all jobs in the stage are completed
      class StagedGroupStage
        include Resque::Plugins::Stages::RedisAccess
        include Comparable

        attr_reader :group_stage_id

        def initialize(group_stage_id)
          @group_stage_id = group_stage_id
        end

        def <=>(other)
          return nil unless other.is_a?(Resque::Plugins::Stages::StagedGroupStage)

          group_stage_id <=> other.group_stage_id
        end

        def enqueue(klass, *args)
          job = create_enqueue_job(klass, args)

          return job if status == :pending

          self.status = :running if status != :running

          job.status = :queued
          Resque.enqueue(*job.enqueue_args)

          job
        end

        def enqueue_to(queue, klass, *args)
          job = create_enqueue_job(klass, args)

          return job if status == :pending

          self.status = :running if status != :running

          job.status = :queued
          Resque.enqueue_to(queue, *job.enqueue_args)

          job
        end

        def enqueue_at(timestamp, klass, *args)
          job = create_enqueue_job(klass, args)

          return job if status == :pending

          self.status = :running if status != :running

          job.status = :queued
          Resque.enqueue_at(timestamp, *job.enqueue_args)

          job
        end

        def enqueue_at_with_queue(queue, timestamp, klass, *args)
          job = create_enqueue_job(klass, args)

          return job if status == :pending

          self.status = :running if status != :running

          job.status = :queued
          Resque.enqueue_at_with_queue(queue, timestamp, *job.enqueue_args)

          job
        end

        def enqueue_in(number_of_seconds_from_now, klass, *args)
          job = create_enqueue_job(klass, args)

          return job if status == :pending

          self.status = :running if status != :running

          job.status = :queued
          Resque.enqueue_in(number_of_seconds_from_now, *job.enqueue_args)

          job
        end

        def enqueue_in_with_queue(queue, number_of_seconds_from_now, klass, *args)
          job = create_enqueue_job(klass, args)

          return job if status == :pending

          self.status = :running if status != :running

          job.status = :queued
          Resque.enqueue_in_with_queue(queue, number_of_seconds_from_now, *job.enqueue_args)

          job
        end

        def status
          redis.hget(staged_group_key, "status")&.to_sym || :pending
        end

        def status=(value)
          redis.hset(staged_group_key, "status", value.to_s)

          staged_group&.stage_completed if status == :complete
        end

        def number
          redis.hget(staged_group_key, "number")&.to_i || 1
        end

        def number=(value)
          redis.hset(staged_group_key, "number", value)
        end

        def staged_group
          return nil if staged_group_id.blank?

          @staged_group ||= Resque::Plugins::Stages::StagedGroup.new(staged_group_id)
        end

        def staged_group=(value)
          @staged_group    = value
          @staged_group_id = value.group_id

          value.add_stage(self)
          redis.hset(staged_group_key, "staged_group_id", value.group_id)
        end

        def jobs(start = 0, stop = -1)
          redis.lrange(stage_key, start, stop).map { |id| Resque::Plugins::Stages::StagedJob.new(id) }
        end

        def jobs_by_status(status)
          jobs.select { |job| job.status == status }
        end

        def num_jobs
          redis.llen(stage_key)
        end

        def add_job(staged_group_job)
          redis.rpush stage_key, staged_group_job.job_id
          staged_group&.add_stage(self)
        end

        def remove_job(staged_group_job)
          redis.lrem(stage_key, 0, staged_group_job.job_id)
        end

        def delete
          jobs.each(&:delete)

          staged_group&.remove_stage self

          redis.del stage_key
          redis.del staged_group_key
        end

        def initiate
          self.status = :running

          jobs.each do |job|
            next if job.completed?
            next if job.queued?

            job.enqueue_job
          end
        end

        def job_completed
          return unless jobs.all?(&:completed?)

          self.status = :complete
        end

        private

        def create_enqueue_job(klass, args)
          Resque::Plugins::Stages::StagedJob.create_job self, klass, *args
        end

        def stage_key
          "StagedGroupStage::#{group_stage_id}"
        end

        def staged_group_key
          "#{stage_key}::staged_group"
        end

        def staged_group_id
          @staged_group_id ||= redis.hget(staged_group_key, "staged_group_id")
        end
      end
    end
  end
end
