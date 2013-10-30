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
			def initialize(name, source)
				@name = name
				@source = File.absolute_path(source)
			end

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

		# A list of Ladder::Cookbook objects
		# If the arguments list is empty, all cookbooks are used
		def selected_cookbooks
			names = arguments.empty? ? @sources.keys : arguments
			names.map { |name| @sources[name] }
		end
	end

	class Fetch < Command
		def execute
			super
			puts "Fetching cookbooks:"
			ensure_directory(global_options[:directory])
			for cookbook in selected_cookbooks
				puts " - #{cookbook.name}"
				cookbook.fetch(global_options[:directory])
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
			puts "Uploading cookbooks:"
			for cookbook in selected_cookbooks
				puts " + #{cookbook.name}"
				upload_cookbook(load_cookbook(cookbook))
			end
		end

		def load_cookbook(cookbook)
			@loader ||= Chef::CookbookLoader.new(global_options[:directory])
			chef_cookbook = @loader.load_cookbook(cookbook.name)
			if chef_cookbook.nil?
				raise "Could not load cookbook '#{cookbook.name}'"
			else
				return chef_cookbook
			end
		end

		def upload_cookbook(cookbooks)
			Chef::CookbookUploader.new(cookbooks, global_options[:directory]).upload_cookbooks
		end
	end
end

Escort::App.create do |app|
	app.version '0.4.0'
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
