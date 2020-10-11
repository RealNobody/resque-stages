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
    FakeLogger.error("RetryJob.perform", *args)
  end
end
