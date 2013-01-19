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

                def encode(value)
                    Marshal.dump(value)
                end

                def decode(value)
                    Marshal.load(value)
                end

                def []=(key, value)
                    redis.hset(@redis_key, key, encode(value))
                end

                def [](key)
                    value = redis.hget(@redis_key, key) and decode(value)
                end

                def delete(key)
                    deleted = self[key] and @redis.hdel(@redis_key, key)
                    deleted
                end

                def keys
                    @redis.hkeys(@redis_key)
                end

                def values
                    @redis.hvals(@redis_key).map { |v| decode(v) }
                end

                def length
                    @redis.hlen(@redis_key)
                end

                def to_hash
                    encoded = @redis.hgetall(@redis_key)
                    decoded = encoded.map { |k, v| [ k, decode(v) ] }
                    Hash[decoded]
                end

                def to_a
                    to_hash.to_a
                end

                def each(&block)
                    @redis.hgetall(@redis_key).each do |key, value|
                        if(block.arity < 2)
                            yield([ key, decode(value) ])
                        else
                            yield(key, decode(value))
                        end
                    end
                end
            end
        end
    end
end
