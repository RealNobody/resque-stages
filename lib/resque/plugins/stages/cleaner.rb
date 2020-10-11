# frozen_string_literal: true

module Resque
  module Plugins
    module Stages
      # A class for cleaning up stranded objects for the Stages plugin
      class Cleaner
        include Resque::Plugins::Stages::RedisAccess

        class << self
          def redis
            @redis ||= Resque::Plugins::Stages::Cleaner.new.redis
          end

          def purge_all
            keys = redis.keys("*")

            return if keys.blank?

            redis.del(*keys)
          end

          def cleanup_jobs
            jobs = redis.keys("StagedJob::*")

            jobs.each do |job_key|
              job = Resque::Plugins::Stages::StagedJob.new(job_key[11..])

              job.verify
            end
          end
        end
      end
    end
  end
end
