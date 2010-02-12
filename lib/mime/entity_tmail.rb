require 'tmail'
require 'ietf/rfc2045'
String::ALPHANUMERIC_CHARACTERS = ('a'..'z').to_a + ('A'..'Z').to_a unless defined? String::ALPHANUMERIC_CHARACTERS
def String.random(size)
  length = String::ALPHANUMERIC_CHARACTERS.length
  (0...size).collect { String::ALPHANUMERIC_CHARACTERS[Kernel.rand(length)] }.join
end

module MIME
  def self.capitalize_header(header_name)
    header_name.gsub(/^(\w)/) {|m| m.capitalize}.gsub(/-(\w)/) {|n| '-' + n[1].chr.capitalize}
  end
  class Entity
    def initialize(one=nil,two=nil)
      if one.is_a?(Hash) || two.is_a?(Hash) # Intent is to generate a message from parameters
        @headers = one.is_a?(Hash) ? one : two
        set_content one if one.is_a?(String)
        @encoding = 'quoted-printable' unless encoding
      elsif one.is_a?(String) # Intent is to parse a message body
        @raw = one.gsub(/\r/,'').gsub(/\n/, "\r\n") # normalizes end-of-line characters
        @tmail = TMail::Mail.parse(@raw)
        from_tmail(@tmail)
      elsif one.is_a?(TMail::Mail)
        @tmail = one
        from_tmail(@tmail)
      end
    end

    def inspect
      "<#{self.class.name}##{object_id} Headers:{#{headers.collect {|k,v| "#{k}=#{v}"}.join(' ')}} content:#{multipart? ? 'multipart' : 'flat'}>"
    end

    # This means we have a structure from IETF::RFC2045.
    # Entity is: [headers, content], while content may be an array of Entities.
    # Or, {:type, :boundary, :content}
    def from_parsed(parsed)
      case parsed
      when Array
        if parsed[0].is_a?(Hash) && (parsed[1].is_a?(Hash) || parsed[1].is_a?(String))
          @headers = parsed[0]
          @content = parsed[1].is_a?(Hash) ? parsed[1][:content].collect {|p| Entity.new.from_parsed(p)} : parsed[1]
          if parsed[1].is_a?(Hash)
            @multipart_type = parsed[1][:type]
            @multipart_boundary = parsed[1][:boundary]
            raise "IETF PARSING FAIL! (empty boundary)" if @multipart_boundary == ''
          end
        else
          raise "IETF PARSING FAIL! ('A' structure)"
        end
        return self
      when Hash
        if parsed.has_key?(:type) && parsed.has_key?(:boundary) && parsed.has_key?(:content)
          @content = parsed[:content].is_a?(Array) ? parsed[:content].collect {|p| Entity.new.from_parsed(p)} : parsed[:content]
        else
          raise "IETF PARSING FAIL! ('H' structure)"
        end
        return self
      end
      raise ArgumentError, "Must pass in either: [an array with two elements: headers(hash) and content(string or array)] OR [a hash containing :type, :boundary, and :content(being the former or a string)]"
    end
    def from_tmail(tmail)
      raise ArgumentError, "Expecting a TMail::Mail object." unless tmail.is_a?(TMail::Mail)
      @headers ||= Hash.new {|h,k| @tmail.header[k].to_s }
      if multipart?
        @content = @tmail.parts.collect { |tpart| Entity.new.from_tmail(tpart) }
      else
        set_content @tmail.body # TMail has already decoded it, but we need it still encoded
      end
    end

    ##############
    # ATTRIBUTES #

    # An Entity has Headers.
    def headers
      @headers ||= {}
    end
    # An Entity has Content.
    #   IF the Content-Type is a multipart type,
    #   the content will be one or more Entities.
    attr_reader :content, :multipart_type

    #################
    # Macro Methods #

    def multipart?
      @tmail.multipart?
      # !!(headers['content-type'] =~ /multipart\//) if headers['content-type']
    end
    def multipart_type
      if headers['content-type'] =~ /multipart\/(\w+)/
        $1
      end if headers['content-type']
    end
    # Auto-generates a boundary if one doesn't yet exist.
    def multipart_boundary
      return nil unless multipart?
      unless @multipart_boundary ||= (@tmail && @tmail.header['content-type'] ? @tmail.header['content-type'].params['boundary'] : nil)
        # Content-Type: multipart/mixed; boundary=000e0cd28d1282f4ba04788017e5
        @multipart_boundary = String.random(25)
        headers['content-type'] = "multipart/#{multipart_type}; boundary=#{@multipart_boundary}"
        @multipart_boundary
      end
      @multipart_boundary
    end
    def attachment?
      @tmail.disposition_is_attachment? || headers['content-disposition'] =~ /^form-data;.* filename=[\"\']?[^\"\']+[\"\']?/ if headers['content-disposition']
    end
    alias :file? :attachment?
    def part_filename
      # Content-Disposition: attachment; filename="summary.txt"
      if headers['content-disposition'] =~ /; filename=[\"\']?([^\"\']+)/
        $1
      end if headers['content-disposition']
    end

    def encoding
      @encoding ||= headers['content-transfer-encoding'] || nil
    end
    # Re-encodes content if necessary when a new encoding is set
    def encoding=(new_encoding)
      raw_content = decoded_content # nil if multipart
      @encoding = new_encoding
      set_content(raw_content) if raw_content # skips if multipart
      @encoding
    end
    alias :set_encoding :encoding=

    def find_part(options)
      find_parts(options,true).first
    end
    def find_parts(options,find_only_one=false)
      parts = []
      return nil unless (options[:content_type] && headers['content-type']) || (options[:content_disposition] && headers['content-disposition'])
        # Do I match your search?
        iam = true
        iam = false if options[:content_type] && headers['content-type'] !~ /^#{options[:content_type]}(?=;|$)/
        iam = false if options[:content_disposition] && headers['content-disposition'] !~ /^#{options[:content_disposition]}(?=;|$)/
        parts << self if iam
        return parts unless parts.empty?
        # Do any of my children match your search?
        content.each do |part|
          parts.concat part.find_parts(options,find_only_one)
          return parts if !parts.empty? && find_only_one
        end if multipart?
      return parts
    end

    def save_to_file(path=nil)
      filename = path if path && !File.exists?(path) # If path doesn't exist, assume it's a filename
      filename ||= path + '/' + part_filename if path && attachment? # If path does exist, and we're saving an attachment, use the attachment filename
      filename ||= (attachment? ? part_filename : path) # If there is no path and we're saving an attachment, use the attachment filename; otherwise use path (whether it is present or not)
      filename ||= '.' # No path supplied, and not saving an attachment. We'll just save it in the current directory.
      if File.directory?(filename)
        i = 0
        begin
          i += 1
          filename = filename + "/attachment-#{i}"
        end until !File.exists(filename)
      end
      # After all that trouble to get a filename to save to...
      File.open(filename, 'w') do |file|
        file << decoded_content
      end
    end

    ##########################
    # CONVERTING / RENDERING #

    # Renders this data structure into a string, encoded
    def to_s
      multipart_boundary # initialize the boundary if necessary, so it will be included in the headers
      headers.inject('') {|a,(k,v)| a << "#{MIME.capitalize_header(k)}: #{v}\r\n"} + "\r\n" + if content.is_a?(Array)
        "\r\n--#{multipart_boundary}\r\n" + content.collect {|part| part.to_s }.join("\r\n--#{multipart_boundary}\r\n") + "\r\n--#{multipart_boundary}--\r\n"
      else
        content.to_s
      end
    end

    # Converts this data structure into a string, but decoded if necessary
    def decoded_content
      return nil if @content.is_a?(Array)
      case encoding.to_s.downcase
      when 'quoted-printable'
        @content.unpack('M')[0]
      when 'base64'
        @content.unpack('m')[0]
      # when '7bit'
      #   # should get this 7bit encoding done too...
      else
        @content
      end
    end

    # You can set new content, and it will be saved in encoded form.
    def set_content(raw)
      @content = raw.is_a?(Array) ? raw :
        case encoding.to_s.downcase
        when 'quoted-printable'
          [raw].pack('M')
        when 'base64'
          [raw].pack('m')
        else
          raw
        end
    end
    alias :content= :set_content

    private
      def transfer_to(other)
        other.instance_variable_set(:@content, @content.dup) if @content
        other.headers.clear
        other.headers.merge!(Hash[*headers.dup.select {|k,v| k =~ /content/}.flatten])
      end

  end
end
