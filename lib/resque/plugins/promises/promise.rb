require "thread"
require "redis"
require "timeout"
require "resque/plugins/promises/redis_queue"

module Resque
    module Plugins
        module Promises
            class Promise
                attr_accessor :uuid, :redis, :queue

                def initialize(id = nil)
                    @queue = RedisQueue.new(id)
                    @handlers = Hash.new { |h, k| h[k] = [] }
                end

                def id
                    @queue.id
                end

                def subscriber
                    raise("publishers-only") if subscriber?
                    result = self.class.new(id)
                    result.subscribe!
                    result
                end

                def subscribe!
                    @subscriber = true
                end

                def subscriber?
                    @subscriber == true
                end

                # FIXME: Handle exceptions.
                def once(*events, &block)
                    raise("subscribers-only") unless subscriber?
                    events.map!(&:to_s)
                    events.push(:all) if events.empty?
                    events.each { |e| @handlers[e] << block }
                    true
                end

                # FIXME: Handle exceptions.
                def on(*events, &block)
                    raise("subscribers-only") unless subscriber?
                    once(*events) do
                        block.call
                        on(*events, &block)
                    end
                    true
                end

                def wait(*events)
                    raise("subscribers-only") unless subscriber?
                    options = (events.last.is_a?(Hash) ? events.pop.dup : {})
                    events.map!(&:to_s)
                    while(envelope = @queue.pop(options[:timeout]))
                        event, message = envelope
                        handlers = @handlers.delete(event.to_s) || []
                        handlers.concat(@handlers.delete(:all) || [])
                        handlers.each { |h| h.call(event.to_sym, message) }
                        break if events.include?(event.to_s)
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
            end
        end
    end
end
