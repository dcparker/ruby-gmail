require 'test_helper'

class GmailTest < Test::Unit::TestCase
  def test_initialize
    imap = mock('imap')
    Net::IMAP.expects(:new).with('imap.gmail.com', 993, true, nil, false).returns(imap)
    gmail = Gmail.new('test', 'password')
  end
  
  def test_imap_does_login
    setup_mocks(:at_exit => true)

    @imap.expects(:disconnected?).at_least_once.returns(true).then.returns(false)
    @imap.expects(:login).with('test@gmail.com', 'password')
    @gmail.imap
  end

  def test_imap_does_login_only_once
    setup_mocks(:at_exit => true)

    @imap.expects(:disconnected?).at_least_once.returns(true).then.returns(false)
    @imap.expects(:login).with('test@gmail.com', 'password')
    @gmail.imap
    @gmail.imap
    @gmail.imap
  end

  def test_imap_does_login_without_appending_gmail_domain
    setup_mocks(:at_exit => true)

    @imap.expects(:disconnected?).at_least_once.returns(true).then.returns(false)
    @imap.expects(:login).with('test@gmail.com', 'password')
    @gmail.imap
  end
  
  def test_imap_logs_out
    setup_mocks(:at_exit => true)

    @imap.expects(:disconnected?).at_least_once.returns(true).then.returns(false)
    @imap.expects(:login).with('test@gmail.com', 'password')
    @gmail.imap
    @imap.expects(:logout).returns(true)
    @gmail.logout
  end

  def test_imap_logout_does_nothing_if_not_logged_in
    setup_mocks

    @imap.expects(:disconnected?).returns(true)
    @imap.expects(:logout).never
    @gmail.logout
  end
  
  def test_imap_calls_create_label
    setup_mocks(:at_exit => true)
    @imap.expects(:disconnected?).at_least_once.returns(true).then.returns(false)
    @imap.expects(:login).with('test@gmail.com', 'password')
    @imap.expects(:create).with('foo')
    @gmail.create_label('foo')
  end
  
  private
  def setup_mocks(options = {})
    options = {:at_exit => false}.merge(options)
    @imap = mock('imap')
    Net::IMAP.expects(:new).with('imap.gmail.com', 993, true, nil, false).returns(@imap)
    @gmail = Gmail.new('test@gmail.com', 'password')
    
    # need this for the at_exit block that auto-exits after this test method completes
    @imap.expects(:logout).at_least(0) if options[:at_exit]
  end
end