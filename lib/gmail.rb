require 'net/imap'
require 'net/smtp'
require 'smtp_tls'

class Gmail
  VERSION = '0.0.9'

  class NoLabel < RuntimeError; end

  def initialize(username, password)
    # This is to hide the username and password, not like it REALLY needs hiding, but ... you know.
    # Could be helpful when demoing the gem in irb, these bits won't show up that way.
    meta = class << self
      class << self
        attr_accessor :username, :password
      end
      self
    end
    meta.username = username =~ /@/ ? username : username + '@gmail.com'
    meta.password = password
    @imap = Net::IMAP.new('imap.gmail.com',993,true,nil,false)
    if block_given?
      @imap.login(username, password)
      yield self
      logout
    end
  end

  # Accessors for IMAP things
  def mailbox(name)
    mailboxes[name] ||= Mailbox.new(self, name)
  end

  # Accessors for Gmail things
  def inbox
    mailbox('inbox')
  end
  # Accessor for @imap, but ensures that it's logged in first.
  def imap
    if @imap.disconnected?
      meta = class << self; self end
      @imap.login(meta.username, meta.password)
      at_exit { logout } # Set up auto-logout for later.
    end
    @imap
  end
  # Log out of gmail
  def logout
    @imap.logout unless @imap.disconnected?
  end

  def create_label(name)
    imap.create(name)
  end

  def in_mailbox(mailbox, &block)
    raise ArgumentError, "Must provide a code block" unless block_given?
    mailbox_stack << mailbox
    unless @selected == mailbox.name
      imap.select(mailbox.name)
      @selected = mailbox.name
    end
    value = block.arity == 1 ? block.call(mailbox) : block.call
    mailbox_stack.pop
    # Select previously selected mailbox if there is one
    if mailbox_stack.last
      imap.select(mailbox_stack.last.name)
      @selected = mailbox.name
    end
    return value
  end
  alias :in_label :in_mailbox

  def open_smtp(&block)
    raise ArgumentError, "This method is to be used with a block." unless block_given?
    meta = class << self; self end
    puts "Opening SMTP..."
    Net::SMTP.start('smtp.gmail.com', 587, 'localhost.localdomain', meta.username, meta.password, 'plain', true) do |smtp|
      puts "SMTP open."
      block.call(lambda {|to, body|
        from = meta.username
        puts "Sending from #{from} to #{to}:\n#{body}"
        smtp.send_message(body, from, to)
      })
      puts "SMTP closing."
    end
    puts "SMTP closed."
  end
  
  def new_message
    MIME::Message.generate
  end
  
  def send_email(to, body=nil)
    meta = class << self; self end
    if to.is_a?(MIME::Message)
      to.headers['from'] = meta.username
      to.headers['date'] = Time.now.strftime("%a, %d %b %Y %H:%M:%S %z")
      body = to.to_s
      to = to.to
    end
    raise ArgumentError, "Please supply (to, body) to Gmail#send_email" if body.nil?
    open_smtp do |smtp|
      smtp.call to, body
    end
  end
  
  private
    def mailboxes
      @mailboxes ||= {}
    end
    def mailbox_stack
      @mailbox_stack ||= []
    end
end

require 'gmail/mailbox'
require 'gmail/message'
