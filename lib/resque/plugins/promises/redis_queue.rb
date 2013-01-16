require "securerandom"
require "redis"
require "timeout"
require 'resque/plugins/promises/base62'

module Resque
    module Plugins
        module Promises
            class RedisQueue
                include Timeout

                attr_reader :id, :redis

                def self.connect(redis)
                    @redis = redis
                end

                def self.redis
                    @redis
                end

                def initialize(id = nil)
                    @id = id || random_key
                    connect(self.class.redis)
                    @mailbox_id = random_key
                    @mailbox = []
                    @ttl = 60
                    redis.multi { register }
                end

                def connect(redis)
                    redis ||= Redis.new
                    keys = %w(scheme host port path timeout password db)
                    options = keys.map { |k|
                        v = redis.client.send(k) and [ k.to_sym, v] }
                    @redis = Redis.new(Hash[options.compact])
                    self
                end

                def subscriber_list_key
                    "promise:#{id}"
                end

                def mailbox_key
                    "promise:#{id}:#{@mailbox_id}"
                end

                def push(message)
                    subscribers = redis.zrange(subscriber_list_key, 0, -1)
                    redis.multi do
                        redis.zremrangebyscore(subscriber_list_key, 0,
                            (Time.now.to_f - @ttl))
                        subscribers.each do |subscriber_key|
                            redis.lpush(subscriber_key, Marshal.dump(message))
                            redis.pexpire(subscriber_key, (@ttl * 1000).to_i)
                        end
                        redis.pexpire(mailbox_key, (@ttl * 1000).to_i)
                    end
                    subscribers.count
                end

                def pop(interval = nil)
                    wait(interval)
                    result = @mailbox.shift and Marshal.load(result)
                end

                def wait(interval = nil)
                    begin
                        register
                        reader = Proc.new {
                            @mailbox << redis.brpop(mailbox_key).last }
                        interval ? timeout(interval, &reader) : reader.call
                    rescue Timeout::Error
                        return
                    end
                end

                def dup
                    self.class.new(@id).connect(redis)
                end

                def ttl(interval)
                    @ttl = interval
                    self
                end

                def ==(other)
                    other.instance_of?(self.class) and (other.id == @id)
                end

                private

                def random_key
                    Base62.encode(SecureRandom.random_number(2 ** 128))
                end

                def register
                    redis.zadd(subscriber_list_key, Time.now.to_f, mailbox_key)
                end
            end
        end
    end
end
