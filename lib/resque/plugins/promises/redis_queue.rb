require "securerandom"
require "redis"
require "timeout"
require 'resque/plugins/promises/base62'

module Resque
    module Plugins
        module Promises
            class RedisQueue
                include Timeout

                attr_reader :id, :redis, :position

                def self.connect(redis)
                    @redis = redis
                end

                def self.redis
                    @redis
                end

                def initialize(id = nil, position = nil)
                    connect(self.class.redis)
                    @id = id || random_key
                    @consumer_id = random_key
                    @mailbox = []
                    @ttl = 3600
                    @position = position || timestamp
                    register_as_consumer
                end

                def connect(redis)
                    redis ||= Redis.new
                    keys = %w(scheme host port path timeout password db)
                    options = keys.map { |k|
                        v = redis.client.send(k) and [ k.to_sym, v] }
                    @redis = Redis.new(Hash[options.compact])
                    self
                end

                def consumer_list_key
                    "promise:#{id}:consumers"
                end

                def consumer_key
                    "promise:#{id}:#{@consumer_id}"
                end

                def mailbox_key
                    "promise:#{id}"
                end

                def timestamp
                    time = redis.time
                    time[0] + (time[1] / 1000000.0)
                end

                def push(message)
                    now_at = timestamp
                    redis.zremrangebyscore(consumer_list_key, 0, now_at - @ttl)
                    redis.zremrangebyscore(mailbox_key, 0, now_at - @ttl)
                    consumers = redis.zrange(consumer_list_key, 0, -1)
                    redis.multi do
                        envelope = Marshal.dump([ now_at, message ])
                        redis.zadd(mailbox_key, now_at, envelope)
                        redis.pexpire(mailbox_key, (@ttl * 1000).to_i)
                        consumers.each do |consumer_key|
                            redis.lpush(consumer_key, now_at)
                            redis.pexpire(consumer_key, (@ttl * 1000).to_i)
                        end
                    end
                    consumers.count
                end

                def pop(interval = nil)
                    process_new_messages
                    return(@mailbox.shift) unless @mailbox.empty?
                    wait(interval)
                    process_new_messages
                    @mailbox.shift
                end

                def wait(interval = nil)
                    begin
                        register_as_consumer
                        waiter = Proc.new { redis.brpop(consumer_key) }
                        interval ||= @timeout
                        interval ? timeout(interval, &waiter) : waiter.call
                    rescue Timeout::Error
                        return
                    end
                end

                def length
                    redis.zcount(mailbox_key, @position, "(#{timestamp}")
                end

                def dup
                    self.class.new(@id).connect(redis)
                end

                def rewind(pointer)
                    @position = pointer
                    self
                end

                def ttl(interval)
                    @ttl = interval
                    self
                end

                def timeout=(interval)
                    @timeout = interval
                end

                def ==(other)
                    other.instance_of?(self.class) and (other.id == @id)
                end

                private

                def process_new_messages
                    now_at = timestamp
                    messages = redis.zrangebyscore(mailbox_key,
                        @position, "(#{now_at}")
                    @position = now_at
                    messages.each { |m| @mailbox << Marshal.load(m).last }
                end

                def random_key
                    Base62.encode(SecureRandom.random_number(2 ** 128))
                end

                def register_as_consumer
                    now = timestamp
                    redis.zadd(consumer_list_key, now, consumer_key)
                end
            end
        end
    end
end
