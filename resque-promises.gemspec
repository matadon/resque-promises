# $:.push File.expand_path("lib/resque-promises", __FILE__)
# require 'version'

Gem::Specification.new do |spec|
    spec.name = "resque-promises"
    spec.version = '0.0.1'
    # spec.required_rubygems_version = Gem::Requirement.new(">= 1.8") \
        # if spec.respond_to?(:required_rubygems_version=)
    spec.authors = [ "Don Werve" ]
    spec.description = 'Promises for Resque.'
    # spec.summary = <<-END
    # END
    spec.email = 'don@madwombat.com'
    # FIXME: Use Dir.glob for this
    spec.files = %w(.gitignore
        README.markdown
        LICENSE
        Rakefile
        Gemfile
        resque-promises.gemspec)
    spec.files.concat(Dir['lib/**/*.rb'])
    spec.homepage = 'http://github.com/matadon/resque-promises'
    spec.has_rdoc = false
    spec.require_paths = [ "lib" ]
    # spec.rubygems_version = '1.3.6'
    spec.add_dependency('redis', '>= 3.0.0')
    spec.add_dependency('resque', '>= 1.7.0')
    spec.add_development_dependency('rspec', '>= 2.7.0')
    spec.add_development_dependency('rspec-core', '>= 2.7.0')
    # spec.add_development_dependency('rspec-longrun')
    # spec.add_development_dependency('json_pure', '>= 1.6.0')
    # spec.add_development_dependency('nokogiri')
end
