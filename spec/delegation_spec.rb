require 'resque/plugins/promises/delegation'
require 'spec_helper'

describe Delegation do
    let!(:target) { double }

    let!(:klass) do
        klass = Class.new
        klass.send(:include, Delegation)
        klass.send(:define_method, :hello) { "world" }
        klass.send(:attr_accessor, :delegate)
        klass
    end

    it "#delegate fails without methods" do
        lambda { klass.delegate }.should raise_error(ArgumentError)
    end

    it "#delegate fails without a delegate" do
        lambda { klass.delegate(:action) } \
            .should raise_error(ArgumentError)
    end

    it "#delegate a method to a target" do
        klass.delegate(:action, to: :delegate)
        instance = klass.new
        target.stub(:action).and_return(:result)
        instance.delegate = target
        instance.action.should == :result
    end

    it "#delegate missing target" do
        klass.delegate(:action, to: :nope)
        instance = klass.new
        lambda { instance.action }.should raise_error(TypeError)
    end

    it "#delegate nil target" do
        klass.delegate(:action, to: :delegate)
        instance = klass.new
        lambda { instance.action }.should raise_error(TypeError)
    end

    it "#delegate allow_nil missing target" do
        klass.delegate(:action, to: :nope, allow_nil: true)
        instance = klass.new
        instance.action.should be_nil
    end

    it "#delegate allow_nil missing target" do
        klass.delegate(:action, to: :delegate, allow_nil: true)
        instance = klass.new
        instance.action.should be_nil
    end

    it "#delegate passes args" do
        klass.delegate(:action, to: :delegate)
        instance = klass.new
        block = Proc.new { true }
        target.should_receive(:action).with(:one, :two).and_yield
        instance.delegate = target
        instance.action(:one, :two, &block)
    end
end
