# frozen_string_literal: true

class RetryJob
  extend Resque::Plugins::Retry
  include Resque::Plugins::Stages

  @retry_limit = 5
  @retry_delay = 1.minute

  def self.queue
    "RetryJobQueue"
  end

  def self.perform(*args)
    job = perform_job(*args)

    FakeLogger.error("RetryJob.perform job_id", job.job_id)
    FakeLogger.error("RetryJob.perform args", *args)
    FakeLogger.error("RetryJob.perform job.args", *job.args)
  end
end
