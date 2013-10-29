#!/usr/bin/env ruby

require 'chef/cookbook_loader'
require 'chef/cookbook_uploader'
require 'escort'
require 'git'

module Ladder
	class Sources < Hash
		def self.from_file(filename)
			config = Sources.new
			config.instance_eval(File.read(filename), filename)
			return config
		end

		def cookbook(name, source, type=:git)
			self[name] = cookbook_source(source, type)
		end

		private

		def cookbook_source(source, type)
			case type
			when :git
				return source
			when :github
				return "git@github.com:#{source}.git"
			else
				raise Exception.new("Unknown type for cookbook #{name}")
			end
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

			path = File.join(global_options[:directory], name)


			if Dir.exists?(path)
				Git.open(path).pull()
			else
				Git.clone(@sources[name], path)
			end
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
	app.version '0.2.0'
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
