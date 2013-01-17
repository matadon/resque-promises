require 'spec_helper'
require 'thread'
require 'resque/plugins/promises/promise'

# http://www.quora.com/Redis/What-are-5-mistakes-to-avoid-when-using-Redis

# class PromisedJob
#     include Resque::Plugins::Promises::Promises

#     def enqueue_with_promise(*args)
#         combined_args = [ promise_id, args ]
#         Redis.enqueue(self, *combined_args)
#     end

#     def after_dequeue_with_promise(*combined_args)
#         promise_id, args = combined_args
#     end

#     def around_perform_with_promise(*args)
#         promise_id, args = combined_args
#         yield(args)
#     end

#     def on_failure_with_promise(error, *args)
#         # FIXME: this could also explode
#         promise_id, args = combined_args
#     end
# end

# Hashlike
#     set(key, value)
#     delete(key)
#     get(key)
#     keys
#     values
#     clear

include Resque::Plugins::Promises

describe Promise do
    it "#subscriber" do
        publisher = Promise.new
        subscriber = publisher.subscriber
        publisher.__id__.should_not == subscriber.__id__
        publisher.should == subscriber
        subscriber.should be_subscriber
    end

    context "#publish" do
        let!(:publisher) { Promise.new }

        it "only publishes" do
            lambda { publisher.on(:event) }.should raise_error
            lambda { publisher.wait }.should raise_error
        end

        it "triggers without any subscribers" do
            Timeout::timeout(0.001) { publisher.trigger(:tick) }
        end

        context "#subscribe" do
            let!(:subscriber) { publisher.subscriber }

            def trigger(*args)
                sleep(0.005)
                publisher.trigger(*args)
                sleep(0.005)
            end

            def as_consumer(&block)
                @consumers << Thread.new(&block)
            end

            def check_consumers
                @consumers.each { |c| yield(c.status) }
            end

            def wait_for_consumers
                @consumers.each(&:join)
            end

            around(:each) do |example|
                @consumers = []
                example.run
                @consumers.each(&:kill)
            end

            it "#wait" do
                as_consumer { subscriber.wait }
                check_consumers { |c| c.should_not be_nil }
                trigger(:tick)
                check_consumers { |c| c.should_not be_nil }
            end

            it "#wait timeout" do
                Timeout::timeout(0.1) { subscriber.wait(timeout: 0.01) }
            end

            it "#wait on event" do
                as_consumer { subscriber.wait(:tock) }
                check_consumers { |c| c.should_not be_nil }
                trigger(:tick)
                check_consumers { |c| c.should_not be_nil }
                trigger(:tock)
                check_consumers { |c| c.should be_false }
            end

            it "#wait on multiple events" do
                as_consumer { subscriber.wait(:tick, :tock) }
                check_consumers { |c| c.should_not be_nil }
                trigger(:tock)
                check_consumers { |c| c.should be_false }
            end

            it "#once" do
                events = Queue.new
                subscriber.once { |event, message| events.push(event) }
                as_consumer { subscriber.wait }
                trigger(:tick)
                events.length.should == 1
                trigger(:tick)
                events.length.should == 1
            end

            it "#once message" do
                events = Queue.new
                subscriber.once { |event, message| events.push(message) }
                as_consumer { subscriber.wait }
                trigger(:tick, 'message')
                events.length.should == 1
                events.pop.should == 'message'
            end

            it "#once event" do
                events = Queue.new
                subscriber.once(:tock) { |event, message| events.push(event) }
                as_consumer { subscriber.wait }
                trigger(:tick)
                events.length.should == 0
                trigger(:tock)
                events.length.should == 1
            end

            it "#once multiple events" do
                events = Queue.new
                subscriber.once(:tick, :tock) { |event, message|
                    events.push(event) }
                as_consumer { subscriber.wait }
                trigger(:tock)
                events.length.should == 1
                events.pop.should == :tock
            end

            it "#on" do
                events = Queue.new
                subscriber.on { |event, message| events.push(event) }
                as_consumer { subscriber.wait }
                trigger(:tick)
                events.length.should == 1
                trigger(:tick)
                events.length.should == 2
            end

            it "#on event" do
                events = Queue.new
                subscriber.on(:tock) { |event, message| events.push(event) }
                as_consumer { subscriber.wait }
                trigger(:tick)
                events.length.should == 0
                trigger(:tock)
                events.length.should == 1
                trigger(:tock)
                events.length.should == 2
            end

            it "#on multiple events" do
                events = Queue.new
                subscriber.on(:tick, :tock) { |event, message|
                    events.push(event) }
                as_consumer { subscriber.wait }
                trigger(:tick)
                events.length.should == 1
                trigger(:tock)
                events.length.should == 2
                trigger(:tock)
                events.length.should == 3
            end

            it "multiple subscribers" do
                events = Queue.new
                5.times do
                    as_consumer do
                        consumer = publisher.subscriber
                        consumer.on(:tick) { |e, m| events << e }
                        consumer.wait(timeout: 0.5)
                    end
                end
                trigger(:tick)
                wait_for_consumers
                events.length.should == 5
            end

            it "multiple publishers" do
                events = Queue.new

                as_consumer do 
                    subscriber.on { |event, message| events << event }
                    subscriber.wait(timeout: 0.5)
                end

                5.times do |index|
                    as_consumer do
                        producer = Promise.new(publisher.id)
                        producer.trigger(:tick, index)
                    end
                end

                wait_for_consumers
                events.length.should == 5
            end

            it "explodes without an error handler" do
                subscriber.on { raise(ArgumentError, 'boom') }
                trigger(:tick)
                lambda { subscriber.wait(timeout: 0.01) } \
                    .should raise_error(ArgumentError)
            end

            it "handles errors" do
                events = Queue.new
                subscriber.on { raise(ArgumentError, 'boom') }
                subscriber.error { |error| events << error }
                trigger(:tick)
                subscriber.wait(timeout: 0.01)
                events.length.should == 1
                error = events.pop
                error.should be_a(ArgumentError)
                error.to_s.should == 'boom'
            end

            pending "supports a default timeout"
        end
    end
end
