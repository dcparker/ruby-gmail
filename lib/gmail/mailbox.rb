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
    def emails(key = :all, opts = {})
      aliases = {
        :all => ['ALL'],
        :unread => ['UNSEEN'],
        :read => ['SEEN']
      }
      search = aliases[key] || key

      # Support other search options
      # :before => Date, :on => Date, :since => Date,
      # :from => String, :to => String
      search += ['BEFORE', date_to_string(opts[:before])] if opts[:before]
      search += ['ON', date_to_string(opts[:on])] if opts[:on]
      search += ['SINCE', date_to_string(opts[:since])] if opts[:since]
      search += ['FROM', opts[:from]] if opts[:from]
      search += ['TO', opts[:to]] if opts[:to]

      # puts "Gathering #{(aliases[key] || key).inspect} messages for mailbox '#{name}'..."
      @gmail.in_mailbox(self) do
        @gmail.imap.uid_search(search).collect { |uid| messages[uid] ||= Message.new(@gmail, self, uid) }
      end
    end

    def messages
      @messages ||= {}
    end

    private

    # Converts the given object to a IMAP date string if we can
    def date_to_string(date_or_string)
      date_or_string.respond_to?(:strftime) ? date_or_string.strftime("%d-%B-%Y") : date_or_string
    end
  end
end
