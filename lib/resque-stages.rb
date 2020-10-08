# frozen_string_literal: true

require "resque"
require File.expand_path(File.join("resque", "plugins", "stages", "redis_access"), File.dirname(__FILE__))

require File.expand_path(File.join("resque", "plugins", "stages"), File.dirname(__FILE__))
