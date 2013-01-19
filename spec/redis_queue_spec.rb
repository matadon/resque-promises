require 'resque/plugins/promises/redis_queue'
require 'spec_helper'

describe RedisQueue do
    let(:queue) { RedisQueue.new }

    before(:each) { queue.timeout = 0.01 }

    it "#new with id" do
        other = RedisQueue.new(queue.id)
        queue.push('hello')
        other.length.should == 1
        other.pop.should == 'hello'
    end

    it "#new with id and position" do
        start = queue.position
        queue.push('hello')
        queue.pop
        other = RedisQueue.new(queue.id, start)
        queue.length.should == 0
        other.length.should == 1
    end

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

    it "#length" do
        queue.length.should == 0
        queue.push('hello')
        queue.length.should == 1
    end

    it "#rewind" do
        start = queue.position
        queue.push('hello')
        queue.pop.should == 'hello'
        queue.rewind(start)
        queue.pop.should == 'hello'
    end

    it "pops new messages only" do
        10.times { |index| queue.push(index) }
        other = queue.dup
        10.times { |index| queue.push(index * 10) }
        10.times { |index| other.pop.should == index * 10 }
    end

    it "cleans up" do
        queue.redis.flushall
        queue.ttl(0.001).push(:tick)
        queue.redis.keys('*').should_not be_empty
        sleep(0.002)
        queue.redis.keys('*').should be_empty
    end

    context "multithreaded" do
        it "pushes to multiple subscribers" do
            results = Queue.new

            subscribers = 20.times.map do |message|
                consumer = RedisQueue.new(queue.id)
                consumer.timeout = 0.1
                Thread.new { m = consumer.pop and results.push(m) }
            end

            queue.push(:tick)
            subscribers.each(&:join)
            results.length.should == 20
        end

        it "reads from multiple publishers" do
            publishers = 20.times.map do
                Thread.new do
                    RedisQueue.new(queue.id).push('message')
                end
            end

            publishers.each(&:join)
            queue.length.should == 20
        end
    end

end
