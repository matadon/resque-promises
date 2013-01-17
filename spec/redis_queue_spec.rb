require 'thread'
require 'spec_helper'
require 'resque/plugins/promises/redis_queue'

include Resque::Plugins::Promises

describe RedisQueue do
    let(:queue) { RedisQueue.new }

    before(:each) { queue.timeout = 0.01 }

    it "#dup" do
        copy = queue.dup
        queue.__id__.should_not == copy.__id__
        queue.should == copy
    end

    it "#pop without timeout" do
        queue.timeout = nil
        lambda { timeout(0.1) { queue.pop } } \
            .should raise_error(Timeout::Error)
    end

    it "#pop with timeout" do
        queue.timeout = nil
        time = Benchmark.measure { timeout(0.1) { queue.pop(0.01) } }
        time.real.should >= 0.01
    end

    it "#pop default timeout" do
        queue.timeout = 0.01
        time = Benchmark.measure { timeout(0.1) { queue.pop } }
        time.real.should >= 0.01
    end

    it "pushes and pops" do
        queue.push(:tick)
        queue.pop.should == :tick
    end

    it "pushes to multiple subscribers" do
        subscribers = 5.times.map { RedisQueue.new(queue.id) }
        queue.push(:tick)
        results = subscribers.map { |s| s.pop(0.01) }
        results.compact.count.should == 5
    end

    it "reads from multiple publishers" do
        5.times { RedisQueue.new(queue.id).push('message') }
        results = 5.times.map { |s| queue.pop(0.01) }
        results.compact.count.should == 5
    end

    it "serializes objects" do
        queue.push(hello: 'world')
        message = queue.pop
        message.should be_a(Hash)
        message.should have_key(:hello)
    end

    it "pushes messages in order" do
        10.times { |index| queue.push(index) }
        10.times { |index| queue.pop.should == index }
    end

    it "interleaves messages" do
        10.times do |index|
            queue.push(index) 
            queue.pop.should == index
        end
    end

    it "pops new messages only" do
        10.times { |index| queue.push(index) }
        other = queue.dup
        10.times { |index| queue.push(index * 10) }
        10.times { |index| other.pop.should == index * 10 }
    end

    it "cleans up" do
        queue.ttl(0.001).push(:tick)
        sleep(0.002)
        queue.pop(0.01).should be_nil
    end

    context "multithreaded" do
        it "pushes to multiple subscribers" do
            results = Queue.new
            subscribers = 5.times.map do |message|
                Thread.new do
                    consumer = RedisQueue.new(queue.id)
                    consumer.timeout = 0.01
                    sleep
                    message = consumer.pop and results.push(message)
                end
            end

            sleep(0.01)
            queue.push(:tick)
            subscribers.each(&:wakeup).each(&:join)
            results.length.should == 5
        end

        it "reads from multiple publishers" do
            publishers = 5.times.map do
                Thread.new do
                    producer = RedisQueue.new(queue.id)
                    producer.timeout = 0.01
                    producer.push('message')
                end
            end

            publishers.each(&:join)
            results = 5.times.map { |s| queue.pop }
            results.compact.count.should == 5
        end
    end

end
