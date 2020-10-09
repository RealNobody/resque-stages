# frozen_string_literal: true

module Resque
  module Plugins
    module Stages
      # This class represents the toplevel grouping of a set of staged jobs.
      #
      # The group defines individual numbered stages (starting with 0) and
      # intiates subsequent stages as the current stage completes.
      #
      # There are methods on the group to initiate groups and add jobs to
      # individual stages or get/create new stages
      class StagedGroup
        include Resque::Plugins::Stages::RedisAccess

        attr_reader :group_id

        def initialize(group_id, description: "")
          @group_id = group_id

          self.description = description
        end

        class << self
          def within_a_grouping(description = nil)
            group = Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid, description: description)

            yield group

            group.initiate
          end
        end

        def initiate
          next_stage&.initiate
        end

        def description
          @description ||= redis.hget(staged_group_key, "description").presence || group_id
        end

        def description=(value)
          @description = value.presence
          redis.hset(staged_group_key, "description", description)
        end

        def current_stage
          next_stage || new_stage
        end

        def last_stage
          group_stages = stages
          last_key     = group_stages.keys.max

          group_stages[last_key]
        end

        def add_stage(staged_group_stage)
          redis.rpush group_key, staged_group_stage.group_stage_id
        end

        def remove_stage(staged_group_stage)
          redis.lrem(group_key, 0, staged_group_stage.group_stage_id)
        end

        def stages
          all_stages = redis.lrange(group_key, 0, -1).map { |stage_id| Resque::Plugins::Stages::StagedGroupStage.new(stage_id) }

          all_stages.each_with_object({}) do |stage, hash|
            num = stage.number
            num += 1 while hash.key?(num)

            stage.number = num if stage.number != num
            hash[num]    = stage
          end
        end

        def stage(stage_number)
          found_stage = stages[stage_number]

          found_stage || create_stage(stage_number)
        end

        def delete
          stages.each_value(&:delete)

          redis.del group_key
          redis.del staged_group_key
        end

        def stage_completed
          stage = next_stage

          if stage
            stage.initiate
          else
            delete
          end
        end

        private

        def next_stage
          group_stages = stages
          keys         = group_stages.keys.sort

          current_number = keys.detect do |key|
            group_stages[key].status != :complete
          end

          group_stages[current_number]
        end

        def group_key
          "StagedGroup::#{group_id}"
        end

        def staged_group_key
          "#{group_key}::StagedGroup"
        end

        def new_stage
          next_stage_number = (last_stage&.number || 0) + 1

          create_stage(next_stage_number)
        end

        def create_stage(stage_number)
          stage = Resque::Plugins::Stages::StagedGroupStage.new(SecureRandom.uuid)

          stage.staged_group = self
          stage.number       = stage_number

          stage
        end
      end
    end
  end
end
