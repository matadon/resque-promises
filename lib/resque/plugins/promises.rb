require 'resque/plugins/promises/promise'

module Resque
    module Plugins
        module Promises
            def self.extended(base)
                base.send(:extend, ClassMethods)
                base.send(:include, self)
            end

            module ClassMethods
                def enqueue(*args)
                    promise = Promise.new.connect(Resque.redis)
                    Resque.enqueue(self, *embed_promise_in_args(promise,
                        args))
                    promise.subscriber
                end

                def enqueue_to(queue, *args)
                    promise = Promise.new.connect(Resque.redis)
                    promise.status = 'promised'
                    Resque.enqueue_to(queue, self,
                        *embed_promise_in_args(promise, args))
                    promise.subscriber
                end

                def embed_promise_in_args(promise, args)
                    [ 'promise', promise.id, args ]
                end

                def extract_promise_from_args(args)
                    Promise.new(args[1]).connect(Resque.redis)
                end

                def extract_original_args(args)
                    args[2]
                end

                def args_has_promise?(args)
                    (args.count == 3) \
                        and (args[0] == 'promise') \
                        and (args[1] =~ /^[0-9a-zA-Z]{1,22}$/) \
                        and (args[2].is_a?(Array))
                end

                def after_enqueue_with_promise(*args)
                    promise = extract_promise_from_args(args)
                    promise.status = 'queued'
                    original_args = extract_original_args(args)
                    promise.trigger(:enqueue, original_args)
                end

                def after_dequeue_with_promise(*args)
                    promise = extract_promise_from_args(args)
                    original_args = extract_original_args(args)
                    promise.trigger(:dequeue, original_args)
                end

                def around_perform_with_promise(*args)
                    raise("need-to-enqueue-with-special-accessor") \
                        unless args_has_promise?(args)
                    promise = extract_promise_from_args(args)
                    original_args = extract_original_args(args)
                    promise.trigger(:perform, original_args)
                    @promise = promise
                    promise.status = 'started'
                    perform(*original_args)
                    promise.status = 'finished'
                    promise.trigger(:success, original_args)
                    promise.trigger(:finished, original_args)
                end

                def on_failure_with_promise(error, *args)
                    promise = extract_promise_from_args(args)
                    promise.status = 'finished'
                    original_args = extract_original_args(args)
                    promise.trigger(:error, [ error, original_args ])
                    promise.trigger(:finished, original_args)
                end

                def promise
                    @promise
                end
            end
        end
    end
end

