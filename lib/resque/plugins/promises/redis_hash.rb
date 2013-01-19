require 'redis'

module Resque
    module Plugins
        module Promises
            class RedisHash
                attr_reader :redis

                def initialize(redis_key)
                    @redis_key = redis_key
                    @redis = Redis.new
                end

                def connect(redis)
                    @redis = redis
                    self
                end

                def ttl(interval)
                    @ttl = interval
                end

                def []=(key, value)
                    redis.hset(@redis_key, key, encode(value))
                    expire(@redis_key)
                    value
                end

                def [](key)
                    expire(@redis_key)
                    value = redis.hget(@redis_key, key) and decode(value)
                end

                def delete(key)
                    deleted = self[key] and @redis.hdel(@redis_key, key)
                    expire(@redis_key)
                    deleted
                end

                def keys
                    expire(@redis_key)
                    @redis.hkeys(@redis_key)
                end

                def values
                    expire(@redis_key)
                    @redis.hvals(@redis_key).map { |v| decode(v) }
                end

                def length
                    expire(@redis_key)
                    @redis.hlen(@redis_key)
                end

                def to_hash
                    expire(@redis_key)
                    encoded = @redis.hgetall(@redis_key)
                    decoded = encoded.map { |k, v| [ k, decode(v) ] }
                    Hash[decoded]
                end

                def to_a
                    to_hash.to_a
                end

                def each(&block)
                    expire(@redis_key)
                    @redis.hgetall(@redis_key).each do |key, value|
                        if(block.arity < 2)
                            yield([ key, decode(value) ])
                        else
                            yield(key, decode(value))
                        end
                    end
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
            end
        end
    end
end
