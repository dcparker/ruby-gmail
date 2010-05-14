require "openssl"
require "net/smtp"

Net::SMTP.class_eval do
  
  def self.start( address, port = nil,
                  helo = 'localhost.localdomain',
                  user = nil, secret = nil, authtype = nil, use_tls = false,
                  &block) # :yield: smtp
    new(address, port).start(helo, user, secret, authtype, use_tls, &block)
  end

  def start( helo = 'localhost.localdomain',
             user = nil, secret = nil, authtype = nil ) # :yield: smtp
    start_method = starttls_auto? ? :do_tls_start : :do_start
    if block_given?
      begin
        send(start_method, helo, user, secret, authtype)
        return yield(self)
      ensure
        do_finish
      end
    else
      send(start_method, helo, user, secret, authtype)
      return self
    end
  end

  private
  
  def do_tls_start(helodomain, user, secret, authtype)
    raise IOError, 'SMTP session already started' if @started
    if RUBY_VERSION == '1.8.6'
      check_auth_args(user, secret, authtype) if user or secret
    else
      check_auth_args(user, secret) if user or secret
    end

    sock = timeout(@open_timeout) { TCPSocket.open(@address, @port) }
    @socket = Net::InternetMessageIO.new(sock)
    @socket.read_timeout = 60 #@read_timeout
    @socket.debug_output = STDERR #@debug_output

    check_response(critical { recv_response() })
    do_helo(helodomain)

    raise 'openssl library not installed' unless defined?(OpenSSL)
    starttls
    ssl = OpenSSL::SSL::SSLSocket.new(sock)
    ssl.sync_close = true
    ssl.connect
    @socket = Net::InternetMessageIO.new(ssl)
    @socket.read_timeout = 60 #@read_timeout
    @socket.debug_output = STDERR #@debug_output
    do_helo(helodomain)

    authenticate user, secret, authtype if user
    @started = true
  ensure
    unless @started
      # authentication failed, cancel connection.
        @socket.close if not @started and @socket and not @socket.closed?
      @socket = nil
    end
  end

  def do_helo(helodomain)
     begin
      if @esmtp
        ehlo helodomain
      else
        helo helodomain
      end
    rescue Net::ProtocolError
      if @esmtp
        @esmtp = false
        @error_occured = false
        retry
      end
      raise
    end
  end

  def starttls
    getok('STARTTLS')
  end

  def quit
    begin
      getok('QUIT')
    rescue EOFError, OpenSSL::SSL::SSLError
    end
  end
end