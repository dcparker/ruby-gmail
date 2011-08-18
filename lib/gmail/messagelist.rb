class Gmail
	# A MessageList object contains references to a specific subset of messages in a given mailbox
	# All messages are idenitifed by uids and can be further filtered, fetched or operated on.
	class MessageList
		include Enumerable
		attr_reader :list, :mailbox
		def initialize(gmail, mailbox, list)
			@gmail = gmail
			@mailbox = mailbox
			@list = list
		end

		# Iterate over each message
		def each(&block)
			@list.each(&block)
		end

		# Number of messages
		# @return [Number] Number of messages
		def size
			@list.size
		end

		# Is list empty?
		# @return [Boolean] True if list is empty
		def empty?
			@list.empty?
		end

		# Fetch all the bodies for the messages that haven't yet been loaded
		# @return [self]
		def fetch_all
			@gmail.in_label(@mailbox) do |mbox|
				Gmail.auto_segment(@list.reject { |m| m.loaded? }, 25) do |fetch_uids|
					@gmail.imap.uid_fetch(fetch_uids, ['ENVELOPE', 'RFC822']).map do |info|
						# These messages must already exist in the mailbox hash
						# because they have already had the envelopes fetched
						message = mbox.messages[info.attr['UID']]
						message.envelope = info.attr['ENVELOPE']
						message.message_id = message.envelope.message_id
						info.attr['ENVELOPE'].message_id
					end
				end
			end
			self
		end

		# @group Bulk Utility Functions
		
		# Archive messages (ie. remove from inbox)
		def archive!
			if @mailbox == @gmail.inbox
				@mailbox.flag(uids, :Deleted)
			else
				with_label(@gmail.inbox_label).archive!
			end
		end

		# Delete all messages from mailbox/label
		def delete!
			@mailbox.flag(uids, :Deleted)
		end

		# Mark messages as read/unread/deleted/spam.
		#
		# @param flag [:read, :unread, :deleted, :spam] Standard gmail actions
		def mark(flag)
			case flag
			when :read
				@mailbox.flag(uids, :Seen)
			when :unread
				@mailbox.unflag(uids, :Seen)
			when :deleted
				@mailbox.flag(uids, :Deleted)
			when :spam
				@mailbox.move_to(uids, @gmail.spam_label)
			end ? true : false
		end

		def uids
			@list.map { |m| m.uid }
		end
		private :uids

		# Delete all messages from specified mailbox/label
		#
		# @param label [String] Label/Mailbox to remove the messages from
		def remove_label(label)
			label = label.is_a?(String) ? @gmail.label(label) : label

			if @mailbox == label
				delete!
			else
				with_label(label).delete!
			end
		end
		# @endgroup
		

		# @group Search Functions
	
		# Find all the messages in this selection that have a given label
		# @return [Gmail::MessageList] Subset of messages
		def with_label(label)
			label = label.is_a?(String) ? @gmail.label(label) : label

			return self if label == @mailbox

			return MessageList.new(@gmail, label, []) if empty?

			@gmail.in_label(label) do |mbox|

				# Search for message ids in named folder
				uids = []

				uids = Gmail.auto_segment(@list, 25) do |search_list|
					search = []
					search_list.each_with_index do |m, index|
						search.unshift "OR" unless index.zero?
						search << "HEADER" << "Message-ID" << m.message_id
					end
					@gmail.imap.uid_search(search)
				end

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

				message_ids += Gmail.auto_segment(missing_uids, 25) do |fetch_uids|
					@gmail.imap.uid_fetch(fetch_uids, ['ENVELOPE']).map do |info|
						message = mbox.messages[info.attr['UID']]
						message.envelope = info.attr['ENVELOPE']
						message.message_id = message.envelope.message_id
						info.attr['ENVELOPE'].message_id
					end
				end

				MessageList.new(@gmail, mbox, uids.map { |uid| mbox.messages[uid] })
			end
		end

		# endgroup
	end

end
