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
        include Comparable

        attr_reader :group_id

        def initialize(group_id, description: "")
          @group_id = group_id

          Resque::Plugins::Stages::StagedGroupList.new.add_group(self)

          redis.hsetnx(group_info_key, "created_at", Time.now)
          self.description = description if description.present?
        end

        def <=>(other)
          return nil unless other.is_a?(Resque::Plugins::Stages::StagedGroup)

          group_id <=> other.group_id
        end

        class << self
          def within_a_grouping(description = nil)
            group = Resque::Plugins::Stages::StagedGroup.new(SecureRandom.uuid, description: description)

            yield group

            group.initiate
          end
        end

        def initiate
          stage = next_stage

          if stage
            stage.initiate
          else
            delete
          end
        end

        def description
          @description ||= redis.hget(group_info_key, "description").presence || group_id
        end

        def created_at
          @created_at ||= redis.hget(group_info_key, "created_at").presence.to_time || Time.now
        end

        def description=(value)
          @description = value.presence
          redis.hset(group_info_key, "description", description)
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

        def num_stages
          redis.llen group_key
        end

        def stages
          all_stages = redis.lrange(group_key, 0, -1).map { |stage_id| Resque::Plugins::Stages::StagedGroupStage.new(stage_id) }

          all_stages.each_with_object({}) do |stage, hash|
            num = stage.number
            num += 1 while hash.key?(num)

            hash[num]    = stage
            stage.number = num if stage.number != num
          end
        end

        def paged_stages(page_num = 1, page_size = nil)
          page_size ||= 20
          page_size = page_size.to_i
          page_size = 20 if page_size < 1
          start     = (page_num - 1) * page_size
          start     = 0 if start >= num_stages || start.negative?

          stages.values[start..start + page_size - 1]
        end

        def stage(stage_number)
          found_stage = stages[stage_number]

          found_stage || create_stage(stage_number)
        end

        def delete
          stages.each_value(&:delete)

          Resque::Plugins::Stages::StagedGroupList.new.remove_group(self)

          redis.del group_key
          redis.del group_info_key
        end

        def stage_completed
          initiate
        end

        def blank?
          !redis.exists(group_key) && !redis.exists(group_info_key)
        end

        def verify_stage(stage)
          ids = redis.lrange(group_key, 0, -1)

          return if ids.include?(stage.group_stage_id)

          redis.lpush(group_key, stage.group_stage_id)
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

        def group_info_key
          "#{group_key}::Info"
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
