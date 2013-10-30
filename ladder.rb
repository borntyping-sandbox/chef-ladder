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

			attr_reader :name
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
				dest = File.join(directory, @name)
				FileUtils.remove(dest, :force => true)
				FileUtils.symlink(@source, dest, :force => true)
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
		def execute
			# Load Chef configuration
			@@chef_config ||= Chef::Config.from_file(global_options[:knife])

			# Load Ladderfile configuration
			@sources = Ladder::Sources.from_file(global_options[:config])
		end

		# If the arguments list is empty, all cookbooks are used
		def cookbook_names
			return arguments.empty? ? @sources.keys : arguments
		end

		def cookbooks
			return cookbook_names.map { |name| @sources[name] }
		end

		def directory
			return global_options[:directory]
		end
	end

	class Fetch < Command
		def execute
			super
			puts "Fetching cookbooks:  #{cookbook_names.join(', ')}"
			ensure_directory(directory)
			cookbooks.each { |cookbook| cookbook.fetch(directory) }
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

			puts "Uploading cookbooks: #{cookbook_names.join(', ')}"

			# Load the selected cookbooks from the ladder directory
			@loader = Chef::CookbookLoader.new(directory)

			# Upload the selected cookbooks
			@uploader = Chef::CookbookUploader.new(chef_cookbooks, directory)
			@uploader.upload_cookbooks
		end

		def load_cookbook(cookbook)
			chef_cookbook = @loader.load_cookbook(cookbook.name)

			if chef_cookbook.nil?
				raise "Could not load cookbook '#{cookbook.name}'"
			end

			return chef_cookbook
		end

		def chef_cookbooks
			cookbooks.map { |cookbook| load_cookbook(cookbook) }
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

	app.command :update do |command|
		command.summary "Fetch and upload cookbooks"
		command.description "Fetch and upload  cookbooks"

		command.action do |options, arguments|
			Ladder::Fetch.new(options, arguments).execute
			Ladder::Upload.new(options, arguments).execute
		end
	end
end
