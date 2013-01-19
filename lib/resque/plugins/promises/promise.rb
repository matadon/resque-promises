require "thread"
require "redis"
require "timeout"
require "resque/plugins/promises/redis_queue"
require "resque/plugins/promises/redis_hash"
require "resque/plugins/promises/delegation"

module Resque
    module Plugins
        module Promises
            class Promise
                include Delegation

                attr_accessor :uuid, :redis, :queue, :timeout

                attr_reader :locals

                delegate '[]', '[]=', to: :locals

                def initialize(id = nil, position = nil)
                    @queue = RedisQueue.new(id, position)
                    @redis = @queue.redis
                    @handlers = Hash.new { |h, k| h[k] = [] }
                    @locals = RedisHash.new(locals_key).connect(redis)
                end

                def connect(redis)
                    @queue.connect(redis)
                    self
                end

                def locals_key
                    "promise:#{id}:locals"
                end

                def id
                    @queue.id
                end

                def dup
                    self.class.new(@queue.id, @queue.position)
                end

                def subscriber
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
                    events.map!(&:to_s)
                    events.push(:all) if events.empty?
                    events.each { |e| @handlers[e] << block }
                    self
                end

                def on(*events, &block)
                    once(*events) do |event, message|
                        reregister_events = events.empty? ? [] : [ event ]
                        on(*reregister_events, &block)
                        if(block.arity < 2)
                            block.call(message)
                        else
                            block.call(event, message)
                        end
                    end
                    self
                end

                def error(&block)
                    @handlers[:error] << block
                    self
                end

                def wait(*events)
                    options = (events.last.is_a?(Hash) ? events.pop.dup : {})
                    events.map!(&:to_s)
                    interval = @timeout
                    interval = options[:timeout] if options.has_key?(:timeout)
                    while(envelope = @queue.pop(interval))
                        begin
                            event, message = envelope
                            handlers = @handlers.delete(event.to_s) || []
                            handlers.concat(@handlers.delete(:all) || [])
                            handlers.each do |handler|
                                if (handler.arity < 2)
                                    handler.call(message)
                                else
                                    handler.call(event.to_sym, message)
                                end
                            end
                            break if events.include?(event.to_s)
                        rescue => error
                            handlers = @handlers[:error]
                            raise if handlers.empty?
                            handlers.each { |h| h.call(error) }
                        end
                    end
                end

                def trigger(event, message = nil)
                    envelope = [ event.to_sym, message ]
                    @queue.push(envelope)
                    true
                end

                def status=(state)
                    locals[:_promised_job_status] = state
                end

                def status
                    locals[:_promised_job_status]
                end

                def ==(other)
                    other.instance_of?(self.class) and (other.uuid == @uuid)
                end
            end
        end
    end
end
