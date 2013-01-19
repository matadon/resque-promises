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

                def initialize(id = nil, position = nil)
                    connect(Redis.new)
                    @id = id || random_key
                    @consumer_id = random_key
                    @mailbox = []
                    @ttl = 86400
                    @head = position || redis.llen(mailbox_key)
                    register_as_consumer
                end

                def position
                    @head
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

                # we need a sequence of guaranteed deliveries
                #
                # we don't want duplicate copies of all messages (it's very
                # wasteful if you've got a large number of subscribers)
                #
                # each message must be received once and only once
                #
                # list of subscribers
                #
                # central mailbox
                #
                # publish a unique message id
                #
                # we want to know how old a message was, so we can clean
                # our message queue later -- do this in a separate queue

                def push(message)
                    index = redis.rpush(mailbox_key, encode(message))
                    expire(mailbox_key)
                    expire(consumer_list_key)
                    consumers = redis.zrange(consumer_list_key, 0, -1)
                    consumers.each do |consumer_key|
                        redis.lpush(consumer_key, index)
                        expire(consumer_key)
                    end
                    consumers.count
                end

                def pop(interval = nil)
                    # process_new_messages
                    # return(@mailbox.shift) unless @mailbox.empty?
                    wait(interval)
                    process_new_messages
                    @mailbox.shift
                end

                def wait(interval = nil)
                    return unless @mailbox.empty?
                    register_as_consumer

                    begin
                        waiter = Proc.new do
                            while(true)
                                redis.brpop(consumer_key)
                                break if (length > 0)
                            end
                        end
                        interval ||= @timeout
                        interval ? timeout(interval, &waiter) : waiter.call
                    rescue Timeout::Error
                        return
                    end
                end

                def length
                    redis.llen(mailbox_key) - @head
                end

                def dup
                    self.class.new(@id).connect(redis)
                end

                def rewind(pointer)
                    @head = pointer
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

                def expire(key)
                    @ttl and redis.pexpire(key, (@ttl * 1000).to_i)
                end

                def encode(value)
                    Marshal.dump(value)
                end

                def decode(value)
                    Marshal.load(value)
                end

                def process_new_messages
                    tail = redis.llen(mailbox_key) - 1
                    return if (tail < @head)
                    messages = redis.lrange(mailbox_key, @head, tail)
                    messages.each { |m| @mailbox << decode(m) }
                    @head = tail + 1
                end

                def random_key
                    Base62.encode(SecureRandom.random_number(2 ** 128))
                end

                def register_as_consumer
                    redis.zadd(consumer_list_key, Time.now.to_f, consumer_key)
                end
            end
        end
    end
end
