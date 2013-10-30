Gem::Specification.new do |s|
	s.name        = 'chef-ladder'
	s.version     = '1.0.0'
	s.date        = '2013-10-30'
	s.summary     = "Helps fetch those hard to reach cookbooks"
	s.description = "Fetches and uploads external cookbooks from git"
	s.authors     = ["Sam Clements"]
	s.email       = "sam@borntyping.co.uk"
	s.homepage    = "https://github.com/borntyping/chef-ladder"
	s.license     = 'MIT'

	s.files       = ['lib/chef/ladder.rb', 'lib/chef/ladder/cookbooks.rb', 'lib/chef/ladder/main.rb']
	s.executables = ['ladder']

	s.add_dependency 'escort', '~> 0.4.0'
	s.add_dependency 'chef'
	s.add_dependency 'git', '~> 1.2.6'
end
