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
    gem.post_install_message = "\n\033[34mIf ruby-gmail saves you TWO hours of work, want to compensate me for, like, a half-hour?\nSupport me in making new and better gems:\033[0m \033[31;4mhttp://pledgie.com/campaigns/7087\033[0m\n\n"
    gem.add_dependency('shared-mime-info', '>= 0')
    gem.add_dependency('mail', '>= 2.2.1')
    # gem is a Gem::Specification... see http://www.rubygems.org/read/chapter/20 for additional settings
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

task :test do
	system 'bundle exec ruby -Ilib -Itest test/test_gmail.rb'
end
