module IETF
  CRLF = /\r\n/ # We can be a little lax about those carriage-returns.
  TEXT = /.+?(?=#{CRLF.source}|$)/
  HTAB = Regexp.new(11.chr)
  LWSP_CHAR = /[ \t#{HTAB.source}]/
  CTL = Regexp.new([(0...37).to_a,177].flatten.map {|i| i.chr}.join)
  FIELD_BODY = /#{TEXT.source}(?:#{CRLF.source}#{LWSP_CHAR.source}#{TEXT.source})*/
  FIELD_NAME = /^[^#{CTL.source} :]+/
  FIELD = /(#{FIELD_NAME.source}):\s*(#{FIELD_BODY.source})/
  module RFC822
    def self.parse_rfc822_from(raw)
      headers = {}
      # Parse out rfc822 (headers)
      head, remaining_raw = raw.split(/#{CRLF.source}#{CRLF.source}/,2)
      head.scan(FIELD) do |field_name, field_body|
        headers[field_name.downcase] = field_body
      end
      return [headers, remaining_raw]
    end
  end
end
