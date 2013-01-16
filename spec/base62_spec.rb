require 'spec_helper'
require 'resque/plugins/promises/base62'

describe Resque::Plugins::Promises::Base62 do
    it "#encode" do
        Resque::Plugins::Promises::Base62.encode(18446744073709551615) \
            .should == 'lYGhA16ahyf'
    end

    it "#decode" do
        Resque::Plugins::Promises::Base62.decode('lYGhA16ahyf') \
            .should == 18446744073709551615
    end
end 
