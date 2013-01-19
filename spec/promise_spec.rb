require 'resque/plugins/promises/promise'
require 'spec_helper'

describe Promise do
    it "#subscriber" do
        publisher = Promise.new
        subscriber = publisher.subscriber
        publisher.__id__.should_not == subscriber.__id__
        publisher.should == subscriber
        subscriber.should be_subscriber
    end

    it "#connect" do
        Promise.new.connect(Redis.new).should be_a(Promise)
    end

    it "#locals" do
        promise = Promise.new
        promise.locals.is_a?(RedisHash)
        promise[:key] = 'value'
        promise[:key].should == 'value'
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
                20.times do
                    consumer = publisher.subscriber
                    as_consumer do
                        consumer.on(:tick) { |e, m| events << e }
                        consumer.wait(timeout: 0.2)
                    end
                end
                trigger(:tick)
                wait_for_consumers
                events.length.should == 20
            end

            it "multiple publishers" do
                events = Queue.new
                20.times { |index| as_consumer {
                    Promise.new(publisher.id).trigger(:tick, index) } }
                subscriber.on { |event, message| events << event }
                subscriber.wait(timeout: 0.1)
                wait_for_consumers
                events.length.should == 20
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

            it "supports a default timeout" do
                subscriber.timeout = 0.05
                Timeout::timeout(0.1) { subscriber.wait }
            end

            it "sets a local from the publisher" do
                publisher[:key] = 'value'
                subscriber[:key].should == 'value'
            end

            it "sets a local from the subscriber" do
                subscriber[:key] = 'value'
                publisher[:key].should == 'value'
            end
        end
    end
end
