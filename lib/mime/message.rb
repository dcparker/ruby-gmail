require 'mime/entity'
require 'shared-mime-info'
module MIME
  # A Message is really a MIME::Entity,
  # but should be used for the outermost Entity, because
  # it includes helper methods to access common data
  # from an email message.
  class Message < Entity
    def self.generate
      Message.new('content-type' => 'text/plain', 'mime-version' => '1.0')
    end

    def to(addressee=nil)
      headers['to'] = addressee if addressee
      headers['to'].match(/([A-Z0-9._%+-]+@[A-Z0-9._%+-]+\.[A-Z]+)/i)[1]
    end

    def subject(subj=nil)
      headers['subject'] = subj if subj
      headers['subject']
    end

    def from
      headers['from'].match(/([A-Z0-9._%+-]+@[A-Z0-9._%+-]+\.[A-Z]+)/i)[1]
    end

    def attachments
      find_parts(:content_disposition => 'attachment')
    end

    def text
      part = find_part(:content_type => 'text/plain')
      part.content if part
    end
    def html
      part = find_part(:content_type => 'text/html')
      part.content if part
    end

    def save_attachments_to(path=nil)
      attachments.each {|a| a.save_to_file(path) }
    end

    def generate_multipart(*content_types)
      headers['content-type'] = 'multipart/alternative'
      @content = content_types.collect { |content_type| Entity.new('content-type' => content_type) }
    end

    def attach_file(filename)
      short_filename = filename.match(/([^\\\/]+)$/)[1]

      # Generate the attachment piece
      attachment = Entity.new(
        'content-type' => MIME.check(filename).type + "; \r\n  name=\"#{short_filename}\"",
        'content-disposition' => "attachment; \r\n  filename=\"#{short_filename}\"",
        'content-transfer-encoding' => 'base64'
      )
      attachment.content = File.read(filename)
      
      # Enclose in a top-level multipart/mixed
      if multipart? && multipart_type == 'mixed'
        # If already enclosed, all we have to do is add the attachment part
        (@content ||= []) << attachment
      else
        # Generate the new top-level multipart, transferring what is here already into a child object
        new_content = Entity.new
        # Whatever it is, since it's not multipart/mixed, transfer it into a child object and add the attachment.
        transfer_to(new_content)
        headers.reject! {|k,v| k =~ /content/}
        headers['content-type'] = 'multipart/mixed'
        @content = [new_content, attachment]
      end

      attachment
    end
  end
end
