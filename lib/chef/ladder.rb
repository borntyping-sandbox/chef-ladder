#!/usr/bin/env ruby

require 'chef/cookbook_loader'
require 'chef/cookbook_uploader'
require 'escort'

module Ladder
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
				puts " - #{cookbook.name} from #{cookbook.source}"
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
				chef_cookbook = load_cookbook(cookbook)
				puts " + #{chef_cookbook.metadata.name} version #{chef_cookbook.version}"
				upload_cookbook(chef_cookbook)
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

require 'chef/ladder/cookbooks'
