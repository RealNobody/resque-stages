# frozen_string_literal: true

require "rails_helper"

RSpec.describe Resque::Plugins::Stages::StagedGroup do
  let(:group) { Resque::Plugins::Stages::StagedGroup.new SecureRandom.uuid }
  let(:load_group) { Resque::Plugins::Stages::StagedGroup.new group.group_id }

  describe "within_a_grouping" do
    it "yields a grouping" do
      Resque::Plugins::Stages::StagedGroup.within_a_grouping do |grouping|
        expect(grouping).to be_a Resque::Plugins::Stages::StagedGroup
      end
    end

    it "initiates the grouping" do
      test_grouping = nil

      Resque::Plugins::Stages::StagedGroup.within_a_grouping do |grouping|
        test_grouping = grouping
        allow(grouping).to receive(:initiate)
      end

      expect(test_grouping).to have_received(:initiate)
    end
  end

  describe "description" do
    it "defaults the description to the group_id" do
      group.description = nil

      expect(load_group.description).to eq group.group_id.to_s
    end

    it "sets the description to anything" do
      group.description = "This is a description"

      expect(load_group.description).to eq "This is a description"
    end
  end

  describe "created_at" do
    it "returns the created_at time" do
      time = Time.now

      travel_to(time) do
        time = Time.now
        group
      end

      travel_to(time + 1.day) do
        expect(load_group.created_at).to eq time
      end
    end
  end

  context "with stages" do
    let(:stages) do
      stage = group.stage(8)
      Resque::Plugins::Stages::StagedJob.create_job stage, BasicJob
      stage.redis.hset(stage.send(:staged_group_key), "status", :running.to_s)

      stage = group.stage(1)
      Resque::Plugins::Stages::StagedJob.create_job stage, BasicJob
      stage.redis.hset(stage.send(:staged_group_key), "status", :complete.to_s)

      stage = group.stage(2)
      Resque::Plugins::Stages::StagedJob.create_job stage, BasicJob
      stage.redis.hset(stage.send(:staged_group_key), "status", :pending.to_s)

      stage = group.stage(0)
      Resque::Plugins::Stages::StagedJob.create_job stage, BasicJob
      stage.redis.hset(stage.send(:staged_group_key), "status", :complete.to_s)

      group.stages
    end

    describe "initiate" do
      it "initiates the first non-completed stage" do
        allow(group).to receive(:stages).and_return stages

        stages.each_value { |stage| allow(stage).to receive(:initiate) }

        group.initiate

        expect(stages[2]).to have_received(:initiate)
        stages.each do |key, stage|
          next if key == 2

          expect(stage).not_to have_received(:initiate)
        end
      end
    end

    describe "current_stage" do
      it "returns the first non-complete stage" do
        stages

        expect(load_group.current_stage).to eq stages[2]
      end

      it "returns the first non-complete stage" do
        stage = stages[2]
        stage.redis.hset(stage.send(:staged_group_key), "status", :complete.to_s)

        expect(load_group.current_stage).to eq stages[8]
      end

      it "builds a new stage if all current stages are complete" do
        stages[2].status = :complete
        stages[8].status = :complete

        stage = load_group.current_stage
        expect(stage.number).to eq 1
      end
    end

    describe "stage_completed" do
      it "initiates the next stage when a stage is compelted" do
        allow(group).to receive(:stages).and_return stages

        stages.each_value do |stage|
          allow(stage).to receive(:initiate)
          allow(stage).to receive(:staged_group).and_return group
        end

        stages[8].status = :complete

        expect(stages[2]).to have_received(:initiate)
      end

      it "deletes the group if the last stage is completed" do
        allow(group).to receive(:stages).and_return stages
        allow(group).to receive(:delete)

        stages.each_value do |stage|
          allow(stage).to receive(:initiate)
          allow(stage).to receive(:staged_group).and_return group
        end

        stages[8].status = :complete
        stages[2].status = :complete

        expect(group).to have_received(:delete)
      end
    end

    describe "last_stage" do
      it "returns the largest stage" do
        stages

        expect(load_group.last_stage).to eq stages[8]
      end
    end

    describe "stages" do
      it "returns a hash of all stages keyed by the stage number" do
        stages

        expect(load_group.stages).to eq stages
      end
    end

    describe "paged_stages" do
      it "a page of data" do
        stages

        expect(load_group.paged_stages(1, 2)).to eq [stages[8], stages[1]]
      end

      it "a mid page of data" do
        stages

        expect(load_group.paged_stages(2, 2)).to eq [stages[2], stages[0]]
      end
    end

    describe "num_stages" do
      it "a page of data" do
        stages

        expect(load_group.num_stages).to eq 4
      end
    end

    describe "stage(value)" do
      it "returns the stage with that number if it exists" do
        stages

        stage = load_group.stage(2)
        expect(stage).to eq stages[2]
        expect(stage.number).to eq 2
      end

      it "returns a new stage with that number if it does not exist" do
        stages

        stage = load_group.stage(6)
        expect(stages).not_to be_include stage
        expect(stage.number).to eq 6

        expect(load_group.stages.length).to eq stages.length + 1
      end
    end

    describe "delete" do
      it "deletes all stages" do
        allow(group).to receive(:stages).and_return stages

        stages.each { |_key, stage| allow(stage).to receive(:delete) }

        group.delete

        stages.each_value do |stage|
          expect(stage).to have_received(:delete)
        end
      end

      it "removes a stage when it is deleted" do
        stages[2].delete

        expect(load_group.stages[2]).to be_nil
      end
    end
  end
end
