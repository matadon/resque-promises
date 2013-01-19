require 'resque'
require 'resque/plugins/promises'
require 'spec_helper'

describe Resque::Plugins::Promises do
    class PromisedJob
        @queue = :promised_jobs

        extend Resque::Plugins::Promises

        def self.callback(&block)
            @callback = block_given? ? block : nil
        end

        def self.perform
            @callback and @callback.call
            promise.trigger(:tick)
        end
    end

    before(:all) do
        Resque.redis.namespace = "resque-promises-testing"
        Resque.redis.keys('*').each { |k| Resque.redis.del(k) }
    end

    before(:each) { PromisedJob.callback }

    it ".enqueue" do
        promise = PromisedJob.enqueue
        promise.should be_a(Promise)
        payload = Resque.pop(:promised_jobs)
        payload['class'].should == 'PromisedJob'
        payload['args'].should == [ 'promise', promise.id, [] ]
    end
    
    it ".enqueue with args" do
        PromisedJob.enqueue(1, 2, 3)
        payload = Resque.pop(:promised_jobs)
        payload['args'][2].should == [ 1, 2, 3 ]
    end
    
    it ".enqueue_to" do
        promise = PromisedJob.enqueue_to(:invaders)
        payload = Resque.pop(:invaders)
        payload['args'][1].should == promise.id
        payload['args'][2].should == []
    end
    
    it ".enqueue_to with args" do
        promise = PromisedJob.enqueue_to(:invaders, 1, 2, 3)
        payload = Resque.pop(:invaders)
        payload['args'][1].should == promise.id
        payload['args'][2].should == [ 1, 2, 3 ]
    end
   
    context "worker" do
        let!(:worker) { Resque::Worker.new(:promised_jobs) }

        before(:each) { Resque.remove_queue(:promised_jobs) }

        after(:each) { worker.shutdown }

        it "enqueue" do
            triggered = false
            promise = PromisedJob.enqueue
            promise.on(:enqueue) { triggered = true }
            promise.wait(:enqueue, timeout: 0.1)
            triggered.should be_true
        end

        it "perform" do
            triggered = false
            promise = PromisedJob.enqueue
            promise.on(:perform) { triggered = true  }
            promise.wait(:perform, timeout: 0.1)
            triggered.should be_false
            job = worker.reserve
            worker.perform(job)
            promise.wait(:perform, timeout: 1)
            triggered.should be_true
        end

        it "success" do
            triggered = false
            promise = PromisedJob.enqueue
            promise.on(:success) { triggered = true }
            promise.on(:error) { |error| raise(error) }
            job = worker.reserve
            worker.perform(job)
            promise.wait(:success, timeout: 1)
            triggered.should be_true
        end

        it "error" do
            triggered = false
            PromisedJob.callback { raise(ArgumentError) }
            promise = PromisedJob.enqueue
            promise.on(:success) { raise(RuntimeError) }
            promise.on(:error) { triggered = true }
            job = worker.reserve
            worker.perform(job)
            promise.wait(:error, timeout: 1)
            triggered.should be_true
        end

        it "error receives exception" do
            PromisedJob.callback { raise(ArgumentError) }
            promise = PromisedJob.enqueue
            promise.on(:error) do |message|
                message.first.should be_a(ArgumentError)
                message.last.should be_a(Array)
            end
            job = worker.reserve
            worker.perform(job)
            promise.wait(:error, timeout: 1)
        end

        it "finished if success" do
            triggered = false
            promise = PromisedJob.enqueue
            promise.on(:finished) { triggered = true }
            worker.perform(worker.reserve)
            promise.wait(:finished, timeout: 1)
            triggered.should be_true
        end

        it "finished if error" do
            triggered = false
            PromisedJob.callback { raise(ArgumentError) }
            promise = PromisedJob.enqueue
            promise.on(:finished) { triggered = true }
            worker.perform(worker.reserve)
            promise.wait(:finished, timeout: 1)
            triggered.should be_true
        end

        it "exposes the promise to the job" do
            triggered = false
            promise = PromisedJob.enqueue
            promise.on(:tick) { triggered = true }
            promise.on(:error) { |error| puts error.inspect }
            job = worker.reserve
            worker.perform(job)
            promise.wait(:finished, timeout: 1)
            triggered.should be_true
        end

        it "status" do
            waiter = Promise.new
            PromisedJob.callback { waiter.wait(:tock, timeout: 1) }
            promise = PromisedJob.enqueue
            promise.on(:error) { |e, v| puts v }
            promise.status.should == 'queued'
            job = worker.reserve
            worker.perform(job)
            promise.wait(:perform, timeout: 1)
            # promise.status.should == 'started'
            waiter.trigger(:tock)
            promise.wait(:finished, timeout: 1)
            # promise.status.should == 'finished'
        end

    end
end
