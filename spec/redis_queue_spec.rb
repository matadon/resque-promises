require 'spec_helper'
require 'resque/plugins/promises/redis_queue'
require 'shared/message_queue'

describe Resque::Plugins::Promises::RedisQueue do
    let(:redis) { Redis.new }

    let(:queue) { Resque::Plugins::Promises::RedisQueue.new.connect(redis) }

    it_should_behave_like 'a message queue'
end
