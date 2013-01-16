module Resque
    module Plugins
        module Promises
            class Base62
                DIGITS = [ '0'..'9', 'a'..'z', 'A'..'Z' ].map(&:to_a).flatten
                
                def self.encode(integer)
                    raise(ArgumentError) unless integer.is_a?(Integer)
                    result = (integer == 0) ? '0' : ''
                    while(integer > 0)
                        result = DIGITS[integer % 62] + result
                        integer /= 62
                    end
                    result
                end

                def self.decode(string)
                    raise(ArgumentError) unless string.is_a?(String)

                    total = 0
                    string.reverse.chars.each_with_index do |char, index|
                        digit = DIGITS.index(char) or raise(ArgumentError,
                            "Input not base-62 encoded.")
                        total += digit * (62 ** index)
                    end
                    total
                end
            end
        end
    end
end
