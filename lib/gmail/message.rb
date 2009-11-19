require 'mime/message'
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
      @uid ||= @gmail.imap.uid_search(['HEADER', 'Message-ID', message_id])[0]
    end
    def message_id
      @message_id || begin
        @gmail.in_mailbox(@mailbox) do
          @message_id = @gmail.imap.uid_fetch(@uid, ['ENVELOPE'])[0].attr['ENVELOPE'].message_id
        end
      end
      @message_id
    end
    def body
      @body ||= @gmail.in_mailbox(@mailbox) do
        @gmail.imap.uid_fetch(uid, "RFC822")[0].attr["RFC822"]
      end
    end

    # Parsed MIME message object
    def message
      @message ||= MIME::Message.new(body)
    end

    # IMAP Operations
    def flag(flg)
      @gmail.in_mailbox(@mailbox) do
        @gmail.imap.uid_store(uid, "+FLAGS", [flg])
      end
    end
    def unflag(flg)
      @gmail.in_mailbox(@mailbox) do
        @gmail.imap.uid_store(uid, "-FLAGS", [flg])
      end
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
        move_to('[Gmail]/Spam')
      end
    end
    def delete!
      @mailbox.messages.delete(uid)
      flag(:Deleted)
    end
    def label(name)
      @gmail.in_mailbox(@mailbox) do
        @gmail.imap.uid_copy(uid, name)
      end
    end
    # We're not sure of any 'labels' except the 'mailbox' we're in at the moment.
    # Research whether we can find flags that tell which other labels this email is a part of.
    # def remove_label(name)
    # end
    def move_to(name)
      label(name) && delete!
    end
    def archive!
      move_to('[Gmail]/All Mail')
    end
  end
end
