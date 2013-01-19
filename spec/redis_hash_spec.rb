require 'resque/plugins/promises/redis_hash'
require 'spec_helper'

describe RedisHash do
    let(:hash) { RedisHash.new('redis-hash-test') }

    it "#connect" do
        hash.connect(Redis.new).should be_a(RedisHash)
    end

    it "set and get" do
        hash['foo'] = "hello, world"
        hash['foo'].should == "hello, world"
    end

    it "set and get treats symbols as strings" do
        hash['foo'] = "hello, world"
        hash[:foo].should == hash['foo']
    end

    it "#delete" do
        hash['foo'] = "hello, world"
        hash.delete('foo').should == "hello, world"
        hash['foo'].should be_nil
    end

    it "#delete with symbol" do
        hash['foo'] = "hello, world"
        hash.delete(:foo).should == "hello, world"
        hash['foo'].should be_nil
    end

    it "#to_hash" do
        hash['foo'] = "hello"
        hash['bar'] = "world"
        ruby_hash = hash.to_hash
        ruby_hash.should be_a(Hash)
        ruby_hash.length.should == 2
        ruby_hash.keys.sort.should == %w(bar foo)
        ruby_hash.values.sort.should == %w(hello world)
    end

    it "#to_a" do
        hash['foo'] = "hello"
        hash['bar'] = "world"
        array = hash.to_a
        array.length.should == 2
        array.map(&:first).sort.should == %w(bar foo)
        array.map(&:last).sort.should == %w(hello world)
    end

    it "#length" do
        hash['foo'] = "hello"
        hash['bar'] = "world"
        hash.keys.length.should == 2
    end

    it "#keys" do
        hash['foo'] = "hello"
        hash['bar'] = "world"
        hash.keys.should include("foo")
        hash.keys.should include("bar")
    end

    it "#values" do
        hash['foo'] = "hello"
        hash['bar'] = "world"
        hash.values.should include("hello")
        hash.values.should include("world")
    end

    it "#each" do
        hash['foo'] = "hello"
        hash['bar'] = "world"
        hash.each { |k| k.should be_a(Array) }
        hash.each { |k| hash[k[0]].should == k[1] }
        hash.each { |k, v| k.should be_a(String) }
        hash.each { |k, v| hash[k].should == v }
    end
end
