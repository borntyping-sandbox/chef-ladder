#!/usr/bin/env ruby

require 'escort'
require 'git'
require 'ridley'

module Ladder
	class Utils
		# Creates a directory if it does not exist
		def self.ensure_directory(path)
			Dir.mkdir(path) unless File.exists?(path)
		end
	end

	class Config
		# Creates a Config object from a file
		def self.from_file(filename)
			config = Config.new
			config.instance_eval(File.read(filename), filename)
			return config
		end

		attr_reader :cookbooks

		def initialize()
			@cookbooks = Hash.new()
		end

		def cookbook(name, source, type=:git)
			case type
			when :git
				@cookbooks[name] = source
			when :github
				@cookbooks[name] = "git@github.com:#{source}.git"
			else
				raise Exception("Unknown type for cookbook #{name}")
			end
		end
	end

	class Error < RuntimeError

	end

	class Command < ::Escort::ActionCommand::Base
		def execute
			@directory = File.join(Dir.home, '.ladder')
			@config = Config.from_file(global_options[:config])
			# TODO: Make --ssl-verify an option
			@ridley = Ridley.from_chef_config(nil, :ssl => {:verify => false})

			for name in arguments
				self[name]
			end
		end

		def cookbook_path(name)
			return File.join(@directory, name)
		end

		def cookbook_exists(name)
			return File.exists?(cookbook_path(name))
		end
	end

	class Fetch < Command
		def [](name)
			if cookbook_exists(name)
				raise Ladder::Error.new("Cookbook '#{name}' is already present!")
			end

			Escort::Logger.output.puts "Fetching cookbook '#{name}'"
			Ladder::Utils.ensure_directory(@directory)
			Git.clone(@config.cookbooks[name], cookbook_path(name))
		end
	end

	class Upload < Command
		def [](name)
			Ladder::Fetch[name] if not cookbook_exists(name)
			Escort::Logger.output.puts "Uploading cookbook '#{name}'"
			@ridley.cookbook.upload(cookbook_path(name), :validate => true)
		end
	end
end

Escort::App.create do |app|
	app.version '0.1.0'
	app.summary 'Fetch those hard to reach cookbooks'

	app.options do |opts|
		opts.opt :config, "Config", :short => '-c', :long => '--config', :type => :string, :default => 'Ladderfile'
	end

	app.command :fetch do |command|
		command.summary "Fetch cookbooks"

		command.action do |options, arguments|
			Ladder::Fetch.new(options, arguments).execute
		end
	end

	app.command :upload do |command|
		command.summary "Upload cookbooks"

		command.action do |options, arguments|
			Ladder::Upload.new(options, arguments).execute
		end
	end
end
