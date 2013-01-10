require "redis"
require "securerandom"

module Resque
    module Plugins
        module Promises
            class PromiseGroup
            end

            class Promise
                include Enumerable

                attr_reader :uuid, :identifier
                
                attr_accessor :redis

                def initialize
                    @redis ||= Redis.new
                    self.uuid = SecureRandom.hex
                end
                
                def uuid=(uuid)
                    @identifier = "promise-#{uuid}"
                    @uuid = uuid
                end

                def trigger(event, message = nil)
                    bundle = Marshal.dump([ event.to_sym, message ])
                    @redis.publish(@identifier, bundle)
                end

                def on(*events)
                    events = events.flatten.map(&:to_sym)
                    @redis.subscribe(@identifier) do |on|
                        on.message do |channel, bundle|
                            event, message = Marshal.load(bundle)
                            return unless events.include?(event.to_sym)
                            yield(message, event)
                        end
                    end
                end

                def once(*events)
                    on(*events) do |message, event|
                        @redis.unsubscribe(@identifier)
                        yield(message, event)
                    end
                end

                def tick
                    trigger(:tick)
                end
            end

            module ClassMethods
                def redis
                    @redis ||= Redis.new
                end

                def uuid
                end

                def tick
                end
            end
        end
    end
end

require 'thread'

lock = Mutex.new

puts "starting..."

promise = Resque::Plugins::Promises::Promise.new

thread = Thread.new do
    our_promise = Resque::Plugins::Promises::Promise.new
    our_promise.uuid = promise.uuid

    puts "waiting..."
    our_promise.once('tick') do |message|
        puts "ticked!"
        puts "message: #{message.inspect}"
    end

    our_promise.once('tick') do |message|
        puts "ticked!"
        puts "message: #{message.inspect}"
    end
end

sleep(1)
puts "ticking..."

promise.trigger(:tick, one: 1)
promise.trigger(:tick)

thread.join
