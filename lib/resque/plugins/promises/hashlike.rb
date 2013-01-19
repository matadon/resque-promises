# http://www.quora.com/Redis/What-are-5-mistakes-to-avoid-when-using-Redis

module Resque
    module Plugins
        module Promises
            module Hashlike
                include Enumerable

                def flatten
                    to_a.flatten
                end
                
                def to_hash
                    Hash[*flatten]
                end

                def size
                    length
                end

                def empty?
                    length == 0
                end

                def each_value(&block)
                    values.each(&block)
                end

                def each_key(&block)
                    keys.each(&block)
                end

                def each_pair(&block)
                    each(&block)
                end

                def values_at(*keys)
                    keys.map { |k| self[k] }
                end

                def shift
                    key = keys.first
                    value = delete(key)
                    [ key, value ]
                end

                def delete_if
                    each { |key, value| yield(key, value) and delete(key) }
                    self
                end

                def reject(&block)
                    to_hash.reject(&block)
                end

                def reject!(&block)
                    delete_if(&block)
                end

                def keep_if
                    each { |key, value| yield(key, value) or delete(key) }
                    self
                end

                def select!(&block)
                    keep_if(&block)
                end

                def select(&block)
                    to_hash.select(&block)
                end

                def clear
                    keys.each { |k| delete(k) }
                end

                def invert
                    to_hash.invert
                end

                def update(changes)
                    changes.each { |k, v| self[k] = v }
                end

                def merge!(changes)
                    update(changes)
                end

                def replace(changes)
                    clear
                    update(changes)
                end

                def merge(changes)
                    to_hash.merge(changes)
                end

                def assoc(obj)
                    each { |k, v| return([k, v]) if (k == obj) }
                    nil
                end

                def rassoc(obj)
                    each { |k, v| return([k, v]) if (v == obj) }
                    nil
                end

                def has_key?(key)
                    not self[key].nil?
                end

                def key?(key)
                    has_key?(key)
                end

                def member?(key)
                    has_key?(key)
                end

                def include?(key)
                    has_key?(key)
                end

                def has_value?(value)
                    values.include?(value)
                end

                def value?(value)
                    has_value?(value)
                end

                def ==(other)
                    return(false) unless (other.length == length)
                    other.each { |k, v| return(false) unless self[k] == v }
                    true
                end
            end
        end
    end
end

# Hashlike
#     set(key, value)
#     delete(key)
#     get(key)
#     keys
#     values
#     clear

