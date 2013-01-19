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
            sleep(0.001)
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
        def run_resque_worker
            @thread = Thread.new { worker.perform(worker.reserve) }
        end

        let!(:worker) { Resque::Worker.new(:promised_jobs) }

        let(:promise) { PromisedJob.enqueue }

        before(:each) do
            @triggered = false
            Resque.remove_queue(:promised_jobs)
        end

        after(:each) do
            @thread and @thread.join
            worker.shutdown
        end

        it "enqueue" do
            promise.on(:enqueue) { @triggered = true }
            promise.wait(:enqueue, timeout: 0.1)
            @triggered.should be_true
        end

        it "perform" do
            promise.on(:perform) { @triggered = true  }
            promise.wait(:perform, timeout: 0.1)
            @triggered.should be_false
            run_resque_worker
            promise.wait(:perform, timeout: 1)
            @triggered.should be_true
        end

        it "success" do
            promise.on(:success) { @triggered = true }
            promise.on(:error) { |error| raise(error) }
            run_resque_worker
            promise.wait(:success, timeout: 1)
            @triggered.should be_true
        end

        it "error" do
            PromisedJob.callback { raise(ArgumentError) }
            promise.on(:success) { raise(RuntimeError) }
            promise.on(:error) do |message|
                message.first.should be_a(ArgumentError)
                message.last.should be_a(Array)
                @triggered = true
            end
            run_resque_worker
            promise.wait(:error, timeout: 1)
            @triggered.should be_true
        end

        it "finished if success" do
            promise.on(:finished) { @triggered = true }
            run_resque_worker
            promise.wait(:finished, timeout: 1)
            @triggered.should be_true
        end

        it "finished if error" do
            PromisedJob.callback { raise(ArgumentError) }
            promise.on(:finished) { @triggered = true }
            run_resque_worker
            promise.wait(:finished, timeout: 1)
            @triggered.should be_true
        end

        it "exposes the promise to the job" do
            promise.on(:tick) { @triggered = true }
            promise.on(:error) { |error| raise error }
            run_resque_worker
            promise.wait(:finished, timeout: 1)
            @triggered.should be_true
        end

        it "status" do
            promise.on(:tick) { promise.status.should == 'started' }
            promise.status.should == 'queued'
            run_resque_worker
            promise.wait(:finished, timeout: 1)
            promise.status.should == 'finished'
        end
    end
end
