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

  ###########################
  #  READING EMAILS
  # 
  #  gmail.inbox
  #  gmail.label('News')
  #  
  ###########################
  def create_label(name)
	@xlist_result = nil
    imap.create(name)
  end

  # List the available labels
  def labels
	labels = []
    prefixes = ['']
	done = []
	until prefixes.empty?
		prefix = prefixes.shift
		done << prefix
		(imap.list(prefix, "%")||[]).each { |e|
			if e[:attr].include?(:Haschildren)
				unless done.include?(e[:name]+"/") or e[:name].empty?
					prefixes << e[:name]+"/"
				end
			end
			unless e[:attr].include?(:Noselect)
			  labels << e[:name]
			end
		}
	end
	labels
  end

  def imap_xlist
	  unless @imap.respond_to?(:xlist)
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
		    send_command('XLIST', '', '*')
		    remove_response_handler(handler)
		    return @responses.delete('XLIST')
		  end
		end
	  end

	  @xlist_result ||= @imap.xlist('', '*')
  end

  def self.special_labels
	  [:Inbox, :Allmail, :Spam, :Trash, :Drafts, :Important, :Starred, :Sent]
  end

  def special_labels
	  self.class.special_labels
  end

  def normal_labels
	  imap_xlist.reject { |label|
		label.attr.include?(:Noselect) or label.attr.any? { |flag| special_labels.include?(flag) }
	  }.map { |label|
		  label.name
	  }
  end

  def imap_xlist!
	  @xlist_result = nil
	  imap_xlist
  end

  def label_of_type(type)
	info = imap_xlist.find { |l| l.attr.include?(type) }
	info && info.name || nil
  end

  special_labels.each do |label|
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

  ###########################
  #  MAKING EMAILS
  # 
  #  gmail.generate_message do
  #    ...inside Mail context...
  #  end
  # 
  #  gmail.deliver do ... end
  # 
  #  mail = Mail.new...
  #  gmail.deliver!(mail)
  ###########################
  def generate_message(&block)
    require 'net/smtp'
    require 'smtp_tls'
    require 'mail'
    mail = Mail.new(&block)
    mail.delivery_method(*smtp_settings)
    mail
  end

  def deliver(mail=nil, &block)
    require 'net/smtp'
    require 'smtp_tls'
    require 'mail'
    mail = Mail.new(&block) if block_given?
    mail.delivery_method(*smtp_settings)
    mail.from = meta.username unless mail.from
    mail.deliver!
  end
  
  ###########################
  #  LOGIN
  ###########################
  def login
    res = @imap.login(meta.username, meta.password)
    @logged_in = true if res.name == 'OK'
  end
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

  ###########################
  #  Other...
  ###########################
  def inspect
    "#<Gmail:#{'0x%x' % (object_id << 1)} (#{meta.username}) #{'dis' if !logged_in?}connected>"
  end
  
  # Accessor for @imap, but ensures that it's logged in first.
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
