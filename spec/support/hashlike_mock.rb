class HashlikeMock
    attr_accessor :base

    def initialize
        @base = Hash.new
    end

    def []=(key, value)
        @base[key.to_s] = value
    end

    def [](key)
        @base[key.to_s]
    end

    def delete(key)
        @base.delete(key.to_s)
    end

    def keys
        @base.keys
    end

    def values
        @base.values
    end

    def length
        @base.length
    end

    def to_a
        @base.to_a
    end

    def each(&block)
        @base.each(&block)
    end
end
