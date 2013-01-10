require "securerandom"
require "redis"

module Resque
    module Plugins
        module Promises
            class RedisQueue
                include Timeout

                attr_reader :id, :redis, :position

                def initialize(id = nil)
                    @id = id || SecureRandom.hex
                    @position = timestamp
                    @ttl = 3600
                    @mailbox = []
                end

                def connect(redis)
                    @redis = redis
                    self
                end

                def timestamp
                    (Time.now.to_f * 1000000).to_i
                end

                def channel_key
                    "promise-#{id}-channel"
                end

                def mailbox_key
                    "promise-#{id}-mailbox"
                end
 
                def push(message)
                    envelope = Marshal.dump(message)
                    redis.multi do
                        redis.zadd(mailbox_key, timestamp, envelope)
                        redis.publish(channel_key, '')
                        interval = (@ttl * 1000).to_i
                        redis.pexpire(mailbox_key, interval)
                        redis.pexpire(channel_key, interval)
                    end
                end

                def pop(timeout = nil)
                    return(Marshal.load(@mailbox.shift)) \
                        unless @mailbox.empty?
                    wait(timeout) or return
                    new_position = timestamp
                    @mailbox.concat(redis.zrangebyscore(mailbox_key, 
                        @position, "(#{new_position}"))
                    @position = new_position
                    Marshal.load(@mailbox.shift)
                end

                def wait(interval = nil)
                    return(true) if (length > 0)
                    begin
                        timeout(interval || 60) do
                            redis.subscribe(channel_key) do |on|
                                on.message { redis.unsubscribe(channel_key) }
                            end
                        end
                        true
                    rescue Timeout::Error
                        return(true) if (length > 0)
                        retry if interval.nil?
                        false
                    end
                end

                def length
                    redis.zcount(mailbox_key, position, "(#{timestamp}")
                end

                def rewind(new_position)
                    @position = new_position
                    self
                end

                def ttl(interval)
                    @ttl = interval
                    self
                end

                def dup
                    self.class.new(@id).rewind(@position).connect(redis)
                end

                def ==(other)
                    other.instance_of?(self.class) and (other.id == @id)
                end
            end
        end
    end
end
