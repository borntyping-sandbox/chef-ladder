require 'chef/ladder'
require 'escort'

Escort::App.create do |app|
	app.version '1.0.0'
	app.summary 'Fetch those hard to reach cookbooks'

	app.options do |opts|
		opts.opt :config, "Ladder configuration file", :short => '-c', :long => '--config', :type => :string, :default => './Ladderfile'
		opts.opt :directory, "Ladder cookbooks directory", :short => '-d', :long => '--directory', :type => :string, :default => File.join(Dir.home, '.ladder')
		opts.opt :knife, "Knife configuration file", :short => '-k', :long => '--knife-config', :type => :string, :default => File.join(Dir.home, '.chef', 'knife.rb')
	end

	app.command :fetch do |command|
		command.summary "Fetch cookbooks"
		command.description "Fetch cookbooks"

		command.action do |options, arguments|
			Ladder::Fetch.new(options, arguments).execute
		end
	end

	app.command :upload do |command|
		command.summary "Upload cookbooks"
		command.description "Upload cookbooks"

		command.action do |options, arguments|
			Ladder::Upload.new(options, arguments).execute
		end
	end

	app.command :update do |command|
		command.summary "Fetch and upload cookbooks"
		command.description "Fetch and upload  cookbooks"

		command.action do |options, arguments|
			Ladder::Fetch.new(options, arguments).execute
			Ladder::Upload.new(options, arguments).execute
		end
	end
end
