# Notice

First, the gem on rubygems.org is out of date. I am trying to gain ownership over that gem, but it is proving difficult - I may have to rename the gem.

Second, this gem needs to get back on track. I am looking for people to help go through issues and fix bugs. I want to push a solid, stable release first, then look at charting out the future of the gem. Please email me at <myobie@gmail.com> if you want to help or just get started on the issues.

# ruby-gmail

* Homepage: [http://dcparker.github.com/ruby-gmail/](http://dcparker.github.com/ruby-gmail/)
* Code: [http://github.com/dcparker/ruby-gmail](http://github.com/dcparker/ruby-gmail)
* Gem: [http://gemcutter.org/gems/ruby-gmail](http://gemcutter.org/gems/ruby-gmail)

## Author(s)

* Daniel Parker of BehindLogic.com

Extra thanks for specific feature contributions from:

  * [Justin Perkins](http://github.com/justinperkins)
  * [Mikkel Malmberg](http://github.com/mikker)
  * [Julien Blanchard](http://github.com/julienXX)
  * [Federico Galassi](http://github.com/fgalassi)

## Description

A Rubyesque interface to Gmail, with all the tools you'll need. Search, read and send multipart emails; archive, mark as read/unread, delete emails; and manage labels.

## Features

* Search emails
* Read emails (handles attachments)
* Emails: Label, archive, delete, mark as read/unread/spam
* Create and delete labels
* Create and send multipart email messages in plaintext and/or html, with inline images and attachments
* Utilizes Gmail's IMAP & SMTP, MIME-type detection and parses and generates MIME properly.

## Problems:

* May not correctly read malformed MIME messages. This could possibly be corrected by having IMAP parse the MIME structure.
* Cannot grab the plain or html message without also grabbing attachments. It might be nice to lazy-[down]load attachments.

## Example Code:

### 1) Require gmail

    require 'gmail'
    
### 2) Start an authenticated gmail session

    #    If you pass a block, the session will be passed into the block,
    #    and the session will be logged out after the block is executed.
    gmail = Gmail.new(username, password)
    # ...do things...
    gmail.logout

    Gmail.new(username, password) do |gmail|
      # ...do things...
    end

### 3) Count and gather emails!
    
    # Get counts for messages in the inbox
    gmail.inbox.count
    gmail.inbox.count(:unread)
    gmail.inbox.count(:read)

    # Count with some criteria
    gmail.inbox.count(:after => Date.parse("2010-02-20"), :before => Date.parse("2010-03-20"))
    gmail.inbox.count(:on => Date.parse("2010-04-15"))
    gmail.inbox.count(:from => "myfriend@gmail.com")
    gmail.inbox.count(:to => "directlytome@gmail.com")

    # Combine flags and options
    gmail.inbox.count(:unread, :from => "myboss@gmail.com")
    
    # Labels work the same way as inbox
    gmail.mailbox('Urgent').count
    
    # Getting messages works the same way as counting: optional flag, and optional arguments
    # Remember that every message in a conversation/thread will come as a separate message.
    gmail.inbox.emails(:unread, :before => Date.parse("2010-04-20"), :from => "myboss@gmail.com")

    # Get messages without marking them as read on the server.
    gmail.peek = true
    gmail.inbox.emails(:unread, :before => Date.parse("2010-04-20"), :from => "myboss@gmail.com")
    
### 4) Work with emails!

    # any news older than 4-20, mark as read and archive it...
    gmail.inbox.emails(:before => Date.parse("2010-04-20"), :from => "news@nbcnews.com").each do |email|
      email.mark(:read) # can also mark :unread or :spam
      email.archive!
    end

    # delete emails from X...
    gmail.inbox.emails(:from => "x-fiancé@gmail.com").each do |email|
      email.delete!
    end

    # Save all attachments in the "Faxes" label to a folder
    folder = "/where/ever"
    gmail.mailbox("Faxes").emails.each do |email|
      if !email.message.attachments.empty?
        email.message.save_attachments_to(folder)
      end
    end

    # Save just the first attachment from the newest unread email (assuming pdf)
    # For #save_to_file:
    #   + provide a path - save to attachment filename in path
    #   + provide a filename - save to file specified
    #   + provide no arguments - save to attachment filename in current directory
    email = gmail.inbox.emails(:unread).first
    email.attachments[0].save_to_file("/path/to/location")

    # Add a label to a message
    email.label("Faxes")

    # Or "move" the message to a label
    email.move_to("Faxes")

### 5) Create new emails!

Creating emails now uses the amazing [Mail](http://rubygems.org/gems/mail) rubygem. See its [documentation here](http://github.com/mikel/mail). Ruby-gmail will automatically configure your Mail emails to be sent via your Gmail account's SMTP, so they will be in your Gmail's "Sent" folder. Also, no need to specify the "From" email either, because ruby-gmail will set it for you.

    gmail.deliver do
      to "email@example.com"
      subject "Having fun in Puerto Rico!"
      text_part do
        body "Text of plaintext message."
      end
      html_part do
        body "<p>Text of <em>html</em> message.</p>"
      end
      add_file "/path/to/some_image.jpg"
    end
    # Or, generate the message first and send it later
    email = gmail.generate_message do
      to "email@example.com"
      subject "Having fun in Puerto Rico!"
      body "Spent the day on the road..."
    end
    email.deliver!
    # Or...
    gmail.deliver(email)

## Requirements

* ruby
* net/smtp
* net/imap
* tmail
* shared-mime-info rubygem (for MIME-detection when attaching files)

## Install

    gem install ruby-gmail

## License

(The MIT License)

Copyright (c) 2009 BehindLogic

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
