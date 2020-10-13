# frozen_string_literal: true

class CompressedJob
  def self.queue
    "CompressedJobQueue"
  end

  def self.perform(*args)
    job = perform_job(*args)

    FakeLogger.error("CompressedJob.perform job_id", job.job_id)
    FakeLogger.error("CompressedJob.perform args", *args)
    FakeLogger.error("CompressedJob.perform job.args", *job.args)
  end

  extend Resque::Plugins::Compressible
  include Resque::Plugins::Stages
end
