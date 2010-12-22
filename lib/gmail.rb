require 'net/imap'

class Gmail
  VERSION = '0.0.9'

  class NoLabel < RuntimeError; end

  ##################################
  #  Gmail.new(username, password)
  ##################################
  def initialize(username, password)
    # This is to hide the username and password, not like it REALLY needs hiding, but ... you know.
    # Could be helpful when demoing the gem in irb, these bits won't show up that way.
    class << self
      class << self
        attr_accessor :username, :password
      end
    end
    meta.username = username =~ /@/ ? username : username + '@gmail.com'
    meta.password = password
    @imap = Net::IMAP.new('imap.gmail.com',993,true,nil,false)
    if block_given?
      login # This is here intentionally. Normally, we get auto logged-in when first needed.
      yield self
      logout
    end
  end

  # @group Labels/Mailbox uility functions

  # Create label
  def create_label(name)
	@xlist_result = nil
    imap.create(name)
  end

  # List the available labels
  def labels
	labels = []
	(imap.list('', "*")||[]).each { |e|
		unless e.attr.include?(:Noselect)
		  labels << e.name
		end
	}
	labels
  end

  def imap_xlist
	  unless imap.respond_to?(:xlist)
		def @imap.xlist(refname, mailbox)
			handler = proc do |resp|
			  if resp.kind_of?(Net::IMAP::UntaggedResponse) and resp.name == "XLIST" && resp.raw_data.nil?
				list_resp = Net::IMAP::ResponseParser.new.instance_eval {
					@str, @pos, @token = "#{resp.name} " + resp.data, 0, nil
					@lex_state = Net::IMAP::ResponseParser::EXPR_BEG
					list_response
				}
				if @responses['XLIST'].last == resp.data
					@responses['XLIST'].pop
					@responses['XLIST'].push(list_resp.data)
				end
			  end
		  end
		  synchronize do
		    add_response_handler(handler)
		    send_command('XLIST', refname, mailbox)
		    remove_response_handler(handler)
		    return @responses.delete('XLIST')
		  end
		end
	  end

	  @xlist_result ||= @imap.xlist('', '*')
  end
  protected :imap_xlist

  def self.gmail_label_types
	  [:Inbox, :Allmail, :Spam, :Trash, :Drafts, :Important, :Starred, :Sent]
  end

  # List of known GMail label types
  #
  # These correspond to the special flags returned by the XLIST command
  def gmail_label_types
	  self.class.gmail_label_types
  end

  # Return list of "normal" labels
  #
  # Filters out any special mailboxes
  def normal_labels
	  imap_xlist.reject { |label|
		label.attr.include?(:Noselect) or label.attr.any? { |flag| gmail_label_types.include?(flag) }
	  }.map { |label|
		label.name
	  }
  end

  def imap_xlist!
	  @xlist_result = nil
	  imap_xlist
  end
  protected :imap_xlist!

  # Returns name of label/mailbox of specified type
  #
  # @param type [Symbol] One of the types returned by {#gmail_label_types}
  def label_of_type(type)
	info = imap_xlist.find { |l| l.attr.include?(type) }
	info && info.name || nil
  end

  gmail_label_types.each do |label|
	  module_eval <<-EOL
	    def #{label.to_s.downcase} &block
		  in_label(#{label.to_s.downcase}_label, &block)
		end
		def #{label.to_s.downcase}_label
          label_of_type(#{label.inspect})
		end
	  EOL
  end

  # gmail.label(name)
  def label(name)
    mailboxes[name] ||= Mailbox.new(self, name)
  end
  alias :mailbox :label

  # @group Making/Sending Emails
  
  #  Generate and return message
  #
  #  gmail.generate_message do
  #    ...inside Mail context...
  #  end
  # 
  #  gmail.deliver do ... end
  # 
  #  mail = Mail.new...
  #  gmail.deliver!(mail)
  #
  # @yield [Mail] Mail object
  # @return [Mail] Created mail object
  def generate_message(&block)
    require 'net/smtp'
    require 'smtp_tls'
    require 'mail'
    mail = Mail.new(&block)
    mail.delivery_method(*smtp_settings)
    mail
  end

  # Generate message and delivery using gmail smtp
  #
  # @yield [Mail] Mail object
  # @param mail [optional, Mail] Message as a Mail object
  def deliver(mail=nil, &block)
    require 'net/smtp'
    require 'smtp_tls'
    require 'mail'
    mail = Mail.new(&block) if block_given?
    mail.delivery_method(*smtp_settings)
    mail.from = meta.username unless mail.from
    mail.deliver!
  end
  # @endgroup

  # @group Login related functions
  
  # Login as specified user
  def login
    res = @imap.login(meta.username, meta.password)
    @logged_in = true if res.name == 'OK'
  end

  # Check whether imap connection has logged in yet.
  #
  # @return [Boolean] Is logged in?
  def logged_in?
    !!@logged_in
  end

  # Log out of gmail
  def logout
    if logged_in?
      res = @imap.logout
      @logged_in = false if res.name == 'OK'
    end
  end

  # @endgroup

  # @overload in_mailbox(mailbox, &block)
  #   Selects specified mailbox, yields it to block and then returns to previous mailbox 
  #   when block exits
  #   @yield [Gmail::Mailbox] Current mailbox
  #   @return Result of block
  #
  # @overload in_mailbox(mailbox)
  #   Returns Mailbox object coresponding to name
  #   @return [Gmail::Mailbox]
  #
  def in_mailbox(mailbox, &block)
    if block_given?
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
    else
      mailboxes[mailbox] ||= Mailbox.new(self, mailbox)
    end
  end
  alias :in_label :in_mailbox

  # Describe object
  def inspect
    "#<Gmail:#{'0x%x' % (object_id << 1)} (#{meta.username}) #{'dis' if !logged_in?}connected>"
  end
  
  # Accessor for @imap, but ensures that it's logged in first.
  # Internal use only.
  #
  def imap
    unless logged_in?
      login
      at_exit { logout } # Set up auto-logout for later.
    end
    @imap
  end

  private
    def mailboxes
      @mailboxes ||= {}
    end
    def mailbox_stack
      @mailbox_stack ||= []
    end
    def meta
      class << self; self end
    end
    def domain
      meta.username.split('@')[0]
    end
    def smtp_settings
      [:smtp, {:address => "smtp.gmail.com",
      :port => 587,
      :domain => domain,
      :user_name => meta.username,
      :password => meta.password,
      :authentication => 'plain',
      :enable_starttls_auto => true}]
    end
end

require 'gmail/mailbox'
require 'gmail/message'
require 'gmail/messagelist'

