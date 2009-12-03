require 'date'
require 'time'
class Object
  def to_imap_date
    Date.parse(to_s).strftime("%d-%B-%Y")
  end
end

class Gmail
  class Mailbox
    attr_reader :name

    def initialize(gmail, name)
      @gmail = gmail
      @name = name
    end

    def inspect
      "<#Mailbox name=#{@name}>"
    end

    def to_s
      name
    end

    # Method: emails
    # Args: [ :all | :unread | :read ]
    # Opts: {:since => Date.new}
    def emails(key_or_opts = :all, opts={})
      if key_or_opts.is_a?(Hash) && opts.empty?
        search = ['ALL']
        opts = key_or_opts
      elsif key_or_opts.is_a?(Symbol) && opts.is_a?(Hash)
        aliases = {
          :all => ['ALL'],
          :unread => ['UNSEEN'],
          :read => ['SEEN']
        }
        search = aliases[key_or_opts]
      elsif key_or_opts.is_a?(Array) && opts.empty?
        search = key_or_opts
      else
        raise ArgumentError, "Couldn't make sense of arguments to #emails - should be an optional hash of options preceded by an optional read-status bit; OR simply an array of parameters to pass directly to the IMAP uid_search call."
      end
      if !opts.empty?
        # Support for several search macros
        # :before => Date, :on => Date, :since => Date, :from => String, :to => String
        search.concat ['SINCE', opts[:after].to_imap_date] if opts[:after]
        search.concat ['BEFORE', opts[:before].to_imap_date] if opts[:before]
        search.concat ['ON', opts[:on].to_imap_date] if opts[:on]
        search.concat ['FROM', opts[:from]] if opts[:from]
        search.concat ['TO', opts[:to]] if opts[:to]
      end

      # puts "Gathering #{(aliases[key] || key).inspect} messages for mailbox '#{name}'..."
      @gmail.in_mailbox(self) do
        @gmail.imap.uid_search(search).collect { |uid| messages[uid] ||= Message.new(@gmail, self, uid) }
      end
    end

    # This is a convenience method that really probably shouldn't need to exist, but it does make code more readable
    # if seriously all you want is the count of messages.
    def count(*args)
      emails(*args).length
    end

    def messages
      @messages ||= {}
    end
  end
end
