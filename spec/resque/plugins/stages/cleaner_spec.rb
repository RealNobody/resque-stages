# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Stages::Cleaner do
  let(:group) { Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid) }
  let(:load_group) { Resque::Plugins::Stages::StagedGroup.new(group.group_id) }
  let(:stage) { group.current_stage }
  let(:load_stage) { Resque::Plugins::Stages::StagedGroupStage.new(stage.group_stage_id) }
  let!(:job) { stage.enqueue BasicJob }
  let(:load_job) { Resque::Plugins::Stages::StagedJob.new(job.job_id) }

  describe "purge_all" do
    it "deletes all values" do
      Resque::Plugins::Stages::Cleaner.purge_all

      expect(job).to be_blank
      expect(stage).to be_blank
      expect(group).to be_blank
    end
  end

  describe "cleanup_jobs" do
    it "does not recreate the group if the group info is deleted" do
      job.redis.keys("StagedGroup::*::Info").each { |key| job.redis.del(key) }

      Resque::Plugins::Stages::Cleaner.cleanup_jobs
      expect(load_group.stages.values).to be_include stage
    end

    it "does not recreate the group if the group list is deleted" do
      job.redis.keys("StagedGroup::*").each { |key| next if key.include?("::Info"); job.redis.del(key) }

      Resque::Plugins::Stages::Cleaner.cleanup_jobs
      expect(load_group.stages.values).to be_include stage
    end

    it "recreates the group if the group is deleted" do
      job.redis.keys("StagedGroup::*").each { |key| job.redis.del(key) }

      Resque::Plugins::Stages::Cleaner.cleanup_jobs
      expect(load_group.stages.values).to be_include stage
    end

    it "creates a new group if the group is deleted and cannot be found" do
      job.redis.keys("StagedGroup::*").each { |key| job.redis.del(key) }
      job.redis.keys("StagedGroupStage::*::staged_group").each { |key| job.redis.del(key) }

      Resque::Plugins::Stages::Cleaner.cleanup_jobs
      expect(load_group.stages.values).not_to be_include stage
      expect(load_stage.staged_group.stages.values).to be_include stage
      expect(load_stage.jobs).to be_include(job)
    end

    it "does not create a new stage if it can be found" do
      job.redis.keys("StagedGroup::*").each { |key| job.redis.del(key) }
      job.redis.keys("StagedGroupStage::*").each { |key| next if key.include?("::staged_group"); job.redis.del(key) }

      Resque::Plugins::Stages::Cleaner.cleanup_jobs
      expect(load_group.stages.values).to be_include stage
      expect(load_stage.jobs).to be_include(job)
    end

    it "create a new stage if it can be found" do
      job.redis.keys("StagedGroup::*").each { |key| job.redis.del(key) }
      job.redis.keys("StagedGroupStage::*").each { |key| job.redis.del(key) }

      Resque::Plugins::Stages::Cleaner.cleanup_jobs
      expect(load_stage.jobs).not_to be_include(job)
      expect(load_job.staged_group_stage.jobs).to be_include(job)
      expect(load_job.staged_group_stage.staged_group.stages.values).to be_include(load_job.staged_group_stage)
    end
  end
end
