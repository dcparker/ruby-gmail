class Gmail
  class Message
    def initialize(gmail, mailbox, uid)
      @gmail = gmail
      @mailbox = mailbox
      @uid = uid
    end

    def inspect
      "<#Message:#{object_id} mailbox=#{@mailbox.name}#{' uid='+@uid.to_s if @uid}#{' message_id='+@message_id.to_s if @message_id}>"
    end

    # Auto IMAP info
    def uid
      @uid ||= @gmail.in_mailbox(@mailbox) { @gmail.imap.uid_search(['HEADER', 'Message-ID', message_id])[0] }
    end

    # @group IMAP Operations

    def flag(flg)
	  @mailbox.flag([uid], flg)
    end

    def unflag(flg)
 	  @mailbox.flag([uid], flg)
    end

	# @endgroup

	attr_writer :message_id
	attr_writer :envelope
	def message_id?
		!! (@envelope || @message_id || @message)
	end
	def message_id
		@message_id ||= @envelope ? @envelope.message_id : self.header['Message-ID'].value
	end
	def envelope
		@envelope ||= @gmail.in_mailbox(@mailbox) { @gmail.imap.uid_fetch(uid, "ENVELOPE")[0].attr["ENVELOPE"] }
	end
	def envelope?
		!! @envelope
	end
	def subject
		@envelope ? @envelope.subject : self.header['Subject'].value
	end
	def from
		@envelope ? @envelope.from : self.header['From'].value
	end
	def to
		@envelope ? @envelope.to : self.header['To'].value
	end

	def has_label?(label)
		return true if @mailbox == @gmail.mailbox(label)
		@gmail.mailbox(label).contains_message?(self.message_id)
		false
	end

	def archived?
		! has_label?(@gmail.inbox_label)
	end

	def starred?
		has_label?(@gmail.starred_label)
	end

	def sent?
		has_label?(@gmail.sent_label)
	end

	def important?
		has_label?(@gmail.important_label)
	end

	def labels
		mbox = @mailbox
		list = [mbox.name]
		@gmail.normal_labels.each do |label|
			next if mbox.name == label
			list << label if has_label?(label)
		end
		list
	end

    # Gmail Operations
    def mark(flag)
      case flag
      when :read
        flag(:Seen)
      when :unread
        unflag(:Seen)
      when :deleted
        flag(:Deleted)
      when :spam
        move_to(@gmail.spam_label)
      end ? true : false
    end

    def delete!
      @mailbox.messages.delete(uid)
      flag(:Deleted)
    end

    def label(name)
	  @mailbox.copy_to(uid, name)
    end

    def label!(name)
      @gmail.in_mailbox(@mailbox) do
        begin
          @gmail.imap.uid_copy(uid, name)
        rescue Net::IMAP::NoResponseError
          # need to create the label first
          @gmail.create_label(name)
          retry
        end
      end
    end

    def remove_label(label)
		return false if label.downcase == @gmail.allmail_label.downcase

		return delete! if label.downcase == @mailbox.name.downcase

		@gmail.in_mailbox(@gmail.label(label)) do |mailbox|
			message = mailbox.emails(['HEADER', 'Message-ID', self.message_id]).first
			if message
				message.delete!
			else
				# Doesn't have label in the first place?
			end
		end
    end

    def move_to(name)
      @mailbox.move_to(uid, name)
    end

	# Archive, in the gmail sense, means remove label Inbox, 
	# rather than simply remove current label
    def archive!
      remove_label(@gmail.inbox_label)
    end

    def save_attachments_to(path=nil)
      attachments.each {|a| a.save_to_file(path) }
    end

	def loaded?
		!! @message
	end

	def set_body(body)
		require 'mail'
		@message = Mail.new(body)
	end

    private
    # Parsed MIME message object
    def message
	  return @message if @message
      require 'mail'
      _body = @gmail.in_mailbox(@mailbox) { @gmail.imap.uid_fetch(uid, "RFC822")[0].attr["RFC822"] }
      @message ||= Mail.new(_body)
    end

    # Delegate all other methods to the Mail message
    def method_missing(*args, &block)
      if block_given?
        message.send(*args, &block)
      else
        message.send(*args)
      end
    end
  end
end
