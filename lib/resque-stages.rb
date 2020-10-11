# frozen_string_literal: true

require "resque"
require File.expand_path(File.join("resque", "plugins", "stages", "redis_access"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "stages", "staged_group_list"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "stages", "staged_group"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "stages", "staged_group_stage"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "stages", "staged_job"), File.dirname(__FILE__))
require File.expand_path(File.join("resque", "plugins", "stages", "cleaner"), File.dirname(__FILE__))

require File.expand_path(File.join("resque", "plugins", "stages"), File.dirname(__FILE__))
