# frozen_string_literal: true

module Resque
  module Plugins
    module Stages
      # A utility class that keeps track of all Groups and lists them.
      class StagedGroupList
        include Resque::Plugins::Stages::RedisAccess

        def groups
          redis.smembers(list_key).map { |group_id| Resque::Plugins::Stages::StagedGroup.new(group_id) }
        end

        def order_param(sort_option, current_sort, current_order)
          current_order ||= "asc"

          if sort_option == current_sort
            current_order == "asc" ? "desc" : "asc"
          else
            "asc"
          end
        end

        def paginated_groups(sort_key = :description,
                             sort_order = "asc",
                             page_num = 1,
                             queue_page_size = 20)
          queue_page_size = queue_page_size.to_i
          queue_page_size = 20 if queue_page_size < 1

          group_list = sorted_groups(sort_key)

          page_start = (page_num - 1) * queue_page_size
          page_start = 0 if page_start > group_list.length || page_start.negative?

          (sort_order == "desc" ? group_list.reverse : group_list)[page_start..(page_start + queue_page_size - 1)]
        end

        def num_groups
          groups.length
        end

        def add_group(group)
          redis.sadd list_key, group.group_id
        end

        def remove_group(group)
          redis.srem list_key, group.group_id
        end

        def delete_all
          groups.each(&:delete)
        end

        private

        def sorted_groups(sort_key)
          groups.sort_by do |group|
            group_sort_value(group, sort_key)
          end
        end

        def group_sort_value(group, sort_key)
          case sort_key.to_sym
            when :description,
                :num_stages
              group.public_send(sort_key)
            when :created_at
              group.public_send(sort_key).to_s
          end
        end

        def list_key
          "StagedGroupList"
        end
      end
    end
  end
end
