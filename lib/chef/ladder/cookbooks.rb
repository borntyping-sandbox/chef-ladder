require 'git'

module Ladder::Cookbooks
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
		attr_reader :source
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
