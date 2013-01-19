require 'resque/plugins/promises/hashlike'
require 'spec_helper'
require 'support/hashlike_mock'

describe Hashlike do
    before(:all) { HashlikeMock.send(:include, Hashlike) }

    let!(:hash) { HashlikeMock.new }

    let!(:base) { hash.base }

    let!(:original) { { 'foo' => 'hello', 'bar' => 'world' } }

    let!(:changes) { { 'bar' => 'earth', 'baz' => 'lings' } }

    before(:each) do
        hash[:foo] = 'hello'
        hash['bar'] = 'world'
    end

    it { hash.flatten.should == base.flatten }

    it { hash.to_hash.should == base }

    it { hash.size.should == base.size }

    it { hash.should_not be_empty }

    it { HashlikeMock.new.should be_empty }

    it "#each_value" do
        hash.each_value { |v| original.delete_if { |a, b| b == v} }
        original.should be_empty
    end

    it "#each_key" do
        hash.each_key { |v| original.delete(v) }
        original.should be_empty
    end

    it "#each_pair" do
        hash.each_pair { |k, v| original.delete(k).should == v }
        original.should be_empty
    end

    it { hash.values_at(*base.keys).should == base.values_at(*base.keys) }

    it "#shift" do
        key, value = hash.shift
        original[key].should == value
        hash.length.should == 1
        hash[key].should be_nil
    end

    it "#delete_if" do
        result = hash.delete_if { |k, v| k == 'foo' }
        hash.should == original.delete_if { |k, v| k == 'foo' }
        result.should == hash
    end

    it "#reject" do
        result = hash.reject { |k, v| k == 'foo' }
        result.should == original.reject { |k, v| k == 'foo' }
        hash.should == original 
    end

    it "#reject!" do
        result = hash.reject! { |k, v| k == 'foo' }
        hash.should == original.reject! { |k, v| k == 'foo' }
        result.should == hash
    end

    it "#keep_if" do
        result = hash.keep_if { |k, v| k == 'foo' }
        hash.should == original.keep_if { |k, v| k == 'foo' }
        result.should == hash
    end

    it "#select!" do
        result = hash.select! { |k, v| k == 'foo' }
        hash.should == original.select! { |k, v| k == 'foo' }
        result.should == hash
    end

    it "#select" do
        result = hash.select { |k, v| k == 'foo' }
        result.should == original.select { |k, v| k == 'foo' }
        hash.should == original 
    end

    it "#clear" do
        hash.clear
        hash.should be_empty
    end

    it { hash.invert.should == original.invert }

    it "#update" do
        hash.update(bar: 'earth', baz: 'lings')
        original.update('bar' => 'earth', 'baz' => 'lings')
        hash.should == original
    end

    it "#merge!" do
        hash.merge!(changes)
        original.merge!(changes)
        hash.should == original
    end

    it "#replace" do
        hash.replace(changes)
        hash.should == changes
    end

    it "#merge" do
        hash.merge(changes).should == original.merge(changes)
        hash.should == original
    end

    it { hash.assoc('foo').should == original.assoc('foo') }

    it { hash.assoc('nada').should == original.assoc('nada') }

    it { hash.rassoc('world').should == original.rassoc('world') }

    it { hash.rassoc('nada').should == original.rassoc('nada') }

    it { hash.flatten.should == original.flatten }

    it { hash.has_key?('foo').should == original.has_key?('foo') }

    it { hash.has_key?('nada').should == original.has_key?('nada') }

    it { hash.key?('foo').should == original.key?('foo') }

    it { hash.key?('nada').should == original.key?('nada') }

    it { hash.member?('foo').should == original.member?('foo') }

    it { hash.member?('nada').should == original.member?('nada') }

    it { hash.include?('foo').should == original.include?('foo') }

    it { hash.include?('nada').should == original.include?('nada') }

    it { hash.has_value?('world').should == original.has_value?('world') }

    it { hash.has_value?('nada').should == original.has_value?('nada') }

    it { hash.value?('world').should == original.value?('world') }

    it { hash.value?('nada').should == original.value?('nada') }

    it { hash.should == base }
end
