= ruby-gmail

* Homepage: http://dcparker.github.com/ruby-gmail/
* Code: http://github.com/dcparker/ruby-gmail
* Gem: http://gemcutter.org/gems/ruby-gmail

== Author(s):

* Daniel Parker of BehindLogic.com

Extra thanks for specific feature contributions from:

  * Justin Perkins (http://github.com/justinperkins/)
  * Mikkel Malmberg (http://github.com/mikker/)


== DESCRIPTION:

A Rubyesque interface to Gmail. Connect to Gmail via IMAP and manipulate emails and labels. Send email with your Gmail account via SMTP. Includes full support for parsing and generating MIME messages.

== FEATURES:

* Read emails via IMAP
* Full MIME parsing ability, with understanding of attachments
* Create, rename, and delete labels
* Label, archive, delete, mark as read/unread/spam
* Send emails via SMTP
* Full ability to generate MIME messages including inline images and attachments

== PROBLEMS:

* May not correctly read malformed MIME messages. This could possibly be corrected by having IMAP parse the MIME structure.
* Cannot grab the plain or html message without also grabbing attachments. It might be nice to lazy-[down]load attachments.

== SYNOPSIS:

  require 'gmail'
  gmail = Gmail.new(username, password) do |g|
    gmail.inbox.count # takes the same arguments as gmail.inbox.emails
    unread = gmail.inbox.emails(:unread)
    unread[0].archive!
    unread[1].delete!
    unread[2].move_to('FunStuff') # => Labels 'FunStuff' and removes from inbox
    unread[3].message # => a MIME::Message, parsed from the email body
    unread[3].mark(:read)
    unread[3].message.attachments.length
    unread[4].label('FunStuff') # => Just adds the label 'FunStuff'
    unread[4].message.save_attachments_to('path/to/save/into')
    unread[5].message.attachments[0].save_to_file('path/to/save/into')
    unread[6].mark(:spam)
  end

  # Optionally use a block like above to have the gem automatically login and logout,
  # or just use it without a block after creating the object like below, and it will
  # automatically logout at_exit. The block method is recommended, to limit your signed-in session.

  older = gmail.inbox.emails(:after => '2009-03-04', :before => '2009-03-15')
  todays_date = Time.parse(Time.now.strftime('%Y-%m-%d'))
  yesterday = gmail.inbox.emails(:after => (todays_date - 24*60*60), :before => todays_date)
  todays_unread = gmail.inbox.emails(:unread, :after => todays_date)
  
  new_email = MIME::Message.generate
  new_email.to "email@example.com"
  new_email.subject "Having fun in Puerto Rico!"
  plain, html = new_email.generate_multipart('text/plain', 'text/html')
  plain.content = "Text of plain message."
  html.content = "<p>Text of <em>html</em> message.</p>"
  new_email.attach_file('some_image.dmg')
  gmail.send_email(new_email)

== REQUIREMENTS:

* ruby
* net/smtp
* net/imap
* gem shared-mime-info

== INSTALL:

* [sudo] gem install ruby-gmail -s http://gemcutter.org

== LICENSE:

(The MIT License)

Copyright (c) 2009 BehindLogic.com

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
