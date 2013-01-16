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

describe Resque::Plugins::Promises::Promise do
    it "#subscriber" do
        publisher = Resque::Plugins::Promises::Promise.new
        subscriber = publisher.subscriber
        publisher.__id__.should_not == subscriber.__id__
        publisher.should == subscriber
        subscriber.should be_subscriber
    end

    context "#publish" do
        let!(:publisher) { Resque::Plugins::Promises::Promise.new }

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
                publisher.trigger(*args)
                sleep(0.01)
            end

            def as_consumer(&block)
                @consumers << Thread.new(&block)
            end

            def check_consumers
                @consumers.each { |c| yield(c.status) }
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

            it "#once" do
                events = Queue.new
                subscriber.once { |event, message| events.push(event) }
                as_consumer { subscriber.wait }
                trigger(:tick)
                events.length.should == 1
                trigger(:tick)
                events.length.should == 1
            end

            it "#once gets a message" do
                events = Queue.new
                subscriber.once { |event, message| events.push(message) }
                as_consumer { subscriber.wait }
                trigger(:tick, 'message')
                events.length.should == 1
                events.pop.should == 'message'
            end

            it "#once specific event" do
                events = Queue.new
                subscriber.once(:tock) { |event, message| events.push(event) }
                as_consumer { subscriber.wait }
                trigger(:tick)
                events.length.should == 0
                trigger(:tock)
                events.length.should == 1
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

            it "#on a specific event" do
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
        end
    end
end
