require 'ietf/rfc822'
module IETF
  module RFC2045
    def self.parse_rfc2045_from(raw)
      headers, raw = IETF::RFC822.parse_rfc822_from(raw)

      if headers['content-type'] =~ /multipart\/(\w+); boundary=([\"\']?)(.*)\2?/
        content = {}
        content[:type] = $1
        content[:boundary] = $3
        content[:content] = IETF::RFC2045.parse_rfc2045_content_from(raw, content[:boundary])
      else
        content = raw
      end

      return [headers, content]
    end

    def self.parse_rfc2045_content_from(raw, boundary)
      parts = ("\r\n" + raw).split(/#{CRLF.source}--#{boundary}(?:--)?(?:#{CRLF.source}|$)/)
      parts.reject! {|p| p.gsub(/^[ \r\n#{HTAB}]?$/,'') == ''} # Remove any parts that are blank
      puts "[RFC2045] PARTS:\n\t#{parts.map {|p| p.gsub(/\n/,"\n\t")}.join("\n---\n\t")}" if $DEBUG
      parts.collect {|part|
        puts "[RFC2045] Parsing PART with boundary #{boundary.inspect}:\n\t#{part.gsub(/\n/,"\n\t")}" if $DEBUG
        IETF::RFC2045.parse_rfc2045_from(part)
      }
    end
  end
end
