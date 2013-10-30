#!/usr/bin/env ruby

require 'chef/cookbook_loader'
require 'chef/cookbook_uploader'
require 'escort'
require 'git'

module Ladder
	module Cookbooks
		class Cookbook
			def self.create(name, options)
				if options.has_key? :path
					return LocalCookbook.new(name, options[:path])
				elsif options.has_key? :git
					return GitCookbook.new(name, options[:git])
				elsif options.has_key? :github
					return GithubCookbook.new(name, options[:github])
				else
					raise "No valid source defined for cookbook '#{name}'"
				end
			end

			def initialize(name, source)
				@name = name
				@source = source
			end
		end

		class GitCookbook < Cookbook
			def fetch(directory)
				path = File.join(directory, @name)

				if Dir.exists?(path)
					Git.open(path).pull()
				else
					Git.clone(@source, path)
				end
			end
		end

		class GithubCookbook < GitCookbook
			def initialize(name, source)
				@name = name
				@source = "git@github.com:#{source}.git"
			end
		end

		class LocalCookbook < Cookbook
			def fetch(directory)
				FileUtils.cp_r(@source, directory)
			end
		end
	end

	class Sources < Hash
		def self.from_file(filename)
			config = Sources.new
			config.instance_eval(File.read(filename), filename)
			return config
		end

		def cookbook(name, options)
			self[name] = Ladder::Cookbooks::Cookbook.create(name, options)
		end
	end

	class Command < Escort::ActionCommand::Base
		# Shortcut to the Escort logger
		@@log = Escort::Logger.output

		# Common command setup
		def execute
			# Load Chef configuration
			@chef_config = Chef::Config.from_file(global_options[:knife])

			# Load Ladderfile configuration
			@sources = Ladder::Sources.from_file(global_options[:config])

			# If not arguments, use every cookbook in the Ladderfile
			@cookbooks = arguments.empty? ? @sources.keys : arguments
		end
	end

	class Fetch < Command
		def execute
			super
			@@log.info "Fetching cookbooks: #{@cookbooks.join(', ')}"
			@cookbooks.each { |name| fetch_cookbook(name) }
		end

		# Fetches a single cookbook
		def fetch_cookbook(name)
			if not @sources.has_key? name
				raise "No source listed for cookbook '#{name}'"
			end

			ensure_directory(global_options[:directory])
			@sources[name].fetch(global_options[:directory])
		end

		private

		# Creates a directory if it does not exist
		def ensure_directory(path)
			Dir.mkdir(path) unless File.exists?(path)
		end
	end

	class Upload < Command
		def execute
			super

			# Load the selected cookbooks from the ladder directory
			loader = Chef::CookbookLoader.new(global_options[:directory])
			cookbooks = @cookbooks.map { |name| loader.load_cookbook(name) }

			@@log.info "Uploading cookbooks: #{cookbooks.map {|c| c.name.to_s }.join(', ')}"

			# Upload the selected cookbooks
			Chef::CookbookUploader.new(cookbooks, global_options[:directory]).upload_cookbooks
		end
	end
end

Escort::App.create do |app|
	app.version '0.3.0'
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
end
