require 'spec_helper'
require 'benchmark'
require 'resque/plugins/promises/redis_queue'

describe Resque::Plugins::Promises::RedisQueue do
    let(:redis) { Redis.new }

    let(:queue) { Resque::Plugins::Promises::RedisQueue.new.connect(redis) }

    it "#dup" do
        original = Resque::Plugins::Promises::RedisQueue.new
        copy = original.dup
        original.__id__.should_not == copy.__id__
        original.should == copy
    end

    it "#pop with timeout" do
        time = Benchmark.measure { Timeout::timeout(0.1) {
            queue.pop(0.01) } }
        time.total.should >= 0.01
    end

    it "#pop without timeout" do
        lambda { Timeout::timeout(0.1) { queue.pop } } \
            .should raise_error(Timeout::Error)
    end

    it "pushes and pops" do
        queue.push(:tick)
        queue.pop.should == :tick
    end

    it "pushes to multiple subscribers" do
        other = queue.dup
        queue.push(:tick)
        queue.pop.should == :tick
        other.pop.should == :tick
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
        other = queue.dup.rewind(queue.timestamp)
        10.times { |index| queue.push(index * 10) }
        10.times { |index| other.pop.should == index * 10 }
    end

    it "#length" do
        10.times { |index| queue.push(index) }
        queue.length.should == 10
    end

    it "cleans up" do
        queue.ttl(0.001).push(:tick)
        sleep(0.002)
        queue.length.should == 0
    end
end
