chef-ladder
===========

[![Gem Version](https://badge.fury.io/rb/chef-ladder.png)](http://badge.fury.io/rb/chef-ladder)

Ladder is a very small command line tool for managing external cookbooks. While inspired by [berkshelf](http://berkshelf.com/) and [librarian-chef](https://github.com/applicationsonline/librarian-chef), it is much simpler, and only provides a few operations.

## Installation

    gem install chef-ladder

## Usage

* `ladder fetch <cookbooks>` Fetches cookbooks defined in the `Ladderfile` and places them in `~/.ladder`
* `ladder upload <cookbooks>` Uploads cookbooks from `~/.ladder` to the chef server
* `ladder update <cookbooks>` Fetches and uploads cookbooks

For each subcommand, specifing no cookbooks will fetch or upload all cookbooks defined in the `Ladderfile`. Chef settings are taken from `~/.chef/knife.rb`.

## Configuration

Ladder is configured in a similar way to berkshelf, and can source cookbooks from git and local paths:

    cookbook "supervisor-git", :git => "git@github.com:borntyping/cookbook-supervisor.git"
    cookbook "supervisor-github", :github => "borntyping/cookbook-supervisor"
    cookbook "supervisor-path", :path => "../cookbook-supervisor"

## Licence

The MIT License (MIT)

Copyright (c) 2013 Sam Clements

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
