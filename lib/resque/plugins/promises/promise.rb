require "thread"
require "redis"
require "timeout"
require "resque/plugins/promises/redis_queue"

module Resque
    module Plugins
        module Promises
            class Promise
                attr_accessor :uuid, :redis, :queue, :timeout

                def initialize(id = nil, position = nil)
                    @queue = RedisQueue.new(id, position)
                    @redis = @queue.redis
                    @handlers = Hash.new { |h, k| h[k] = [] }
                end

                def connect(redis)
                    @queue.connect(redis)
                    self
                end

                def id
                    @queue.id
                end

                def dup
                    self.class.new(@queue.id, @queue.position)
                end

                def subscriber
                    raise("publishers-only") if subscriber?
                    dup.subscribe!
                end

                def subscribe!
                    @subscriber = true
                    self
                end

                def subscriber?
                    @subscriber == true
                end

                def once(*events, &block)
                    raise("subscribers-only") unless subscriber?
                    events.map!(&:to_s)
                    events.push(:all) if events.empty?
                    events.each { |e| @handlers[e] << block }
                    self
                end

                def on(*events, &block)
                    raise("subscribers-only") unless subscriber?
                    once(*events) do |event, message|
                        reregister_events = events.empty? ? [] : [ event ]
                        on(*reregister_events, &block)
                        block.call(event, message)
                    end
                    self
                end

                def error(&block)
                    raise("subscribers-only") unless subscriber?
                    @handlers[:error] << block
                    self
                end

                def wait(*events)
                    raise("subscribers-only") unless subscriber?
                    options = (events.last.is_a?(Hash) ? events.pop.dup : {})
                    events.map!(&:to_s)
                    interval = @timeout
                    interval = options[:timeout] if options.has_key?(:timeout)
                    while(envelope = @queue.pop(interval))
                        begin
                            event, message = envelope
                            handlers = @handlers.delete(event.to_s) || []
                            handlers.concat(@handlers.delete(:all) || [])
                            handlers.each { |h| h.call(event.to_sym, message) }
                            break if events.include?(event.to_s)
                        rescue => error
                            handlers = @handlers[:error]
                            raise if handlers.empty?
                            handlers.each { |h| h.call(error) }
                        end
                    end
                end

                def trigger(event, message = nil)
                    raise("publishers-only") if subscriber?
                    envelope = [ event.to_sym, message ]
                    @queue.push(envelope)
                    true
                end

                def ==(other)
                    other.instance_of?(self.class) and (other.uuid == @uuid)
                end

                # def []=(key, value)
                # end

                # def [](key)
                # end

                # def delete(key)
                # end

                # def keys
                # end

                # def values
                # end

                # def length
                # end

                # def to_a
                # end

                # def each(&block)
                #     if(block.arity < 2)
                #         yield
                #     else
                #         yield
                #     end
                # end
            end
        end
    end
end
