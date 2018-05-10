# -*- ruby -*-

require 'rubygems'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "ruby-gmail"
    gem.summary = %Q{A Rubyesque interface to Gmail, with all the tools you'll need.}
    gem.description = %Q{A Rubyesque interface to Gmail, with all the tools you'll need. Search, read and send multipart emails; archive, mark as read/unread, delete emails; and manage labels.}
    gem.email = "gems@behindlogic.com"
    gem.homepage = "http://dcparker.github.com/ruby-gmail"
    gem.authors = ["BehindLogic"]
    gem.post_install_message = "Thanks for downloading ruby-gmail :)"
    gem.add_dependency('shared-mime-info', '>= 0')
    gem.add_dependency('mail', '>= 2.2.1')
    gem.add_dependency('mime', '>= 0.1')
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

task :default do
  sh "find test -type f -name '*rb' -exec testrb -I lib:test {} +"
end
