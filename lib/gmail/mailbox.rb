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

	FLAG_KEYWORDS = [
		['ANSWERED', 'UNANSWERED'],
		['DELETED', 'UNDELETED'],
		['DRAFT', 'UNDRAFT'],
		['FLAGGED', 'UNFLAGGED'],
		['RECENT', 'OLD'],
		['SEEN', 'UNSEEN']
	]
	VALID_SEARCH_KEYS = %w[
		ALL
		BCC
		BEFORE
		BODY
		CC
		FROM
		HEADER
		KEYWORD
		LARGER
		NEW
		NOT
		ON
		OR
		SENTBEFORE
		SENTON
		SENTSINCE
		SINCE
		SMALLER
		SUBJECT
		TEXT
		TO
		UID
		UNKEYWORD
	] + FLAG_KEYWORDS.flatten
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

	  fetch = opts.delete(:fetch)

      if !opts.empty?
        # Support for several search macros
        # :before => Date, :on => Date, :since => Date, :from => String, :to => String
		opts = opts.dup
		VALID_SEARCH_KEYS.each do |keyword|
			key = keyword.downcase.intern
			if opts[key]
				val = opts.delete(key)
				case val
				when Date, Time
					search.concat([keyword, val.to_imap_date])
				when String
					search.concat([keyword, val])
				when Numeric
					search.concat([keyword, val.to_s])
				when Array
					search.concat([keyword, *val])
				when TrueClass, FalseClass
					# If it's a known flag keyword & val == false,
					# try to invert it's meaning.
					if row = FLAG_KEYWORDS.find { |row| row.include?(keyword) }
						row_index = row.index(keyword)
						altkey = row[ val ? row_index : 1 - row_index ]
						search.push(altkey)
					else
						search.push(keyword) if val
					end
				when NilClass
					next
				else
					search.push(keyword) # e.g. flag
				end
			end
		end

		# API compatibility
        search.concat ['SINCE', opts.delete(:after).to_imap_date] if opts[:after]

		unless opts.empty?
			raise "Unrecognised keys: #{opts.keys.inspect}"
		end
      end

	  list = []

      @gmail.in_mailbox(self) do
		uids = @gmail.imap.uid_search(search)
        list = uids.collect { |uid| messages[uid] ||= Message.new(@gmail, self, uid) }

		if fetch
			missing = list.reject { |message| message.loaded? }.map { |message| message.uid }
			@gmail.imap.uid_fetch(missing, ['ENVELOPE', 'RFC822']).each do |info|
				message = messages[info.attr['UID']]
				message.envelope = info.attr['ENVELOPE']
				message.set_body(info.attr['RFC822'])
			end
		else
			missing = list.reject { |message| message.message_id? }.map { |message| message.uid }
			@gmail.imap.uid_fetch(missing, ['ENVELOPE']).each do |info|
				message = messages[info.attr['UID']]
				message.envelope = info.attr['ENVELOPE']
				message.message_id = info.attr['ENVELOPE'].message_id
			end
		end
      end

	  MessageList.new(@gmail, list)
    end

	class MessageList
		include Enumerable
		attr_reader :list
		def initialize(gmail, list)
			@gmail = gmail
			@list = list
		end
		def size
			@list.size
		end
		def each(&block)
			@list.each(&block)
		end
		def empty?
			@list.empty?
		end
		def with_label(label)
			return MessageList.new(@gmail, []) if empty?

			label = label.is_a?(String) ? @gmail.label(label) : label
			@gmail.in_label(label) do |mbox|

				# Search for message ids in named folder
				search = []
				@list.each_with_index do |m, index|
					search.unshift "OR" unless index.zero?#.empty?
					search << "HEADER" << "Message-ID" << m.message_id
				end
				uids = @gmail.imap.uid_search(search)

				# Fetch envelopes for uids
				message_ids = []

				missing_uids = uids.collect { |uid|
					mbox.messages[uid] ||= Message.new(@gmail, mbox, uid)
				}.reject { |message|
					if message.loaded? or message.message_id?
						message_ids << message.message_id
						true
					else
						false
					end
				}.map { |message|
					message.uid
				}

				message_ids += @gmail.imap.uid_fetch(missing_uids, ['ENVELOPE']).map do |info|
					message = mbox.messages[info.attr['UID']]
					message.envelope = info.attr['ENVELOPE']
					info.attr['ENVELOPE'].message_id
				end

				MessageList.new(@gmail, @list.select { |m| message_ids.include?(m.message_id) })
			end
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
