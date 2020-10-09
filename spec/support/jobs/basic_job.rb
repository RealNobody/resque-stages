# frozen_string_literal: true

class BasicJob
  include Resque::Plugins::Stages

  def self.queue
    "BasicJobQueue"
  end

  def self.perform(*args)
    FakeLogger.error("BasicJob.perform", *args)
  end
end
