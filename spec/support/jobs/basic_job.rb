# frozen_string_literal: true

class BasicJob
  include Resque::Plugins::Stages

  def self.queue
    "BasicJobQueue"
  end

  def self.perform(*args)
    job = perform_job(*args)

    FakeLogger.error("BasicJob.perform job_id", job.job_id)
    FakeLogger.error("BasicJob.perform args", *args)
    FakeLogger.error("BasicJob.perform job.args", *job.args)
  end
end
